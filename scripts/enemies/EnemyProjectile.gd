extends Area2D
class_name EnemyProjectile

@export var speed: float = 600.0
@export var lifetime: float = 5.0
@export var rotate_to_direction: bool = true  # Set to false for projectiles that shouldn't rotate

var _direction: Vector2 = Vector2.RIGHT
var _damage: int = 15
var _time_alive: float = 0.0
var _hit_targets: Dictionary = {}

func initialize(direction: Vector2, damage: int) -> void:
	_direction = direction.normalized()
	_damage = damage
	
	# Optionally rotate to face direction
	if rotate_to_direction:
		rotation = _direction.angle()
	
	# Flip VFX based on direction (if VFX exists)
	_update_vfx_flip()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Check for overlapping areas BEFORE moving (early collision detection)
	var overlapping = get_overlapping_areas()
	for area in overlapping:
		if area != null and area.get_parent() != null:
			var parent = area.get_parent()
			if parent.is_in_group("player"):
				_try_hit(parent)
				return  # Stop processing after hit
	
	# Check for overlapping bodies BEFORE moving
	var overlapping_bodies = get_overlapping_bodies()
	for body in overlapping_bodies:
		if body != null and body.is_in_group("player"):
			_try_hit(body)
			return  # Stop processing after hit
	
	global_position += _direction * speed * delta
	_time_alive += delta

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
	
	# Prevent multi-hit
	if _hit_targets.has(target):
		return
	_hit_targets[target] = true
	
	pass
	
	# Immediately stop movement and hide visual
	set_physics_process(false)
	set_process(false)
	
	# Stop and hide the visual immediately
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual is AnimatedSprite2D:
			visual.stop()
		visual.visible = false
		visual.modulate.a = 0.0
	
	# Stop and hide the wind VFX
	if has_node("WindVFX"):
		var vfx = get_node("WindVFX")
		if vfx is AnimatedSprite2D:
			vfx.stop()
		vfx.visible = false
	
	# Make entire projectile completely invisible
	modulate.a = 0.0
	visible = false
	
	# Disable collision to prevent further hits
	if has_node("CollisionShape2D"):
		var collision = get_node("CollisionShape2D")
		collision.set_deferred("disabled", true)
	
	# Apply damage
	if target.has_node("Health"):
		var health: Node = target.get_node("Health")
		if health != null and health.has_method("take_damage"):
			health.call("take_damage", _damage, self, false)
	elif target.has_method("take_damage"):
		target.call("take_damage", _damage, self, false)
	
	# Hide VFX too
	if has_node("WindVFX"):
		var vfx = get_node("WindVFX")
		vfx.visible = false
	
	# Destroy projectile after hitting
	pass
	queue_free()


func _update_vfx_flip() -> void:
	"""Flip WindVFX based on arrow direction"""
	if not has_node("WindVFX"):
		return
	
	var vfx: Node = get_node("WindVFX")
	if vfx is Sprite2D or vfx is AnimatedSprite2D:
		# Flip Y if arrow is pointing left (direction.x < 0)
		vfx.flip_v = _direction.x < 0
