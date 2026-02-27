extends Node
class_name AirDashVFX
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

## Spawns directional air dash VFX when the player dashes while airborne
## VFX flips horizontally based on dash direction

@export var player_controller_path: NodePath = ^".."
@export var air_dash_vfx_scene: PackedScene

# VFX positioning
@export var offset_x: float = 0.0
@export var offset_y: float = 0.0

# Anti-spam
@export var cooldown: float = 0.2
@export var debug_logs: bool = false

var _player_controller: Node = null
var _cooldown_left: float = 0.0

func _ready() -> void:
	if debug_logs:
		pass
		pass
	
	_player_controller = get_node_or_null(player_controller_path)
	
	if air_dash_vfx_scene == null:
		push_warning("[AirDashVFX] air_dash_vfx_scene not assigned.")
		return
	
	if _player_controller == null:
		push_warning("[AirDashVFX] PlayerController not found at: %s" % String(player_controller_path))
		return
	
	if debug_logs:
		pass
	
	# Connect to the dash_started signal
	if _player_controller.has_signal("dash_started"):
		if not _player_controller.dash_started.is_connected(_on_dash_started):
			_player_controller.dash_started.connect(_on_dash_started)
			pass
	else:
		push_warning("[AirDashVFX] PlayerController missing signal: dash_started")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func _on_dash_started(facing_direction: int, is_airborne: bool) -> void:
	if debug_logs:
		pass
	
	# Only spawn for AIR dashes (not ground dashes)
	if not is_airborne:
		if debug_logs:
			pass
		return
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_air_dash_vfx(facing_direction)

func _spawn_air_dash_vfx(facing_direction: int) -> void:
	if air_dash_vfx_scene == null:
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
	var vfx_node: Node = air_dash_vfx_scene.instantiate()
	var vfx: Node2D = vfx_node as Node2D
	if vfx == null:
		push_warning("[AirDashVFX] VFX scene root must be a Node2D.")
		vfx_node.queue_free()
		return
	
	# Add to world (same parent as player, so it's in world space)
	var world_parent: Node = player_body.get_parent()
	if world_parent != null:
		world_parent.add_child(vfx)
		VfxRenderUtil.promote(vfx, 220)
		
		# Position BEHIND the player (opposite of dash direction)
		var vfx_position: Vector2 = player_body.global_position
		vfx_position.y += offset_y + 10.0  # Move down slightly
		# Offset in opposite direction: if dashing right (+1), VFX goes left (negative offset)
		# Distance behind player (adjust this value as needed)
		var behind_offset: float = -130.0  # Distance behind player in pixels
		vfx_position.x += offset_x + (facing_direction * behind_offset)
		
		vfx.global_position = vfx_position
		
		# Set facing direction (VFX flips horizontally)
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", facing_direction)
			if debug_logs:
				pass
	else:
		vfx.queue_free()
		push_warning("[AirDashVFX] Could not find world parent to spawn VFX")
