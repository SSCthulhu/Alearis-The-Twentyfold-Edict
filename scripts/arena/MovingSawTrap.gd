extends Node2D
class_name MovingSawTrap

@export var left_x: float = 47250.0
@export var right_x: float = 47750.0
@export var fixed_y: float = 13000.0
@export var move_speed: float = 90.0
@export var end_pause_seconds: float = 2.0
@export var rotation_speed_deg: float = 360.0
@export var contact_damage: int = 5
@export var damage_cooldown: float = 0.35
@export var debug_logs: bool = false

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _hurt_area: Area2D = get_node_or_null("HurtArea") as Area2D

var _moving_to_right: bool = true
var _pause_timer: float = 0.0
var _damage_timer: float = 0.0
var _overlapping: Array[Node2D] = []

func _ready() -> void:
	if right_x < left_x:
		var tmp: float = left_x
		left_x = right_x
		right_x = tmp

	global_position = Vector2(clampf(global_position.x, left_x, right_x), fixed_y)
	_moving_to_right = true
	_pause_timer = 0.0
	_damage_timer = 0.0

	if _hurt_area != null:
		_hurt_area.collision_layer = 0
		_hurt_area.collision_mask = 2
		_hurt_area.monitoring = true
		_hurt_area.monitorable = false
		if not _hurt_area.body_entered.is_connected(_on_hurt_area_body_entered):
			_hurt_area.body_entered.connect(_on_hurt_area_body_entered)
		if not _hurt_area.body_exited.is_connected(_on_hurt_area_body_exited):
			_hurt_area.body_exited.connect(_on_hurt_area_body_exited)

func _physics_process(delta: float) -> void:
	# Keep trap movement strictly on X-axis.
	global_position.y = fixed_y

	var target_x: float = right_x if _moving_to_right else left_x

	if _pause_timer > 0.0:
		_pause_timer = maxf(_pause_timer - delta, 0.0)
	else:
		var new_x: float = move_toward(global_position.x, target_x, move_speed * delta)
		global_position.x = new_x
		if is_equal_approx(new_x, target_x):
			_moving_to_right = not _moving_to_right
			_pause_timer = end_pause_seconds

	if _sprite != null:
		_sprite.rotation += deg_to_rad(rotation_speed_deg) * delta

	_tick_damage(delta)

func _tick_damage(delta: float) -> void:
	if _overlapping.is_empty():
		return

	if _damage_timer > 0.0:
		_damage_timer = maxf(_damage_timer - delta, 0.0)
		return

	_damage_timer = damage_cooldown

	var still_overlapping: Array[Node2D] = []
	for body: Node2D in _overlapping:
		if body == null or not is_instance_valid(body):
			continue
		still_overlapping.append(body)
		_try_damage_body(body)
	_overlapping = still_overlapping

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if not _overlapping.has(body):
		_overlapping.append(body)
	_try_damage_body(body)
	_damage_timer = damage_cooldown

func _on_hurt_area_body_exited(body: Node2D) -> void:
	if body == null:
		return
	var idx: int = _overlapping.find(body)
	if idx >= 0:
		_overlapping.remove_at(idx)

func _try_damage_body(body: Node2D) -> void:
	var health: Node = null
	if body.has_node("Health"):
		health = body.get_node("Health")
	elif body.get_parent() != null and body.get_parent().has_node("Health"):
		health = body.get_parent().get_node("Health")

	if health != null and health.has_method("take_damage"):
		health.call("take_damage", contact_damage, self)
		if debug_logs:
			print("[MovingSawTrap] dealt ", contact_damage, " to ", body.name)
