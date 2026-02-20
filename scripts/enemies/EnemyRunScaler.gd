extends Node
class_name RunScaler

@export var health_path: NodePath = ^"../Health"
@export var health_bar_path: NodePath = ^"../HealthBar"
@export var enemy_root_path: NodePath = ^".."

@export var scale_hp: bool = true
@export var scale_contact_damage: bool = true

var _applied: bool = false

func apply_once() -> void:
	if _applied:
		return
	_applied = true

	if RunStateSingleton == null:
		return

	var enemy_root: Node = get_node_or_null(enemy_root_path)
	var health: Node = get_node_or_null(health_path)
	var bar: ProgressBar = get_node_or_null(health_bar_path) as ProgressBar

	# ---- HP scaling ----
	if scale_hp and health != null and health.has_method("set_max_and_full_heal"):
		var base_max_var: Variant = health.get("max_hp")
		if base_max_var != null:
			var base_max: int = int(base_max_var)
			var mult: float = float(RunStateSingleton.enemy_health_mult)
			var new_max: int = max(1, int(round(float(base_max) * mult)))
			health.call("set_max_and_full_heal", new_max)

	# ---- Contact damage scaling (enemy script owns this) ----
	# We do NOT assume every enemy has these properties.
	if scale_contact_damage and enemy_root != null:
		var base_cd_var: Variant = enemy_root.get("_base_contact_damage")
		if base_cd_var != null:
			var base_cd: int = int(base_cd_var)
			var mult2: float = float(RunStateSingleton.enemy_damage_mult)
			enemy_root.set("contact_damage", max(1, int(round(float(base_cd) * mult2))))

	# ---- Update bar if present ----
	if bar != null and health != null:
		var max_hp_var: Variant = health.get("max_hp")
		if max_hp_var != null:
			bar.max_value = float(max_hp_var)

		var hp_var: Variant = health.get("hp")
		if hp_var != null:
			bar.value = float(hp_var)
