extends Node
class_name LandingVFX

## Spawns landing VFX when the player lands from a jump/fall
## Similar to PerfectDodgeVFX pattern

@export var player_controller_path: NodePath = ^".."
@export var landing_vfx_scene: PackedScene

# VFX positioning
@export var feet_offset_y: float = 32.0  # Offset below player center to feet level
@export var feet_offset_x: float = 0.0   # Horizontal offset

# Anti-spam for rapid re-landings
@export var cooldown: float = 0.2
@export var debug_logs: bool = false

var _player_controller: Node = null
var _cooldown_left: float = 0.0

func _ready() -> void:
	if debug_logs:
		pass
		pass
		pass
		pass
	
	_player_controller = get_node_or_null(player_controller_path)
	
	if landing_vfx_scene == null:
		push_warning("[LandingVFX] landing_vfx_scene not assigned.")
		return
	
	if _player_controller == null:
		push_warning("[LandingVFX] PlayerController not found at: %s" % String(player_controller_path))
		return
	
	if debug_logs:
		pass
		pass
	
	# Connect to the landed signal
	if _player_controller.has_signal("landed"):
		if not _player_controller.landed.is_connected(_on_player_landed):
			_player_controller.landed.connect(_on_player_landed)
			pass
	else:
		push_warning("[LandingVFX] PlayerController missing signal: landed")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func _on_player_landed(was_double_jump: bool, facing_direction: int) -> void:
	if debug_logs:
		pass
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_landing_vfx(was_double_jump, facing_direction)

func _spawn_landing_vfx(_was_double_jump: bool, facing_direction: int) -> void:
	if landing_vfx_scene == null:
		if debug_logs:
			pass
		return
	
	# Get player body position
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		if debug_logs:
			pass
		return
	
	if debug_logs:
		pass
	
	# Instantiate VFX
	var vfx_node: Node = landing_vfx_scene.instantiate()
	var vfx: Node2D = vfx_node as Node2D
	if vfx == null:
		push_warning("[LandingVFX] VFX scene root must be a Node2D.")
		vfx_node.queue_free()
		return
	
	# Add to world (same parent as player, so it's in world space)
	var world_parent: Node = player_body.get_parent()
	if world_parent != null:
		world_parent.add_child(vfx)
		
		# Position at player's feet
		var feet_position: Vector2 = player_body.global_position
		feet_position.y += feet_offset_y  # Move down to feet
		feet_position.x += feet_offset_x  # Optional horizontal offset
		
		vfx.global_position = feet_position
		
		# Set facing direction
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", facing_direction)
			if debug_logs:
				pass
	else:
		vfx.queue_free()
		push_warning("[LandingVFX] Could not find world parent to spawn VFX")
