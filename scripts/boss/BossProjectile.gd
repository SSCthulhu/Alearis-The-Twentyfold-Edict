extends Area2D
class_name BossProjectile
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

## A projectile spawned by boss attacks
## Can move in straight lines, curves, or custom paths

signal hit_target(target: Node)

@export var speed: float = 400.0
@export var lifetime: float = 8.0
@export var damage: int = 15
@export var pierce_count: int = 0  # 0 = destroy on first hit, -1 = infinite pierce

# Visual
@export var sprite_path: NodePath = ^"Sprite2D"
@export var trail_enabled: bool = false

# Movement
enum MovementType { STRAIGHT, HOMING, SINE_WAVE, SPIRAL }
@export var movement_type: MovementType = MovementType.STRAIGHT

# Homing parameters
@export var homing_strength: float = 2.0
@export var homing_duration: float = 2.0

# Sine wave parameters
@export var wave_amplitude: float = 50.0
@export var wave_frequency: float = 2.0

# Spiral parameters
@export var spiral_radius_growth: float = 100.0
@export var spiral_rotation_speed: float = 2.0

var _direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0
var _hit_count: int = 0
var _sprite: Sprite2D = null
var _glow_sprite: Sprite2D = null
var _initial_position: Vector2 = Vector2.ZERO
var _target: Node2D = null
var _color: Color = Color(1.0, 0.2, 0.2, 1.0)

func initialize(direction: Vector2, proj_damage: int = -1, proj_speed: float = -1.0) -> void:
	"""Initialize projectile with direction and optional overrides"""
	_direction = direction.normalized()
	if proj_damage >= 0:
		damage = proj_damage
	if proj_speed > 0:
		speed = proj_speed
	
	# Rotate sprite to face direction
	rotation = _direction.angle()
	_initial_position = global_position
	
	# Randomize size for visual variety (0.8 to 1.2 scale multiplier)
	var random_scale: float = randf_range(0.8, 1.2)
	if _sprite != null:
		_sprite.scale = _sprite.scale * random_scale  # Multiply existing scale
	if _glow_sprite != null:
		_glow_sprite.scale = _glow_sprite.scale * random_scale * 1.15  # Multiply existing scale
	
	# Scale collision shape to match sprite (multiply existing scale)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision_shape != null:
		collision_shape.scale = collision_shape.scale * random_scale

func set_target(target: Node2D) -> void:
	"""Set homing target"""
	_target = target

func set_color(color: Color) -> void:
	"""Set the visual color of this projectile"""
	_color = color
	_apply_color()

func _apply_color() -> void:
	"""Apply the color to sprite nodes"""
	if _sprite != null:
		_sprite.modulate = _color
	if _glow_sprite != null:
		var glow_color: Color = _color
		glow_color.a = 0.5
		_glow_sprite.modulate = glow_color

func _ready() -> void:
	VfxRenderUtil.promote(self, 260)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_glow_sprite = get_node_or_null(^"Glow") as Sprite2D
	
	# Don't apply color here - wait for set_color() to be called after initialization
	# _apply_color()

func _physics_process(delta: float) -> void:
	_time_alive += delta

	# Auto-destroy after lifetime (checked here so it respects pause — we don't run when paused)
	if _time_alive >= lifetime:
		_destroy()
		return

	# Update movement based on type
	match movement_type:
		MovementType.STRAIGHT:
			_move_straight(delta)
		MovementType.HOMING:
			_move_homing(delta)
		MovementType.SINE_WAVE:
			_move_sine_wave(delta)
		MovementType.SPIRAL:
			_move_spiral(delta)
	
	# Update rotation to face direction
	rotation = _direction.angle()

func _move_straight(delta: float) -> void:
	global_position += _direction * speed * delta

func _move_homing(delta: float) -> void:
	if _time_alive < homing_duration and _target != null and is_instance_valid(_target):
		var to_target: Vector2 = (_target.global_position - global_position).normalized()
		_direction = _direction.lerp(to_target, homing_strength * delta).normalized()
	
	global_position += _direction * speed * delta

func _move_sine_wave(delta: float) -> void:
	# Move forward
	var forward_movement: Vector2 = _direction * speed * delta
	
	# Add perpendicular sine wave
	var perpendicular: Vector2 = Vector2(-_direction.y, _direction.x)
	var wave_offset: float = sin(_time_alive * wave_frequency * TAU) * wave_amplitude * delta
	
	global_position += forward_movement + (perpendicular * wave_offset)

func _move_spiral(_delta: float) -> void:
	# Spiral outward from spawn point
	var angle: float = _time_alive * spiral_rotation_speed * TAU
	var radius: float = _time_alive * spiral_radius_growth
	
	var spiral_offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius
	global_position = _initial_position + (_direction * speed * _time_alive) + spiral_offset

func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	# Try hitting area's parent (for player hurtbox)
	if area != null and area.get_parent() != null:
		_try_hit(area.get_parent())

func _try_hit(target: Node) -> void:
	if target == null:
		return
	if not target.is_in_group("player"):
		return
	
	# Apply damage
	var hit_success: bool = false
	if target.has_node("Health"):
		var health: Node = target.get_node("Health")
		if health != null and health.has_method("take_damage"):
			health.call("take_damage", damage, self, false)
			hit_success = true
	elif target.has_method("take_damage"):
		target.call("take_damage", damage, self, false)
		hit_success = true
	
	if hit_success:
		hit_target.emit(target)
		_hit_count += 1
		
		# Check if we should destroy
		if pierce_count >= 0 and _hit_count > pierce_count:
			_destroy()

func _destroy() -> void:
	queue_free()
