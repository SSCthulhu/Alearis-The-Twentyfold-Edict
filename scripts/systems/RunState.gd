extends Node
class_name RunState

signal dice_changed(min_value: int, max_value: int, current_roll: int)
signal relics_changed()

const SAVE_PATH: String = "user://meta_save.json"

var meta_next_start_value: int = 10

# Persistent starting dice range (saved between game sessions)
var starting_dice_min: int = 10
var starting_dice_max: int = 10

var run_seed: int = 0
var world_index: int = 1
var floor_index: int = 1

var dice_min: int = 10
var dice_max: int = 10
var last_roll: int = 10

# WORLD-scoped modifier ids for UI/debug
var applied_modifier_ids: Array[StringName] = []

@export var dice_hard_min: int = 1
@export var dice_hard_max: int = 20

# DEBUG ONLY: Modifier injector (safe to disable for release).
# Toggle this off for release builds and the injector becomes inert.
@export var debug_modifier_injector_enabled: bool = false
@export var debug_modifier_injector_log_actions: bool = false
@export_group("Performance Diagnostics")
@export var perf_diag_enabled: bool = true
@export var perf_diag_spike_ms_threshold: float = 28.0
@export var perf_diag_report_cooldown_sec: float = 2.0
@export var perf_diag_startup_grace_sec: float = 12.0
@export var perf_diag_use_warning_logs: bool = false
@export var perf_diag_minor_spike_ms_threshold: float = 12.5
@export var perf_diag_sample_window_sec: float = 0.5
@export var perf_diag_min_spikes_to_report: int = 2
@export var frame_pacing_fps_cap_enabled: bool = true
@export var frame_pacing_fps_cap_value: int = 165

# Optional: control warning spam for new/unmapped ids
@export var warn_on_unknown_effects: bool = false
var _unknown_effects_warned: Dictionary = {} # StringName -> true
var _debug_modifier_cycle_index: Dictionary = {} # String -> int
var _debug_toast_layer: CanvasLayer = null
var _debug_toast_label: Label = null
var _debug_toast_time_left: float = 0.0
var _perf_diag_report_cd_left: float = 0.0
var _perf_diag_uptime_sec: float = 0.0
var _perf_diag_window_left: float = 0.0
var _perf_diag_window_samples: int = 0
var _perf_diag_window_spikes_minor: int = 0
var _perf_diag_window_spikes_major: int = 0
var _perf_diag_window_peak_ms: float = 0.0

const DEBUG_MINOR_BOONS: Array[StringName] = [
	&"s_steady_hands", &"s_guarded_footing", &"s_orb_attunement", &"s_skybound_step",
	&"s_combat_focus", &"s_vampiric_thread", &"s_burst_runner", &"s_lucky_spark"
]
const DEBUG_MAJOR_BOONS: Array[StringName] = [
	&"m_ironblood", &"m_flow_engine", &"m_warded_soul", &"m_ritual_of_stability",
	&"m_kinetic_overdrive", &"m_orb_mastery", &"m_battle_hymn", &"m_fated_reservoir"
]
const DEBUG_MINOR_PERILS: Array[StringName] = [
	&"p_blood_moon", &"p_siege_lines", &"p_loaded_momentum", &"p_gravity_flux",
	&"p_ruthless_hunt", &"p_hemorrhage_doctrine", &"p_velocity_collapse", &"p_volatile_siphon"
]
const DEBUG_MAJOR_PERILS: Array[StringName] = [
	&"x_apex_predators", &"x_no_safe_space", &"x_edge_of_ambition", &"x_execution_order",
	&"x_dice_vice", &"x_predators_edge", &"x_blood_tax", &"x_skull_standard"
]

# -----------------------------
# RUN-LONG relic inventory
# -----------------------------
const MAX_RELICS: int = 3
var owned_relic_ids: Array[StringName] = [] # persists across World1->World3->Final, resets on new run

func can_add_relic() -> bool:
	return owned_relic_ids.size() < MAX_RELICS

func has_relic(id: StringName) -> bool:
	return owned_relic_ids.has(id)

func add_relic(id: StringName) -> bool:
	if id == &"":
		return false
	if has_relic(id):
		return false
	if not can_add_relic():
		return false
	owned_relic_ids.append(id)
	relics_changed.emit()
	return true

func apply_relic_by_id(id: StringName) -> bool:
	# VictoryUI calls this (or add_relic directly). Keep it as a stable API.
	return add_relic(id)

func clear_relics() -> void:
	owned_relic_ids.clear()
	relics_changed.emit()

func get_owned_relic_ids() -> Array[StringName]:
	return owned_relic_ids.duplicate()

func remove_relic(id: StringName) -> bool:
	var i := owned_relic_ids.find(id)
	if i == -1:
		return false
	owned_relic_ids.remove_at(i)
	relics_changed.emit()
	return true

func set_relics(ids: Array[StringName]) -> void:
	owned_relic_ids = ids.duplicate()
	relics_changed.emit()

# -----------------------------
# E1 Loaded Fate (player chooses reward roll once per world)
# -----------------------------
const RELIC_LOADED_FATE: StringName = &"e1_loaded_fate"

# -1 means "no forced roll set"
var forced_reward_roll: int = -1

func is_loaded_fate_available_this_world() -> bool:
	return has_relic(RELIC_LOADED_FATE) and (not relic_loaded_fate_used_this_world)

func set_forced_reward_roll(v: int) -> void:
	# v < 0 clears
	if v < 0:
		forced_reward_roll = -1
		return
	_clamp_and_fix()
	forced_reward_roll = clampi(v, dice_min, dice_max)

func consume_loaded_fate_roll(chosen_roll: int) -> int:
	# Clamp, set forced roll, mark used for this world.
	_clamp_and_fix()
	var r: int = clampi(chosen_roll, dice_min, dice_max)
	forced_reward_roll = r
	relic_loaded_fate_used_this_world = true
	return r

# -----------------------------
# Victory relic roll determinism helpers
# -----------------------------
func make_rng_for_victory_relic_choices() -> RandomNumberGenerator:
	# Backwards-compatible default: uses last_roll.
	return make_rng_for_victory_relic_choices_for_roll(last_roll)

func make_rng_for_victory_relic_choices_for_roll(reward_roll: int) -> RandomNumberGenerator:
	# Deterministic per-run + per-world + per-floor + reward roll.
	# (So reopening VictoryUI gives the same options for the same roll.)
	return make_rng_for_domain(&"victory_relic_choices", reward_roll)

func make_rng_for_domain(domain: StringName, extra: int = 0) -> RandomNumberGenerator:
	# Single deterministic RNG factory for gameplay roll domains.
	# Domain examples: "modifier_options", "victory_reward_roll", "final_boss_selection".
	var rng := RandomNumberGenerator.new()
	var s: int = _compute_domain_seed(domain, extra)
	rng.seed = s
	return rng

func roll_for_domain_in_range(domain: StringName, min_value: int, max_value: int, extra: int = 0) -> int:
	var lo: int = mini(min_value, max_value)
	var hi: int = maxi(min_value, max_value)
	lo = clampi(lo, dice_hard_min, dice_hard_max)
	hi = clampi(hi, dice_hard_min, dice_hard_max)
	var rng: RandomNumberGenerator = make_rng_for_domain(domain, extra)
	return rng.randi_range(lo, hi)

func roll_for_domain_in_current_range(domain: StringName, extra: int = 0) -> int:
	var rng: RandomNumberGenerator = make_rng_for_domain(domain, extra)
	return roll_in_range(rng)

func _compute_domain_seed(domain: StringName, extra: int = 0) -> int:
	_clamp_and_fix()
	var s: int = int(run_seed)
	s = _mix_seed(s, world_index)
	s = _mix_seed(s, floor_index)
	s = _mix_seed(s, dice_min)
	s = _mix_seed(s, dice_max)
	s = _mix_seed(s, last_roll)
	s = _mix_seed(s, int(hash(String(domain))))
	s = _mix_seed(s, extra)
	return s

func _mix_seed(base: int, value: int) -> int:
	var s: int = base
	s = int(s ^ (value + 0x9E3779B9 + (s << 6) + (s >> 2)))
	return s

func get_target_relic_band_from_last_roll() -> int:
	# Backwards-compatible default: uses last_roll.
	return get_target_relic_band_from_roll(last_roll)

func get_target_relic_band_from_roll(reward_roll: int) -> int:
	# Simple heuristic you can tune:
	# Low rolls -> SURVIVAL, mid -> CORE, high -> GREED/DAMAGE
	if reward_roll <= 8:
		return int(RelicData.Band.SURVIVAL)
	if reward_roll <= 14:
		return int(RelicData.Band.CORE)
	return int(RelicData.Band.GREED_DAMAGE)

# -----------------------------
# Victory reward roll (for relic band selection)
# -----------------------------
func get_victory_reward_roll() -> int:
	# If Loaded Fate forced a roll, use it (clamped to current range).
	_clamp_and_fix()

	if forced_reward_roll >= dice_min and forced_reward_roll <= dice_max:
		last_roll = forced_reward_roll
		return last_roll

	# Otherwise: deterministic RNG roll in range.
	var rng: RandomNumberGenerator = make_rng_for_domain(&"victory_reward_roll", last_roll)
	last_roll = rng.randi_range(dice_min, dice_max)
	return last_roll

# -----------------------------
# Relic-driven knobs (RUN-LONG)
# These are computed/used by RelicEffectsPlayer + controllers
# -----------------------------
var relic_damage_mult: float = 1.0
var relic_damage_taken_mult: float = 1.0
var relic_attack_speed_mult: float = 1.0

var relic_bleed_damage_mult: float = 1.0

var relic_roll_max_charges_bonus: int = 0
var relic_roll_recharge_mult: float = 1.0 # < 1 faster, > 1 slower
var relic_dice_meter_charge_mult: float = 1.0

var relic_defend_duration_bonus: float = 0.0

var relic_orb_charge_mult_bonus: float = 1.0

var relic_ultimate_gain_mult: float = 1.0 # used as cooldown divisor in your current system

# Encounter-related flags
var relic_orb_surge_active: bool = false
var relic_loaded_fate_used_this_world: bool = false

# -----------------------------
# Gameplay modifiers (WORLD-scoped currently)
# -----------------------------
var enemy_damage_mult: float = 1.0
var enemy_health_mult: float = 1.0
var enemy_projectile_speed_mult: float = 1.0
var enemy_crit_chance_add: float = 0.0
var enemy_crit_damage_mult: float = 1.0
var player_damage_mult: float = 1.0
var player_health_mult: float = 1.0
var player_move_speed_mult: float = 1.0
var player_jump_height_mult: float = 1.0
var player_gravity_mult: float = 1.0
var player_flux_jump_height_mult: float = 1.0
var player_attack_speed_mult: float = 1.0

# World-scoped effects list (flags)
var world_effects: Array[StringName] = []

var hazard_rise_mult: float = 1.0
var healing_mult: float = 1.0
var cooldown_mult: float = 1.0
var ultimate_cooldown_mult: float = 1.0
var orb_charge_mult: float = 1.0
var loot_quality_bonus: float = 0.0
var shop_price_mult: float = 1.0
var extra_shop_slots: int = 0
var free_shop_rerolls: int = 0
var rare_relic_bonus: float = 0.0
var elites_to_spawn_bonus: int = 0
var elites_per_floor_bonus: int = 0

# World-scoped flags (recognized ids you may reference elsewhere)
var perfect_step_enabled: bool = false
var clean_cuts_enabled: bool = false
var ritual_of_stability_enabled: bool = false
var _ritual_last_floor_healed: int = 0
var loaded_momentum_enabled: bool = false
var loaded_momentum_stacks: int = 0
var vampiric_thread_enabled: bool = false
var edge_of_ambition_enabled: bool = false
var _edge_of_ambition_time_left: float = 0.0
var gravity_flux_enabled: bool = false
var _gravity_flux_timer: float = 10.0
var _gravity_flux_phase: int = 0
var _base_player_move_speed_mult: float = 1.0
var _base_player_attack_speed_mult: float = 1.0
var hemorrhage_doctrine_enabled: bool = false
var _hemorrhage_stacks: int = 0
var _hemorrhage_time_left: float = 0.0
var _hemorrhage_tick_left: float = 1.0
var velocity_collapse_enabled: bool = false
var _velocity_collapse_phase: int = 0
var _velocity_collapse_timer: float = 12.0
var _burst_runner_enabled: bool = false
var _burst_runner_time_left: float = 0.0
var blood_tax_enabled: bool = false
var _blood_tax_tick_left: float = 8.0
var _suppress_modifier_damage_callback: bool = false
var lucky_spark_enabled: bool = false
var volatile_siphon_enabled: bool = false
var battle_hymn_enabled: bool = false
var fated_reservoir_enabled: bool = false
var _battle_hymn_time_left: float = 0.0
var _volatile_siphon_time_left: float = 0.0
var _fated_reservoir_stacks: int = 0

func _ready() -> void:
	load_meta()
	_apply_frame_pacing_cap()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	if debug_modifier_injector_enabled and debug_modifier_injector_log_actions:
		print("[RunState][Debug Modifier Injector] Enabled. Keys: 6=Clear, 7=Minor Boon, 8=Major Boon, 9=Minor Peril, 0=Major Peril (top row or numpad).")

func _process(delta: float) -> void:
	_tick_dynamic_world_effects(delta)
	_tick_debug_toast(delta)
	_tick_perf_diag(delta)

func _get_dice_meter_singleton() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DiceMeterSingleton")

func _input(event: InputEvent) -> void:
	if not debug_modifier_injector_enabled:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or (not key_event.pressed) or key_event.echo:
		return
	# Hotkeys:
	# 6 = clear world modifiers
	# 7 = apply next Minor Boon (-1)
	# 8 = apply next Major Boon (-2)
	# 9 = apply next Minor Peril (+1)
	# 0 = apply next Major Peril (+2)
	if _debug_event_matches_keys(key_event, [KEY_6, KEY_KP_6]):
		clear_world_modifiers()
		_emit()
		_debug_modifier_log("Cleared all world modifiers")
		return
	if _debug_event_matches_keys(key_event, [KEY_7, KEY_KP_7]):
		_debug_apply_next_modifier("minor_boon", DEBUG_MINOR_BOONS, -1)
		return
	if _debug_event_matches_keys(key_event, [KEY_8, KEY_KP_8]):
		_debug_apply_next_modifier("major_boon", DEBUG_MAJOR_BOONS, -2)
		return
	if _debug_event_matches_keys(key_event, [KEY_9, KEY_KP_9]):
		_debug_apply_next_modifier("minor_peril", DEBUG_MINOR_PERILS, +1)
		return
	if _debug_event_matches_keys(key_event, [KEY_0, KEY_KP_0]):
		_debug_apply_next_modifier("major_peril", DEBUG_MAJOR_PERILS, +2)
		return

func _debug_event_matches_keys(event: InputEventKey, keys: Array[int]) -> bool:
	for k: int in keys:
		if event.keycode == k or event.physical_keycode == k:
			return true
	return false

func _debug_apply_next_modifier(pool_key: String, pool: Array[StringName], value: int) -> void:
	if pool.is_empty():
		return
	var idx: int = int(_debug_modifier_cycle_index.get(pool_key, 0))
	if idx < 0:
		idx = 0
	var effect_id: StringName = pool[idx % pool.size()]
	_debug_modifier_cycle_index[pool_key] = (idx + 1) % pool.size()
	apply_floor_modifier_payload(value, effect_id, &"")
	var label: String = _debug_modifier_label(effect_id)
	var desc: String = _debug_modifier_description(effect_id)
	_debug_modifier_log("Applied %s (%+d)\n%s" % [label, value, desc])

func _debug_modifier_label(id: StringName) -> String:
	var s: String = String(id)
	for p in ["s_", "m_", "p_", "x_", "b_", "d_", "g_", "bg_"]:
		if s.begins_with(p):
			s = s.substr(p.length())
			break
	s = s.replace("_", " ")
	var words: PackedStringArray = s.split(" ", false)
	for i in range(words.size()):
		var w: String = words[i]
		if w.length() > 0:
			words[i] = w.left(1).to_upper() + w.substr(1)
	return " ".join(words)

func _debug_modifier_description(id: StringName) -> String:
	match id:
		&"s_steady_hands": return "-10% Cooldowns"
		&"s_guarded_footing": return "+8% Damage, -6% Enemy Damage"
		&"s_orb_attunement": return "+20% Orb Charge, -5% Cooldowns"
		&"s_skybound_step": return "+12% Jump Height, +8% Move Speed"
		&"s_combat_focus": return "+10% Damage, -8% Enemy Health"
		&"s_vampiric_thread": return "Heal 2 HP on kill (4 HP on elite kill)"
		&"s_burst_runner": return "Enemy kills grant +20% Move Speed for 2.5s"
		&"s_lucky_spark": return "Elite kills heal 6% Max HP, -3% Cooldowns"
		&"m_ironblood": return "+20% Max HP, -10% Enemy Damage"
		&"m_flow_engine": return "-25% Cooldowns, -10% Ultimate Cooldown"
		&"m_warded_soul": return "Heal 12% Max HP now, +15% Orb Charge, -6% Enemy Damage"
		&"m_ritual_of_stability": return "Heal 10% now, then 8% Max HP each floor"
		&"m_kinetic_overdrive": return "+15% Move Speed, +18% Jump Height, +12% Attack Speed"
		&"m_orb_mastery": return "+30% Orb Charge, +8% Damage"
		&"m_battle_hymn": return "Perfect Dodge: +30% Attack Speed, +15% Move Speed (3.5s), heal 2%, -8% Cooldowns"
		&"m_fated_reservoir": return "Each floor: heal 6%, +4% Damage and -3% Cooldowns (max 4), +10% Orb Charge"
		&"p_blood_moon": return "Enemies +12% Damage, +10% Health"
		&"p_siege_lines": return "Enemies +18% Projectile Speed, +5% Damage"
		&"p_loaded_momentum": return "+2% Damage per kill (max +20%) until hit, Enemies +8% Damage"
		&"p_gravity_flux": return "Gravity cycles to moon-bounce mode, Enemies +10% Damage"
		&"p_ruthless_hunt": return "+1 Elite Spawn, Enemies +8% Damage"
		&"p_hemorrhage_doctrine": return "Enemy hits apply stacking bleed (up to 3), Enemies +10% Damage"
		&"p_velocity_collapse": return "Move Speed cycles: normal -> -30% -> +20%, Enemies +8% Damage"
		&"p_volatile_siphon": return "Kills drain 1% HP (non-lethal), grant +10% Attack Speed (3s), Enemies +8% Damage"
		&"x_apex_predators": return "Enemies +20% Damage, +18% Health, +1 Elite"
		&"x_no_safe_space": return "Enemies +30% Projectile Speed, +15% Damage"
		&"x_edge_of_ambition": return "Enemies +25% Damage, Perfect Dodge grants +20% Attack Speed (3s)"
		&"x_execution_order": return "+2 Elite Spawns, Enemies +12% Damage, +10% Health"
		&"x_dice_vice": return "Enemies +18% Damage, +18% Cooldowns, -10% Orb Charge"
		&"x_predators_edge": return "Enemy hits can crit (+10% chance, +35% crit damage), Enemies +10% Damage"
		&"x_blood_tax": return "Lose 1.5% Max HP every 8s (non-lethal), Enemies +12% Damage"
		&"x_skull_standard": return "+1 Elite each combat floor, Enemies +10% Damage and +10% Health"
		_:
			return "Effect active"

func _debug_modifier_log(msg: String) -> void:
	_show_debug_toast(msg)
	if not debug_modifier_injector_log_actions:
		return
	print("[RunState][Debug Modifier Injector] %s" % msg)

func _tick_perf_diag(delta: float) -> void:
	if not perf_diag_enabled:
		return
	_perf_diag_uptime_sec += maxf(delta, 0.0)
	if _perf_diag_uptime_sec < maxf(perf_diag_startup_grace_sec, 0.0):
		return

	if _perf_diag_window_left <= 0.0:
		_perf_diag_window_left = maxf(perf_diag_sample_window_sec, 0.1)
		_perf_diag_window_samples = 0
		_perf_diag_window_spikes_minor = 0
		_perf_diag_window_spikes_major = 0
		_perf_diag_window_peak_ms = 0.0

	if _perf_diag_report_cd_left > 0.0:
		_perf_diag_report_cd_left = maxf(_perf_diag_report_cd_left - delta, 0.0)
	var frame_ms: float = delta * 1000.0
	_perf_diag_window_samples += 1
	_perf_diag_window_peak_ms = maxf(_perf_diag_window_peak_ms, frame_ms)

	var major_thresh: float = maxf(perf_diag_spike_ms_threshold, 1.0)
	var minor_thresh: float = clampf(perf_diag_minor_spike_ms_threshold, 1.0, major_thresh)
	if frame_ms >= major_thresh:
		_perf_diag_window_spikes_major += 1
	if frame_ms >= minor_thresh:
		_perf_diag_window_spikes_minor += 1

	_perf_diag_window_left = maxf(_perf_diag_window_left - delta, 0.0)
	if _perf_diag_window_left > 0.0:
		return

	var should_report: bool = false
	if _perf_diag_window_spikes_major > 0:
		should_report = true
	elif _perf_diag_window_spikes_minor >= maxi(perf_diag_min_spikes_to_report, 1):
		should_report = true
	if not should_report:
		return
	if _perf_diag_report_cd_left > 0.0:
		return
	_perf_diag_report_cd_left = maxf(perf_diag_report_cooldown_sec, 0.1)
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var scene_name: String = "<none>"
	if tree.current_scene != null:
		scene_name = String(tree.current_scene.name)
	# NOTE: group "enemies" typically includes hurtboxes, not AI roots.
	# Keep it for reference but label it clearly.
	var enemy_hurtboxes_count: int = tree.get_nodes_in_group("enemies").size()
	var floor5_count: int = tree.get_nodes_in_group("floor5_enemies").size()
	var subarena_count: int = tree.get_nodes_in_group("subarena_enemies").size()
	var rocks_count: int = tree.get_nodes_in_group("orb_flight_rocks").size()
	var active_rocks_count: int = 0
	var rocks: Array[Node] = tree.get_nodes_in_group("orb_flight_rocks")
	for r: Node in rocks:
		if r != null and is_instance_valid(r) and r.has_method("is_active") and bool(r.call("is_active")):
			active_rocks_count += 1
	var floor_number: int = -1
	var floor_enemies_left: int = -1
	var floor_ctrl: Node = tree.get_first_node_in_group("floor_progression")
	if floor_ctrl == null and tree.current_scene != null:
		floor_ctrl = tree.current_scene.find_child("FloorProgressionController", true, false)
	if floor_ctrl != null:
		if floor_ctrl.has_method("get_current_floor_number"):
			floor_number = int(floor_ctrl.call("get_current_floor_number"))
		if floor_ctrl.has_method("get_enemies_left_current_floor"):
			floor_enemies_left = int(floor_ctrl.call("get_enemies_left_current_floor"))
	var fps: float = float(Engine.get_frames_per_second())
	var msg: String = "[PerfDiag] peak=%.1fms window=%.2fs samples=%d minor=%d major=%d | fps=%.1f | scene=%s | floor=%d floor_enemies=%d floor5=%d subarena=%d enemy_hurtboxes=%d rocks=%d active_rocks=%d" % [_perf_diag_window_peak_ms, maxf(perf_diag_sample_window_sec, 0.1), _perf_diag_window_samples, _perf_diag_window_spikes_minor, _perf_diag_window_spikes_major, fps, scene_name, floor_number, floor_enemies_left, floor5_count, subarena_count, enemy_hurtboxes_count, rocks_count, active_rocks_count]
	if perf_diag_use_warning_logs:
		push_warning(msg)
	else:
		print(msg)

func _apply_frame_pacing_cap() -> void:
	if not frame_pacing_fps_cap_enabled:
		return
	var cap: int = maxi(frame_pacing_fps_cap_value, 30)
	Engine.max_fps = cap

func _ensure_debug_toast() -> void:
	if _debug_toast_layer != null and is_instance_valid(_debug_toast_layer):
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	_debug_toast_layer = CanvasLayer.new()
	_debug_toast_layer.name = "DebugModifierToastLayer"
	_debug_toast_layer.layer = 110
	_debug_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(_debug_toast_layer)

	_debug_toast_label = Label.new()
	_debug_toast_label.name = "DebugModifierToastLabel"
	_debug_toast_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_debug_toast_label.visible = false
	_debug_toast_label.z_index = 999
	_debug_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_debug_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_toast_label.add_theme_font_size_override("font_size", 24)
	_debug_toast_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2, 1.0))
	_debug_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_debug_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_debug_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	_debug_toast_layer.add_child(_debug_toast_label)
	_layout_debug_toast()

func _layout_debug_toast() -> void:
	if _debug_toast_label == null or not is_instance_valid(_debug_toast_label):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(vp.x * 0.8, 1200.0)
	_debug_toast_label.position = Vector2((vp.x - w) * 0.5, vp.y * 0.16)
	_debug_toast_label.size = Vector2(w, 110.0)

func _show_debug_toast(msg: String) -> void:
	if not debug_modifier_injector_enabled:
		return
	_ensure_debug_toast()
	if _debug_toast_label == null or not is_instance_valid(_debug_toast_label):
		return
	_layout_debug_toast()
	_debug_toast_label.text = "Debug Modifier: %s" % msg
	_debug_toast_label.modulate = Color(1, 1, 1, 1)
	_debug_toast_label.visible = true
	_debug_toast_time_left = 1.6

func _tick_debug_toast(delta: float) -> void:
	if _debug_toast_label == null or not is_instance_valid(_debug_toast_label):
		return
	if _debug_toast_time_left <= 0.0:
		return
	_debug_toast_time_left = maxf(_debug_toast_time_left - delta, 0.0)
	var alpha: float = clampf(_debug_toast_time_left / 1.6, 0.0, 1.0)
	_debug_toast_label.modulate = Color(1, 1, 1, alpha)
	if _debug_toast_time_left <= 0.0:
		_debug_toast_label.visible = false

func _reset_dice_meter_if_available() -> void:
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter != null and dice_meter.has_method("reset_meter"):
		dice_meter.call("reset_meter")

func _apply_dice_meter_debug_range_override_if_enabled() -> void:
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter == null:
		return
	if not dice_meter.has_method("is_debug_test_mode_enabled"):
		return
	if not bool(dice_meter.call("is_debug_test_mode_enabled")):
		return

	var forced_min: int = dice_hard_min
	var forced_max: int = dice_hard_max
	if dice_meter.has_method("get_debug_forced_range"):
		var v: Variant = dice_meter.call("get_debug_forced_range")
		if v is Vector2i:
			var r: Vector2i = v
			forced_min = r.x
			forced_max = r.y
	dice_min = clampi(mini(forced_min, forced_max), dice_hard_min, dice_hard_max)
	dice_max = clampi(maxi(forced_min, forced_max), dice_hard_min, dice_hard_max)
	last_roll = clampi(last_roll, dice_min, dice_max)

func set_dice_range_debug_override(min_value: int, max_value: int) -> void:
	dice_min = clampi(mini(min_value, max_value), dice_hard_min, dice_hard_max)
	dice_max = clampi(maxi(min_value, max_value), dice_hard_min, dice_hard_max)
	last_roll = clampi(last_roll, dice_min, dice_max)
	_emit()

# -----------------------------
# Run lifecycle
# -----------------------------
func reset_on_death_and_retry() -> void:
	world_index = 1
	floor_index = 1

	dice_min = meta_next_start_value
	dice_max = meta_next_start_value
	last_roll = meta_next_start_value

	applied_modifier_ids.clear()

	_reset_run_modifiers()
	clear_relics()

	# E1 state
	forced_reward_roll = -1
	relic_loaded_fate_used_this_world = false

	_emit()
	_reset_dice_meter_if_available()

func start_new_run(run_seed_override: int = 0) -> void:
	pass
	run_seed = run_seed_override if run_seed_override != 0 else int(Time.get_unix_time_from_system())
	world_index = 1
	floor_index = 1

	# Use saved starting dice range instead of meta_next_start_value
	dice_min = starting_dice_min
	dice_max = starting_dice_max
	last_roll = starting_dice_min
	_apply_dice_meter_debug_range_override_if_enabled()
	
	pass

	applied_modifier_ids.clear()

	_reset_run_modifiers()
	clear_relics()

	# E1 state
	forced_reward_roll = -1
	relic_loaded_fate_used_this_world = false

	_emit()
	pass
	_reset_dice_meter_if_available()

func _reset_run_modifiers() -> void:
	enemy_damage_mult = 1.0
	enemy_health_mult = 1.0
	enemy_projectile_speed_mult = 1.0
	enemy_crit_chance_add = 0.0
	enemy_crit_damage_mult = 1.0
	player_damage_mult = 1.0
	player_health_mult = 1.0
	player_move_speed_mult = 1.0
	player_jump_height_mult = 1.0
	player_gravity_mult = 1.0
	player_flux_jump_height_mult = 1.0
	player_attack_speed_mult = 1.0
	_base_player_move_speed_mult = 1.0

	_reset_world_modifiers_only()
	_reset_relic_knobs()

func _reset_relic_knobs() -> void:
	relic_damage_mult = 1.0
	relic_damage_taken_mult = 1.0
	relic_attack_speed_mult = 1.0
	relic_bleed_damage_mult = 1.0
	relic_roll_max_charges_bonus = 0
	relic_roll_recharge_mult = 1.0
	relic_dice_meter_charge_mult = 1.0
	relic_defend_duration_bonus = 0.0
	relic_orb_charge_mult_bonus = 1.0
	relic_ultimate_gain_mult = 1.0
	relic_orb_surge_active = false
	relic_loaded_fate_used_this_world = false

	# E1
	forced_reward_roll = -1

func clear_world_modifiers() -> void:
	applied_modifier_ids.clear()

	enemy_damage_mult = 1.0
	enemy_health_mult = 1.0
	enemy_projectile_speed_mult = 1.0
	enemy_crit_chance_add = 0.0
	enemy_crit_damage_mult = 1.0
	player_damage_mult = 1.0
	player_health_mult = 1.0
	player_move_speed_mult = 1.0
	player_jump_height_mult = 1.0
	player_gravity_mult = 1.0
	player_flux_jump_height_mult = 1.0
	player_attack_speed_mult = 1.0
	_base_player_move_speed_mult = 1.0

	_reset_world_modifiers_only()
	_emit()

func _reset_world_modifiers_only() -> void:
	world_effects.clear()
	hazard_rise_mult = 1.0
	healing_mult = 1.0
	cooldown_mult = 1.0
	ultimate_cooldown_mult = 1.0
	orb_charge_mult = 1.0
	loot_quality_bonus = 0.0
	shop_price_mult = 1.0
	extra_shop_slots = 0
	free_shop_rerolls = 0
	rare_relic_bonus = 0.0
	elites_to_spawn_bonus = 0
	elites_per_floor_bonus = 0

	perfect_step_enabled = false
	clean_cuts_enabled = false
	ritual_of_stability_enabled = false
	_ritual_last_floor_healed = 0
	loaded_momentum_enabled = false
	loaded_momentum_stacks = 0
	vampiric_thread_enabled = false
	edge_of_ambition_enabled = false
	_edge_of_ambition_time_left = 0.0
	gravity_flux_enabled = false
	_gravity_flux_timer = 10.0
	_gravity_flux_phase = 0
	_base_player_attack_speed_mult = 1.0
	hemorrhage_doctrine_enabled = false
	_hemorrhage_stacks = 0
	_hemorrhage_time_left = 0.0
	_hemorrhage_tick_left = 1.0
	velocity_collapse_enabled = false
	_velocity_collapse_phase = 0
	_velocity_collapse_timer = 12.0
	_burst_runner_enabled = false
	_burst_runner_time_left = 0.0
	blood_tax_enabled = false
	_blood_tax_tick_left = 8.0
	_suppress_modifier_damage_callback = false
	lucky_spark_enabled = false
	volatile_siphon_enabled = false
	battle_hymn_enabled = false
	fated_reservoir_enabled = false
	_battle_hymn_time_left = 0.0
	_volatile_siphon_time_left = 0.0
	_fated_reservoir_stacks = 0

	_unknown_effects_warned.clear()

func advance_floor() -> void:
	if ritual_of_stability_enabled:
		_heal_player_percent(0.08)
	floor_index += 1

func advance_world() -> void:
	world_index += 1
	floor_index = 1
	clear_world_modifiers()

	# E1: reset per-world usage + clear forced roll
	relic_loaded_fate_used_this_world = false
	forced_reward_roll = -1
	# Intentionally preserve Dice Meter charge across world transitions.

# -----------------------------
# Dice range operations
# -----------------------------
func apply_range_delta(delta_min: int, delta_max: int) -> void:
	pass
	dice_min += delta_min
	dice_max += delta_max
	_clamp_and_fix()
	pass
	_emit()

func roll_in_range(rng: RandomNumberGenerator) -> int:
	_clamp_and_fix()
	last_roll = rng.randi_range(dice_min, dice_max)
	_emit()
	return last_roll

func set_next_run_start_from_last_roll() -> void:
	meta_next_start_value = last_roll
	save_meta()

func apply_floor_modifier_payload(value: int, effect_id: StringName, greed_id: StringName) -> void:
	if value > 0:
		apply_range_delta(0, value)
	elif value < 0:
		apply_range_delta(value, 0)
	else:
		_emit()

	if value == 0:
		_full_heal_player()
	else:
		_apply_effect(effect_id)
		if greed_id != &"":
			_apply_effect(greed_id)

	if effect_id != &"":
		applied_modifier_ids.append(effect_id)
	if greed_id != &"":
		applied_modifier_ids.append(greed_id)

	_emit()

func get_active_modifier_ids() -> Array[StringName]:
	return applied_modifier_ids.duplicate()

# -----------------------------
# Effect mapping
# -----------------------------
func _register_world_effect(id: StringName) -> void:
	if id == &"":
		return
	if not world_effects.has(id):
		world_effects.append(id)

func _warn_unknown_once(id: StringName) -> void:
	if not warn_on_unknown_effects:
		return
	if id == &"":
		return
	if _unknown_effects_warned.has(id):
		return
	_unknown_effects_warned[id] = true
	push_warning("[RunState] Unknown effect id: %s" % String(id))

func _apply_effect(id: StringName) -> void:
	if id == &"":
		return

	match id:
		&"s_steady_hands":
			cooldown_mult *= 0.90
		&"s_guarded_footing":
			player_damage_mult *= 1.08
			enemy_damage_mult *= 0.94
		&"s_orb_attunement":
			orb_charge_mult *= 1.20
			cooldown_mult *= 0.95
		&"s_skybound_step":
			player_jump_height_mult *= 1.12
			_base_player_move_speed_mult *= 1.08
		&"s_tempered_guard":
			player_health_mult *= 1.12
			_apply_player_health_multiplier_now()
			_heal_player_percent(0.08)
		&"s_combat_focus":
			player_damage_mult *= 1.10
			enemy_health_mult *= 0.92
		&"s_vampiric_thread":
			vampiric_thread_enabled = true
		&"s_burst_runner":
			_burst_runner_enabled = true
		&"s_lucky_spark":
			lucky_spark_enabled = true
			cooldown_mult *= 0.97

		&"m_warded_soul":
			_heal_player_percent(0.12)
			orb_charge_mult *= 1.15
			enemy_damage_mult *= 0.94
		&"m_composure_engine":
			player_damage_mult *= 1.12
			enemy_health_mult *= 0.88
			cooldown_mult *= 0.90
		&"m_orb_mastery":
			orb_charge_mult *= 1.30
			player_damage_mult *= 1.08
		&"m_ritual_of_stability":
			ritual_of_stability_enabled = true
			_heal_player_percent(0.10)
		&"m_kinetic_overdrive":
			_base_player_move_speed_mult *= 1.15
			player_jump_height_mult *= 1.18
			_base_player_attack_speed_mult *= 1.12
		&"m_battle_hymn":
			battle_hymn_enabled = true
			cooldown_mult *= 0.92
		&"m_fated_reservoir":
			fated_reservoir_enabled = true
			orb_charge_mult *= 1.10

		&"p_blood_moon":
			enemy_damage_mult *= 1.12
			enemy_health_mult *= 1.10
		&"p_siege_lines":
			enemy_projectile_speed_mult *= 1.18
			enemy_damage_mult *= 1.05
		&"p_ruthless_hunt":
			elites_to_spawn_bonus += 1
			enemy_damage_mult *= 1.08
		&"p_hemorrhage_doctrine":
			hemorrhage_doctrine_enabled = true
			enemy_damage_mult *= 1.10
		&"p_velocity_collapse":
			velocity_collapse_enabled = true
			enemy_damage_mult *= 1.08
		&"p_volatile_siphon":
			volatile_siphon_enabled = true
			enemy_damage_mult *= 1.08
		&"p_loaded_momentum":
			loaded_momentum_enabled = true
			enemy_damage_mult *= 1.08
		&"p_gravity_flux":
			gravity_flux_enabled = true
			_gravity_flux_phase = 1
			_gravity_flux_timer = 10.0
			enemy_damage_mult *= 1.10
		&"p_fractured_orbits":
			enemy_health_mult *= 1.12
			cooldown_mult *= 1.10
		&"p_tight_windows":
			enemy_damage_mult *= 1.12
			cooldown_mult *= 1.08

		&"x_apex_predators":
			enemy_damage_mult *= 1.20
			enemy_health_mult *= 1.18
			elites_to_spawn_bonus += 1
		&"x_no_safe_space":
			enemy_projectile_speed_mult *= 1.30
			enemy_damage_mult *= 1.15
		&"x_attrition_law":
			enemy_damage_mult *= 1.12
			cooldown_mult *= 1.15
			enemy_health_mult *= 1.15
		&"x_execution_order":
			elites_to_spawn_bonus += 2
			enemy_damage_mult *= 1.12
			enemy_health_mult *= 1.10
		&"x_edge_of_ambition":
			edge_of_ambition_enabled = true
			enemy_damage_mult *= 1.25
		&"x_predators_edge":
			enemy_crit_chance_add += 0.10
			enemy_crit_damage_mult *= 1.35
			enemy_damage_mult *= 1.10
		&"x_blood_tax":
			blood_tax_enabled = true
			enemy_damage_mult *= 1.12
		&"x_skull_standard":
			elites_per_floor_bonus += 1
			enemy_damage_mult *= 1.10
			enemy_health_mult *= 1.10
		&"x_dice_vice":
			enemy_damage_mult *= 1.18
			cooldown_mult *= 1.18
			orb_charge_mult *= 0.90

		# Backward-compatible legacy ids
		&"b_sharpened":
			player_damage_mult *= 1.12
		&"b_fleetfoot":
			_base_player_move_speed_mult *= 1.10
		&"b_coolheaded":
			cooldown_mult *= 0.85
		&"b_heavyhand":
			player_damage_mult *= 1.10
		&"b_bulwark_start":
			_register_world_effect(id)
		&"b_orb_handler":
			orb_charge_mult *= 1.15
		&"b_surge_on_kill":
			_register_world_effect(id)

		&"b_perfect_step":
			perfect_step_enabled = true
			_register_world_effect(id)

		&"b_clean_cuts":
			clean_cuts_enabled = true
			player_damage_mult *= 1.08
			_register_world_effect(id)
		&"b_stagger_training":
			player_damage_mult *= 1.10

		&"m_berserker_pact":
			player_damage_mult *= 1.25
			enemy_damage_mult *= 1.10
		&"m_ironblood":
			player_health_mult *= 1.20
			_apply_player_health_multiplier_now()
			enemy_damage_mult *= 0.90
		&"m_flow_engine":
			cooldown_mult *= 0.75
			ultimate_cooldown_mult *= 0.90
		&"m_executioner":
			player_damage_mult *= 1.15
		&"m_shockwave":
			_register_world_effect(id)
		&"m_second_wind":
			_register_world_effect(id)
		&"m_predator":
			_base_player_move_speed_mult *= 1.10
		&"m_guardian_shell":
			_register_world_effect(id)
		&"m_orb_overcharge":
			orb_charge_mult *= 1.15
			_register_world_effect(id)
		&"m_cleanse_mastery":
			_register_world_effect(id)

		&"d_overcharged_foes":
			enemy_damage_mult *= 1.12
		&"d_reinforced_foes":
			enemy_health_mult *= 1.18
		&"d_hunted":
			hazard_rise_mult *= 1.15
		&"d_elite_presence":
			elites_to_spawn_bonus += 1
			pass
		&"d_sniper_winds":
			enemy_projectile_speed_mult *= 1.15

		&"x_brutal_foes":
			enemy_damage_mult *= 1.22
		&"x_unstable_ground":
			hazard_rise_mult *= 1.30
		&"x_cursed_recovery":
			enemy_damage_mult *= 1.08
			cooldown_mult *= 1.08
		&"x_marked":
			_register_world_effect(id)
		&"x_elite_pack":
			elites_to_spawn_bonus += 2
			pass

		# Deprecated currency/shop/loot ids intentionally no-op for now.
		&"g_loot_quality_small":
			pass
		&"g_shop_extra_slot":
			pass
		&"g_shop_free_reroll":
			pass
		&"g_rare_relic_chance_small":
			pass
		&"bg_boss_extra_choice":
			pass
		&"bg_loot_quality_big":
			pass
		&"bg_shop_discount":
			pass
		&"bg_rare_relic_chance_big":
			pass
		&"g_boss_currency":
			pass
		&"bg_free_dice_tool":
			pass

		_:
			_register_world_effect(id)
			_warn_unknown_once(id)

# -----------------------------
# Player lookup + health helpers
# -----------------------------
func _get_player_node() -> Node:
	return get_tree().get_first_node_in_group("player")

func _has_active_hostiles() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	for node_obj in tree.get_nodes_in_group("enemies"):
		var node: Node = node_obj as Node
		if node != null and is_instance_valid(node):
			return true
	for node_obj in tree.get_nodes_in_group("bosses"):
		var node: Node = node_obj as Node
		if node != null and is_instance_valid(node):
			return true
	return false

func _get_health_node(player: Node) -> Node:
	if player == null:
		return null
	if player.has_node("Health"):
		return player.get_node("Health")
	for c in player.get_children():
		var n: Node = c as Node
		if n == null:
			continue
		var name_l: String = String(n.name).to_lower()
		if name_l.contains("health") or name_l == "hp":
			return n
	return null

func _full_heal_player() -> void:
	var player: Node = _get_player_node()
	if player == null:
		return
	var h: Node = _get_health_node(player)
	if h == null:
		return

	if h.has_method("full_heal"):
		h.call("full_heal")
		return
	if h.has_method("revive_full"):
		h.call("revive_full")
		return

	var max_hp_val: int = _read_max_hp(h)
	if max_hp_val >= 1:
		_write_hp(h, max_hp_val)
		_emit_health_changed_if_possible(h)

func _apply_player_health_multiplier_now() -> void:
	var player: Node = _get_player_node()
	if player == null:
		return
	var h: Node = _get_health_node(player)
	if h == null:
		return

	var base_max: int = _read_max_hp(h)
	if base_max < 1:
		return

	var new_max: int = max(1, int(round(float(base_max) * player_health_mult)))

	if h.has_method("set_max_and_full_heal"):
		h.call("set_max_and_full_heal", new_max)
		return

	_write_max_hp(h, new_max)
	_write_hp(h, new_max)
	_emit_health_changed_if_possible(h)

func _emit_health_changed_if_possible(h: Node) -> void:
	if h == null:
		return
	if h.has_signal("health_changed"):
		var cur: int = _read_hp(h)
		var mx: int = _read_max_hp(h)
		if cur >= 0 and mx >= 1:
			h.emit_signal("health_changed", cur, mx)

func _heal_player_percent(pct: float) -> void:
	var player: Node = _get_player_node()
	if player == null:
		return
	var h: Node = _get_health_node(player)
	if h == null:
		return
	var p: float = clampf(pct, 0.0, 1.0)
	if h.has_method("heal_percent"):
		h.call("heal_percent", p)
		return
	var max_hp_val: int = _read_max_hp(h)
	var hp_val: int = _read_hp(h)
	if max_hp_val <= 0 or hp_val < 0:
		return
	var amount: int = maxi(1, int(round(float(max_hp_val) * p)))
	_write_hp(h, mini(max_hp_val, hp_val + amount))
	_emit_health_changed_if_possible(h)

func _heal_player_flat(amount: int) -> void:
	if amount <= 0:
		return
	var player: Node = _get_player_node()
	if player == null:
		return
	var h: Node = _get_health_node(player)
	if h == null:
		return
	if h.has_method("heal"):
		h.call("heal", amount)
		return
	var max_hp_val: int = _read_max_hp(h)
	var hp_val: int = _read_hp(h)
	if max_hp_val <= 0 or hp_val < 0:
		return
	_write_hp(h, mini(max_hp_val, hp_val + amount))
	_emit_health_changed_if_possible(h)

func _apply_player_percent_damage_from_modifier(pct: float, nonlethal: bool) -> void:
	var player: Node = _get_player_node()
	if player == null:
		return
	var h: Node = _get_health_node(player)
	if h == null:
		return
	var max_hp_val: int = _read_max_hp(h)
	var hp_val: int = _read_hp(h)
	if max_hp_val <= 0 or hp_val <= 0:
		return
	var amount: int = maxi(1, int(round(float(max_hp_val) * clampf(pct, 0.0, 1.0))))
	if nonlethal:
		amount = mini(amount, maxi(hp_val - 1, 0))
	if amount <= 0:
		return
	_suppress_modifier_damage_callback = true
	if h.has_method("take_damage"):
		h.call("take_damage", amount, self, true)
	else:
		_write_hp(h, maxi(hp_val - amount, 0))
		_emit_health_changed_if_possible(h)
	_suppress_modifier_damage_callback = false

func on_enemy_killed_for_modifiers(_is_elite: bool = false) -> void:
	if vampiric_thread_enabled:
		_heal_player_flat(4 if _is_elite else 2)
	if _burst_runner_enabled:
		_burst_runner_time_left = 2.5
	if lucky_spark_enabled:
		if _is_elite:
			_heal_player_percent(0.06)
	if volatile_siphon_enabled:
		_apply_player_percent_damage_from_modifier(0.01, true)
		_volatile_siphon_time_left = 3.0
	if not loaded_momentum_enabled:
		return
	loaded_momentum_stacks = mini(loaded_momentum_stacks + 1, 10)
	_emit()

func on_player_took_hp_damage(_amount: int) -> void:
	if _suppress_modifier_damage_callback:
		return
	if hemorrhage_doctrine_enabled:
		_hemorrhage_stacks = mini(_hemorrhage_stacks + 1, 3)
		_hemorrhage_time_left = 4.0
		_hemorrhage_tick_left = minf(_hemorrhage_tick_left, 1.0)
	if loaded_momentum_stacks > 0:
		loaded_momentum_stacks = 0
	if edge_of_ambition_enabled:
		# Keep this skill-rewarding: taking damage also drops any edge tempo.
		_edge_of_ambition_time_left = 0.0
		_tick_dynamic_world_effects(0.0)
	_emit()

func on_perfect_dodge_for_modifiers() -> void:
	if battle_hymn_enabled:
		_battle_hymn_time_left = 3.5
		_heal_player_percent(0.02)
	if not edge_of_ambition_enabled:
		return
	_edge_of_ambition_time_left = 3.0
	_tick_dynamic_world_effects(0.0)
	_emit()

func on_floor_cleared_for_modifiers(floor_number: int) -> void:
	# Floor number expected as 1-based index within current world.
	if fated_reservoir_enabled:
		_heal_player_percent(0.06)
		if _fated_reservoir_stacks < 4:
			_fated_reservoir_stacks += 1
			player_damage_mult *= 1.04
			cooldown_mult *= 0.97
	if not ritual_of_stability_enabled:
		return
	var f: int = maxi(floor_number, 0)
	if f <= _ritual_last_floor_healed:
		return
	_ritual_last_floor_healed = f
	_heal_player_percent(0.08)
	_emit()

func get_loaded_momentum_damage_mult() -> float:
	if not loaded_momentum_enabled:
		return 1.0
	return 1.0 + (float(loaded_momentum_stacks) * 0.02)

func _tick_dynamic_world_effects(delta: float) -> void:
	if edge_of_ambition_enabled and _edge_of_ambition_time_left > 0.0:
		_edge_of_ambition_time_left = maxf(_edge_of_ambition_time_left - delta, 0.0)
	if gravity_flux_enabled:
		_gravity_flux_timer -= delta
		if _gravity_flux_timer <= 0.0:
			_gravity_flux_timer = 10.0
			_gravity_flux_phase = 1 - _gravity_flux_phase
		# Phase 1: normal jump/gravity. Phase 0: moon-bounce mode.
		if _gravity_flux_phase == 0:
			player_gravity_mult = 0.20
			player_flux_jump_height_mult = 2.10
		else:
			player_gravity_mult = 1.0
			player_flux_jump_height_mult = 1.0
	else:
		player_gravity_mult = 1.0
		player_flux_jump_height_mult = 1.0
	if velocity_collapse_enabled:
		_velocity_collapse_timer -= delta
		if _velocity_collapse_timer <= 0.0:
			_velocity_collapse_phase = (_velocity_collapse_phase + 1) % 3
			_velocity_collapse_timer = 3.0 if _velocity_collapse_phase > 0 else 12.0
	if _burst_runner_time_left > 0.0:
		_burst_runner_time_left = maxf(_burst_runner_time_left - delta, 0.0)
	if _battle_hymn_time_left > 0.0:
		_battle_hymn_time_left = maxf(_battle_hymn_time_left - delta, 0.0)
	if _volatile_siphon_time_left > 0.0:
		_volatile_siphon_time_left = maxf(_volatile_siphon_time_left - delta, 0.0)
	var edge_mult: float = 1.20 if (edge_of_ambition_enabled and _edge_of_ambition_time_left > 0.0) else 1.0
	var hymn_attack_mult: float = 1.30 if _battle_hymn_time_left > 0.0 else 1.0
	var volatile_attack_mult: float = 1.10 if _volatile_siphon_time_left > 0.0 else 1.0
	player_attack_speed_mult = _base_player_attack_speed_mult * edge_mult * hymn_attack_mult * volatile_attack_mult
	var move_mult: float = _base_player_move_speed_mult
	if velocity_collapse_enabled:
		if _velocity_collapse_phase == 1:
			move_mult *= 0.70
		elif _velocity_collapse_phase == 2:
			move_mult *= 1.20
	if _battle_hymn_time_left > 0.0:
		move_mult *= 1.15
	if _burst_runner_time_left > 0.0:
		move_mult *= 1.20
	player_move_speed_mult = move_mult
	if hemorrhage_doctrine_enabled and _hemorrhage_stacks > 0:
		_hemorrhage_time_left = maxf(_hemorrhage_time_left - delta, 0.0)
		_hemorrhage_tick_left -= delta
		if _hemorrhage_tick_left <= 0.0:
			_hemorrhage_tick_left += 1.0
			_apply_player_percent_damage_from_modifier(0.005 * float(_hemorrhage_stacks), true)
		if _hemorrhage_time_left <= 0.0:
			_hemorrhage_stacks = 0
			_hemorrhage_tick_left = 1.0
	if blood_tax_enabled:
		_blood_tax_tick_left -= delta
		if _blood_tax_tick_left <= 0.0:
			_blood_tax_tick_left += 8.0
			if _has_active_hostiles():
				_apply_player_percent_damage_from_modifier(0.015, true)


func _read_hp(h: Node) -> int:
	if h == null:
		return -1
	if ("hp" in h):
		return int(h.get("hp"))
	if ("current_hp" in h):
		return int(h.get("current_hp"))
	return -1

func _read_max_hp(h: Node) -> int:
	if h == null:
		return -1
	if ("max_hp" in h):
		return int(h.get("max_hp"))
	if ("max_health" in h):
		return int(h.get("max_health"))
	return -1

func _write_hp(h: Node, v: int) -> void:
	if h == null:
		return
	if ("hp" in h):
		h.set("hp", v)
		return
	if ("current_hp" in h):
		h.set("current_hp", v)
		return

func _write_max_hp(h: Node, v: int) -> void:
	if h == null:
		return
	if ("max_hp" in h):
		h.set("max_hp", v)
		return
	if ("max_health" in h):
		h.set("max_health", v)
		return

func _clamp_and_fix() -> void:
	dice_min = clampi(dice_min, dice_hard_min, dice_hard_max)
	dice_max = clampi(dice_max, dice_hard_min, dice_hard_max)
	if dice_min > dice_max:
		var tmp: int = dice_min
		dice_min = dice_max
		dice_max = tmp

func _emit() -> void:
	dice_changed.emit(dice_min, dice_max, last_roll)

func save_meta() -> void:
	var data: Dictionary = {
		"meta_next_start_value": meta_next_start_value,
		"starting_dice_min": starting_dice_min,
		"starting_dice_max": starting_dice_max,
		"last_run_seed": run_seed
	}
	var json_text: String = JSON.stringify(data)
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[RunState] Failed to save meta.")
		return
	f.store_string(json_text)
	pass

func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		pass
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		return
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed as Dictionary
	if d.has("meta_next_start_value"):
		meta_next_start_value = int(d["meta_next_start_value"])
	if d.has("starting_dice_min"):
		starting_dice_min = int(d["starting_dice_min"])
	if d.has("starting_dice_max"):
		starting_dice_max = int(d["starting_dice_max"])
	if d.has("last_run_seed"):
		run_seed = int(d["last_run_seed"])
	pass

func update_starting_dice_range(new_value: int) -> void:
	"""Update starting dice range to new value after final boss victory"""
	starting_dice_min = new_value
	starting_dice_max = new_value
	save_meta()
	pass
