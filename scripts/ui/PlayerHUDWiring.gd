extends Node
class_name PlayerHUDWiring

@export var hud_cluster_path: NodePath
@export var player_path: NodePath
@export var combat_path: NodePath

# Ability IDs
@export var light_id: StringName = &"light"
@export var heavy_id: StringName = &"heavy"
@export var defend_id: StringName = &"defend"

# Fallback totals
@export var light_total_fallback: float = 0.8
@export var heavy_total_fallback: float = 2.0
@export var defend_total_fallback: float = 60.0
@export var dodge_recharge_total_fallback: float = 10.0

@export var ultimate_id: StringName = &"ultimate"
@export var ultimate_total: float = 60.0

@export_range(0.02, 1.0, 0.01)
var sample_interval: float = 0.05

@export var combat_returns_elapsed: bool = false

@export var debug: bool = true
@export var run_when_paused: bool = true

var _hud: PlayerHUDCluster
var _player: Node
var _combat: Node
var _timer: Timer

var _health: PlayerHealth
var _last_known_max_hp: int = 0

var _last_cd_mult: float = -1.0
var _last_ability_names: Dictionary = {} # StringName -> String

func _get_display_name_from_player(id: StringName) -> String:
	# Preferred: Player provides names per character
	if _player != null and _player.has_method("get_ability_display_name"):
		return str(_player.call("get_ability_display_name", id))

	# Fallback: Combat provides names (if you implement it there instead)
	if _combat != null and _combat.has_method("get_ability_display_name"):
		return str(_combat.call("get_ability_display_name", id))

	# Final fallback: just use the id itself
	return String(id).to_upper()

func _ready() -> void:
	# Make the controller resilient to pause if desired
	if run_when_paused:
		process_mode = Node.PROCESS_MODE_ALWAYS

	_hud = get_node_or_null(hud_cluster_path) as PlayerHUDCluster
	if _hud == null:
		push_error("[PlayerHUDWiring] Could not find PlayerHUDCluster. Assign hud_cluster_path.")
		return

	_player = _resolve_player()
	if _player == null:
		push_error("[PlayerHUDWiring] Could not resolve Player. Assign player_path or ensure group 'player'.")
		return

	# Health wiring (HP + Shield)
	_health = _resolve_health(_player)
	if _health == null:
		push_warning("[PlayerHUDWiring] PlayerHealth not found (expected child 'Health'). Shield/HP HUD won't update.")
	else:
		if not _health.health_changed.is_connected(_on_health_changed):
			_health.health_changed.connect(_on_health_changed)

		if _health.has_signal("shield_changed"):
			if not _health.shield_changed.is_connected(_on_shield_changed):
				_health.shield_changed.connect(_on_shield_changed)
		else:
			push_warning("[PlayerHUDWiring] PlayerHealth missing signal shield_changed.")

		# Prime immediately using current values
		_last_known_max_hp = maxi(_health.max_hp, 1)
		_hud.set_health(float(_health.hp), float(_health.max_hp))
		_hud.set_shield(float(_health.shield), float(_health.max_hp))

	_combat = _resolve_combat(_player)
	if _combat == null:
		push_warning("[PlayerHUDWiring] Combat not found. Assign combat_path or ensure Player has child 'Combat' and is in group 'player'.")
		return

	# Create a deterministic tick source
	_timer = Timer.new()
	_timer.name = "HUDWiringTimer"
	_timer.one_shot = false
	_timer.wait_time = maxf(sample_interval, 0.02)
	_timer.autostart = true
	_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	if run_when_paused:
		_timer.process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(_timer)
	_timer.timeout.connect(_on_tick)

	# Prime immediately
	_on_tick()

	if debug:
		pass

func _exit_tree() -> void:
	if debug:
		pass

func _on_health_changed(current: int, max_value: int) -> void:
	_last_known_max_hp = maxi(max_value, 1)
	if _hud != null:
		_hud.set_health(float(current), float(max_value))

	# Keep shield ratio correct when max HP changes (Vital Thread, etc.)
	if _health != null and is_instance_valid(_health):
		_hud.set_shield(float(_health.shield), float(_last_known_max_hp))

func _on_shield_changed(current: int, _max_value: int) -> void:
	# We intentionally scale shield vs max HP (design intent)
	var max_hp_ref: int = maxi(_last_known_max_hp, 1)
	if _hud != null:
		_hud.set_shield(float(current), float(max_hp_ref))

func _on_tick() -> void:
	if _combat == null or _hud == null:
		return

	var cur_cd_mult: float = 1.0
	if RunStateSingleton != null and ("cooldown_mult" in RunStateSingleton):
		cur_cd_mult = float(RunStateSingleton.cooldown_mult)

	if absf(cur_cd_mult - _last_cd_mult) > 0.0001:
		_last_cd_mult = cur_cd_mult
		if _hud != null and _hud.ability_hud != null and _hud.ability_hud.has_method("reset_learned_totals"):
			_hud.ability_hud.call("reset_learned_totals")

	# --- Ultimate ---
	var raw := _get_cd_value(ultimate_id)
	var ult_total := maxf(ultimate_total, 0.01)

	var remaining := raw
	if combat_returns_elapsed:
		remaining = maxf(ult_total - raw, 0.0)

	_hud.set_ultimate_cooldown(remaining, ult_total)

	# --- Abilities (PlayerAbilityHUD) ---
	if _hud.ability_hud != null and _hud.ability_hud is PlayerAbilityHUD:
		var ah: PlayerAbilityHUD = _hud.ability_hud as PlayerAbilityHUD

		# 1) Update display names (only when they change)
		var n_light: String = _get_display_name_from_player(light_id)
		var n_heavy: String = _get_display_name_from_player(heavy_id)
		var n_def: String = _get_display_name_from_player(defend_id)

		if _last_ability_names.get(light_id, "") != n_light:
			_last_ability_names[light_id] = n_light
			if ah.has_method("set_ability_name"):
				ah.call("set_ability_name", light_id, n_light)

		if _last_ability_names.get(heavy_id, "") != n_heavy:
			_last_ability_names[heavy_id] = n_heavy
			if ah.has_method("set_ability_name"):
				ah.call("set_ability_name", heavy_id, n_heavy)

		if _last_ability_names.get(defend_id, "") != n_def:
			_last_ability_names[defend_id] = n_def
			if ah.has_method("set_ability_name"):
				ah.call("set_ability_name", defend_id, n_def)

		# 2) Cooldowns (your existing logic)
		var l := _get_cd_value(light_id)
		var h := _get_cd_value(heavy_id)
		var d := _get_cd_value(defend_id)

		ah.set_cooldown(light_id, l, light_total_fallback)
		ah.set_cooldown(heavy_id, h, heavy_total_fallback)
		ah.set_cooldown(defend_id, d, defend_total_fallback)

	# --- Dodge (owned by PlayerHUDCluster) ---
	var cur := _get_roll_charges()
	var mx := _get_roll_max_charges()
	var next_left := _get_roll_next_charge_left()
	var recharge_total := _get_roll_recharge_time()

	_hud.set_dodge_state(cur, mx, next_left, recharge_total)

	if debug:
		pass

func _resolve_player() -> Node:
	if player_path != NodePath():
		var p := get_node_or_null(player_path)
		if p != null:
			return p
	return get_tree().get_first_node_in_group("player")

func _resolve_combat(p: Node) -> Node:
	if combat_path != NodePath():
		var c := get_node_or_null(combat_path)
		if c != null:
			return c
	if p != null and p.has_node("Combat"):
		return p.get_node("Combat")
	return null

func _resolve_health(p: Node) -> PlayerHealth:
	if p == null:
		return null
	if p.has_node("Health"):
		return p.get_node("Health") as PlayerHealth
	return null

func _get_cd_value(key: StringName) -> float:
	if _combat != null and _combat.has_method("get_cooldown_left"):
		return float(_combat.call("get_cooldown_left", key))
	return 0.0

func _get_roll_charges() -> int:
	if _player != null and _player.has_method("get_roll_charges"):
		return int(_player.call("get_roll_charges"))
	return 0

func _get_roll_max_charges() -> int:
	if _player != null and _player.has_method("get_roll_max_charges"):
		return int(_player.call("get_roll_max_charges"))
	return 2

func _get_roll_next_charge_left() -> float:
	if _player != null and _player.has_method("get_roll_next_charge_time_left"):
		return float(_player.call("get_roll_next_charge_time_left"))
	return 0.0

func _get_roll_recharge_time() -> float:
	if _player != null and _player.has_method("get_roll_recharge_time"):
		return float(_player.call("get_roll_recharge_time"))
	return maxf(dodge_recharge_total_fallback, 0.01)
