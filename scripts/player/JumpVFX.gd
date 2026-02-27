extends Node
class_name JumpVFX
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

## Spawns jump VFX when the player jumps (regular or double jump)
## VFX is rotated 90 degrees and flips based on facing direction

@export var player_controller_path: NodePath = ^".."
@export var jump_vfx_scene: PackedScene

# VFX positioning
@export var offset_x: float = 0.0
@export var offset_y: float = 50.0

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
	
	if jump_vfx_scene == null:
		push_warning("[JumpVFX] jump_vfx_scene not assigned.")
		return
	
	if _player_controller == null:
		push_warning("[JumpVFX] PlayerController not found at: %s" % String(player_controller_path))
		return
	
	if debug_logs:
		pass
	
	# Connect to the jump_started signal
	if _player_controller.has_signal("jump_started"):
		if not _player_controller.jump_started.is_connected(_on_jump_started):
			_player_controller.jump_started.connect(_on_jump_started)
			pass
	else:
		push_warning("[JumpVFX] PlayerController missing signal: jump_started")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func _on_jump_started(is_double_jump: bool, facing_direction: int) -> void:
	if debug_logs:
		pass
	
	# Only spawn for REGULAR jumps (not double jumps)
	if is_double_jump:
		if debug_logs:
			pass
		return
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_jump_vfx(is_double_jump, facing_direction)

func _spawn_jump_vfx(_is_double_jump: bool, facing_direction: int) -> void:
	if jump_vfx_scene == null:
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
	var vfx_node: Node = jump_vfx_scene.instantiate()
	var vfx: Node2D = vfx_node as Node2D
	if vfx == null:
		push_warning("[JumpVFX] VFX scene root must be a Node2D.")
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
		
		# Set facing direction (VFX is already rotated 90° in scene)
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", facing_direction)
			if debug_logs:
				pass
	else:
		vfx.queue_free()
		push_warning("[JumpVFX] Could not find world parent to spawn VFX")
