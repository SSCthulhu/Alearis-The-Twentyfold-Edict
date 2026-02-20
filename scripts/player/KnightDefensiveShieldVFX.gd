extends Node

## Manager for Knight defensive shield VFX
## Handles three-stage shield system:
##   1. Shield_On (activation animation)
##   2. Shield_Active (continuous while buff is active)
##   3. Shield_Off (deactivation animation)

@export var shield_on_vfx_scene: PackedScene = null
@export var shield_active_vfx_scene: PackedScene = null
@export var shield_off_vfx_scene: PackedScene = null
@export var defensive_duration: float = 10.0  # How long the defensive buff lasts

var _active_shield: Node2D = null  # Reference to the continuous shield VFX

func _ready() -> void:
	var player = get_parent()
	if player == null:
		pass
		return
	
	if not player.has_signal("defensive_activated"):
		pass
		return
	
	player.defensive_activated.connect(_on_defensive_activated)
	pass

func _on_defensive_activated(character_name: String, _facing_direction: int) -> void:
	"""Handle defensive activation signal"""
	# Only trigger for Knight
	if character_name != "Knight":
		return
	
	# Validate scenes
	if shield_on_vfx_scene == null:
		pass
		return
	if shield_active_vfx_scene == null:
		pass
		return
	if shield_off_vfx_scene == null:
		pass
		return
	
	pass
	
	# Phase 1: Spawn shield_on animation
	_spawn_shield_on()

func _spawn_shield_on() -> void:
	"""Spawn shield activation animation"""
	var player = get_parent()
	if player == null:
		return
	
	var player_pos: Vector2 = player.global_position
	
	var vfx: Node2D = shield_on_vfx_scene.instantiate()
	vfx.global_position = player_pos
	
	# Connect to animation_complete signal to trigger next phase
	if vfx.has_signal("animation_complete"):
		vfx.animation_complete.connect(_on_shield_on_complete)
	
	# Add to world (not as child of player)
	get_tree().root.add_child(vfx)
	
	pass

func _on_shield_on_complete() -> void:
	"""Called when shield_on animation finishes"""
	pass
	
	# Phase 2: Spawn continuous shield
	_spawn_shield_active()
	
	# Phase 3: Schedule shield_off after defensive duration
	await get_tree().create_timer(defensive_duration).timeout
	_spawn_shield_off()

func _spawn_shield_active() -> void:
	"""Spawn continuous shield that follows player"""
	var player = get_parent()
	if player == null:
		return
	
	var player_pos: Vector2 = player.global_position
	
	_active_shield = shield_active_vfx_scene.instantiate()
	_active_shield.global_position = player_pos
	
	# Set player reference for following
	if _active_shield.has_method("set_player"):
		_active_shield.call("set_player", player)
	
	# Add to world
	get_tree().root.add_child(_active_shield)
	
	pass

func _spawn_shield_off() -> void:
	"""Spawn shield deactivation animation"""
	# Destroy active shield
	if _active_shield != null and is_instance_valid(_active_shield):
		_active_shield.queue_free()
		_active_shield = null
		pass
	
	var player = get_parent()
	if player == null:
		return
	
	var player_pos: Vector2 = player.global_position
	
	var vfx: Node2D = shield_off_vfx_scene.instantiate()
	vfx.global_position = player_pos
	
	# Add to world
	get_tree().root.add_child(vfx)
	
	pass
