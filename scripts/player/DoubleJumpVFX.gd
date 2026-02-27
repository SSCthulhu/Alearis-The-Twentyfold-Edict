extends Node
class_name DoubleJumpVFX
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

## Spawns double jump VFX when the player performs a double jump
## VFX is rotated 270 degrees and flips based on facing direction

@export var player_controller_path: NodePath = ^".."
@export var double_jump_vfx_scene: PackedScene

# VFX positioning
@export var offset_x: float = 0.0
@export var offset_y: float = 30.0

# Anti-spam
@export var cooldown: float = 0.15
@export var debug_logs: bool = false

var _player_controller: Node = null
var _cooldown_left: float = 0.0

func _ready() -> void:
	if debug_logs:
		pass
		pass
	
	_player_controller = get_node_or_null(player_controller_path)
	
	if double_jump_vfx_scene == null:
		push_warning("[DoubleJumpVFX] double_jump_vfx_scene not assigned.")
		return
	
	if _player_controller == null:
		push_warning("[DoubleJumpVFX] PlayerController not found at: %s" % String(player_controller_path))
		return
	
	if debug_logs:
		pass
	
	# Connect to the jump_started signal
	if _player_controller.has_signal("jump_started"):
		if not _player_controller.jump_started.is_connected(_on_jump_started):
			_player_controller.jump_started.connect(_on_jump_started)
			pass
	else:
		push_warning("[DoubleJumpVFX] PlayerController missing signal: jump_started")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func _on_jump_started(is_double_jump: bool, facing_direction: int) -> void:
	if debug_logs:
		pass
	
	# Only spawn for DOUBLE jumps (not regular jumps)
	if not is_double_jump:
		if debug_logs:
			pass
		return
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_double_jump_vfx(facing_direction)

func _spawn_double_jump_vfx(facing_direction: int) -> void:
	if double_jump_vfx_scene == null:
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
	var vfx_node: Node = double_jump_vfx_scene.instantiate()
	var vfx: Node2D = vfx_node as Node2D
	if vfx == null:
		push_warning("[DoubleJumpVFX] VFX scene root must be a Node2D.")
		vfx_node.queue_free()
		return
	
	# Add to world (same parent as player, so it's in world space)
	var world_parent: Node = player_body.get_parent()
	if world_parent != null:
		world_parent.add_child(vfx)
		VfxRenderUtil.promote(vfx, 220)
		
		# Position VFX
		var vfx_position: Vector2 = player_body.global_position
		vfx_position.y += offset_y
		vfx_position.x += offset_x
		
		vfx.global_position = vfx_position
		
		# Set facing direction (VFX is already rotated 270° in scene)
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", facing_direction)
			if debug_logs:
				pass
	else:
		vfx.queue_free()
		push_warning("[DoubleJumpVFX] Could not find world parent to spawn VFX")
