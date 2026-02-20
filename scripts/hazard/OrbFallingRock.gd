# res://scripts/OrbFallingRock.gd
extends Area2D
class_name OrbFallingRock

@export var life_seconds: float = 4.0
@export var rock_texture_path: String = "res://art/Worlds/Tropical/Props/stone/rock 1.png"
@export var debug_collision: bool = false  # ✅ Show collision shape debug (disabled for performance)
@export var debug_collision_hits: bool = false  # ✅ Debug collision detection (disabled - too many prints)
@export var debug_orblight_only: bool = true  # ✅ Only debug OrbLight hits

var _player: Node2D = null
var _orb: Node2D = null
var _player_health: PlayerHealth = null  # ⚡ OPTIMIZATION: Cache health reference
var _fall_speed: float = 900.0
var _damage: int = 10
var _timer: float = 0.0
var _hit: bool = false
var _active: bool = false  # ✅ Track if rock is in use (for pooling)

# Cached nodes for performance
var _sprite: Sprite2D = null
var _collision: CollisionShape2D = null

func _ready() -> void:
	add_to_group(&"orb_flight_rocks")
	_timer = life_seconds
	
	# ✅ Cache child nodes for performance
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	
	# ✅ Store ORIGINAL collision size ONCE in _ready (never changes)
	if _collision != null and _collision.shape != null:
		var shape := _collision.shape
		if not _collision.has_meta("_original_collision_scale"):
			if shape is CircleShape2D:
				_collision.set_meta("_original_collision_scale", shape.radius)
				if debug_collision:
					pass
			elif shape is RectangleShape2D:
				_collision.set_meta("_original_collision_scale", shape.size)
				if debug_collision:
					pass
	
	# ✅ Debug: Check if collision shape exists
	if debug_collision:
		pass
		pass
		pass
		if _collision != null:
			pass
			if _collision.shape is CircleShape2D:
				pass
			elif _collision.shape is RectangleShape2D:
				pass
	
	# ✅ Load rock texture once
	if _sprite != null and rock_texture_path != "":
		var tex := load(rock_texture_path) as Texture2D
		if tex != null:
			_sprite.texture = tex

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# ✅ Also connect area_entered in case orb is Area2D
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	
	# Enable debug collision drawing in editor
	set_notify_transform(true)

# ✅ Handle Area2D collisions (in case orb is Area2D, not CharacterBody2D)
func _on_area_entered(area: Area2D) -> void:
	if debug_collision:
		pass
	
	# Treat area collision same as body collision
	_on_body_entered(area)

# ✅ Configure for pooling (called when activating from pool)
func configure(player: Node2D, fall_speed: float, damage: int, orb: Node2D = null, health: PlayerHealth = null) -> void:
	_player = player
	_orb = orb
	# ⚡ OPTIMIZATION: Cache health to avoid node lookup on every collision
	_player_health = health
	_fall_speed = maxf(fall_speed, 1.0)
	_damage = maxi(damage, 1)
	_timer = life_seconds
	_hit = false
	_active = true
	
	# ✅ Randomize appearance for variety
	_randomize_appearance()
	
	# Reset visibility and collision (use set_deferred for safety)
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

# ✅ Randomize scale, rotation, and color tint
func _randomize_appearance() -> void:
	if _sprite == null:
		pass
		return
	
	# Random scale (0.4 to 0.9x - smaller rocks)
	var scale_factor: float = randf_range(0.4, 0.9)
	
	# ✅ DON'T scale the Area2D node - scale sprite and collision separately!
	# This prevents double-scaling issues
	
	# Scale sprite
	_sprite.scale = Vector2(scale_factor, scale_factor)
	
	# ✅ Scale collision shape to match sprite size
	if _collision == null:
		pass
		return
	
	if _collision.shape == null:
		pass
		return
	
	var shape := _collision.shape
	
	# ✅ Get the PERMANENT original size (stored in _ready, never changes)
	if not _collision.has_meta("_original_collision_scale"):
		pass
		return
	
	# Apply scale to collision shape using PERMANENT original
	if shape is CircleShape2D:
		var original_radius: float = _collision.get_meta("_original_collision_scale", 32.0)
		shape.radius = original_radius * scale_factor
		if debug_collision:
			pass
	elif shape is RectangleShape2D:
		var original_size: Vector2 = _collision.get_meta("_original_collision_scale", Vector2(64, 64))
		shape.size = original_size * scale_factor
		if debug_collision:
			pass
	
	# Random rotation
	rotation = randf() * TAU
	
	# Slight color variation (gray rocks with subtle tint)
	var tint_variation: float = randf_range(0.85, 1.0)
	_sprite.modulate = Color(tint_variation, tint_variation, tint_variation, 1.0)

# ✅ Debug: Draw collision shape
func _draw() -> void:
	if not debug_collision or not _active:
		return
	
	if _collision == null or _collision.shape == null:
		return
	
	var shape := _collision.shape
	var color := Color.RED
	color.a = 0.3
	
	if shape is CircleShape2D:
		draw_circle(Vector2.ZERO, shape.radius, color)
		draw_arc(Vector2.ZERO, shape.radius, 0, TAU, 32, Color.RED, 2.0)
	elif shape is RectangleShape2D:
		var rect := Rect2(-shape.size / 2.0, shape.size)
		draw_rect(rect, color)
		draw_rect(rect, Color.RED, false, 2.0)

# ✅ Deactivate (for pooling - called instead of queue_free)
func deactivate() -> void:
	_active = false
	visible = false
	# ✅ Use set_deferred to avoid "Function blocked during signal" errors
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_player = null
	_player_health = null  # ⚡ Clear health cache
	_orb = null
	_hit = false

# ✅ Check if rock is pooled and available
func is_active() -> bool:
	return _active

func _physics_process(delta: float) -> void:
	if not _active:
		return
	
	global_position.y += _fall_speed * delta

	_timer -= delta
	if _timer <= 0.0:
		deactivate()  # ✅ Deactivate instead of queue_free for pooling
	
	# Redraw collision debug visualization
	if debug_collision:
		queue_redraw()

func _on_body_entered(b: Node) -> void:
	# Early exit for non-targets
	if not _active or _hit:
		return
	if _player == null or not is_instance_valid(_player):
		return
	
	# ✅ Check if we hit either the player OR the orb (during flight)
	var is_player: bool = (b == _player)
	var is_orb: bool = (_orb != null and b == _orb)
	var hit_target: bool = is_player or is_orb
	
	# ✅ Debug ONLY OrbLight hits
	if b.name == "OrbLight" and debug_orblight_only:
		var _orb_ref: String = "null"
		if _orb != null:
			_orb_ref = _orb.name
		pass
	
	if not hit_target:
		return

	_hit = true
	
	# ⚡ OPTIMIZATION: Use cached health (no node lookup!)
	if _player_health != null:
		_player_health.take_damage(_damage, self, false)
		if b.name == "OrbLight" and debug_orblight_only:
			pass

	deactivate()
