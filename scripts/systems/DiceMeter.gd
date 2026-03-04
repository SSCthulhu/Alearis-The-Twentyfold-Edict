extends Node
class_name DiceMeter

signal charge_changed(current_charge: float, max_charge: float)
signal meter_filled()
signal roll_resolved(roll_value: int, event_id: StringName, band: int)

@export var max_charge: float = 100.0
@export var charge_per_enemy_kill: float = 8.0
@export var charge_per_elite_kill: float = 20.0
@export var charge_per_perfect_dodge: float = 10.0
@export var boss_damage_step: float = 250.0
@export var charge_per_boss_damage_step: float = 8.0
@export var trigger_action: StringName = &"dice_meter_trigger"
@export var input_buffer_seconds: float = 0.15
@export var debug_logs: bool = true
@export_group("Debug Test Mode")
@export var debug_test_mode_enabled: bool = false
@export var debug_lock_meter_full: bool = true
@export var debug_prevent_enemy_deaths: bool = true
@export var debug_force_range_min: int = 1
@export var debug_force_range_max: int = 20

@export var default_event_table_path: String = "res://data/dice_meter/DiceMeterEventTable_Default.tres"
@export var event_table: DiceMeterEventTable

var current_charge: float = 0.0
var _pending_boss_damage: float = 0.0
var _trigger_count: int = 0

var last_roll: int = -1
var last_event_id: StringName = &""
var last_event_band: int = int(DiceMeterEventData.OutcomeBand.NEUTRAL)
var last_result: Dictionary = {}
var active_effect_name: String = ""
var active_effect_brief_text: String = ""
var active_effect_band: int = int(DiceMeterEventData.OutcomeBand.NEUTRAL)
var active_effect_time_left: float = 0.0
var _active_temp_effects: Array[Dictionary] = []
var _active_enemy_slow_effects: Array[Dictionary] = []
var _active_echo_pulses: Array[Dictionary] = []
var _active_player_hp_drain_effects: Array[Dictionary] = []
var _active_target_execution_effects: Array[Dictionary] = []
var _trigger_buffer_left: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	if event_table == null and ResourceLoader.exists(default_event_table_path):
		event_table = load(default_event_table_path) as DiceMeterEventTable
	_emit_charge_changed()

func _process(delta: float) -> void:
	_apply_debug_test_mode_overrides()
	_tick_enemy_slow_effects(delta)
	_tick_echo_pulses(delta)
	_tick_player_hp_drain_effects(delta)
	_tick_target_execution_effects(delta)
	_tick_temp_effects(delta)
	_process_trigger_input(delta)

func reset_meter() -> void:
	_clear_enemy_slow_effects()
	_clear_echo_pulses()
	_clear_player_hp_drain_effects()
	_clear_target_execution_effects()
	_clear_temp_effects()
	current_charge = 0.0
	_pending_boss_damage = 0.0
	_trigger_count = 0
	last_roll = -1
	last_event_id = &""
	last_event_band = int(DiceMeterEventData.OutcomeBand.NEUTRAL)
	last_result = {}
	active_effect_name = ""
	active_effect_brief_text = ""
	active_effect_time_left = 0.0
	_emit_charge_changed()
	_log_debug("Meter reset.")

func set_event_table(table: DiceMeterEventTable) -> void:
	event_table = table

func add_charge(amount: float, _reason: StringName = &"") -> void:
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
	if amount <= 0.0:
		return
	_pending_boss_damage += amount
	if boss_damage_step <= 0.0:
		return
	while _pending_boss_damage >= boss_damage_step:
		_pending_boss_damage -= boss_damage_step
		add_charge(charge_per_boss_damage_step, &"boss_damage_step")

func can_trigger_roll() -> bool:
	return current_charge >= max_charge and event_table != null

func trigger_roll(forced_roll: int = -1) -> Dictionary:
	if not can_trigger_roll():
		return {"ok": false, "reason": "meter_not_ready"}

	var roll: int = _resolve_roll_value(forced_roll)
	var rng: RandomNumberGenerator = _resolve_event_pick_rng(roll)
	var event_data: DiceMeterEventData = event_table.pick_event_for_roll(rng, roll)
	if event_data == null:
		return {"ok": false, "reason": "no_event_for_roll", "roll": roll}

	current_charge = 0.0
	_pending_boss_damage = 0.0
	_trigger_count += 1
	last_roll = roll
	last_event_id = event_data.id
	last_event_band = int(event_data.band)
	_sync_roll_to_run_state(roll)

	last_result = {
		"ok": true,
		"roll": roll,
		"event_id": event_data.id,
		"display_name": event_data.display_name,
		"brief_text": event_data.brief_text,
		"description": event_data.description,
		"band": int(event_data.band),
		"effect_id": event_data.effect_id,
		"duration_seconds": event_data.duration_seconds,
		"effect_params": event_data.effect_params
	}
	active_effect_name = event_data.display_name
	active_effect_brief_text = event_data.brief_text
	active_effect_band = int(event_data.band)
	active_effect_time_left = event_data.duration_seconds
	_apply_event_result(last_result)
	roll_resolved.emit(roll, event_data.id, int(event_data.band))
	_emit_charge_changed()
	_log_debug("Roll=%d, Event=%s, Band=%d, Effect=%s, Duration=%.2fs" % [
		roll,
		String(event_data.id),
		int(event_data.band),
		String(event_data.effect_id),
		event_data.duration_seconds
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
			_apply_temp_mult_to_runstate("enemy_damage_mult", 1.12, duration)
			_apply_floorwide_enemy_damage(0.015, 3)
		&"apply_hex_barrage":
			_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.16)), duration)
			_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 0.88)), duration)
		&"apply_crosswind_pressure":
			_apply_temp_mult_to_runstate("player_damage_mult", 0.92, duration)
			_apply_temp_mult_to_runstate("cooldown_mult", 1.10, duration)
		&"apply_gravity_well":
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 1.12)), duration)
			_apply_enemy_slow_field(duration, {"slow_mult": float(params.get("slow_mult", 0.85))})
		&"apply_weighted_calm":
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("enemy_haste_mult", 0.95)), duration)
		&"apply_coinflip_tempo":
			_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.05)), duration)
			_apply_temp_mult_to_runstate("enemy_damage_mult", float(params.get("enemy_damage_mult", 1.05)), duration)
		&"apply_astral_momentum":
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.85)), duration)
			_apply_temp_mult_to_runstate("player_damage_mult", 1.10, duration)
		&"apply_reprieve_sigil":
			_heal_player_percent(float(params.get("heal_percent", 0.35)))
			_grant_player_shield_percent(float(params.get("shield_percent", 0.12)), float(params.get("shield_duration", 6.0)), float(params.get("shield_cap_percent", 0.20)))
			_apply_temp_mult_to_runstate("healing_mult", float(params.get("healing_mult", 1.35)), duration)
			_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.90)), duration)
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
		&"apply_void_tax":
			_apply_void_tax(duration, params)
		&"apply_ascension_draft":
			_apply_ascension_draft(duration, params)
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
	_apply_floorwide_enemy_damage(float(params.get("blast_percent", 0.30)), int(params.get("blast_flat", 45)))
	_apply_enemy_slow_field(minf(duration, 6.0), {"slow_mult": float(params.get("slow_mult", 0.65))})
	_start_echo_pulses(duration, {
		"pulse_count": int(params.get("pulse_count", 5)),
		"pulse_interval": float(params.get("pulse_interval", 0.65)),
		"pulse_percent": float(params.get("pulse_percent", 0.06)),
		"pulse_flat": int(params.get("pulse_flat", 14))
	})

func _apply_miracle_effect(duration: float, params: Dictionary) -> void:
	var run_state := _get_run_state()
	if run_state != null and run_state.has_method("_full_heal_player"):
		run_state.call("_full_heal_player")
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("damage_mult", 1.40)), duration)
	_apply_temp_mult_to_runstate("cooldown_mult", 0.80, duration)

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
	var pulse_count: int = maxi(1, int(params.get("pulse_count", 4)))
	var pulse_interval: float = maxf(0.1, float(params.get("pulse_interval", 0.7)))
	var pulse_percent: float = maxf(0.0, float(params.get("pulse_percent", 0.05)))
	var pulse_flat: int = maxi(0, int(params.get("pulse_flat", 10)))
	_active_echo_pulses.append({
		"time_left": 0.08,
		"interval": pulse_interval,
		"pulses_left": pulse_count,
		"pulse_percent": pulse_percent,
		"pulse_flat": pulse_flat,
		"max_duration": duration
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
	var target: Node = _find_highest_hp_enemy()
	if target == null:
		return
	_active_target_execution_effects.append({
		"target": target,
		"time_left": duration,
		"interval_left": maxf(float(params.get("tick_interval", 1.0)), 0.1),
		"interval": maxf(float(params.get("tick_interval", 1.0)), 0.1),
		"tick_percent": maxf(float(params.get("tick_percent", 0.06)), 0.0),
		"tick_flat": maxi(int(params.get("tick_flat", 8)), 0)
	})

func _apply_false_crown(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.45)), duration)
	_active_player_hp_drain_effects.append({
		"time_left": duration,
		"interval_left": maxf(float(params.get("drain_interval", 1.0)), 0.1),
		"interval": maxf(float(params.get("drain_interval", 1.0)), 0.1),
		"drain_percent": maxf(float(params.get("drain_percent", 0.06)), 0.0),
		"enemy_blast_percent": maxf(float(params.get("enemy_blast_percent", 0.04)), 0.0),
		"enemy_blast_flat": maxi(int(params.get("enemy_blast_flat", 4)), 0)
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
		"enemy_blast_percent": maxf(float(params.get("enemy_blast_percent", 0.06)), 0.0),
		"enemy_blast_flat": maxi(int(params.get("enemy_blast_flat", 6)), 0)
	})

func _apply_ascension_draft(duration: float, params: Dictionary) -> void:
	_apply_temp_mult_to_runstate("player_damage_mult", float(params.get("player_damage_mult", 1.25)), duration)
	_apply_temp_mult_to_runstate("cooldown_mult", float(params.get("cooldown_mult", 0.80)), duration)
	_apply_enemy_slow_field(duration, {"slow_mult": float(params.get("slow_mult", 0.85))})
	_grant_player_shield_percent(float(params.get("shield_percent", 0.10)), float(params.get("shield_duration", 5.0)), float(params.get("shield_cap_percent", 0.20)))

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
		_apply_floorwide_enemy_damage(float(pulse.get("pulse_percent", 0.05)), int(pulse.get("pulse_flat", 10)))
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
		var target: Node = e.get("target", null)
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
				"node": enemy,
				"field": field_name,
				"original": base_v,
				"time_left": duration
			})
			break
	_log_debug("Applied enemy slow field x%.2f for %.2fs" % [slow_mult, duration])

func _tick_enemy_slow_effects(delta: float) -> void:
	if _active_enemy_slow_effects.is_empty():
		return
	for i: int in range(_active_enemy_slow_effects.size() - 1, -1, -1):
		var e: Dictionary = _active_enemy_slow_effects[i]
		var t: float = float(e.get("time_left", 0.0)) - delta
		if t > 0.0:
			e["time_left"] = t
			_active_enemy_slow_effects[i] = e
			continue
		var n: Node = e.get("node", null)
		if n != null and is_instance_valid(n):
			var field_name: String = String(e.get("field", ""))
			if field_name != "" and (field_name in n):
				n.set(field_name, float(e.get("original", n.get(field_name))))
		_active_enemy_slow_effects.remove_at(i)

func _clear_enemy_slow_effects() -> void:
	for e: Dictionary in _active_enemy_slow_effects:
		var n: Node = e.get("node", null)
		if n == null or not is_instance_valid(n):
			continue
		var field_name: String = String(e.get("field", ""))
		if field_name != "" and (field_name in n):
			n.set(field_name, float(e.get("original", n.get(field_name))))
	_active_enemy_slow_effects.clear()

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
	if damage <= 0:
		return
	var hp_node: Node = target.get_node_or_null("Health")
	if hp_node != null and hp_node.has_method("take_damage"):
		hp_node.call("take_damage", damage, self, tag, false)
	elif target.has_method("take_damage"):
		target.call("take_damage", damage, self)

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

func _collect_enemy_like_nodes(node: Node, out: Array[Node], seen: Dictionary) -> void:
	if node == null:
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
	if active_effect_time_left > 0.0:
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
	if RunStateSingleton == null:
		if forced_roll >= 1:
			return forced_roll
		return randi_range(1, 20)

	var min_roll: int = int(RunStateSingleton.dice_min)
	var max_roll: int = int(RunStateSingleton.dice_max)
	if forced_roll >= min_roll and forced_roll <= max_roll:
		return forced_roll

	if RunStateSingleton.has_method("roll_for_domain_in_range"):
		return int(RunStateSingleton.call("roll_for_domain_in_range", &"dice_meter_roll", min_roll, max_roll, _trigger_count))

	var fallback_rng := RandomNumberGenerator.new()
	fallback_rng.randomize()
	return fallback_rng.randi_range(min_roll, max_roll)

func _resolve_event_pick_rng(roll: int) -> RandomNumberGenerator:
	if RunStateSingleton != null and RunStateSingleton.has_method("make_rng_for_domain"):
		var seeded_rng: RandomNumberGenerator = RunStateSingleton.call("make_rng_for_domain", &"dice_meter_event_pick", (_trigger_count * 100) + roll) as RandomNumberGenerator
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
