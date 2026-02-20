extends Node
## Roll VFX Manager
## Spawns smoke trail VFX behind player when they roll/dodge

@export var vfx_scene: PackedScene
@export var target_character: String = "Rogue"  # Which character this VFX is for
@export var behind_offset: float = 100.0  # Distance behind player to spawn VFX
@export var offset_y: float = 0.0  # Y offset from player center
@export var cooldown: float = 0.2  # Anti-spam cooldown
@export var debug_logs: bool = true

@onready var _player_controller: Node = get_parent()

var _cooldown_left: float = 0.0


func _ready() -> void:
	if _player_controller == null or not _player_controller.has_signal("roll_started"):
		push_error("[RollVFX] Parent must be PlayerControllerV3 with roll_started signal!")
		return
	
	_player_controller.roll_started.connect(_on_roll_started)
	pass


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _on_roll_started(character_name: String, facing_direction: int) -> void:
	"""Spawn roll VFX when player rolls"""
	if debug_logs:
		pass
	
	# Filter by character
	if character_name != target_character:
		if debug_logs:
			pass
		return
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	if vfx_scene == null:
		push_error("[RollVFX] No VFX scene assigned!")
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_roll_vfx(facing_direction)


func _spawn_roll_vfx(facing_direction: int) -> void:
	"""Spawn roll smoke VFX behind player based on roll direction"""
	var vfx: Node2D = vfx_scene.instantiate()
	
	# Add to world (not as child of player)
	var world = get_tree().root
	world.add_child(vfx)
	
	# Position behind player based on facing direction
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		vfx.queue_free()
		push_error("[RollVFX] Parent is not a Node2D")
		return
	
	var vfx_position: Vector2 = player_body.global_position
	
	# Calculate behind offset (opposite of facing direction)
	# If facing right (+1), spawn behind (left side, -offset)
	# If facing left (-1), spawn behind (right side, +offset)
	vfx_position.x -= facing_direction * behind_offset
	vfx_position.y += offset_y
	
	vfx.global_position = vfx_position
	
	# Set facing direction if VFX supports it
	if vfx.has_method("set_facing"):
		vfx.set_facing(facing_direction)
	
	if debug_logs:
		pass
