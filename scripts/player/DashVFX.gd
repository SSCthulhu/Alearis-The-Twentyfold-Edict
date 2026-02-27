extends Node
class_name DashVFX
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

## Spawns directional dash VFX when the player dashes
## VFX flips horizontally based on dash direction
## Continuously spawns VFX while player is sprinting

@export var player_controller_path: NodePath = ^".."
@export var dash_vfx_scene: PackedScene

# VFX positioning
@export var offset_x: float = 0.0
@export var offset_y: float = 0.0

# Anti-spam
@export var cooldown: float = 0.2
@export var sprint_vfx_interval: float = 0.15  # How often to spawn VFX while sprinting
@export var debug_logs: bool = false

var _player_controller: Node = null
var _cooldown_left: float = 0.0
var _sprint_vfx_timer: float = 0.0

func _ready() -> void:
	if debug_logs:
		pass
		pass
	
	_player_controller = get_node_or_null(player_controller_path)
	
	if dash_vfx_scene == null:
		push_warning("[DashVFX] dash_vfx_scene not assigned.")
		return
	
	if _player_controller == null:
		push_warning("[DashVFX] PlayerController not found at: %s" % String(player_controller_path))
		return
	
	if debug_logs:
		pass
	
	# Connect to the dash_started signal
	if _player_controller.has_signal("dash_started"):
		if not _player_controller.dash_started.is_connected(_on_dash_started):
			_player_controller.dash_started.connect(_on_dash_started)
			pass
	else:
		push_warning("[DashVFX] PlayerController missing signal: dash_started")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	
	# Check if player is sprinting and spawn VFX periodically
	if _player_controller != null and _player_controller.has_method("get_current_state"):
		var current_state = _player_controller.get_current_state()
		# Check if in SPRINT state (STATE.SPRINT = 2)
		var is_sprinting: bool = (current_state == 2)  # SPRINT state
		
		if is_sprinting:
			_sprint_vfx_timer -= delta
			if _sprint_vfx_timer <= 0.0:
				_sprint_vfx_timer = sprint_vfx_interval
				# Get player's facing direction
				var facing: int = 1
				if _player_controller.has_method("get_facing_direction"):
					facing = _player_controller.get_facing_direction()
				if debug_logs:
					pass
				_spawn_dash_vfx(facing)
		else:
			# Reset timer when not sprinting
			_sprint_vfx_timer = 0.0

func _on_dash_started(facing_direction: int, is_airborne: bool) -> void:
	if debug_logs:
		pass
	
	# Only spawn for GROUND dashes (not air dashes)
	if is_airborne:
		if debug_logs:
			pass
		return
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_dash_vfx(facing_direction)

func _spawn_dash_vfx(facing_direction: int) -> void:
	if dash_vfx_scene == null:
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
	var vfx_node: Node = dash_vfx_scene.instantiate()
	var vfx: Node2D = vfx_node as Node2D
	if vfx == null:
		push_warning("[DashVFX] VFX scene root must be a Node2D.")
		vfx_node.queue_free()
		return
	
	# Add to world (same parent as player, so it's in world space)
	var world_parent: Node = player_body.get_parent()
	if world_parent != null:
		world_parent.add_child(vfx)
		VfxRenderUtil.promote(vfx, 220)
		
		# Position at player center
		var vfx_position: Vector2 = player_body.global_position
		vfx_position.y += offset_y
		vfx_position.x += offset_x
		
		vfx.global_position = vfx_position
		
		# Set facing direction (VFX flips horizontally)
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", facing_direction)
			if debug_logs:
				pass
	else:
		vfx.queue_free()
		push_warning("[DashVFX] Could not find world parent to spawn VFX")
