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

# Optional: control warning spam for new/unmapped ids
@export var warn_on_unknown_effects: bool = false
var _unknown_effects_warned: Dictionary = {} # StringName -> true

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
	# Deterministic per-run + per-world + per-floor + roll used for rewards.
	# (So reopening VictoryUI gives same choices for the same roll.)
	var rng := RandomNumberGenerator.new()

	# Mix values to reduce collisions.
	var s: int = int(run_seed)
	s = int(s * 1103515245 + 12345)
	s ^= (world_index * 10007)
	s ^= (floor_index * 20011)
	s ^= (reward_roll * 30011)
	rng.seed = s
	return rng

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
	var rng: RandomNumberGenerator = make_rng_for_victory_relic_choices_for_roll(last_roll)
	# NOTE: the seed already depends on last_roll via make_rng_for_victory_relic_choices_for_roll
	# but we want an actual reward roll in [dice_min, dice_max].
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
var player_damage_mult: float = 1.0
var player_health_mult: float = 1.0

# World-scoped effects list (flags)
var world_effects: Array[StringName] = []

var hazard_rise_mult: float = 1.0
var healing_mult: float = 1.0
var cooldown_mult: float = 1.0
var orb_charge_mult: float = 1.0
var loot_quality_bonus: float = 0.0
var shop_price_mult: float = 1.0
var extra_shop_slots: int = 0
var free_shop_rerolls: int = 0
var rare_relic_bonus: float = 0.0
var elites_to_spawn_bonus: int = 0

# World-scoped flags (recognized ids you may reference elsewhere)
var perfect_step_enabled: bool = false
var clean_cuts_enabled: bool = false

func _ready() -> void:
	load_meta()

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

func start_new_run(run_seed_override: int = 0) -> void:
	pass
	run_seed = run_seed_override if run_seed_override != 0 else int(Time.get_unix_time_from_system())
	world_index = 1
	floor_index = 1

	# Use saved starting dice range instead of meta_next_start_value
	dice_min = starting_dice_min
	dice_max = starting_dice_max
	last_roll = starting_dice_min
	
	pass

	applied_modifier_ids.clear()

	_reset_run_modifiers()
	clear_relics()

	# E1 state
	forced_reward_roll = -1
	relic_loaded_fate_used_this_world = false

	_emit()
	pass

func _reset_run_modifiers() -> void:
	enemy_damage_mult = 1.0
	enemy_health_mult = 1.0
	player_damage_mult = 1.0
	player_health_mult = 1.0

	_reset_world_modifiers_only()
	_reset_relic_knobs()

func _reset_relic_knobs() -> void:
	relic_damage_mult = 1.0
	relic_damage_taken_mult = 1.0
	relic_attack_speed_mult = 1.0
	relic_bleed_damage_mult = 1.0
	relic_roll_max_charges_bonus = 0
	relic_roll_recharge_mult = 1.0
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
	player_damage_mult = 1.0
	player_health_mult = 1.0

	_reset_world_modifiers_only()
	_emit()

func _reset_world_modifiers_only() -> void:
	world_effects.clear()
	hazard_rise_mult = 1.0
	healing_mult = 1.0
	cooldown_mult = 1.0
	orb_charge_mult = 1.0
	loot_quality_bonus = 0.0
	shop_price_mult = 1.0
	extra_shop_slots = 0
	free_shop_rerolls = 0
	rare_relic_bonus = 0.0
	elites_to_spawn_bonus = 0

	perfect_step_enabled = false
	clean_cuts_enabled = false

	_unknown_effects_warned.clear()

func advance_floor() -> void:
	floor_index += 1

func advance_world() -> void:
	world_index += 1
	floor_index = 1
	clear_world_modifiers()

	# E1: reset per-world usage + clear forced roll
	relic_loaded_fate_used_this_world = false
	forced_reward_roll = -1

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
		&"b_sharpened":
			player_damage_mult *= 1.12
		&"b_coolheaded":
			cooldown_mult *= 0.85
		&"b_heavyhand":
			player_damage_mult *= 1.10
		&"b_orb_handler":
			orb_charge_mult *= 1.15

		&"b_perfect_step":
			perfect_step_enabled = true
			_register_world_effect(id)

		&"b_clean_cuts":
			clean_cuts_enabled = true
			player_damage_mult *= 1.08
			_register_world_effect(id)

		&"m_berserker_pact":
			player_damage_mult *= 1.25
			enemy_damage_mult *= 1.10
		&"m_ironblood":
			player_health_mult *= 1.20
			_apply_player_health_multiplier_now()
			enemy_damage_mult *= 0.90
		&"m_flow_engine":
			cooldown_mult *= 0.75

		&"d_overcharged_foes":
			enemy_damage_mult *= 1.12
		&"d_reinforced_foes":
			enemy_health_mult *= 1.18
		&"d_hunted":
			hazard_rise_mult *= 1.15
		&"d_elite_presence":
			elites_to_spawn_bonus += 1
			pass

		&"x_brutal_foes":
			enemy_damage_mult *= 1.22
		&"x_unstable_ground":
			hazard_rise_mult *= 1.30
		&"x_cursed_recovery":
			healing_mult *= 0.60
		&"x_elite_pack":
			elites_to_spawn_bonus += 2
			pass

		&"g_loot_quality_small":
			loot_quality_bonus += 0.10
		&"g_shop_extra_slot":
			extra_shop_slots += 1
		&"g_shop_free_reroll":
			free_shop_rerolls += 1
		&"g_rare_relic_chance_small":
			rare_relic_bonus += 0.05

		&"bg_boss_extra_choice":
			pass
		&"bg_loot_quality_big":
			loot_quality_bonus += 0.25
		&"bg_shop_discount":
			shop_price_mult *= 0.85
		&"bg_rare_relic_chance_big":
			rare_relic_bonus += 0.15

		_:
			_register_world_effect(id)
			_warn_unknown_once(id)

# -----------------------------
# Player lookup + health helpers
# -----------------------------
func _get_player_node() -> Node:
	return get_tree().get_first_node_in_group("player")

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
		"starting_dice_max": starting_dice_max
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
	pass

func update_starting_dice_range(new_value: int) -> void:
	"""Update starting dice range to new value after final boss victory"""
	starting_dice_min = new_value
	starting_dice_max = new_value
	save_meta()
	pass
