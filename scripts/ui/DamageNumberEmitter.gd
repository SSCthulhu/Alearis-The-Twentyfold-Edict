# res://scripts/ui/DamageNumberEmitter.gd
extends Node
class_name DamageNumberEmitter

@export var damage_number_scene: PackedScene

# Where to spawn from (prefer Hurtbox center)
@export var hurtbox_path: NodePath = ^"../Hurtbox"
@export var fallback_origin_path: NodePath = ^".." # usually the enemy root / boss node
@export var offset: Vector2 = Vector2(0.0, -24.0)

# Optional: auto-hook a Health-like node that emits signals
@export var health_path: NodePath = ^"../Health"

# Tag ids (must match DamageNumber.gd)
const TAG_SHOCK: StringName = &"shock"
const TAG_BLEED: StringName = &"bleed"
const TAG_CRIT: StringName = &"crit"

@export var debug_logs: bool = false

var _health: Node = null
var _hurtbox: Area2D = null
var _fallback_origin: Node2D = null

func _ready() -> void:
	_hurtbox = get_node_or_null(hurtbox_path) as Area2D
	_fallback_origin = get_node_or_null(fallback_origin_path) as Node2D
	_health = get_node_or_null(health_path)

	# ---- Signal hookup (PRIORITY) ----
	# Crit-tagged signal > tagged signal > legacy plain signal.
	if _health != null:
		var has_tagged_crit: bool = _health.has_signal("damaged_tagged_crit")
		var has_tagged: bool = _health.has_signal("damaged_tagged")
		var has_plain: bool = _health.has_signal("damaged")

		if has_tagged_crit:
			# Only connect this one (prevents double spawns on crit)
			if not _health.damaged_tagged_crit.is_connected(_on_health_damaged_tagged_crit):
				_health.damaged_tagged_crit.connect(_on_health_damaged_tagged_crit)
				if debug_logs:
					pass
		elif has_tagged:
			# Only connect tagged (prevents double spawns if tagged is emitted for all hits)
			if not _health.damaged_tagged.is_connected(_on_health_damaged_tagged):
				_health.damaged_tagged.connect(_on_health_damaged_tagged)
				if debug_logs:
					pass
		elif has_plain:
			# Fallback legacy
			if not _health.damaged.is_connected(_on_health_damaged_plain):
				_health.damaged.connect(_on_health_damaged_plain)
				if debug_logs:
					pass

	if debug_logs:
		pass

# -----------------------------
# Public API (Boss can call directly)
# -----------------------------
func show_damage(amount: int, tag: StringName = &"", is_crit: bool = false) -> void:
	_spawn(amount, tag, is_crit)

func show_text(text: String, color: Color, scale_mult: float = 1.0) -> void:
	if damage_number_scene == null:
		return
	var dn: Node = damage_number_scene.instantiate()
	var dn2d: Node2D = dn as Node2D
	if dn2d != null:
		dn2d.global_position = _get_spawn_pos()
	get_tree().current_scene.add_child(dn)

	if dn.has_method("setup_text"):
		dn.call("setup_text", text, color, scale_mult)

# -----------------------------
# Health hooks
# -----------------------------
func _on_health_damaged_plain(amount: int) -> void:
	_spawn(amount, &"", false)

func _on_health_damaged_tagged(amount: int, tag: StringName) -> void:
	_spawn(amount, tag, false)

func _on_health_damaged_tagged_crit(amount: int, tag: StringName, is_crit: bool) -> void:
	if debug_logs:
		pass
	_spawn(amount, tag, is_crit)

# -----------------------------
# Internals
# -----------------------------
func _spawn(amount: int, tag: StringName, is_crit: bool) -> void:
	if debug_logs:
		pass
	
	if damage_number_scene == null:
		if debug_logs:
			pass
		return
	if amount <= 0:
		if debug_logs:
			pass
		return

	var resolved_tag: StringName = tag
	if is_crit and resolved_tag == &"":
		resolved_tag = TAG_CRIT

	var dn: Node = damage_number_scene.instantiate()
	var dn2d: Node2D = dn as Node2D
	if dn2d != null:
		dn2d.global_position = _get_spawn_pos()

	get_tree().current_scene.add_child(dn)

	if debug_logs:
		pass

	# Prefer unified API
	if dn.has_method("setup_damage"):
		dn.call("setup_damage", amount, resolved_tag, is_crit)
		return

	# Next: setup_amount_tagged(amount, tag, is_crit=false)
	if dn.has_method("setup_amount_tagged"):
		var argc: int = dn.get_method_argument_count("setup_amount_tagged")
		if argc >= 3:
			dn.call("setup_amount_tagged", amount, resolved_tag, is_crit)
		else:
			dn.call("setup_amount_tagged", amount, resolved_tag)
		return

	# Legacy
	if dn.has_method("setup"):
		dn.call("setup", amount)

func _get_spawn_pos() -> Vector2:
	var base: Vector2 = Vector2.ZERO

	if _hurtbox != null and is_instance_valid(_hurtbox):
		var cs: CollisionShape2D = _hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		base = cs.global_position if cs != null else _hurtbox.global_position
	elif _fallback_origin != null and is_instance_valid(_fallback_origin):
		base = _fallback_origin.global_position

	return base + offset
