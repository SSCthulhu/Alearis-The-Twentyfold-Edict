extends Node
## Projectile Hit VFX Manager
## Spawns explosion VFX on player when hit by specific enemy projectiles
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

@export var fire_explosion_scene: PackedScene  # For SkeletonMageProjectile
@export var blood_explosion_scene: PackedScene  # For NecromancerProjectile
@export var blood_side_burst_scene: PackedScene  # For physical attacks (melee, arrows)
@export var offset_y: float = 0.0  # Y offset from player center
@export var blood_side_offset_x: float = -20.0  # X offset for blood side burst
@export var debug_logs: bool = false

@onready var _player_health: Node = get_parent().get_node_or_null("Health")


func _ready() -> void:
	if _player_health == null:
		push_error("[ProjectileHitVFX] Could not find Health node on parent!")
		return
	
	if not _player_health.has_signal("damage_applied"):
		push_error("[ProjectileHitVFX] Health node missing damage_applied signal!")
		return
	
	_player_health.damage_applied.connect(_on_damage_applied)
	pass


func _on_damage_applied(_damage: int, source: Node) -> void:
	"""Spawn appropriate explosion VFX when player is hit by a projectile"""
	if source == null:
		return
	
	var source_name: String = source.name
	
	if debug_logs:
		pass
	
	# Get projectile position (before it's destroyed)
	var projectile_position: Vector2 = Vector2.ZERO
	if source is Node2D:
		projectile_position = (source as Node2D).global_position
	else:
		# Fallback to player position if source isn't a Node2D
		var player_body: Node2D = get_parent() as Node2D
		if player_body != null:
			projectile_position = player_body.global_position
	
	# Check if hit by SkeletonMageProjectile (fireball) - MAGIC
	if source_name.contains("SkeletonMageProjectile"):
		if fire_explosion_scene != null:
			_spawn_fire_explosion(projectile_position)
		else:
			push_warning("[ProjectileHitVFX] Fire explosion scene not assigned!")
		return
	
	# Check if hit by NecromancerProjectile (blood) - MAGIC
	if source_name.contains("NecromancerProjectile"):
		if blood_explosion_scene != null:
			_spawn_blood_explosion(projectile_position)
		else:
			push_warning("[ProjectileHitVFX] Blood explosion scene not assigned!")
		return
	
	# Check if hit by DeathZone (lava) - NO VFX (lava has its own fire effect)
	if source_name.contains("DeathZone"):
		if debug_logs:
			pass
		return
	
	# All other damage sources (melee, arrows) - PHYSICAL
	# Spawn blood side burst VFX
	if blood_side_burst_scene != null:
		_spawn_blood_side_burst(source)
	else:
		if debug_logs:
			pass


func _spawn_fire_explosion(impact_position: Vector2) -> void:
	"""Spawn fire explosion VFX at impact position"""
	var vfx: Node2D = fire_explosion_scene.instantiate()
	
	# Add to world (not as child of player)
	var world = get_tree().root
	world.add_child(vfx)
	VfxRenderUtil.promote(vfx, 220)
	
	# Position at impact point with offset
	var vfx_position: Vector2 = impact_position
	vfx_position.y += offset_y
	vfx.global_position = vfx_position
	
	if debug_logs:
		pass


func _spawn_blood_explosion(impact_position: Vector2) -> void:
	"""Spawn blood explosion VFX at impact position"""
	var vfx: Node2D = blood_explosion_scene.instantiate()
	
	# Add to world (not as child of player)
	var world = get_tree().root
	world.add_child(vfx)
	VfxRenderUtil.promote(vfx, 220)
	
	# Position at impact point with offset
	var vfx_position: Vector2 = impact_position
	vfx_position.y += offset_y
	vfx.global_position = vfx_position
	
	if debug_logs:
		pass


func _spawn_blood_side_burst(source: Node) -> void:
	"""Spawn blood side burst VFX for physical attacks (melee, arrows)"""
	var vfx: Node2D = blood_side_burst_scene.instantiate()
	
	# Get player position
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		vfx.queue_free()
		return
	
	# Calculate blood spray direction based on attack source
	# Blood sprays AWAY from the attack (opposite direction)
	var blood_direction: int = 1  # Default: spray right
	
	if source != null and source is Node2D:
		var source_pos: Vector2 = (source as Node2D).global_position
		var player_pos: Vector2 = player_body.global_position
		
		# If attack came from the left, spray right (positive)
		# If attack came from the right, spray left (negative)
		if source_pos.x < player_pos.x:
			blood_direction = 1  # Attack from left, blood sprays right
		else:
			blood_direction = -1  # Attack from right, blood sprays left
	
	# Add to world (not as child of player)
	var world = get_tree().root
	world.add_child(vfx)
	VfxRenderUtil.promote(vfx, 220)
	
	# Position at player center with offset
	var vfx_position: Vector2 = player_body.global_position
	vfx_position.x += blood_side_offset_x * float(blood_direction)  # Offset away from attack
	vfx_position.y += offset_y
	vfx.global_position = vfx_position
	
	# Set VFX facing direction (spray away from attack)
	if vfx.has_method("set_facing"):
		vfx.call("set_facing", blood_direction)
	
	if debug_logs:
		pass
