extends Node
class_name DiceMeter

const DiceCouncilRegistryScript = preload("res://scripts/systems/dice/DiceCouncilRegistry.gd")
const ROGUE_HEAVY_VFX_SCENE: PackedScene = preload("res://scenes/vfx/HeavyAttackVFX.tscn")
const KNIGHT_HEAVY_VFX_SCENE: PackedScene = preload("res://scenes/vfx/KnightHeavyAttackVFX.tscn")
const PLAYER_REFLECTION_CLONE_SCENE: PackedScene = preload("res://scenes/vfx/PlayerReflectionCloneVFX.tscn")
const PLAYER_CONTROLLER_SCRIPT_PATH: String = "res://scripts/player/PlayerControllerV3.gd"
const PLAYER_3D_VIEW_SCRIPT_PATH: String = "res://scripts/player/Player3DView.gd"
const PLAYER_REFLECTION_CLONE_SCRIPT_PATH: String = "res://scripts/vfx/PlayerReflectionCloneVFX.gd"
const PLAYER_REFLECTION_CLONE_SCENE_PATH: String = "res://scenes/vfx/PlayerReflectionCloneVFX.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/player/player.tscn"
const PLAYER_3D_VIEW_SCENE_PATH: String = "res://scenes/player/Player3DView.tscn"

signal charge_changed(current_charge: float, max_charge: float)
signal meter_filled()
signal roll_resolved(roll_value: int, event_id: StringName, band: int)

const RELIC_LOADED_EDGE: StringName = &"r7_loaded_edge"
const RELIC_BENT_DIE: StringName = &"r8_broken_die"
const RELIC_BENT_DIE_ALT: StringName = &"r8_bent_die"
const RELIC_TWIN_FATE: StringName = &"e3_twin_fate"

@export var max_charge: float = 100.0
@export var charge_per_enemy_kill: float = 8.0
@export var charge_per_elite_kill: float = 20.0
@export var charge_per_perfect_dodge: float = 5.0
@export var outgoing_damage_step: float = 50.0
@export var charge_per_outgoing_damage_step: float = 4.0
@export var charge_per_boss_kill: float = 20.0
@export var loaded_edge_backlash_percent: float = 0.06
@export var trigger_action: StringName = &"dice_meter_trigger"
@export var input_buffer_seconds: float = 0.15
@export var debug_logs: bool = false
@export_group("Debug Test Mode")
@export var debug_test_mode_enabled: bool = false
@export var debug_lock_meter_full: bool = false
@export var debug_prevent_enemy_deaths: bool = false
@export var debug_force_range_min: int = 1
@export var debug_force_range_max: int = 20

@export var default_event_table_path: String = "res://data/dice_meter/DiceMeterEventTable_Default.tres"
@export var event_table: DiceMeterEventTable

var current_charge: float = 0.0
var _pending_outgoing_damage: float = 0.0
var _trigger_count: int = 0

var last_roll: int = -1
var last_event_id: StringName = &""
var last_event_band: int = int(DiceMeterEventData.OutcomeBand.NEUTRAL)
var last_result: Dictionary = {}
var active_effect_name: String = ""
var active_effect_brief_text: String = ""
var active_effect_band: int = int(DiceMeterEventData.OutcomeBand.NEUTRAL)
var active_effect_time_left: float = 0.0
var active_effect_hide_timer: bool = false
var _active_temp_effects: Array[Dictionary] = []
var _active_enemy_slow_effects: Array[Dictionary] = []
var _active_echo_pulses: Array[Dictionary] = []
var _active_player_hp_drain_effects: Array[Dictionary] = []
var _active_target_execution_effects: Array[Dictionary] = []
var _active_enemy_freeze_effects: Array[Dictionary] = []
var _active_enemy_freeze_pulses: Array[Dictionary] = []
var _active_player_root_effects: Array[Dictionary] = []
var _active_player_freeze_pulses: Array[Dictionary] = []
var _active_player_visual_effects: Array[Dictionary] = []
var _active_lifesteal_effects: Array[Dictionary] = []
var _active_enemy_regen_effects: Array[Dictionary] = []
var _active_wind_effects: Array[Dictionary] = []
var _active_cooldown_pause_effects: Array[Dictionary] = []
var _active_reflection_combo_effects: Array[Dictionary] = []
var _active_phantom_minion_watchers: Array[Dictionary] = []
var _player_motion_lock_count: int = 0
var _player_input_lock_count: int = 0
var _trigger_buffer_left: float = 0.0
var _reflection_visual_debug_tick_left: float = 0.0
var _council_members: Dictionary = {}
var _council_catastrophe_event: Resource = null
var _divine_miracle_event: Resource = null

enum FateAlignment {
	COUNCIL = 0,
	CHAOS = 1,
	DIVINE = 2,
	COUNCIL_CATASTROPHE = 3,
	DIVINE_MIRACLE = 4
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	if event_table == null and ResourceLoader.exists(default_event_table_path):
		event_table = load(default_event_table_path) as DiceMeterEventTable
	_council_members = DiceCouncilRegistryScript.build_members()
	_council_catastrophe_event = DiceCouncilRegistryScript.load_council_catastrophe_event()
	_divine_miracle_event = DiceCouncilRegistryScript.load_divine_miracle_event()
	_emit_charge_changed()

func _process(delta: float) -> void:
	_apply_debug_test_mode_overrides()
	_tick_wind_effects(delta)
	_tick_enemy_slow_effects(delta)
	_tick_enemy_freeze_effects(delta)
	_tick_enemy_freeze_pulses(delta)
	_tick_echo_pulses(delta)
	_tick_player_hp_drain_effects(delta)
	_tick_player_root_effects(delta)
	_tick_player_freeze_pulses(delta)
	_tick_player_visual_effects(delta)
	_tick_lifesteal_effects(delta)
	_tick_enemy_regen_effects(delta)
	_tick_reflection_combo_effects(delta)
	_tick_phantom_minion_watchers(delta)
	_tick_target_execution_effects(delta)
	_tick_cooldown_pause_effects(delta)
	_tick_temp_effects(delta)
	_process_trigger_input(delta)

func reset_meter() -> void:
	_clear_enemy_slow_effects()
	_clear_enemy_freeze_effects()
	_clear_enemy_freeze_pulses()
	_clear_echo_pulses()
	_clear_player_hp_drain_effects()
	_clear_player_root_effects()
	_clear_player_freeze_pulses()
	_clear_player_visual_effects()
	_clear_lifesteal_effects()
	_clear_enemy_regen_effects()
	_clear_reflection_combo_effects()
	_clear_phantom_minion_watchers()
	_clear_wind_effects()
	_clear_target_execution_effects()
	_clear_cooldown_pause_effects()
	_clear_temp_effects()
	current_charge = 0.0
	_pending_outgoing_damage = 0.0
	_trigger_count = 0
	last_roll = -1
	last_event_id = &""
	last_event_band = int(DiceMeterEventData.OutcomeBand.NEUTRAL)
	last_result = {}
	active_effect_name = ""
	active_effect_brief_text = ""
	active_effect_time_left = 0.0
	active_effect_hide_timer = false
	_emit_charge_changed()
	_log_debug("Meter reset.")

func set_event_table(table: DiceMeterEventTable) -> void:
	event_table = table

func add_charge(amount: float, _reason: StringName = &"") -> void:
	if amount <= 0.0:
		return
	var run_state: Node = _get_run_state()
	if run_state != null and ("relic_dice_meter_charge_mult" in run_state):
		amount *= clampf(float(run_state.get("relic_dice_meter_charge_mult")), 0.0, 10.0)
	if amount <= 0.0:
		return
	var cap: float = maxf(max_charge, 1.0)
	# Prevent log/UI flood when systems keep reporting charge while meter is full.
	if current_charge >= cap:
		return
	var before: float = current_charge
	current_charge = clampf(current_charge + amount, 0.0, cap)
	if is_equal_approx(before, current_charge):
		return
	_emit_charge_changed()
	if debug_logs:
		var pct: int = int(round((current_charge / maxf(max_charge, 1.0)) * 100.0))
		_log_debug("Charge +%.2f (%d%%)." % [amount, clampi(pct, 0, 100)])
	if before < max_charge and current_charge >= max_charge:
		meter_filled.emit()
		_log_debug("Meter filled and ready.")

func on_enemy_killed(is_elite: bool = false) -> void:
	add_charge(charge_per_elite_kill if is_elite else charge_per_enemy_kill, &"enemy_kill")

func on_perfect_dodge() -> void:
	add_charge(charge_per_perfect_dodge, &"perfect_dodge")

func on_boss_damage(amount: float) -> void:
	on_outgoing_damage_dealt(amount)

func on_outgoing_damage_dealt(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_lifesteal_from_damage(amount)
	if outgoing_damage_step <= 0.0:
		return
	_pending_outgoing_damage += amount
	while _pending_outgoing_damage >= outgoing_damage_step:
		_pending_outgoing_damage -= outgoing_damage_step
		add_charge(charge_per_outgoing_damage_step, &"outgoing_damage_step")

func on_boss_killed() -> void:
	add_charge(charge_per_boss_kill, &"boss_kill")

func can_trigger_roll() -> bool:
	return current_charge >= max_charge

func trigger_roll(forced_roll: int = -1) -> Dictionary:
	if not can_trigger_roll():
		return {"ok": false, "reason": "meter_not_ready"}

	var roll: int = _resolve_roll_value(forced_roll)
	var alignment: int = _determine_alignment(roll)
	var selection: Dictionary = _select_event_for_roll(roll, alignment)
	if _has_bent_die_relic() and _is_negative_alignment(alignment):
		var bent_result: Dictionary = _apply_bent_die_alignment_reroll(roll, alignment)
		roll = int(bent_result.get("roll", roll))
		alignment = int(bent_result.get("alignment", alignment))
		selection = bent_result.get("selection", selection)
	var event_resource: Resource = selection.get("event_resource", null) as Resource
	if event_resource == null:
		return {"ok": false, "reason": "no_event_for_roll", "roll": roll}
	var event_payload: Dictionary = _event_resource_to_payload(event_resource)
	if event_payload.is_empty():
		return {"ok": false, "reason": "invalid_event_payload", "roll": roll}
	var member: Variant = selection.get("member", null)
	var member_name: String = String(selection.get("member_name", ""))
	var member_theme: String = String(selection.get("member_theme", ""))
	if member is DiceCouncilMember:
		member_name = String((member as DiceCouncilMember).name)
		member_theme = String((member as DiceCouncilMember).theme)

	current_charge = 0.0
	_pending_outgoing_damage = 0.0
	_trigger_count += 1
	last_roll = roll
	last_event_id = event_payload.get("event_id", &"")
	last_event_band = _alignment_to_outcome_band(alignment)
	_sync_roll_to_run_state(roll)

	last_result = {
		"ok": true,
		"roll": roll,
		"event_id": event_payload.get("event_id", &""),
		"display_name": event_payload.get("display_name", ""),
		"brief_text": event_payload.get("brief_text", ""),
		"description": event_payload.get("description", ""),
		"band": _alignment_to_outcome_band(alignment),
		"alignment": alignment,
		"alignment_label": _alignment_to_label(alignment),
		"midpoint": _get_current_dice_range().midpoint(),
		"member_number": clampi(roll, 1, 20),
		"member_name": member_name,
		"member_theme": member_theme,
		"effect_id": event_payload.get("effect_id", &""),
		"duration_seconds": float(event_payload.get("duration_seconds", 0.0)),
		"effect_params": event_payload.get("effect_params", {})
	}
	active_effect_name = String(last_result.get("display_name", ""))
	active_effect_brief_text = String(last_result.get("brief_text", ""))
	active_effect_band = int(last_result.get("band", int(DiceMeterEventData.OutcomeBand.NEUTRAL)))
	active_effect_time_left = float(last_result.get("duration_seconds", 0.0))
	active_effect_hide_timer = false
	var effect_id: StringName = last_result.get("effect_id", &"")
	var effect_params: Dictionary = last_result.get("effect_params", {})
	if effect_id == &"apply_player_chain" and bool(effect_params.get("lock_until_break", false)):
		active_effect_time_left = 9999.0
		active_effect_hide_timer = true
	var result_to_apply: Dictionary = last_result.duplicate(true)
	var roll_bounds: Vector2i = _get_meter_roll_bounds()
	if _has_relic(RELIC_LOADED_EDGE):
		if roll == roll_bounds.y:
			var scaled_params: Dictionary = _scale_effect_params(result_to_apply.get("effect_params", {}), 2.0)
			result_to_apply["effect_params"] = scaled_params
			_log_debug("Loaded Edge: max roll doubled event power.")
		elif roll == roll_bounds.x:
			_apply_player_percent_damage_nonlethal(clampf(loaded_edge_backlash_percent, 0.0, 1.0))
			_log_debug("Loaded Edge: min roll backlash applied.")
	_apply_event_result(result_to_apply)
	roll_resolved.emit(roll, last_event_id, int(last_event_band))
	_emit_charge_changed()
	_log_debug("Roll=%d, Event=%s, Band=%d, Effect=%s, Duration=%.2fs" % [
		roll,
		String(last_event_id),
		int(last_event_band),
		String(last_result.get("effect_id", &"")),
		float(last_result.get("duration_seconds", 0.0))
	])

	return last_result

func _sync_roll_to_run_state(roll: int) -> void:
	var run_state: Node = _get_run_state()
	if run_state == null:
		return
	if "last_roll" in run_state:
		run_state.set("last_roll", roll)
	if run_state.has_method("_emit"):
		run_state.call("_emit")

func _process_trigger_input(delta: float) -> void:
	if trigger_action == &"":
		return
	if Input.is_action_just_pressed(String(trigger_action)):
		_trigger_buffer_left = maxf(input_buffer_seconds, 0.01)
	if _trigger_buffer_left > 0.0:
		_trigger_buffer_left = maxf(_trigger_buffer_left - delta, 0.0)
		if can_trigger_roll() and _can_player_trigger_meter():
			_trigger_buffer_left = 0.0
			_log_debug("Trigger input accepted; rolling now.")
			trigger_roll()

func _can_player_trigger_meter() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return false
	if "_input_locked" in player and bool(player.get("_input_locked")):
		return false
	return true

func _get_current_dice_range() -> DiceRange:
	var bounds: Vector2i = _get_meter_roll_bounds()
	return DiceRange.new(bounds.x, bounds.y)

func _determine_alignment(roll: int) -> int:
	if roll == 1:
		return FateAlignment.COUNCIL_CATASTROPHE
	if roll == 20:
		return FateAlignment.DIVINE_MIRACLE
	var dice_range: DiceRange = _get_current_dice_range()
	var midpoint: float = dice_range.midpoint()
	if float(roll) < midpoint:
		return FateAlignment.COUNCIL
	if float(roll) > midpoint:
		return FateAlignment.DIVINE
	return FateAlignment.CHAOS

func _alignment_to_outcome_band(alignment: int) -> int:
	match alignment:
		FateAlignment.COUNCIL, FateAlignment.COUNCIL_CATASTROPHE:
			return int(DiceMeterEventData.OutcomeBand.DANGER)
		FateAlignment.DIVINE, FateAlignment.DIVINE_MIRACLE:
			return int(DiceMeterEventData.OutcomeBand.MIRACLE)
		_:
			return int(DiceMeterEventData.OutcomeBand.CHAOS)

func _alignment_to_label(alignment: int) -> String:
	match alignment:
		FateAlignment.COUNCIL:
			return "COUNCIL"
		FateAlignment.COUNCIL_CATASTROPHE:
			return "COUNCIL_CATASTROPHE"
		FateAlignment.DIVINE:
			return "DIVINE"
		FateAlignment.DIVINE_MIRACLE:
			return "DIVINE_MIRACLE"
		_:
			return "CHAOS"

func _select_event_for_roll(roll: int, alignment: int) -> Dictionary:
	if alignment == FateAlignment.COUNCIL_CATASTROPHE:
		return {
			"event_resource": _council_catastrophe_event,
			"member_name": "Council Catastrophe",
			"member_theme": "Catastrophe"
		}
	if alignment == FateAlignment.DIVINE_MIRACLE:
		return {
			"event_resource": _divine_miracle_event,
			"member_name": "Divine Miracle",
			"member_theme": "Miracle"
		}
	var clamped_roll: int = clampi(roll, 2, 19)
	if not _council_members.has(clamped_roll):
		return {}
	var member: DiceCouncilMember = _council_members[clamped_roll] as DiceCouncilMember
	if member == null:
		return {}
	var picked_event: Resource = null
	if alignment == FateAlignment.COUNCIL:
		picked_event = member.council_event
	elif alignment == FateAlignment.DIVINE:
		picked_event = member.divine_event
	else:
		var choose_divine: bool = false
		if RunStateSingleton != null and RunStateSingleton.has_method("roll_for_domain_in_range"):
			choose_divine = int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_chaos_pick", 0, 1, _trigger_count + roll)) == 1
		else:
			choose_divine = randi() % 2 == 1
		picked_event = member.divine_event if choose_divine else member.council_event
	return {
		"event_resource": picked_event,
		"member": member,
		"member_name": member.name,
		"member_theme": member.theme
	}

func _event_resource_to_payload(event_resource: Resource) -> Dictionary:
	if event_resource == null:
		return {}
	var event_id: StringName = &""
	var display_name: String = "Unnamed Event"
	var brief_text: String = ""
	var description: String = ""
	var effect_id: StringName = &""
	var duration_seconds: float = 0.0
	var effect_params: Dictionary = {}
	if _resource_has_property(event_resource, "id"):
		event_id = event_resource.get("id")
	if _resource_has_property(event_resource, "display_name"):
		display_name = String(event_resource.get("display_name"))
	if _resource_has_property(event_resource, "brief_text"):
		brief_text = String(event_resource.get("brief_text"))
	if _resource_has_property(event_resource, "description"):
		description = String(event_resource.get("description"))
	if _resource_has_property(event_resource, "effect_id"):
		effect_id = event_resource.get("effect_id")
	if _resource_has_property(event_resource, "duration_seconds"):
		duration_seconds = maxf(float(event_resource.get("duration_seconds")), 0.0)
	if _resource_has_property(event_resource, "effect_params"):
		var value: Variant = event_resource.get("effect_params")
		if value is Dictionary:
			effect_params = (value as Dictionary).duplicate(true)
	if display_name.strip_edges() == "":
		display_name = "Unnamed Event"
	if brief_text.strip_edges() == "":
		brief_text = "Fate twists in battle."
	if description.strip_edges() == "":
		description = brief_text
	return {
		"event_id": event_id,
		"display_name": display_name,
		"brief_text": brief_text,
		"description": description,
		"effect_id": effect_id,
		"duration_seconds": duration_seconds,
		"effect_params": effect_params
	}

func _resource_has_property(resource: Resource, property_name: String) -> bool:
	if resource == null:
		return false
	for prop: Dictionary in resource.get_property_list():
		if String(prop.get("name", "")) == property_name:
			return true
	return false

func _is_negative_alignment(alignment: int) -> bool:
	return alignment == FateAlignment.COUNCIL or alignment == FateAlignment.COUNCIL_CATASTROPHE

func _alignment_rank(alignment: int) -> int:
	match alignment:
		FateAlignment.COUNCIL_CATASTROPHE:
			return 0
		FateAlignment.COUNCIL:
			return 1
		FateAlignment.CHAOS:
			return 2
		FateAlignment.DIVINE:
			return 3
		FateAlignment.DIVINE_MIRACLE:
			return 4
		_:
			return 2

func _apply_bent_die_alignment_reroll(current_roll: int, current_alignment: int) -> Dictionary:
	var bounds: Vector2i = _get_meter_roll_bounds()
	var reroll_value: int = current_roll
	if RunStateSingleton != null and RunStateSingleton.has_method("roll_for_domain_in_range"):
		reroll_value = int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_bent_die_reroll", bounds.x, bounds.y, _trigger_count))
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		reroll_value = rng.randi_range(bounds.x, bounds.y)
	var reroll_alignment: int = _determine_alignment(reroll_value)
	var current_rank: int = _alignment_rank(current_alignment)
	var reroll_rank: int = _alignment_rank(reroll_alignment)
	if reroll_rank > current_rank or (reroll_rank == current_rank and reroll_value > current_roll):
		return {
			"roll": reroll_value,
			"alignment": reroll_alignment,
			"selection": _select_event_for_roll(reroll_value, reroll_alignment)
		}
	return {
		"roll": current_roll,
		"alignment": current_alignment,
		"selection": _select_event_for_roll(current_roll, current_alignment)
	}

func _apply_event_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var effect_id: StringName = result.get("effect_id", &"")
	var duration: float = float(result.get("duration_seconds", 0.0))
	var params: Dictionary = result.get("effect_params", {})
	match effect_id:
		&"apply_nat1_oof":
			_apply_nat1_oof(duration, params)
		&"spawn_void_spike_rain":
			_apply_void_spike_rain(duration, params)
		&"apply_hex_barrage":
			_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.16)), duration)
			_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 0.88)), duration)
		&"apply_crosswind_pressure":
			_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 0.72)), duration)
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 1.22)), duration)
			_active_player_hp_drain_effects.append({
				"time_left": duration,
				"interval_left": maxf(float(params.get("drain_interval", 1.0)), 0.1),
				"interval": maxf(float(params.get("drain_interval", 1.0)), 0.1),
				"drain_percent": maxf(float(params.get("drain_percent", 0.012)), 0.0),
				"enemy_blast_percent": 0.0,
				"enemy_blast_flat": 0
			})
		&"apply_gravity_well":
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 1.12)), duration)
			_apply_enemy_slow_field(duration, {"slow_mult": float(params.get("slow_mult", 0.85))})
		&"apply_weighted_calm":
			var pause_cooldowns: bool = bool(params.get("pause_player_cooldowns", false))
			if not pause_cooldowns:
				_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 1.22)), duration)
			# RunState recomputes player_move_speed_mult every frame, so apply to the base scalar.
			_apply_temp_mult_to_runstate("_base_player_move_speed_mult", float(params.get("player_move_speed_mult", 0.5)), duration)
			_apply_temp_mult_to_runstate("player_jump_height_mult", float(params.get("player_jump_height_mult", 1.0)), duration)
			_apply_temp_mult_to_runstate("player_gravity_mult", float(params.get("player_gravity_mult", 1.55)), duration)
			_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.0)), duration)
			if float(params.get("snag_seconds", 0.0)) > 0.0:
				_apply_player_freeze_pulses(duration, {
					"interval": maxf(float(params.get("snag_interval", 1.0)), 0.1),
					"freeze_seconds": maxf(float(params.get("snag_seconds", 0.16)), 0.05)
				})
			if float(params.get("wind_push_speed", 0.0)) > 0.0:
				_start_wind_push_effect(
					duration,
					true,
					float(params.get("wind_push_speed", 90.0)),
					float(params.get("counter_move_mult", 0.75))
				)
			if pause_cooldowns:
				_apply_player_cooldown_pause(duration)
		&"apply_coinflip_tempo":
			_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.05)), duration)
			_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.05)), duration)
		&"apply_astral_momentum":
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.85)), duration)
			_apply_temp_mult_to_runstate("player_damage_mult", 1.10, duration)
		&"apply_reprieve_sigil":
			_heal_player_percent(float(params.get("heal_percent", 0.35)))
			_heal_player_percent(float(params.get("bonus_heal_percent", 0.10)))
			_grant_player_shield_percent(float(params.get("shield_percent", 0.12)), float(params.get("shield_duration", 6.0)), float(params.get("shield_cap_percent", 0.20)))
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.90)), duration)
			_apply_player_visual_effect(duration, float(params.get("player_alpha", 0.75)))
		&"apply_enemy_slow_field":
			_apply_enemy_slow_field(duration, params)
		&"apply_celestial_overdrive":
			_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("damage_mult", 1.25)), duration)
			_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("damage_taken_mult", 0.88)), duration)
		&"apply_orb_resonance":
			_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.20)), duration)
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.82)), duration)
			_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 0.92)), duration)
		&"trigger_echo_storm":
			_start_echo_pulses(duration, params)
		&"apply_twentyfold_grace":
			_apply_miracle_effect(duration, params)
		&"apply_nat20_clip":
			_apply_nat20_clip(duration, params)
		&"apply_gravity_reversal":
			_apply_gravity_reversal(duration, params)
		&"apply_bone_lottery":
			_apply_bone_lottery(duration, params)
		&"apply_chrono_skip":
			_apply_chrono_skip(duration, params)
		&"apply_royal_decree":
			_apply_royal_decree(duration, params)
		&"apply_false_crown":
			_apply_false_crown(duration, params)
		&"apply_echo_mirror":
			_apply_echo_mirror(duration, params)
		&"apply_reflection_combo":
			_apply_reflection_combo(duration, params)
		&"apply_void_tax":
			_apply_void_tax(duration, params)
		&"apply_ascension_draft":
			_apply_ascension_draft(duration, params)
		&"spawn_council_catastrophe":
			_apply_council_catastrophe(duration, params)
		&"spawn_enemy_reinforcements":
			_apply_enemy_reinforcements(duration, params)
		&"spawn_council_avatar":
			_apply_council_avatar(duration, params)
		&"spawn_divine_spirit_support":
			_apply_divine_spirit_support(duration, params)
		&"spawn_illusion_phantoms":
			_apply_illusion_phantoms(duration, params)
		&"apply_player_chain":
			_apply_player_chain(duration, params)
		&"apply_enemy_chain":
			_apply_enemy_chain(duration, params)
		&"apply_enemy_freeze_pulses":
			_apply_enemy_freeze_pulses(duration, params)
		&"apply_player_freeze_pulses":
			_apply_player_freeze_pulses(duration, params)
		&"apply_player_lifesteal":
			_apply_player_lifesteal(duration, params)
		&"apply_enemy_regen":
			_apply_enemy_regen(duration, params)
		&"apply_wind_push_enemies":
			_start_wind_push_effect(
				duration,
				false,
				float(params.get("push_speed", 140.0)),
				float(params.get("counter_move_mult", 0.6)),
				float(params.get("idle_drift_scale", 0.0))
			)
		&"apply_wind_push_player":
			_apply_temp_mult_to_runstate("_base_player_move_speed_mult", float(params.get("player_move_speed_mult", 1.0)), duration)
			_start_wind_push_effect(
				duration,
				true,
				float(params.get("push_speed", 140.0)),
				float(params.get("counter_move_mult", 0.6)),
				float(params.get("idle_drift_scale", 0.0))
			)
		_:
			pass

func _apply_nat1_oof(duration: float, params: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		var player: Node = tree.get_first_node_in_group("player")
		if player != null:
			var health: Node = player.get_node_or_null("Health")
			if health != null:
				var max_hp: int = 100
				if "max_hp" in health:
					max_hp = int(health.get("max_hp"))
				elif "max_health" in health:
					max_hp = int(health.get("max_health"))
				var dmg: int = maxi(1, int(round(max_hp * float(params.get("player_damage_pct", 0.22)))))
				# Keep this painful but fair: Dice Meter should never directly kill the player.
				_apply_player_damage_nonlethal(dmg)
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 0.82)), duration)
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.18)), duration)
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 1.15)), duration)

func _heal_player_percent(percent_of_max: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return
	var health: Node = player.get_node_or_null("Health")
	if health == null:
		return
	var p: float = clampf(percent_of_max, 0.0, 1.0)
	if health.has_method("heal_percent"):
		health.call("heal_percent", p)
		return
	var max_hp: int = -1
	var cur_hp: int = -1
	if "max_hp" in health:
		max_hp = int(health.get("max_hp"))
	if "hp" in health:
		cur_hp = int(health.get("hp"))
	if max_hp <= 0 or cur_hp < 0:
		return
	var heal_amount: int = maxi(1, int(round(float(max_hp) * p)))
	var new_hp: int = mini(max_hp, cur_hp + heal_amount)
	if "hp" in health:
		health.set("hp", new_hp)
	if health.has_signal("health_changed"):
		health.emit_signal("health_changed", new_hp, max_hp)

func _apply_nat20_clip(duration: float, params: Dictionary) -> void:
	_apply_miracle_effect(duration, params)
	_apply_enemy_slow_field(minf(duration, 6.0), {"slow_mult": float(params.get("slow_mult", 0.65))})

func _apply_miracle_effect(duration: float, params: Dictionary) -> void:
	var run_state := _get_run_state()
	if run_state != null and run_state.has_method("_full_heal_player"):
		run_state.call("_full_heal_player")
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("damage_mult", 1.40)), duration)
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.80)), duration)

	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return
	var health: Node = player.get_node_or_null("Health")
	if health != null and health.has_method("grant_invuln"):
		health.call("grant_invuln", float(params.get("invuln_seconds", 1.5)), "dice_meter_miracle")
	_grant_player_shield_percent(float(params.get("shield_percent", 0.20)), float(params.get("shield_duration", 8.0)), float(params.get("shield_cap_percent", 0.30)))

func _start_echo_pulses(duration: float, params: Dictionary) -> void:
	var pulse_interval: float = maxf(0.1, float(params.get("pulse_interval", 0.7)))
	var pulse_count: int = int(params.get("pulse_count", 0))
	if pulse_count <= 0:
		pulse_count = maxi(1, int(ceil(maxf(duration, 0.1) / pulse_interval)))
	if pulse_count <= 0:
		return
	var pulse_percent: float = maxf(0.0, float(params.get("pulse_percent", 0.05)))
	var pulse_flat: int = maxi(0, int(params.get("pulse_flat", 10)))
	if pulse_percent <= 0.0 and pulse_flat <= 0:
		return
	_active_echo_pulses.append({
		"time_left": 0.08,
		"interval": pulse_interval,
		"pulses_left": pulse_count,
		"pulse_percent": pulse_percent,
		"pulse_flat": pulse_flat,
		"max_duration": duration,
		"friendly_fire_to_player": bool(params.get("friendly_fire_to_player", false)),
		"player_pulse_percent": maxf(0.0, float(params.get("player_pulse_percent", 0.0))),
		"apply_to_enemies": bool(params.get("apply_to_enemies", true))
	})
	_log_debug("Echo pulses armed: count=%d interval=%.2f" % [pulse_count, pulse_interval])

func _apply_gravity_reversal(duration: float, params: Dictionary) -> void:
	_apply_enemy_slow_field(duration, {"slow_mult": float(params.get("slow_mult", 0.72))})
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.88)), duration)

func _apply_bone_lottery(duration: float, params: Dictionary) -> void:
	var enemies: Array[Node] = _get_active_enemy_nodes()
	if enemies.is_empty():
		return
	var index: int = 0
	if RunStateSingleton != null and RunStateSingleton.has_method("roll_for_domain_in_range"):
		index = int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_bone_lottery", 0, enemies.size() - 1, _trigger_count))
	else:
		index = randi_range(0, enemies.size() - 1)
	var target: Node = enemies[index]
	var radius: float = maxf(float(params.get("splash_radius", 260.0)), 1.0)
	var mark_percent: float = maxf(float(params.get("mark_percent", 0.20)), 0.0)
	var splash_percent: float = maxf(float(params.get("splash_percent", 0.08)), 0.0)
	var splash_flat: int = maxi(int(params.get("splash_flat", 10)), 0)
	_apply_damage_to_enemy_node(target, _calc_enemy_damage_value(target, mark_percent, 0), &"dice_meter_bone_mark")
	var center: Vector2 = _node_global_pos_or_zero(target)
	for enemy: Node in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy == target:
			continue
		if _node_global_pos_or_zero(enemy).distance_to(center) <= radius:
			_apply_damage_to_enemy_node(enemy, _calc_enemy_damage_value(enemy, splash_percent, splash_flat), &"dice_meter_bone_splash")
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.95)), duration)

func _apply_chrono_skip(duration: float, params: Dictionary) -> void:
	_refresh_random_combat_cooldown()
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.10)), duration)
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.12)), duration)

func _apply_royal_decree(duration: float, params: Dictionary) -> void:
	var single_hit_floorwide: bool = bool(params.get("single_hit_floorwide", false))
	var target: Node = _find_highest_hp_enemy()
	if target == null and not single_hit_floorwide:
		return
	if single_hit_floorwide:
		_apply_floorwide_enemy_damage(
			maxf(float(params.get("cleave_percent", 0.10)), 0.0),
			maxi(int(params.get("cleave_flat", 12)), 0)
		)
	else:
		# NAT 20 execution fantasy: immediate judgment burst + sustained decree on the strongest foe.
		_apply_damage_to_enemy_node(
			target,
			_calc_enemy_damage_value(
				target,
				maxf(float(params.get("opening_percent", 0.18)), 0.0),
				maxi(int(params.get("opening_flat", 20)), 0)
			),
			&"dice_meter_royal_decree_opening"
		)
		_apply_floorwide_enemy_damage(
			maxf(float(params.get("cleave_percent", 0.10)), 0.0),
			maxi(int(params.get("cleave_flat", 12)), 0)
		)
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.30)), duration)
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.85)), duration)
	_grant_player_shield_percent(
		float(params.get("shield_percent", 0.12)),
		float(params.get("shield_duration", 6.0)),
		float(params.get("shield_cap_percent", 0.25))
	)
	var tick_percent: float = maxf(float(params.get("tick_percent", 0.06)), 0.0)
	var tick_flat: int = maxi(int(params.get("tick_flat", 8)), 0)
	if not single_hit_floorwide and target != null and (tick_percent > 0.0 or tick_flat > 0):
		_active_target_execution_effects.append({
			"target_id": target.get_instance_id(),
			"time_left": duration,
			"interval_left": maxf(float(params.get("tick_interval", 1.0)), 0.1),
			"interval": maxf(float(params.get("tick_interval", 1.0)), 0.1),
			"tick_percent": tick_percent,
			"tick_flat": tick_flat
		})
	var hard_freeze: float = maxf(float(params.get("hard_freeze_seconds", 0.0)), 0.0)
	if hard_freeze > 0.0:
		_apply_enemy_freeze_state(hard_freeze, false)
	elif maxf(float(params.get("freeze_seconds", 0.0)), 0.0) > 0.0:
		_apply_enemy_freeze_pulses(duration, {
			"interval": maxf(float(params.get("freeze_interval", 0.9)), 0.1),
			"freeze_seconds": maxf(float(params.get("freeze_seconds", 0.22)), 0.05),
			"include_boss": false
		})

func _apply_false_crown(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.30)), duration)
	_active_player_hp_drain_effects.append({
		"time_left": duration,
		"interval_left": maxf(float(params.get("drain_interval", 1.0)), 0.1),
		"interval": maxf(float(params.get("drain_interval", 1.0)), 0.1),
		"drain_percent": maxf(float(params.get("drain_percent", 0.06)), 0.0),
		"enemy_blast_percent": maxf(float(params.get("enemy_blast_percent", 0.0)), 0.0),
		"enemy_blast_flat": maxi(int(params.get("enemy_blast_flat", 0)), 0)
	})

func _apply_echo_mirror(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.18)), duration)
	_start_echo_pulses(duration, {
		"pulse_count": maxi(1, int(params.get("pulse_count", 5))),
		"pulse_interval": maxf(0.1, float(params.get("pulse_interval", 0.65))),
		"pulse_percent": maxf(0.0, float(params.get("pulse_percent", 0.018))),
		"pulse_flat": maxi(0, int(params.get("pulse_flat", 5)))
	})

func _apply_void_tax(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.85)), duration)
	_active_player_hp_drain_effects.append({
		"time_left": duration,
		"interval_left": maxf(float(params.get("drain_interval", 0.8)), 0.1),
		"interval": maxf(float(params.get("drain_interval", 0.8)), 0.1),
		"drain_percent": maxf(float(params.get("drain_percent", 0.02)), 0.0),
		"enemy_blast_percent": maxf(float(params.get("enemy_blast_percent", 0.0)), 0.0),
		"enemy_blast_flat": maxi(int(params.get("enemy_blast_flat", 0)), 0)
	})

func _apply_ascension_draft(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.25)), duration)
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.80)), duration)
	_apply_enemy_slow_field(duration, {"slow_mult": float(params.get("slow_mult", 0.85))})
	_grant_player_shield_percent(float(params.get("shield_percent", 0.10)), float(params.get("shield_duration", 5.0)), float(params.get("shield_cap_percent", 0.20)))

func _apply_void_spike_rain(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.12)), duration)
	_active_player_hp_drain_effects.append({
		"time_left": duration,
		"interval_left": maxf(float(params.get("player_hit_interval", 0.9)), 0.1),
		"interval": maxf(float(params.get("player_hit_interval", 0.9)), 0.1),
		"drain_percent": maxf(float(params.get("player_hit_percent", 0.015)), 0.0),
		"enemy_blast_percent": maxf(float(params.get("enemy_blast_percent", 0.0)), 0.0),
		"enemy_blast_flat": maxi(int(params.get("enemy_blast_flat", 0)), 0)
	})

func _apply_council_catastrophe(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.18)), duration)
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 0.90)), duration)
	_apply_player_percent_damage_nonlethal(float(params.get("opening_player_damage_percent", 0.08)))
	_spawn_temporary_enemy_wave(params, duration, true)
	_start_echo_pulses(duration, {
		"pulse_count": maxi(1, int(params.get("pulse_count", maxi(2, int(round(duration / 0.9)))))),
		"pulse_interval": maxf(float(params.get("pulse_interval", 0.9)), 0.1),
		"pulse_percent": maxf(float(params.get("pulse_percent", 0.02)), 0.0),
		"pulse_flat": maxi(int(params.get("pulse_flat", 4)), 0),
		"friendly_fire_to_player": bool(params.get("friendly_fire_to_player", true)),
		"player_pulse_percent": maxf(float(params.get("player_pulse_percent", 0.01)), 0.0),
		"apply_to_enemies": bool(params.get("apply_to_enemies", true))
	})

func _apply_enemy_reinforcements(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.08)), duration)
	_spawn_temporary_enemy_wave(params, duration, false)

func _apply_council_avatar(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.10)), duration)
	_spawn_temporary_enemy_wave(params, duration, true)

func _apply_divine_spirit_support(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.12)), duration)
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.90)), duration)
	_start_echo_pulses(duration, {
		"pulse_count": maxi(1, int(params.get("pulse_count", 4))),
		"pulse_interval": maxf(0.1, float(params.get("pulse_interval", 0.8))),
		"pulse_percent": maxf(0.0, float(params.get("pulse_percent", 0.03))),
		"pulse_flat": maxi(0, int(params.get("pulse_flat", 6)))
	})

func _apply_illusion_phantoms(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.12)), duration)
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var enemies: Array[Node] = _get_primary_enemy_targets()
	if enemies.is_empty():
		return
	var alpha: float = clampf(float(params.get("spirit_alpha", 0.72)), 0.2, 1.0)
	var offset_radius: float = maxf(float(params.get("spawn_offset_radius", 110.0)), 24.0)
	offset_radius = minf(offset_radius, 56.0)
	for i: int in range(enemies.size()):
		var enemy: Node = enemies[i]
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_in_group(&"boss"):
			continue
		if not (enemy is Node2D):
			continue
		var scene_path: String = String(enemy.scene_file_path)
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			continue
		var phantom: Node = scene.instantiate()
		if phantom == null:
			continue
		phantom.set_meta("dice_meter_phantom", true)
		tree.current_scene.add_child(phantom)
		if phantom is Node2D:
			var enemy_pos: Vector2 = (enemy as Node2D).global_position
			var side_sign: float = -1.0 if (i % 2 == 0) else 1.0
			(phantom as Node2D).global_position = enemy_pos + Vector2(side_sign * offset_radius, 0.0)
			var tint: Color = (phantom as Node2D).modulate
			tint.a = alpha
			(phantom as Node2D).modulate = tint
			var p_canvas: CanvasItem = phantom as CanvasItem
			if p_canvas != null:
				var player_canvas: CanvasItem = _resolve_player_canvas_item()
				if player_canvas != null:
					p_canvas.z_as_relative = false
					p_canvas.z_index = player_canvas.z_index
		var floor_group: StringName = _resolve_enemy_floor_group_from_node(enemy)
		if floor_group != &"":
			phantom.add_to_group(floor_group)
		_spawn_necro_phantom_minion_if_applicable(phantom, maxf(duration + 0.2, 0.2), alpha, floor_group)
		_register_phantom_minion_watcher(phantom, maxf(duration + 0.2, 0.2), alpha, floor_group)
		_schedule_temp_enemy_cleanup(phantom, maxf(duration + 0.2, 0.2))

func _apply_reflection_combo(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.10)), duration)
	_clear_all_reflection_combo_actors()
	_cleanup_stray_reflection_visuals()
	_active_reflection_combo_effects.clear()
	if debug_logs:
		_log_reflection_debug_state("pre_spawn")
	var player_root: Node = _resolve_player_node()
	if player_root == null or not (player_root is Node2D):
		return
	_normalize_player_body3d_view_render_nodes(player_root)
	_prune_player_body3d_duplicate_models(player_root)
	_cleanup_reflection_artifacts_under_player(player_root)
	var reflection: Node2D = _spawn_player_reflection_copy(player_root, params)
	if reflection == null:
		return
	var life: float = maxf(float(params.get("copy_lifetime", maxf(duration, 0.1))), 0.1)
	_active_reflection_combo_effects.append({
		"time_left": life,
		"reflection_id": reflection.get_instance_id()
	})
	if debug_logs:
		_log_reflection_debug_state("post_spawn")
		_log_reflection_forensic_scan("post_spawn")

func _spawn_player_reflection_copy(player_root: Node, params: Dictionary = {}) -> Node2D:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	if player_root == null or not (player_root is Node2D):
		return null
	if PLAYER_REFLECTION_CLONE_SCENE == null:
		return null
	var player_pos: Vector2 = (player_root as Node2D).global_position
	var offset_x: float = float(params.get("spawn_offset_x", 100.0))
	var offset_y: float = float(params.get("spawn_offset_y", 0.0))
	# Step-0 baseline: fixed world offset, no facing-based side swaps.
	var spawn_pos: Vector2 = player_pos + Vector2(offset_x, offset_y)
	var debug_marker_mode: bool = bool(params.get("debug_marker_mode", true))
	if debug_marker_mode:
		var marker_root: Node2D = Node2D.new()
		marker_root.name = "ReflectionActor"
		marker_root.add_to_group(&"dice_meter_reflection_actor")
		marker_root.set_meta("dice_meter_reflection", true)
		marker_root.set_meta("reflection_source", "11g_player_anchor")
		marker_root.set_meta("reflection_target_id", 0)
		marker_root.top_level = true
		marker_root.process_mode = Node.PROCESS_MODE_PAUSABLE
		var marker_poly: Polygon2D = Polygon2D.new()
		marker_poly.name = "ReflectionMarker"
		marker_poly.color = Color(1.0, 0.0, 1.0, 0.65)
		marker_poly.polygon = PackedVector2Array([
			Vector2(0.0, -42.0),
			Vector2(32.0, 0.0),
			Vector2(0.0, 42.0),
			Vector2(-32.0, 0.0)
		])
		marker_root.add_child(marker_poly)
		tree.current_scene.add_child(marker_root)
		marker_root.global_position = spawn_pos
		if debug_logs:
			_log_debug("11G reflection marker spawn player=%s spawn=%s" % [str(player_pos), str(spawn_pos)])
		return marker_root
	var snapshot_actor: Node2D = _spawn_reflection_snapshot_actor(player_root, spawn_pos, float(params.get("clone_alpha", 0.95)))
	if snapshot_actor != null:
		if debug_logs:
			_log_debug("11G reflection snapshot spawn player=%s spawn=%s" % [str(player_pos), str(spawn_pos)])
		return snapshot_actor
	var reflection_root: Node2D = PLAYER_REFLECTION_CLONE_SCENE.instantiate() as Node2D
	if reflection_root == null or not (reflection_root is Node2D):
		return null
	var reflection_script: Script = reflection_root.get_script() as Script
	var reflection_script_path: String = String(reflection_script.resource_path) if reflection_script != null else ""
	if reflection_script_path != PLAYER_REFLECTION_CLONE_SCRIPT_PATH:
		if debug_logs:
			_log_debug("11G rejected reflection root: unexpected script=%s" % reflection_script_path)
		reflection_root.queue_free()
		return null
	if not reflection_root.has_method("configure_from_player"):
		if debug_logs:
			_log_debug("11G rejected reflection root: missing configure_from_player")
		reflection_root.queue_free()
		return null
	reflection_root.name = "ReflectionActor"
	reflection_root.add_to_group(&"dice_meter_reflection_actor")
	reflection_root.set_meta("dice_meter_reflection", true)
	reflection_root.set_meta("reflection_source", "11g_player_anchor")
	reflection_root.set_meta("reflection_target_id", 0)
	reflection_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	reflection_root.top_level = true
	tree.current_scene.add_child(reflection_root)
	reflection_root.global_position = spawn_pos
	var copy_canvas: CanvasItem = reflection_root as CanvasItem
	var player_canvas: CanvasItem = _resolve_player_canvas_item()
	if copy_canvas != null and player_canvas != null:
		copy_canvas.z_as_relative = false
		copy_canvas.z_index = player_canvas.z_index
	if reflection_root.has_method("set_clone_alpha"):
		reflection_root.call("set_clone_alpha", 0.95)
	if reflection_root.has_method("set_debug_marker_mode"):
		reflection_root.call("set_debug_marker_mode", false)
	if "character_data" in player_root and reflection_root.has_method("configure_from_character_data"):
		var cdata: Object = player_root.get("character_data") as Object
		reflection_root.call("configure_from_character_data", cdata)
	# Keep spawn path isolated: do not mutate live player view or bind reflection to live player animation state.
	if reflection_root.has_method("play_idle"):
		reflection_root.call("play_idle")
	if reflection_root.has_method("freeze_clone_visual"):
		reflection_root.call("freeze_clone_visual")
	if debug_logs:
		_log_debug("11G reflection anchor spawn player=%s spawn=%s" % [str(player_pos), str(spawn_pos)])
	return reflection_root

func _spawn_reflection_snapshot_actor(player_root: Node, spawn_pos: Vector2, alpha: float) -> Node2D:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	if player_root == null or not is_instance_valid(player_root):
		return null
	var body_view: Node2D = player_root.get_node_or_null("Visual/Body3DView") as Node2D
	if body_view == null:
		return null
	var src_sprite: Sprite2D = body_view.get_node_or_null("ScreenSprite") as Sprite2D
	if src_sprite == null or src_sprite.texture == null:
		return null
	var src_tex: Texture2D = src_sprite.texture
	if src_tex == null:
		return null
	var img: Image = src_tex.get_image()
	if img == null or img.is_empty():
		return null
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	if tex == null:
		return null
	var root: Node2D = Node2D.new()
	root.name = "ReflectionActor"
	root.top_level = true
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_to_group(&"dice_meter_reflection_actor")
	root.set_meta("dice_meter_reflection", true)
	root.set_meta("reflection_source", "11g_player_anchor")
	root.set_meta("reflection_target_id", 0)
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "SnapshotSprite"
	spr.texture = tex
	spr.centered = src_sprite.centered
	spr.region_enabled = src_sprite.region_enabled
	spr.region_rect = src_sprite.region_rect
	# Match player's rendered on-screen size using one effective scale source.
	spr.scale = src_sprite.global_scale
	spr.rotation = src_sprite.global_rotation
	spr.texture_filter = src_sprite.texture_filter
	spr.modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.05, 1.0))
	root.add_child(spr)
	tree.current_scene.add_child(root)
	root.global_position = spawn_pos
	return root

func _cleanup_reflection_artifacts_under_player(player_root: Node) -> void:
	if player_root == null or not is_instance_valid(player_root):
		return
	var canonical_body_view: Node = player_root.get_node_or_null("Visual/Body3DView")
	var stack: Array[Node] = [player_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null or not is_instance_valid(n):
			continue
		var script_ref: Script = n.get_script() as Script
		var script_path: String = String(script_ref.resource_path) if script_ref != null else ""
		var scene_path: String = String(n.scene_file_path)
		var remove_node: bool = false
		if n != canonical_body_view:
			if script_path == PLAYER_REFLECTION_CLONE_SCRIPT_PATH:
				remove_node = true
			elif scene_path == PLAYER_REFLECTION_CLONE_SCENE_PATH:
				remove_node = true
			elif script_path == PLAYER_3D_VIEW_SCRIPT_PATH:
				remove_node = true
			elif scene_path == PLAYER_3D_VIEW_SCENE_PATH:
				remove_node = true
		if remove_node:
			n.queue_free()
			continue
		for child: Node in n.get_children():
			stack.append(child)

func _prune_player_body3d_duplicate_models(player_root: Node) -> void:
	if player_root == null or not is_instance_valid(player_root):
		return
	var body_view: Node = player_root.get_node_or_null("Visual/Body3DView")
	if body_view == null or not is_instance_valid(body_view):
		return
	var facing_pivot: Node = body_view.get_node_or_null("SubViewport/Player3DStage/FacingPivot")
	if facing_pivot == null or not is_instance_valid(facing_pivot):
		return
	var keep: Node = null
	var removed_count: int = 0
	for child: Node in facing_pivot.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if keep == null:
			keep = child
			continue
		removed_count += 1
		child.queue_free()
	if debug_logs and removed_count > 0:
		_log_debug("11G pruned player Body3DView duplicates: removed=%d" % removed_count)

func _normalize_player_body3d_view_render_nodes(player_root: Node) -> void:
	if player_root == null or not is_instance_valid(player_root):
		return
	var body_view: Node = player_root.get_node_or_null("Visual/Body3DView")
	if body_view == null or not is_instance_valid(body_view):
		return
	var first_subviewport: Node = null
	var first_screen_sprite: Node = null
	var removed_subviewports: int = 0
	var removed_screens: int = 0
	for child: Node in body_view.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.name == "SubViewport":
			if first_subviewport == null:
				first_subviewport = child
			else:
				child.queue_free()
				removed_subviewports += 1
				continue
		elif child.name == "ScreenSprite":
			if first_screen_sprite == null:
				first_screen_sprite = child
			else:
				child.queue_free()
				removed_screens += 1
				continue
	if first_subviewport != null and is_instance_valid(first_subviewport):
		var keep_stage: Node = null
		var removed_stages: int = 0
		for sv_child: Node in first_subviewport.get_children():
			if sv_child == null or not is_instance_valid(sv_child):
				continue
			if keep_stage == null:
				keep_stage = sv_child
				continue
			sv_child.queue_free()
			removed_stages += 1
		if debug_logs and (removed_subviewports > 0 or removed_screens > 0 or removed_stages > 0):
			_log_debug(
				"11G normalized player Body3DView render nodes: subviewports_removed=%d screens_removed=%d subviewport_children_removed=%d" % [
					removed_subviewports,
					removed_screens,
					removed_stages
				]
			)

func _clear_all_reflection_combo_actors() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group(&"dice_meter_reflection_actor"):
		if n == null or not is_instance_valid(n):
			continue
		n.free()

func _clear_reflection_actor_for_target(target_id: int) -> void:
	if target_id == 0:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group(&"dice_meter_reflection_actor"):
		if n == null or not is_instance_valid(n):
			continue
		if int(n.get_meta("reflection_target_id", 0)) != target_id:
			continue
		n.queue_free()

func _log_reflection_debug_state(stage: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player_nodes: Array[String] = []
	for p: Node in tree.get_nodes_in_group(&"player"):
		if p == null or not is_instance_valid(p):
			continue
		var p_script: String = ""
		var ps: Script = p.get_script() as Script
		if ps != null:
			p_script = String(ps.resource_path)
		var p_pos: Vector2 = _node_global_pos_or_zero(p)
		player_nodes.append("%s@%s pos=%s script=%s" % [p.name, String(p.scene_file_path), str(p_pos), p_script])
	var actor_nodes: Array[String] = []
	for n: Node in tree.get_nodes_in_group(&"dice_meter_reflection_actor"):
		if n == null or not is_instance_valid(n):
			continue
		var npos: Vector2 = _node_global_pos_or_zero(n)
		actor_nodes.append("%s id=%d target=%d pos=%s src=%s" % [
			n.name,
			n.get_instance_id(),
			int(n.get_meta("reflection_target_id", 0)),
			str(npos),
			String(n.get_meta("reflection_source", ""))
		])
	_log_debug("11G state[%s] players=%d {%s} reflections=%d {%s}" % [
		stage,
		player_nodes.size(),
		"; ".join(player_nodes),
		actor_nodes.size(),
		"; ".join(actor_nodes)
	])
	_log_reflection_visual_link_debug(stage)

func _get_reflection_combo_enemy_targets() -> Array[Node]:
	var out: Array[Node] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return out
	var seen: Dictionary = {}
	var groups: Array[StringName] = [
		&"floor1_enemies", &"floor2_enemies", &"floor3_enemies", &"floor4_enemies", &"floor5_enemies",
		&"subarena_enemies", &"elites", &"enemy", &"enemies"
	]
	for g: StringName in groups:
		for n: Node in tree.get_nodes_in_group(g):
			if n == null or not is_instance_valid(n):
				continue
			if n.is_in_group(&"player") or _is_node_under_player(n):
				continue
			if not (n is Node2D):
				continue
			if not n.has_node("Health") and not n.has_node("BossHealth"):
				continue
			var scene_path: String = String(n.scene_file_path)
			if scene_path == "" or not scene_path.begins_with("res://scenes/enemies/"):
				continue
			var id: int = n.get_instance_id()
			if id == 0 or seen.has(id):
				continue
			seen[id] = true
			out.append(n)
	return out

func _get_selected_character_name(player_root: Node) -> String:
	if player_root != null and ("character_data" in player_root):
		var cdata: Object = player_root.get("character_data") as Object
		if cdata != null and ("character_name" in cdata):
			return String(cdata.get("character_name"))
	return CharacterDatabase.get_selected_character()

func _cleanup_stray_reflection_visuals() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var player_root: Node = _resolve_player_node()
	var player_body_view: Node = null
	if player_root != null and is_instance_valid(player_root):
		player_body_view = player_root.get_node_or_null("Visual/Body3DView")
	var stack: Array[Node] = [tree.current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null or not is_instance_valid(n):
			continue
		var script_ref: Script = n.get_script() as Script
		var script_path: String = String(script_ref.resource_path) if script_ref != null else ""
		var is_reflection_view: bool = script_path == PLAYER_3D_VIEW_SCRIPT_PATH
		var is_reflection_clone: bool = script_path == PLAYER_REFLECTION_CLONE_SCRIPT_PATH
		if is_reflection_view or is_reflection_clone:
			# Keep only managed reflection actors in the dedicated group.
			if n.is_in_group(&"dice_meter_reflection_actor"):
				pass
			elif n.get_parent() != null and n.get_parent().is_in_group(&"dice_meter_reflection_actor"):
				pass
			elif n == player_body_view:
				pass
			else:
				n.queue_free()
				continue
		if _is_legacy_unmanaged_player_clone(n, player_root, player_body_view):
			n.queue_free()
			continue
		for child: Node in n.get_children():
			stack.append(child)

func _is_legacy_unmanaged_player_clone(node: Node, player_root: Node, player_body_view: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node == player_root or node == player_body_view:
		return false
	if node.is_in_group(&"dice_meter_reflection_actor"):
		return false
	if node.get_parent() == player_root and node.name == "Visual":
		return false
	if node.is_in_group(&"player"):
		return true
	if bool(node.get_meta("dice_meter_reflection", false)):
		return true
	var script_ref: Script = node.get_script() as Script
	var script_path: String = String(script_ref.resource_path) if script_ref != null else ""
	if script_path == PLAYER_CONTROLLER_SCRIPT_PATH:
		return true
	if script_path == PLAYER_3D_VIEW_SCRIPT_PATH:
		return true
	if script_path == PLAYER_REFLECTION_CLONE_SCRIPT_PATH:
		return true
	var scene_path: String = String(node.scene_file_path)
	if scene_path == PLAYER_SCENE_PATH:
		return true
	if scene_path == PLAYER_3D_VIEW_SCENE_PATH:
		return true
	# Defensive: catch cloned player roots even when script metadata is missing.
	if node != player_root and node.has_node("Visual/Body3DView") and node.has_node("Combat") and node.has_node("Health"):
		return true
	return false

func _purge_reflection_artifacts() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player_body_view: Node = null
	var player_root: Node = _resolve_player_node()
	if player_root != null:
		player_body_view = player_root.get_node_or_null("Visual/Body3DView")
	for n: Node in tree.get_nodes_in_group(&"dice_meter_reflection_actor"):
		if n != null and is_instance_valid(n):
			n.queue_free()
	var stack: Array[Node] = []
	if tree.current_scene != null:
		stack.append(tree.current_scene)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == null or not is_instance_valid(node):
			continue
		if _is_node_under_player(node):
			# Never modify the live player subtree during reflection cleanup.
			continue
		if node.has_meta("dice_meter_reflection"):
			if node != player_body_view:
				node.queue_free()
				continue
		var is_player_view: bool = false
		var is_reflection_clone: bool = false
		var node_script_ref: Script = node.get_script() as Script
		if node_script_ref != null and String(node_script_ref.resource_path) == "res://scripts/player/Player3DView.gd":
			is_player_view = true
		if node_script_ref != null and String(node_script_ref.resource_path) == "res://scripts/vfx/PlayerReflectionCloneVFX.gd":
			is_reflection_clone = true
		# Never touch the live player view (or anything under a player root).
		if is_player_view and _is_node_under_player(node):
			continue
		# Remove non-player Player3DView artifacts.
		if is_player_view and node != player_body_view:
			node.queue_free()
			continue
		if is_reflection_clone and not node.is_in_group(&"dice_meter_reflection_actor"):
			node.queue_free()
			continue
		if node != player_body_view and not _is_node_under_player(node):
			var stray_script_ref: Script = node.get_script() as Script
			if stray_script_ref != null and (
				String(stray_script_ref.resource_path) == "res://scripts/player/Player3DView.gd" or
				String(stray_script_ref.resource_path) == "res://scripts/vfx/PlayerReflectionCloneVFX.gd"
			):
				node.queue_free()
				continue
		for child: Node in node.get_children():
			stack.append(child)

func _apply_player_like_heavy_to_target(target: Node, params: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	var player_root: Node = _resolve_player_node()
	var combat: Node = null
	if player_root != null:
		combat = player_root.get_node_or_null("Combat")
	var dmg: int = maxi(int(params.get("fallback_damage", 14)), 1)
	if combat != null:
		if "heavy_damage" in combat:
			dmg = maxi(int(combat.get("heavy_damage")), 1)
		if combat.has_method("_apply_run_damage_multiplier"):
			dmg = int(combat.call("_apply_run_damage_multiplier", dmg))
		if combat.has_method("_apply_buffs_outgoing_multiplier"):
			dmg = int(combat.call("_apply_buffs_outgoing_multiplier", dmg))
		var was_crit: bool = false
		if combat.has_method("_roll_crit"):
			was_crit = bool(combat.call("_roll_crit"))
		if combat.has_method("_apply_crit_if_any"):
			dmg = int(combat.call("_apply_crit_if_any", dmg, was_crit))
	dmg = maxi(dmg, 1)
	var hp_node: Node = target.get_node_or_null("Health")
	if hp_node != null and hp_node.has_method("take_damage"):
		var argc: int = hp_node.get_method_argument_count("take_damage")
		if argc >= 4:
			hp_node.call("take_damage", dmg, player_root, &"", false)
		elif argc >= 3:
			hp_node.call("take_damage", dmg, player_root, &"")
		elif argc >= 2:
			hp_node.call("take_damage", dmg, player_root)
		else:
			hp_node.call("take_damage", dmg)
	elif target.has_method("take_damage"):
		target.call("take_damage", dmg, player_root)
	_apply_bleed_to_target_like_player_heavy(target, params)

func _apply_bleed_to_target_like_player_heavy(target: Node, params: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	var receiver: Node = target.get_node_or_null("Health")
	if receiver == null:
		receiver = target
	var status_effects: Node = target.get_node_or_null("StatusEffects")
	if status_effects == null:
		status_effects = EnemyStatusEffects.new()
		status_effects.name = "StatusEffects"
		target.add_child(status_effects)
	if status_effects is EnemyStatusEffects:
		var se: EnemyStatusEffects = status_effects as EnemyStatusEffects
		se.set_receiver(receiver)
		se.apply_bleed_refresh(
			maxi(int(params.get("bleed_tick_damage", 2)), 1),
			maxf(float(params.get("bleed_duration", 4.0)), 0.1),
			maxf(float(params.get("bleed_tick_interval", 0.5)), 0.05)
		)

func _spawn_temporary_enemy_wave(params: Dictionary, duration: float, force_elite: bool) -> void:
	var scene_path: String = String(params.get("spawn_scene", "res://scenes/enemies/EnemyKnightAdd.tscn"))
	if scene_path == "":
		return
	if not ResourceLoader.exists(scene_path):
		return
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return
	var spawn_count: int = maxi(1, int(params.get("spawn_count", 1)))
	var alpha: float = clampf(float(params.get("spirit_alpha", 0.85)), 0.2, 1.0)
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	var floor_group: StringName = _resolve_primary_enemy_floor_group()
	var anchors: Array[Vector2] = _collect_spawn_anchors_for_group(floor_group)
	var anchor: Vector2 = Vector2.ZERO
	if not anchors.is_empty():
		anchor = anchors[0]
	elif player is Node2D:
		anchor = (player as Node2D).global_position
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if RunStateSingleton != null and RunStateSingleton.has_method("make_rng_for_domain"):
		var seeded: RandomNumberGenerator = RunStateSingleton.call("make_rng_for_domain", &"dice_meter_temp_spawns", (_trigger_count * 101) + spawn_count) as RandomNumberGenerator
		if seeded != null:
			rng.seed = seeded.seed
		else:
			rng.randomize()
	else:
		rng.randomize()
	var despawn_after: bool = bool(params.get("despawn_after_duration", false))
	for i: int in range(spawn_count):
		var node: Node = scene.instantiate()
		if node == null:
			continue
		tree.current_scene.add_child(node)
		if node is Node2D:
			var n2d: Node2D = node as Node2D
			if not anchors.is_empty():
				var pick: int = rng.randi_range(0, anchors.size() - 1)
				n2d.global_position = anchors[pick]
			else:
				var offset: Vector2 = Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-40.0, 40.0))
				n2d.global_position = anchor + offset
			var tint: Color = n2d.modulate
			tint.a = alpha
			n2d.modulate = tint
		node.add_to_group(floor_group)
		if force_elite:
			node.add_to_group(&"elites")
		if despawn_after:
			_schedule_temp_enemy_cleanup(node, maxf(duration + 0.8, 6.0))

func _schedule_temp_enemy_cleanup(node: Node, delay_seconds: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(maxf(delay_seconds, 0.1))
	timer.timeout.connect(_on_temp_cleanup_timeout.bind(node.get_instance_id()))

func _on_temp_cleanup_timeout(node_id: int) -> void:
	var obj: Object = instance_from_id(node_id)
	if obj == null or not is_instance_valid(obj) or not (obj is Node):
		return
	(obj as Node).queue_free()

func _resolve_primary_enemy_floor_group() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return &"subarena_enemies"
	for g: StringName in [&"floor1_enemies", &"floor2_enemies", &"floor3_enemies", &"floor4_enemies", &"floor5_enemies"]:
		if not tree.get_nodes_in_group(g).is_empty():
			return g
	return &"subarena_enemies"

func _resolve_enemy_floor_group_from_node(enemy: Node) -> StringName:
	if enemy == null:
		return &""
	for g: StringName in [&"floor1_enemies", &"floor2_enemies", &"floor3_enemies", &"floor4_enemies", &"floor5_enemies", &"subarena_enemies"]:
		if enemy.is_in_group(g):
			return g
	return _resolve_primary_enemy_floor_group()

func _resolve_current_player_floor_group() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return _resolve_primary_enemy_floor_group()
	var floors: Node = tree.get_first_node_in_group("floors")
	if floors == null:
		return _resolve_primary_enemy_floor_group()
	if not ("floor_enemy_groups" in floors):
		return _resolve_primary_enemy_floor_group()
	if not floors.has_method("get_current_floor_number"):
		return _resolve_primary_enemy_floor_group()
	var groups: Array = floors.get("floor_enemy_groups")
	var floor_num: int = int(floors.call("get_current_floor_number"))
	var idx: int = floor_num - 1
	if idx < 0 or idx >= groups.size():
		return _resolve_primary_enemy_floor_group()
	var group_name: Variant = groups[idx]
	if group_name is StringName:
		return group_name as StringName
	return StringName(String(group_name))

func _get_primary_enemy_targets() -> Array[Node]:
	var out: Array[Node] = []
	var seen_actor_ids: Dictionary = {}
	var tree: SceneTree = get_tree()
	if tree == null:
		return out
	var player_pos: Vector2 = _node_global_pos_or_zero(_resolve_player_node())
	var current_group: StringName = _resolve_current_player_floor_group()
	# Prefer active player floor group; include subarena/elites/boss as fallback.
	var search_groups: Array[StringName] = [current_group, &"subarena_enemies", &"elites", &"boss"]
	for g: StringName in search_groups:
		for n: Node in tree.get_nodes_in_group(g):
			if n == null or not is_instance_valid(n):
				continue
			if _is_node_under_player(n):
				continue
			if not (n is Node2D):
				continue
			var scene_path: String = String(n.scene_file_path)
			if scene_path == "":
				continue
			var is_enemy_scene: bool = scene_path.begins_with("res://scenes/enemies/")
			var is_boss_scene: bool = scene_path.begins_with("res://scenes/boss/")
			if not is_enemy_scene and not is_boss_scene:
				continue
			if not n.has_node("Health") and not n.has_node("BossHealth"):
				continue
			# Ignore distant/inactive floor actors to avoid spawning reflections off-map.
			var npos: Vector2 = _node_global_pos_or_zero(n)
			if player_pos != Vector2.ZERO and npos.distance_to(player_pos) > 2800.0:
				continue
			var actor: Node = n
			var actor_id: int = actor.get_instance_id()
			if actor_id == 0:
				continue
			if seen_actor_ids.has(actor_id):
				continue
			seen_actor_ids[actor_id] = true
			out.append(actor)
	return out

func _resolve_reflection_actor_root(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	var cur: Node = node
	while cur != null and is_instance_valid(cur):
		if cur.has_node("Health") or cur.has_node("BossHealth"):
			return cur
		cur = cur.get_parent()
	return null

func _is_valid_reflection_target_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not (node is Node2D):
		return false
	var actor: Node = _resolve_reflection_actor_root(node)
	if actor == null:
		return false
	if actor.is_in_group(&"player"):
		return false
	var scene_path: String = String(actor.scene_file_path)
	if scene_path == "":
		return false
	var is_enemy_scene: bool = scene_path.begins_with("res://scenes/enemies/")
	var is_boss_scene: bool = scene_path.begins_with("res://scenes/boss/")
	if not is_enemy_scene and not is_boss_scene:
		return false
	var health: Node = actor.get_node_or_null("Health")
	if health == null:
		health = actor.get_node_or_null("BossHealth")
	if health == null:
		return false
	return true

func _resolve_player_canvas_item() -> CanvasItem:
	var player: Node = _resolve_player_node()
	if player != null and player is CanvasItem:
		return player as CanvasItem
	return null

func _play_reflection_heavy_vfx(origin: Vector2, facing: int) -> void:
	var selected_character: String = CharacterDatabase.get_selected_character()
	var player_root: Node = _resolve_player_node()
	if player_root != null and ("character_data" in player_root):
		var cdata: Object = player_root.get("character_data") as Object
		if cdata != null and ("character_name" in cdata):
			selected_character = String(cdata.get("character_name"))
	var scene: PackedScene = KNIGHT_HEAVY_VFX_SCENE if selected_character == "Knight" else ROGUE_HEAVY_VFX_SCENE
	if scene == null:
		return
	var node: Node = scene.instantiate()
	if node == null:
		return
	var n2d: Node2D = node as Node2D
	if n2d == null:
		node.queue_free()
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		n2d.queue_free()
		return
	tree.current_scene.add_child(n2d)
	n2d.global_position = origin
	n2d.set_meta("dice_meter_reflection", true)
	var vfx_canvas: CanvasItem = n2d as CanvasItem
	var player_canvas: CanvasItem = _resolve_player_canvas_item()
	if vfx_canvas != null and player_canvas != null:
		vfx_canvas.z_as_relative = false
		vfx_canvas.z_index = player_canvas.z_index
	if n2d.has_method("set_facing"):
		n2d.call("set_facing", facing)
	_schedule_temp_enemy_cleanup(n2d, 1.0)

func _apply_reflection_lunge(copy: Node2D, target_pos: Vector2, player_root: Node) -> void:
	if copy == null or not is_instance_valid(copy):
		return
	var toward: Vector2 = target_pos - copy.global_position
	var travel: float = toward.length()
	if travel < 12.0:
		return
	var attack_distance: float = 86.0
	var attack_duration: float = 0.14
	if player_root != null and ("character_data" in player_root):
		var cdata: Object = player_root.get("character_data") as Object
		if cdata != null and ("attack_movement" in cdata):
			var atk_mv: Dictionary = cdata.get("attack_movement") as Dictionary
			if atk_mv.has("heavy"):
				var cfg: Dictionary = atk_mv["heavy"] as Dictionary
				attack_distance = float(cfg.get("distance", attack_distance))
				attack_duration = float(cfg.get("duration", attack_duration))
	attack_duration = clampf(attack_duration, 0.06, 0.5)
	var end_pos: Vector2 = copy.global_position + toward.normalized() * minf(attack_distance, travel - 6.0)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(copy, "global_position", end_pos, attack_duration)

func _register_phantom_minion_watcher(phantom: Node, life: float, alpha: float, floor_group: StringName) -> void:
	if phantom == null or not is_instance_valid(phantom):
		return
	if not ("_current_minion" in phantom):
		return
	_active_phantom_minion_watchers.append({
		"time_left": maxf(life, 0.2),
		"phantom_id": phantom.get_instance_id(),
		"tracked_minion_id": 0,
		"alpha": alpha,
		"floor_group": floor_group
	})

func _spawn_necro_phantom_minion_if_applicable(phantom: Node, life: float, alpha: float, floor_group: StringName) -> void:
	if phantom == null or not is_instance_valid(phantom):
		return
	if not ("minion_scene" in phantom):
		return
	var minion_scene: PackedScene = phantom.get("minion_scene") as PackedScene
	if minion_scene == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var minion: Node = minion_scene.instantiate()
	if minion == null:
		return
	tree.current_scene.add_child(minion)
	if minion is Node2D and phantom is Node2D:
		(minion as Node2D).global_position = (phantom as Node2D).global_position + Vector2(70.0, 0.0)
		var tint: Color = (minion as Node2D).modulate
		tint.a = alpha
		(minion as Node2D).modulate = tint
	if floor_group != &"":
		minion.add_to_group(floor_group)
	minion.set_meta("dice_meter_phantom", true)
	_schedule_temp_enemy_cleanup(minion, maxf(life, 0.2))

func _tick_phantom_minion_watchers(delta: float) -> void:
	if _active_phantom_minion_watchers.is_empty():
		return
	for i: int in range(_active_phantom_minion_watchers.size() - 1, -1, -1):
		var e: Dictionary = _active_phantom_minion_watchers[i]
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		var phantom_obj: Object = instance_from_id(int(e.get("phantom_id", 0)))
		if phantom_obj == null or not is_instance_valid(phantom_obj) or not (phantom_obj is Node):
			_active_phantom_minion_watchers.remove_at(i)
			continue
		var phantom: Node = phantom_obj as Node
		if "_current_minion" in phantom:
			var minion_node: Node = phantom.get("_current_minion") as Node
			if minion_node != null and is_instance_valid(minion_node):
				var tracked_id: int = int(e.get("tracked_minion_id", 0))
				if tracked_id == 0 or tracked_id != minion_node.get_instance_id():
					e["tracked_minion_id"] = minion_node.get_instance_id()
					minion_node.set_meta("dice_meter_phantom", true)
					if minion_node is Node2D:
						var tint: Color = (minion_node as Node2D).modulate
						tint.a = float(e.get("alpha", 0.72))
						(minion_node as Node2D).modulate = tint
					var fg: StringName = e.get("floor_group", &"") as StringName
					if fg != &"":
						minion_node.add_to_group(fg)
					_schedule_temp_enemy_cleanup(minion_node, maxf(time_left + 0.1, 0.2))
		if time_left <= 0.0:
			_active_phantom_minion_watchers.remove_at(i)
			continue
		e["time_left"] = time_left
		_active_phantom_minion_watchers[i] = e

func _clear_phantom_minion_watchers() -> void:
	_active_phantom_minion_watchers.clear()

func _tick_echo_pulses(delta: float) -> void:
	if _active_echo_pulses.is_empty():
		return
	for i: int in range(_active_echo_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = _active_echo_pulses[i]
		var t: float = float(pulse.get("time_left", 0.0)) - delta
		if t > 0.0:
			pulse["time_left"] = t
			_active_echo_pulses[i] = pulse
			continue
		if bool(pulse.get("apply_to_enemies", true)):
			_apply_floorwide_enemy_damage(float(pulse.get("pulse_percent", 0.05)), int(pulse.get("pulse_flat", 10)))
		if bool(pulse.get("friendly_fire_to_player", false)):
			var player_pct: float = float(pulse.get("player_pulse_percent", 0.01))
			if player_pct > 0.0:
				_apply_player_percent_damage_nonlethal(player_pct)
		var left: int = int(pulse.get("pulses_left", 1)) - 1
		if left <= 0:
			_active_echo_pulses.remove_at(i)
			continue
		pulse["pulses_left"] = left
		pulse["time_left"] = float(pulse.get("interval", 0.7))
		_active_echo_pulses[i] = pulse

func _clear_echo_pulses() -> void:
	_active_echo_pulses.clear()

func _tick_player_hp_drain_effects(delta: float) -> void:
	if _active_player_hp_drain_effects.is_empty():
		return
	for i: int in range(_active_player_hp_drain_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_player_hp_drain_effects[i]
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		var interval_left: float = float(e.get("interval_left", 0.0)) - delta
		if interval_left <= 0.0 and time_left > 0.0:
			_apply_player_percent_damage_nonlethal(float(e.get("drain_percent", 0.02)))
			_apply_floorwide_enemy_damage(float(e.get("enemy_blast_percent", 0.0)), int(e.get("enemy_blast_flat", 0)))
			interval_left += float(e.get("interval", 1.0))
		if time_left <= 0.0:
			_active_player_hp_drain_effects.remove_at(i)
			continue
		e["time_left"] = time_left
		e["interval_left"] = interval_left
		_active_player_hp_drain_effects[i] = e

func _clear_player_hp_drain_effects() -> void:
	_active_player_hp_drain_effects.clear()

func _tick_target_execution_effects(delta: float) -> void:
	if _active_target_execution_effects.is_empty():
		return
	for i: int in range(_active_target_execution_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_target_execution_effects[i]
		var target: Node = _resolve_execution_target_node(e)
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		var interval_left: float = float(e.get("interval_left", 0.0)) - delta
		if target == null or not is_instance_valid(target):
			_active_target_execution_effects.remove_at(i)
			continue
		if interval_left <= 0.0 and time_left > 0.0:
			var tick_percent: float = float(e.get("tick_percent", 0.06))
			var tick_flat: int = int(e.get("tick_flat", 8))
			_apply_damage_to_enemy_node(target, _calc_enemy_damage_value(target, tick_percent, tick_flat), &"dice_meter_royal_decree")
			interval_left += float(e.get("interval", 1.0))
		if time_left <= 0.0:
			_active_target_execution_effects.remove_at(i)
			continue
		e["time_left"] = time_left
		e["interval_left"] = interval_left
		_active_target_execution_effects[i] = e

func _clear_target_execution_effects() -> void:
	_active_target_execution_effects.clear()

func _resolve_execution_target_node(e: Dictionary) -> Node:
	var target_id: int = int(e.get("target_id", 0))
	if target_id == 0:
		# Legacy fallback for entries created before id-based storage.
		var legacy: Variant = e.get("target", null)
		if legacy != null and is_instance_valid(legacy):
			return legacy as Node
		return null
	var obj: Object = instance_from_id(target_id)
	if obj == null or not is_instance_valid(obj):
		return null
	return obj as Node

func _apply_enemy_slow_field(duration: float, params: Dictionary) -> void:
	var slow_mult: float = clampf(float(params.get("slow_mult", 0.70)), 0.1, 1.0)
	for enemy: Node in _get_active_enemy_nodes():
		if enemy == null or not is_instance_valid(enemy):
			continue
		for field_name: String in ["move_speed", "speed", "walk_speed", "chase_speed", "patrol_speed"]:
			if not (field_name in enemy):
				continue
			var base_v: float = float(enemy.get(field_name))
			enemy.set(field_name, base_v * slow_mult)
			_active_enemy_slow_effects.append({
				"node_id": enemy.get_instance_id(),
				"field": field_name,
				"original": base_v,
				"time_left": duration
			})
			break
	_log_debug("Applied enemy slow field x%.2f for %.2fs" % [slow_mult, duration])

func _resolve_slow_effect_node(e: Dictionary) -> Node:
	var node_id: int = int(e.get("node_id", 0))
	if node_id != 0:
		var obj: Object = instance_from_id(node_id)
		if obj != null and is_instance_valid(obj):
			return obj as Node
		return null
	# Legacy fallback for existing entries created before node_id migration.
	var legacy: Variant = e.get("node", null)
	if legacy != null and is_instance_valid(legacy):
		return legacy as Node
	return null

func _tick_enemy_slow_effects(delta: float) -> void:
	if _active_enemy_slow_effects.is_empty():
		return
	for i: int in range(_active_enemy_slow_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_enemy_slow_effects[i]
		var n: Node = _resolve_slow_effect_node(e)
		# Enemy can be freed mid-effect (death/scene transition). Drop stale entry immediately.
		if n == null or not is_instance_valid(n):
			_active_enemy_slow_effects.remove_at(i)
			continue
		var t: float = float(e.get("time_left", 0.0)) - delta
		if t > 0.0:
			e["time_left"] = t
			_active_enemy_slow_effects[i] = e
			continue
		var field_name: String = String(e.get("field", ""))
		if field_name != "" and (field_name in n):
			n.set(field_name, float(e.get("original", n.get(field_name))))
		_active_enemy_slow_effects.remove_at(i)

func _clear_enemy_slow_effects() -> void:
	for e: Dictionary in _active_enemy_slow_effects:
		var n: Node = _resolve_slow_effect_node(e)
		if n == null or not is_instance_valid(n):
			continue
		var field_name: String = String(e.get("field", ""))
		if field_name != "" and (field_name in n):
			n.set(field_name, float(e.get("original", n.get(field_name))))
	_active_enemy_slow_effects.clear()

func _apply_enemy_chain(duration: float, params: Dictionary) -> void:
	_apply_enemy_freeze_state(maxf(duration, 0.1), bool(params.get("include_boss", false)))

func _apply_player_chain(duration: float, params: Dictionary) -> void:
	var player: Node = _resolve_player_motion_node()
	if player == null:
		return
	var allow_break: bool = bool(params.get("allow_break", true))
	var lock_until_break: bool = bool(params.get("lock_until_break", false))
	var used_input_lock: bool = false
	var used_cutscene_lock: bool = false
	if lock_until_break and player.has_method("set_input_locked"):
		_acquire_player_input_lock(player)
		used_input_lock = true
	elif player.has_method("set_cutscene_motion_lock"):
		_acquire_player_motion_lock(player)
		used_cutscene_lock = true
	_active_player_root_effects.append({
		"time_left": -1.0 if lock_until_break else maxf(duration, 0.1),
		"player_id": player.get_instance_id(),
		"used_cutscene_lock": used_cutscene_lock,
		"used_input_lock": used_input_lock,
		"lock_until_break": lock_until_break,
		"allow_break": allow_break,
		"break_actions": PackedStringArray(["dash", "Dodge"])
	})

func _tick_player_root_effects(delta: float) -> void:
	if _active_player_root_effects.is_empty():
		return
	for i: int in range(_active_player_root_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_player_root_effects[i]
		var player: Node = _resolve_player_from_effect(e)
		if player == null:
			_active_player_root_effects.remove_at(i)
			continue
		var break_actions: PackedStringArray = e.get("break_actions", PackedStringArray()) as PackedStringArray
		var broken: bool = false
		if bool(e.get("allow_break", true)):
			for action_name: String in break_actions:
				if not InputMap.has_action(action_name):
					continue
				if Input.is_action_just_pressed(action_name):
					broken = true
					break
		var time_left: float = float(e.get("time_left", 0.0))
		var has_timer: bool = time_left >= 0.0
		if has_timer:
			time_left -= delta
		var timed_out: bool = has_timer and time_left <= 0.0
		if broken or timed_out:
			_release_player_root_effect(e)
			_active_player_root_effects.remove_at(i)
			if not _has_lock_until_break_player_root():
				active_effect_time_left = 0.0
				active_effect_hide_timer = false
			continue
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		e["time_left"] = time_left
		_active_player_root_effects[i] = e

func _clear_player_root_effects() -> void:
	for e: Dictionary in _active_player_root_effects:
		_release_player_root_effect(e)
	_active_player_root_effects.clear()
	active_effect_hide_timer = false

func _apply_enemy_freeze_pulses(duration: float, params: Dictionary) -> void:
	_active_enemy_freeze_pulses.append({
		"time_left": maxf(duration, 0.1),
		"interval_left": maxf(float(params.get("interval", 0.9)), 0.1),
		"interval": maxf(float(params.get("interval", 0.9)), 0.1),
		"freeze_seconds": maxf(float(params.get("freeze_seconds", 0.35)), 0.05),
		"include_boss": bool(params.get("include_boss", false))
	})

func _tick_enemy_freeze_pulses(delta: float) -> void:
	if _active_enemy_freeze_pulses.is_empty():
		return
	for i: int in range(_active_enemy_freeze_pulses.size() - 1, -1, -1):
		var e: Dictionary = _active_enemy_freeze_pulses[i]
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		var interval_left: float = float(e.get("interval_left", 0.0)) - delta
		if interval_left <= 0.0 and time_left > 0.0:
			_apply_enemy_freeze_state(float(e.get("freeze_seconds", 0.35)), bool(e.get("include_boss", false)))
			interval_left += float(e.get("interval", 0.9))
		if time_left <= 0.0:
			_active_enemy_freeze_pulses.remove_at(i)
			continue
		e["time_left"] = time_left
		e["interval_left"] = interval_left
		_active_enemy_freeze_pulses[i] = e

func _clear_enemy_freeze_pulses() -> void:
	_active_enemy_freeze_pulses.clear()

func _apply_player_freeze_pulses(duration: float, params: Dictionary) -> void:
	_active_player_freeze_pulses.append({
		"time_left": maxf(duration, 0.1),
		"interval_left": maxf(float(params.get("interval", 1.0)), 0.1),
		"interval": maxf(float(params.get("interval", 1.0)), 0.1),
		"freeze_seconds": maxf(float(params.get("freeze_seconds", 0.25)), 0.05)
	})

func _tick_player_freeze_pulses(delta: float) -> void:
	if _active_player_freeze_pulses.is_empty():
		return
	for i: int in range(_active_player_freeze_pulses.size() - 1, -1, -1):
		var e: Dictionary = _active_player_freeze_pulses[i]
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		var interval_left: float = float(e.get("interval_left", 0.0)) - delta
		if interval_left <= 0.0 and time_left > 0.0:
			_apply_player_chain(float(e.get("freeze_seconds", 0.25)), {"allow_break": false})
			interval_left += float(e.get("interval", 1.0))
		if time_left <= 0.0:
			_active_player_freeze_pulses.remove_at(i)
			continue
		e["time_left"] = time_left
		e["interval_left"] = interval_left
		_active_player_freeze_pulses[i] = e

func _clear_player_freeze_pulses() -> void:
	_active_player_freeze_pulses.clear()

func _apply_enemy_freeze_state(duration: float, include_boss: bool) -> void:
	for enemy: Node in _get_active_enemy_nodes():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not include_boss and enemy.is_in_group(&"boss"):
			continue
		var existing_idx: int = _find_active_freeze_index(enemy.get_instance_id())
		if existing_idx >= 0:
			var existing: Dictionary = _active_enemy_freeze_effects[existing_idx]
			existing["time_left"] = maxf(float(existing.get("time_left", 0.0)), maxf(duration, 0.05))
			_active_enemy_freeze_effects[existing_idx] = existing
			continue
		var entry := {
			"node_id": enemy.get_instance_id(),
			"time_left": maxf(duration, 0.05),
			"process": enemy.is_processing(),
			"physics": enemy.is_physics_processing()
		}
		enemy.set_process(false)
		enemy.set_physics_process(false)
		if enemy is CharacterBody2D:
			(enemy as CharacterBody2D).velocity = Vector2.ZERO
		_active_enemy_freeze_effects.append(entry)

func _find_active_freeze_index(node_id: int) -> int:
	for i: int in range(_active_enemy_freeze_effects.size()):
		if int(_active_enemy_freeze_effects[i].get("node_id", 0)) == node_id:
			return i
	return -1

func _tick_enemy_freeze_effects(delta: float) -> void:
	if _active_enemy_freeze_effects.is_empty():
		return
	for i: int in range(_active_enemy_freeze_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_enemy_freeze_effects[i]
		var obj: Object = instance_from_id(int(e.get("node_id", 0)))
		if obj == null or not is_instance_valid(obj) or not (obj is Node):
			_active_enemy_freeze_effects.remove_at(i)
			continue
		var n: Node = obj as Node
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		if time_left > 0.0:
			e["time_left"] = time_left
			_active_enemy_freeze_effects[i] = e
			continue
		n.set_process(bool(e.get("process", true)))
		n.set_physics_process(bool(e.get("physics", true)))
		_active_enemy_freeze_effects.remove_at(i)

func _clear_enemy_freeze_effects() -> void:
	for e: Dictionary in _active_enemy_freeze_effects:
		var obj: Object = instance_from_id(int(e.get("node_id", 0)))
		if obj == null or not is_instance_valid(obj) or not (obj is Node):
			continue
		var n: Node = obj as Node
		n.set_process(bool(e.get("process", true)))
		n.set_physics_process(bool(e.get("physics", true)))
	_active_enemy_freeze_effects.clear()

func _apply_player_visual_effect(duration: float, alpha: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if not (player is CanvasItem):
		return
	var ci: CanvasItem = player as CanvasItem
	_active_player_visual_effects.append({
		"node_id": ci.get_instance_id(),
		"time_left": maxf(duration, 0.1),
		"original_modulate": ci.modulate
	})
	var c: Color = ci.modulate
	c.a = clampf(alpha, 0.2, 1.0)
	ci.modulate = c

func _tick_player_visual_effects(delta: float) -> void:
	if _active_player_visual_effects.is_empty():
		return
	for i: int in range(_active_player_visual_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_player_visual_effects[i]
		var obj: Object = instance_from_id(int(e.get("node_id", 0)))
		if obj == null or not is_instance_valid(obj) or not (obj is CanvasItem):
			_active_player_visual_effects.remove_at(i)
			continue
		var ci: CanvasItem = obj as CanvasItem
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		if time_left > 0.0:
			e["time_left"] = time_left
			_active_player_visual_effects[i] = e
			continue
		ci.modulate = e.get("original_modulate", ci.modulate)
		_active_player_visual_effects.remove_at(i)

func _clear_player_visual_effects() -> void:
	for e: Dictionary in _active_player_visual_effects:
		var obj: Object = instance_from_id(int(e.get("node_id", 0)))
		if obj != null and is_instance_valid(obj) and obj is CanvasItem:
			(obj as CanvasItem).modulate = e.get("original_modulate", (obj as CanvasItem).modulate)
	_active_player_visual_effects.clear()

func _apply_player_lifesteal(duration: float, params: Dictionary) -> void:
	_active_lifesteal_effects.append({
		"time_left": maxf(duration, 0.1),
		"ratio": clampf(float(params.get("lifesteal_ratio", 0.5)), 0.0, 1.0)
	})

func _apply_lifesteal_from_damage(amount: float) -> void:
	if _active_lifesteal_effects.is_empty():
		return
	var top_ratio: float = 0.0
	for e: Dictionary in _active_lifesteal_effects:
		top_ratio = maxf(top_ratio, float(e.get("ratio", 0.0)))
	if top_ratio <= 0.0:
		return
	var heal_flat: int = maxi(1, int(round(amount * top_ratio)))
	_heal_player_flat(heal_flat)

func _tick_lifesteal_effects(delta: float) -> void:
	if _active_lifesteal_effects.is_empty():
		return
	for i: int in range(_active_lifesteal_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_lifesteal_effects[i]
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		if time_left <= 0.0:
			_active_lifesteal_effects.remove_at(i)
			continue
		e["time_left"] = time_left
		_active_lifesteal_effects[i] = e

func _clear_lifesteal_effects() -> void:
	_active_lifesteal_effects.clear()

func _apply_enemy_regen(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.12)), duration)
	_active_enemy_regen_effects.append({
		"time_left": maxf(duration, 0.1),
		"interval_left": maxf(float(params.get("interval", 1.0)), 0.1),
		"interval": maxf(float(params.get("interval", 1.0)), 0.1),
		"heal_percent": maxf(float(params.get("heal_percent", 0.02)), 0.0),
		"heal_flat": maxi(int(params.get("heal_flat", 4)), 0)
	})

func _tick_enemy_regen_effects(delta: float) -> void:
	if _active_enemy_regen_effects.is_empty():
		return
	for i: int in range(_active_enemy_regen_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_enemy_regen_effects[i]
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		var interval_left: float = float(e.get("interval_left", 0.0)) - delta
		if interval_left <= 0.0 and time_left > 0.0:
			_heal_active_enemies(float(e.get("heal_percent", 0.02)), int(e.get("heal_flat", 4)))
			interval_left += float(e.get("interval", 1.0))
		if time_left <= 0.0:
			_active_enemy_regen_effects.remove_at(i)
			continue
		e["time_left"] = time_left
		e["interval_left"] = interval_left
		_active_enemy_regen_effects[i] = e

func _clear_enemy_regen_effects() -> void:
	_active_enemy_regen_effects.clear()

func _tick_reflection_combo_effects(delta: float) -> void:
	if _active_reflection_combo_effects.is_empty():
		return
	_cleanup_stray_reflection_visuals()
	_enforce_single_player_anchor_reflection()
	_reflection_visual_debug_tick_left = maxf(_reflection_visual_debug_tick_left - delta, 0.0)
	if debug_logs:
		if _reflection_visual_debug_tick_left <= 0.0:
			_log_reflection_visual_link_debug("tick")
			_reflection_visual_debug_tick_left = 0.35
	for i: int in range(_active_reflection_combo_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_reflection_combo_effects[i]
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		var reflection_obj: Object = instance_from_id(int(e.get("reflection_id", 0)))
		var reflection_node: Node2D = reflection_obj as Node2D
		if time_left <= 0.0:
			if reflection_node != null and is_instance_valid(reflection_node):
				reflection_node.queue_free()
			_active_reflection_combo_effects.remove_at(i)
			continue
		e["time_left"] = time_left
		_active_reflection_combo_effects[i] = e

func _log_reflection_visual_link_debug(stage: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player_root: Node = _resolve_player_node()
	if player_root == null or not is_instance_valid(player_root):
		return
	var player_view: Node = player_root.get_node_or_null("Visual/Body3DView")
	var player_anim: String = ""
	var player_pos: Vector2 = _node_global_pos_or_zero(player_root)
	var player_model_count: int = 0
	var player_model_names: Array[String] = []
	var player_subviewport_count: int = 0
	var player_screensprite_count: int = 0
	if player_view != null and is_instance_valid(player_view):
		for pv_child: Node in player_view.get_children():
			if pv_child == null or not is_instance_valid(pv_child):
				continue
			if pv_child.name == "SubViewport":
				player_subviewport_count += 1
			elif pv_child.name == "ScreenSprite":
				player_screensprite_count += 1
		if player_view.has_method("get_current_anim"):
			player_anim = String(player_view.call("get_current_anim"))
		var player_facing_pivot: Node = player_view.get_node_or_null("SubViewport/Player3DStage/FacingPivot")
		if player_facing_pivot != null and is_instance_valid(player_facing_pivot):
			for c: Node in player_facing_pivot.get_children():
				if c == null or not is_instance_valid(c):
					continue
				player_model_count += 1
				player_model_names.append(c.name)
	var reflection_lines: Array[String] = []
	for n: Node in tree.get_nodes_in_group(&"dice_meter_reflection_actor"):
		if n == null or not is_instance_valid(n):
			continue
		if not (n is Node2D):
			continue
		var n2d: Node2D = n as Node2D
		var reflection_anim: String = ""
		var reflection_model_count: int = 0
		var reflection_model_names: Array[String] = []
		if n.has_method("get_debug_snapshot"):
			var snap_v: Variant = n.call("get_debug_snapshot")
			if snap_v is Dictionary:
				var snap: Dictionary = snap_v as Dictionary
				reflection_anim = String(snap.get("anim", ""))
				reflection_model_count = int(snap.get("facing_child_count", 0))
				var names_v: Variant = snap.get("facing_children", [])
				if names_v is Array:
					for nm: Variant in names_v:
						reflection_model_names.append(String(nm))
		reflection_lines.append(
			"id=%d pos=%s anim=%s model_count=%d model_names=%s" % [
				n.get_instance_id(),
				str(n2d.global_position),
				reflection_anim,
				reflection_model_count,
				", ".join(reflection_model_names)
			]
		)
	_log_debug(
		"11G visual[%s] player_pos=%s player_anim=%s player_model_count=%d player_models=%s player_view_nodes[subviewport=%d screen=%d] reflections=%d {%s}" % [
			stage,
			str(player_pos),
			player_anim,
			player_model_count,
			", ".join(player_model_names),
			player_subviewport_count,
			player_screensprite_count,
			reflection_lines.size(),
			"; ".join(reflection_lines)
		]
	)

func _log_reflection_forensic_scan(stage: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var player_root: Node = _resolve_player_node()
	var player_body_view: Node = null
	if player_root != null and is_instance_valid(player_root):
		player_body_view = player_root.get_node_or_null("Visual/Body3DView")
	var suspicious: Array[String] = []
	var stack: Array[Node] = [tree.current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null or not is_instance_valid(n):
			continue
		var script_ref: Script = n.get_script() as Script
		var script_path: String = String(script_ref.resource_path) if script_ref != null else ""
		var scene_path: String = String(n.scene_file_path)
		var is_suspicious: bool = false
		if n != player_root and n != player_body_view and n.is_in_group(&"player"):
			is_suspicious = true
		if script_path == PLAYER_CONTROLLER_SCRIPT_PATH or script_path == PLAYER_3D_VIEW_SCRIPT_PATH:
			if n != player_root and n != player_body_view:
				is_suspicious = true
		if scene_path == PLAYER_SCENE_PATH or scene_path == PLAYER_3D_VIEW_SCENE_PATH:
			if n != player_root and n != player_body_view:
				is_suspicious = true
		if n != player_root and n.has_node("Visual/Body3DView") and n.has_node("Combat") and n.has_node("Health"):
			is_suspicious = true
		if is_suspicious:
			var npos: Vector2 = _node_global_pos_or_zero(n)
			suspicious.append("%s id=%d pos=%s script=%s scene=%s groups[player=%s refl_actor=%s]" % [
				n.name,
				n.get_instance_id(),
				str(npos),
				script_path,
				scene_path,
				str(n.is_in_group(&"player")),
				str(n.is_in_group(&"dice_meter_reflection_actor"))
			])
		for child: Node in n.get_children():
			stack.append(child)
	# Keep logs bounded but actionable.
	if suspicious.is_empty():
		_log_debug("11G forensic[%s] suspicious=0" % stage)
	else:
		var max_lines: int = mini(10, suspicious.size())
		_log_debug("11G forensic[%s] suspicious=%d -> %s" % [stage, suspicious.size(), " | ".join(suspicious.slice(0, max_lines))])

func _enforce_single_player_anchor_reflection() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var keep_id: int = 0
	for e: Dictionary in _active_reflection_combo_effects:
		var rid: int = int(e.get("reflection_id", 0))
		if rid != 0:
			keep_id = rid
			break
	for n: Node in tree.get_nodes_in_group(&"dice_meter_reflection_actor"):
		if n == null or not is_instance_valid(n):
			continue
		if String(n.get_meta("reflection_source", "")) != "11g_player_anchor":
			continue
		if n.get_instance_id() == keep_id:
			continue
		n.queue_free()

func _clear_reflection_combo_effects() -> void:
	_active_reflection_combo_effects.clear()
	_clear_all_reflection_combo_actors()

func _heal_active_enemies(percent_of_max: float, flat_heal: int) -> void:
	for enemy: Node in _get_active_enemy_nodes():
		if enemy == null or not is_instance_valid(enemy):
			continue
		var hp_node: Node = enemy.get_node_or_null("Health")
		if hp_node == null:
			continue
		if not ("hp" in hp_node) or not ("max_hp" in hp_node):
			continue
		var cur: int = int(hp_node.get("hp"))
		var mx: int = int(hp_node.get("max_hp"))
		if mx <= 0:
			continue
		var heal: int = maxi(flat_heal, 0) + int(round(float(mx) * maxf(percent_of_max, 0.0)))
		if heal <= 0:
			continue
		var new_hp: int = mini(mx, cur + heal)
		hp_node.set("hp", new_hp)
		if hp_node.has_signal("health_changed"):
			hp_node.emit_signal("health_changed", new_hp, mx)

func _start_wind_push_effect(duration: float, affect_player: bool, push_speed: float, counter_move_mult: float, idle_drift_scale: float = 0.0) -> void:
	_active_wind_effects.append({
		"time_left": maxf(duration, 0.1),
		"affect_player": affect_player,
		"push_speed": push_speed,
		"counter_move_mult": counter_move_mult,
		"idle_drift_scale": clampf(idle_drift_scale, 0.0, 2.0)
	})

func _tick_wind_effects(delta: float) -> void:
	if _active_wind_effects.is_empty():
		return
	for i: int in range(_active_wind_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_wind_effects[i]
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		var push_speed: float = float(e.get("push_speed", 120.0))
		var affect_player: bool = bool(e.get("affect_player", false))
		if affect_player:
			var body: CharacterBody2D = _resolve_player_body_node()
			if body != null:
				var idle_drift_scale: float = float(e.get("idle_drift_scale", 0.0))
				var dashing: bool = InputMap.has_action("dash") and Input.is_action_pressed("dash")
				if body.velocity.x > 0.0:
					# Preserve dash/sprint carry so wind doesn't create "run in place" on state transition.
					if dashing or body.velocity.x >= 260.0:
						body.velocity.x *= 0.985
					else:
						body.velocity.x *= float(e.get("counter_move_mult", 0.6))
				elif absf(body.velocity.x) < 20.0 and idle_drift_scale > 0.0:
					body.global_position.x -= push_speed * delta * idle_drift_scale
				elif body.velocity.x > -push_speed * 0.35:
					body.velocity.x -= push_speed * delta * 0.45
		else:
			for enemy: Node in _get_active_enemy_nodes():
				if enemy is CharacterBody2D:
					var body_e: CharacterBody2D = enemy as CharacterBody2D
					body_e.velocity.x -= push_speed * delta * 0.35
					if body_e.velocity.x > 0.0:
						body_e.velocity.x *= float(e.get("counter_move_mult", 0.6))
		if time_left <= 0.0:
			_active_wind_effects.remove_at(i)
			continue
		e["time_left"] = time_left
		_active_wind_effects[i] = e

func _clear_wind_effects() -> void:
	_active_wind_effects.clear()

func _heal_player_flat(amount: int) -> void:
	if amount <= 0:
		return
	var health: Node = _get_player_health_node()
	if health == null:
		return
	if health.has_method("heal"):
		health.call("heal", amount)
		return
	if not ("hp" in health) or not ("max_hp" in health):
		return
	var hp_now: int = int(health.get("hp"))
	var hp_max: int = int(health.get("max_hp"))
	var new_hp: int = mini(hp_max, hp_now + amount)
	health.set("hp", new_hp)
	if health.has_signal("health_changed"):
		health.emit_signal("health_changed", new_hp, hp_max)

func _resolve_player_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")

func _resolve_player_motion_node() -> Node:
	var player_root: Node = _resolve_player_node()
	if player_root == null:
		return null
	if player_root.has_method("set_cutscene_motion_lock"):
		return player_root
	var stack: Array[Node] = [player_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != null and is_instance_valid(n) and n.has_method("set_cutscene_motion_lock"):
			return n
		for child: Node in n.get_children():
			stack.append(child)
	if player_root is CharacterBody2D:
		return player_root
	return null

func _resolve_player_body_node() -> CharacterBody2D:
	var tree: SceneTree = get_tree()
	if tree != null:
		for p: Node in tree.get_nodes_in_group("player"):
			if p is CharacterBody2D:
				return p as CharacterBody2D
			var cur: Node = p
			while cur != null:
				if cur is CharacterBody2D:
					return cur as CharacterBody2D
				cur = cur.get_parent()
	var motion_node: Node = _resolve_player_motion_node()
	if motion_node is CharacterBody2D:
		return motion_node as CharacterBody2D
	var player_root: Node = _resolve_player_node()
	if player_root == null:
		return null
	var stack: Array[Node] = [player_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CharacterBody2D:
			return n as CharacterBody2D
		for child: Node in n.get_children():
			stack.append(child)
	return null

func _resolve_player_from_effect(e: Dictionary) -> Node:
	var node_id: int = int(e.get("player_id", 0))
	if node_id != 0:
		var obj: Object = instance_from_id(node_id)
		if obj != null and is_instance_valid(obj) and obj is Node:
			return obj as Node
	return _resolve_player_motion_node()

func _release_player_root_effect(e: Dictionary) -> void:
	var player: Node = _resolve_player_from_effect(e)
	if player == null:
		return
	if bool(e.get("used_input_lock", false)) and player.has_method("set_input_locked"):
		_release_player_input_lock(player)
	if bool(e.get("used_cutscene_lock", false)) and player.has_method("set_cutscene_motion_lock"):
		_release_player_motion_lock(player)

func _has_lock_until_break_player_root() -> bool:
	for e: Dictionary in _active_player_root_effects:
		if bool(e.get("lock_until_break", false)):
			return true
	return false

func _acquire_player_motion_lock(player: Node) -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("set_cutscene_motion_lock"):
		return
	_player_motion_lock_count += 1
	if _player_motion_lock_count == 1:
		player.call("set_cutscene_motion_lock", true)

func _release_player_motion_lock(player: Node) -> void:
	_player_motion_lock_count = maxi(0, _player_motion_lock_count - 1)
	if _player_motion_lock_count == 0 and player != null and is_instance_valid(player) and player.has_method("set_cutscene_motion_lock"):
		player.call("set_cutscene_motion_lock", false)

func _acquire_player_input_lock(player: Node) -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("set_input_locked"):
		return
	_player_input_lock_count += 1
	if _player_input_lock_count == 1:
		player.call("set_input_locked", true)

func _release_player_input_lock(player: Node) -> void:
	_player_input_lock_count = maxi(0, _player_input_lock_count - 1)
	if _player_input_lock_count == 0 and player != null and is_instance_valid(player) and player.has_method("set_input_locked"):
		player.call("set_input_locked", false)

func _apply_player_cooldown_pause(duration: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return
	var combat: Node = player.get_node_or_null("Combat")
	if combat == null:
		return
	_active_cooldown_pause_effects.append({
		"time_left": maxf(duration, 0.1),
		"combat_id": combat.get_instance_id()
	})

func _tick_cooldown_pause_effects(delta: float) -> void:
	if _active_cooldown_pause_effects.is_empty():
		return
	for i: int in range(_active_cooldown_pause_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_cooldown_pause_effects[i]
		var obj: Object = instance_from_id(int(e.get("combat_id", 0)))
		var time_left: float = float(e.get("time_left", 0.0)) - delta
		if obj == null or not is_instance_valid(obj) or not (obj is Node):
			_active_cooldown_pause_effects.remove_at(i)
			continue
		var combat: Node = obj as Node
		if combat.has_method("add_external_cooldown_pause"):
			combat.call("add_external_cooldown_pause", delta)
		else:
			for field_name: String in ["_light_ready_time", "_heavy_ready_time", "_ultimate_ready_time", "_defend_ready_time"]:
				if field_name in combat:
					combat.set(field_name, float(combat.get(field_name)) + delta)
		if time_left <= 0.0:
			_active_cooldown_pause_effects.remove_at(i)
			continue
		e["time_left"] = time_left
		_active_cooldown_pause_effects[i] = e

func _clear_cooldown_pause_effects() -> void:
	_active_cooldown_pause_effects.clear()

func _apply_floorwide_enemy_damage(percent_of_max: float, flat_damage: int) -> void:
	for target: Node in _get_active_enemy_nodes():
		if target == null or not is_instance_valid(target):
			continue
		var dmg: int = maxi(0, flat_damage)
		var hp_node: Node = target.get_node_or_null("Health")
		if hp_node != null and "max_hp" in hp_node:
			var mx: int = int(hp_node.get("max_hp"))
			dmg += int(round(float(mx) * maxf(percent_of_max, 0.0)))
		if dmg <= 0:
			continue
		dmg = _scale_dice_damage_for_target(target, dmg)
		if dmg <= 0:
			continue
		if hp_node != null and hp_node.has_method("take_damage"):
			hp_node.call("take_damage", dmg, self, &"dice_meter_echo", false)
		elif target.has_method("take_damage"):
			target.call("take_damage", dmg, self)

func _calc_enemy_damage_value(target: Node, percent_of_max: float, flat_damage: int) -> int:
	var dmg: int = maxi(flat_damage, 0)
	if target == null or not is_instance_valid(target):
		return dmg
	var hp_node: Node = target.get_node_or_null("Health")
	if hp_node != null and "max_hp" in hp_node:
		dmg += int(round(float(hp_node.get("max_hp")) * maxf(percent_of_max, 0.0)))
	return maxi(dmg, 0)

func _apply_damage_to_enemy_node(target: Node, damage: int, tag: StringName) -> void:
	if target == null or not is_instance_valid(target):
		return
	var final_damage: int = _scale_dice_damage_for_target(target, damage)
	if final_damage <= 0:
		return
	var hp_node: Node = target.get_node_or_null("Health")
	if hp_node != null and hp_node.has_method("take_damage"):
		hp_node.call("take_damage", final_damage, self, tag, false)
	elif target.has_method("take_damage"):
		target.call("take_damage", final_damage, self)

func _scale_dice_damage_for_target(target: Node, amount: int) -> int:
	var value: int = maxi(amount, 0)
	if value <= 0:
		return 0
	if target != null and target.is_in_group(&"boss"):
		return maxi(1, int(round(float(value) * 0.35)))
	return value

func _node_global_pos_or_zero(node: Node) -> Vector2:
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO

func _find_highest_hp_enemy() -> Node:
	var best: Node = null
	var best_hp: int = -1
	for enemy: Node in _get_active_enemy_nodes():
		if enemy == null or not is_instance_valid(enemy):
			continue
		var hp_node: Node = enemy.get_node_or_null("Health")
		if hp_node == null:
			continue
		var hp_val: int = -1
		if "hp" in hp_node:
			hp_val = int(hp_node.get("hp"))
		elif "max_hp" in hp_node:
			hp_val = int(hp_node.get("max_hp"))
		if hp_val > best_hp:
			best_hp = hp_val
			best = enemy
	return best

func _apply_player_percent_damage_nonlethal(percent_of_max: float) -> void:
	var health: Node = _get_player_health_node()
	if health == null:
		return
	var max_hp: int = 0
	var cur_hp: int = 0
	if "max_hp" in health:
		max_hp = int(health.get("max_hp"))
	if "hp" in health:
		cur_hp = int(health.get("hp"))
	if max_hp <= 0 or cur_hp <= 1:
		return
	var dmg: int = maxi(1, int(round(float(max_hp) * clampf(percent_of_max, 0.0, 1.0))))
	_apply_player_damage_nonlethal(dmg)

func _apply_player_damage_nonlethal(amount: int) -> void:
	if amount <= 0:
		return
	var health: Node = _get_player_health_node()
	if health == null:
		return
	if not ("hp" in health) or not ("max_hp" in health):
		if health.has_method("take_damage"):
			health.call("take_damage", amount, self, false)
		return
	var hp_now: int = int(health.get("hp"))
	var hp_max: int = int(health.get("max_hp"))
	if hp_now <= 1:
		return
	var final_damage: int = mini(maxi(amount, 1), hp_now - 1)
	if final_damage <= 0:
		return
	if health.has_method("take_damage"):
		health.call("take_damage", final_damage, self, false)
	# Safety clamp in case external modifiers altered the final intake.
	if "hp" in health:
		var post_hp: int = int(health.get("hp"))
		if post_hp < 1:
			health.set("hp", 1)
			if health.has_signal("health_changed"):
				health.emit_signal("health_changed", 1, hp_max)

func _get_player_health_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Health")

func _refresh_random_combat_cooldown() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return
	var combat: Node = player.get_node_or_null("Combat")
	if combat == null:
		return
	var options: Array[String] = []
	for ability in [&"heavy", &"ultimate", &"defend"]:
		if combat.has_method("get_cooldown_left"):
			var left: float = float(combat.call("get_cooldown_left", ability))
			if left > 0.0:
				options.append(String(ability))
	if options.is_empty():
		return
	var pick_index: int = 0
	if RunStateSingleton != null and RunStateSingleton.has_method("roll_for_domain_in_range"):
		pick_index = int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_chrono_skip", 0, options.size() - 1, _trigger_count))
	else:
		pick_index = randi_range(0, options.size() - 1)
	pick_index = clampi(pick_index, 0, options.size() - 1)
	if pick_index < 0 or pick_index >= options.size():
		return
	var picked: String = options[pick_index]
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if combat.has_method("_now"):
		now = float(combat.call("_now"))
	match picked:
		"heavy":
			if "_heavy_ready_time" in combat:
				combat.set("_heavy_ready_time", now)
		"ultimate":
			if "_ultimate_ready_time" in combat:
				combat.set("_ultimate_ready_time", now)
		"defend":
			if "_defend_ready_time" in combat:
				combat.set("_defend_ready_time", now)

func _grant_player_shield_percent(percent_of_max: float, duration: float, cap_percent_of_max: float = 0.30) -> void:
	var health: Node = _get_player_health_node()
	if health == null:
		return
	if not health.has_method("add_shield"):
		return
	if not ("max_hp" in health):
		return
	var max_hp: int = int(health.get("max_hp"))
	if max_hp <= 0:
		return
	var grant: int = maxi(1, int(round(float(max_hp) * clampf(percent_of_max, 0.0, 2.0))))
	var cap: int = maxi(grant, int(round(float(max_hp) * clampf(cap_percent_of_max, 0.0, 2.0))))
	health.call("add_shield", grant, maxf(duration, 0.1), cap, true)

func _rescale_player_active_cooldowns(factor: float) -> void:
	if factor <= 0.0:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return
	var combat: Node = player.get_node_or_null("Combat")
	if combat == null:
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if combat.has_method("_now"):
		now = float(combat.call("_now"))
	for field_name: String in ["_heavy_ready_time", "_ultimate_ready_time", "_defend_ready_time", "_light_ready_time"]:
		if not (field_name in combat):
			continue
		var ready_at: float = float(combat.get(field_name))
		var left: float = maxf(ready_at - now, 0.0)
		if left <= 0.0:
			continue
		combat.set(field_name, now + (left * factor))

func _get_active_enemy_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var seen: Dictionary = {}
	var tree: SceneTree = get_tree()
	if tree == null:
		return out
	var groups: Array[StringName] = [
		&"floor1_enemies", &"floor2_enemies", &"floor3_enemies", &"floor4_enemies",
		&"floor5_enemies", &"subarena_enemies", &"elites", &"boss"
	]
	for g: StringName in groups:
		for n: Node in tree.get_nodes_in_group(g):
			if n == null or not is_instance_valid(n):
				continue
			if n.is_in_group(&"player"):
				continue
			var key: int = n.get_instance_id()
			if seen.has(key):
				continue
			seen[key] = true
			out.append(n)
	var current_scene: Node = tree.current_scene
	if current_scene != null:
		_collect_enemy_like_nodes(current_scene, out, seen)
	return out

func _collect_spawn_anchors_for_group(group_name: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return out
	for n: Node in tree.get_nodes_in_group(group_name):
		if n == null or not is_instance_valid(n):
			continue
		if n is Node2D:
			out.append((n as Node2D).global_position)
	return out

func _collect_enemy_like_nodes(node: Node, out: Array[Node], seen: Dictionary) -> void:
	if node == null:
		return
	if _is_node_under_player(node):
		return
	if not node.is_in_group(&"player"):
		var enemy_like: bool = false
		if node.has_node("Health"):
			enemy_like = true
		elif node.has_method("take_damage"):
			enemy_like = true
		if enemy_like:
			var key: int = node.get_instance_id()
			if not seen.has(key):
				seen[key] = true
				out.append(node)
	for child: Node in node.get_children():
		_collect_enemy_like_nodes(child, out, seen)

func _is_node_under_player(node: Node) -> bool:
	if node == null:
		return false
	var cur: Node = node
	while cur != null:
		if cur.is_in_group(&"player"):
			return true
		cur = cur.get_parent()
	return false

func _apply_temp_mult_to_runstate(field_name: String, factor: float, duration: float) -> void:
	var run_state := _get_run_state()
	if run_state == null:
		return
	if duration <= 0.0:
		return
	if factor <= 0.0:
		return
	if not (field_name in run_state):
		return
	var current_value: float = float(run_state.get(field_name))
	run_state.set(field_name, current_value * factor)
	if field_name == "cooldown_mult":
		_rescale_player_active_cooldowns(factor)
	_active_temp_effects.append({
		"field": field_name,
		"factor": factor,
		"time_left": duration
	})
	_log_debug("Applied temp effect: %s x%.3f for %.2fs" % [field_name, factor, duration])

func _tick_temp_effects(delta: float) -> void:
	if active_effect_time_left > 0.0 and not active_effect_hide_timer:
		active_effect_time_left = maxf(active_effect_time_left - delta, 0.0)
		if active_effect_time_left <= 0.0:
			active_effect_name = ""
			active_effect_brief_text = ""

	if _active_temp_effects.is_empty():
		return
	var run_state := _get_run_state()
	if run_state == null:
		_active_temp_effects.clear()
		return
	for i: int in range(_active_temp_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_temp_effects[i]
		var t: float = float(e.get("time_left", 0.0)) - delta
		if t > 0.0:
			e["time_left"] = t
			_active_temp_effects[i] = e
			continue
		var field_name: String = String(e.get("field", ""))
		var factor: float = float(e.get("factor", 1.0))
		if field_name != "" and (field_name in run_state) and factor > 0.0:
			var current_value: float = float(run_state.get(field_name))
			run_state.set(field_name, current_value / factor)
			if field_name == "cooldown_mult":
				_rescale_player_active_cooldowns(1.0 / factor)
			_log_debug("Expired temp effect: %s x%.3f" % [field_name, factor])
		_active_temp_effects.remove_at(i)

func _clear_temp_effects() -> void:
	var run_state := _get_run_state()
	if run_state == null:
		_active_temp_effects.clear()
		return
	for e: Dictionary in _active_temp_effects:
		var field_name: String = String(e.get("field", ""))
		var factor: float = float(e.get("factor", 1.0))
		if field_name != "" and (field_name in run_state) and factor > 0.0:
			var current_value: float = float(run_state.get(field_name))
			run_state.set(field_name, current_value / factor)
			if field_name == "cooldown_mult":
				_rescale_player_active_cooldowns(1.0 / factor)
			_log_debug("Cleared temp effect: %s x%.3f" % [field_name, factor])
	_active_temp_effects.clear()

func _get_run_state() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("RunStateSingleton")

func _resolve_roll_value(forced_roll: int) -> int:
	var bounds: Vector2i = _get_meter_roll_bounds()
	var min_roll: int = bounds.x
	var max_roll: int = bounds.y
	if RunStateSingleton == null:
		if forced_roll >= 1:
			return forced_roll
		return randi_range(1, 20)
	if forced_roll >= min_roll and forced_roll <= max_roll:
		return forced_roll

	if _has_relic(RELIC_TWIN_FATE):
		if RunStateSingleton.has_method("roll_for_domain_in_range"):
			var a: int = int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_roll_twin_a", min_roll, max_roll, _trigger_count))
			var b: int = int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_roll_twin_b", min_roll, max_roll, _trigger_count))
			return mini(a, b)
		var twin_rng := RandomNumberGenerator.new()
		twin_rng.randomize()
		var ra: int = twin_rng.randi_range(min_roll, max_roll)
		var rb: int = twin_rng.randi_range(min_roll, max_roll)
		return mini(ra, rb)

	if RunStateSingleton.has_method("roll_for_domain_in_range"):
		return int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_roll", min_roll, max_roll, _trigger_count))

	var fallback_rng := RandomNumberGenerator.new()
	fallback_rng.randomize()
	return fallback_rng.randi_range(min_roll, max_roll)

func _get_meter_roll_bounds() -> Vector2i:
	if RunStateSingleton == null:
		return Vector2i(1, 20)
	var mn: int = int(RunStateSingleton.dice_min)
	var mx: int = int(RunStateSingleton.dice_max)
	mn = clampi(mini(mn, mx), 1, 20)
	mx = clampi(maxi(mn, mx), 1, 20)
	return Vector2i(mn, mx)

func _has_relic(id: StringName) -> bool:
	if id == &"" or RunStateSingleton == null:
		return false
	if not RunStateSingleton.has_method("has_relic"):
		return false
	return bool(RunStateSingleton.call("has_relic", id))

func _has_bent_die_relic() -> bool:
	return _has_relic(RELIC_BENT_DIE) or _has_relic(RELIC_BENT_DIE_ALT)

func _is_negative_band(band: int) -> bool:
	return band == int(DiceMeterEventData.OutcomeBand.DANGER) or band == int(DiceMeterEventData.OutcomeBand.CHAOS)

func _apply_bent_die_reroll(current_roll: int, current_event_data: DiceMeterEventData) -> Dictionary:
	var bounds: Vector2i = _get_meter_roll_bounds()
	var reroll_value: int = current_roll
	if RunStateSingleton != null and RunStateSingleton.has_method("roll_for_domain_in_range"):
		reroll_value = int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_bent_die_reroll", bounds.x, bounds.y, _trigger_count))
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		reroll_value = rng.randi_range(bounds.x, bounds.y)
	var reroll_rng: RandomNumberGenerator = _resolve_event_pick_rng_with_salt(reroll_value, 1)
	var reroll_event_data: DiceMeterEventData = event_table.pick_event_for_roll(reroll_rng, reroll_value)
	if reroll_event_data == null:
		return {"roll": current_roll, "event_data": current_event_data}
	var choose_reroll: bool = false
	var current_band: int = int(current_event_data.band)
	var reroll_band: int = int(reroll_event_data.band)
	if reroll_band > current_band:
		choose_reroll = true
	elif reroll_band == current_band and reroll_value > current_roll:
		choose_reroll = true
	if choose_reroll:
		_log_debug("Bent Die: rerolled %d -> %d (band %d -> %d)." % [current_roll, reroll_value, current_band, reroll_band])
		return {"roll": reroll_value, "event_data": reroll_event_data}
	_log_debug("Bent Die: rerolled %d -> %d but kept original." % [current_roll, reroll_value])
	return {"roll": current_roll, "event_data": current_event_data}

func _scale_effect_params(params: Dictionary, factor: float) -> Dictionary:
	var out: Dictionary = params.duplicate(true)
	var f: float = maxf(factor, 0.0)
	for k in out.keys():
		var key: String = String(k)
		var v: Variant = out[k]
		if v is float or v is int:
			var num: float = float(v)
			var scaled: float = num * f
			if key.ends_with("_mult"):
				scaled = 1.0 + ((num - 1.0) * f)
			if v is int:
				out[k] = maxi(0, int(round(scaled)))
			else:
				out[k] = scaled
	return out

func _resolve_event_pick_rng(roll: int) -> RandomNumberGenerator:
	return _resolve_event_pick_rng_with_salt(roll, 0)

func _resolve_event_pick_rng_with_salt(roll: int, salt: int) -> RandomNumberGenerator:
	if RunStateSingleton != null and RunStateSingleton.has_method("make_rng_for_domain"):
		var seeded_rng: RandomNumberGenerator = RunStateSingleton.call("make_rng_for_domain", &"dice_meter_event_pick", (_trigger_count * 100) + roll + (salt * 997)) as RandomNumberGenerator
		if seeded_rng != null:
			return seeded_rng

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng

func _emit_charge_changed() -> void:
	charge_changed.emit(current_charge, maxf(max_charge, 1.0))

func _log_debug(msg: String) -> void:
	if not debug_logs:
		return
	print("[DiceMeter] %s" % msg)

func is_debug_test_mode_enabled() -> bool:
	return debug_test_mode_enabled

func is_debug_enemy_death_locked() -> bool:
	return debug_test_mode_enabled and debug_prevent_enemy_deaths

func get_debug_forced_range() -> Vector2i:
	var mn: int = mini(debug_force_range_min, debug_force_range_max)
	var mx: int = maxi(debug_force_range_min, debug_force_range_max)
	mn = clampi(mn, 1, 20)
	mx = clampi(mx, 1, 20)
	return Vector2i(mn, mx)

func _apply_debug_test_mode_overrides() -> void:
	if not debug_test_mode_enabled:
		return
	var forced_range: Vector2i = get_debug_forced_range()
	var run_state: Node = _get_run_state()
	if run_state != null:
		var need_range_push: bool = true
		if ("dice_min" in run_state) and ("dice_max" in run_state):
			need_range_push = int(run_state.dice_min) != forced_range.x or int(run_state.dice_max) != forced_range.y
		if need_range_push and run_state.has_method("set_dice_range_debug_override"):
			run_state.call("set_dice_range_debug_override", forced_range.x, forced_range.y)
	if debug_lock_meter_full:
		var desired: float = maxf(max_charge, 1.0)
		if current_charge < desired:
			current_charge = desired
			_emit_charge_changed()
