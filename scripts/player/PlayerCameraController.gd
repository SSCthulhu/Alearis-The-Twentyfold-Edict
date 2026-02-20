extends Node
class_name PlayerCameraController

@export var camera_path: NodePath = ^"../Camera2D"
@export var ceiling_group: StringName = &"ceiling_gate"

@export var vertical_padding: float = 0.0
@export var smooth_limit_transition: bool = true
@export var limit_lerp_speed: float = 10.0

# Floor-based camera limits
@export_group("Progressive Camera Limits")
@export var enable_progressive_limits: bool = true
@export var floor_progression_path: NodePath = ^"../../FloorProgressionController"
@export var start_at_floor_1_only: bool = true  # Restrict camera to Floor 1 initially
@export var expand_on_player_enters_floor: bool = true  # Expand camera when player enters floor (not just when unlocked)

# Auto-zoom to keep viewport within limits
@export_group("Auto Zoom")
@export var enable_auto_zoom: bool = false  # Automatically zoom out if viewport would exceed limits
@export var base_zoom: float = 1.0  # Default zoom level (1.0 = 100%)
@export var min_zoom: float = 0.5  # Minimum zoom (0.5 = 50%, zoomed out)
@export var max_zoom: float = 1.0  # Maximum zoom (1.0 = 100%, normal)
@export var zoom_lerp_speed: float = 2.0  # How fast to adjust zoom

var _camera: Camera2D
var _current_limit_top: float
var _target_limit_top: float

var _floor_progression: FloorProgressionController = null
var _initial_limit_top: float = 0.0  # Store the world's full camera limit
var _viewport_height: float = 0.0  # Store viewport height for limit calculations
var _pending_floor_expansion: int = -1  # Track which floor expansion is pending
var _target_zoom: float = 1.0  # Target zoom level for auto-zoom
var _current_zoom: float = 1.0  # Current zoom level
var _last_logged_zoom_state: String = ""  # Track what we last logged to prevent spam

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	if _camera == null:
		push_error("[CameraController] Camera2D not found")
		return

	# Get viewport height for camera limit calculations
	_viewport_height = get_viewport().get_visible_rect().size.y
	pass
	
	_initial_limit_top = _camera.limit_top
	_current_limit_top = _camera.limit_top
	_target_limit_top = _camera.limit_top
	
	# Initialize zoom
	_current_zoom = base_zoom
	_target_zoom = base_zoom
	_camera.zoom = Vector2(_current_zoom, _current_zoom)
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Setup progressive camera limits if enabled
	if enable_progressive_limits:
		_setup_progressive_limits()

func _process(delta: float) -> void:
	# Handle smooth limit transitions
	if smooth_limit_transition and _current_limit_top != _target_limit_top:
		_current_limit_top = lerpf(
			_current_limit_top,
			_target_limit_top,
			delta * limit_lerp_speed
		)
		_camera.limit_top = int(_current_limit_top)
	
	# Handle auto-zoom to keep viewport within limits
	if enable_auto_zoom:
		_update_auto_zoom()
		
		# Smooth zoom transition
		if _current_zoom != _target_zoom:
			_current_zoom = lerpf(
				_current_zoom,
				_target_zoom,
				delta * zoom_lerp_speed
			)
			_camera.zoom = Vector2(_current_zoom, _current_zoom)

func set_ceiling_from_gate(ceiling_gate: StaticBody2D) -> void:
	var collision := ceiling_gate.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		push_error("[CameraController] CeilingGate missing CollisionShape2D")
		return

	var shape := collision.shape
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		var ceiling_top_y: float = ceiling_gate.global_position.y - rect.extents.y
		_apply_limit(ceiling_top_y - vertical_padding)
	else:
		push_error("[CameraController] Unsupported ceiling collision shape")

func _apply_limit(world_y: float) -> void:
	if smooth_limit_transition:
		_target_limit_top = world_y
	else:
		_current_limit_top = world_y
		_target_limit_top = world_y
		_camera.limit_top = int(world_y)

# -----------------------------
# Public API
# -----------------------------

func expand_to_full_view() -> void:
	"""Force camera to expand to full world view (for boss area or manual override)"""
	pass
	_current_limit_top = _initial_limit_top
	_target_limit_top = _initial_limit_top
	_camera.limit_top = int(_initial_limit_top)
	_pending_floor_expansion = -1  # Clear any pending expansions

func _on_viewport_size_changed() -> void:
	"""Called when viewport/window is resized"""
	_viewport_height = get_viewport().get_visible_rect().size.y
	pass

func _update_auto_zoom() -> void:
	"""Calculate and set target zoom to keep viewport within camera limits"""
	if _camera == null:
		return
	
	# Get camera's current position and the limit
	var camera_y: float = _camera.global_position.y
	var limit_top: float = _camera.limit_top
	
	# In Godot, Y increases downward, limit_top prevents camera from going too high (small Y)
	# Camera center must be >= limit_top (cannot go above/smaller than limit)
	
	# Calculate how much viewport would extend above camera center at BASE zoom
	var viewport_half_height: float = (_viewport_height / 2.0) / base_zoom
	var viewport_top_edge: float = camera_y - viewport_half_height
	
	# Check if viewport TOP EDGE would go above (be less than) the limit
	if viewport_top_edge < limit_top:
		# Viewport exceeds limit - need to zoom out
		# Calculate space between camera center and limit
		var space_below_limit: float = camera_y - limit_top
		
		# If camera center is already at/above limit, need maximum zoom out
		if space_below_limit <= 0:
			_target_zoom = min_zoom
			var log_key := "at_limit_%.1f" % camera_y
			if _last_logged_zoom_state != log_key:
				pass
				_last_logged_zoom_state = log_key
		else:
			# Calculate required zoom: viewport_half_height_at_zoom <= space_below_limit
			# (viewport_height / 2) / zoom <= space_below_limit
			# zoom >= (viewport_height / 2) / space_below_limit
			var required_zoom: float = (_viewport_height / 2.0) / space_below_limit
			
			# Clamp to min/max zoom and add buffer for smooth operation
			_target_zoom = clampf(required_zoom * 1.05, min_zoom, max_zoom)
			
			var log_key := "exceeds_%.1f_%.2f" % [viewport_top_edge, _target_zoom]
			if _last_logged_zoom_state != log_key:
				pass
				_last_logged_zoom_state = log_key
	else:
		# Within limits, use base zoom
		_target_zoom = base_zoom
		var log_key := "normal_%.2f" % base_zoom
		if _last_logged_zoom_state != log_key:
			if _last_logged_zoom_state != "":  # Only log if we were previously in a different state
				pass
			_last_logged_zoom_state = log_key

# -----------------------------
# Progressive Camera Limits
# -----------------------------

func _setup_progressive_limits() -> void:
	"""Connect to FloorProgressionController and set initial camera limit"""
	_floor_progression = get_node_or_null(floor_progression_path) as FloorProgressionController
	
	if _floor_progression == null:
		# This is expected in sub-arenas - don't warn, just disable silently
		# Keep the camera's pre-configured limits from the scene
		if enable_progressive_limits:
			pass
		# Update our internal tracking to match scene's limits
		_initial_limit_top = _camera.limit_top
		_current_limit_top = _camera.limit_top
		_target_limit_top = _camera.limit_top
		return
	
	pass
	
	# Connect to signals
	if not _floor_progression.floor_unlocked.is_connected(_on_floor_unlocked):
		_floor_progression.floor_unlocked.connect(_on_floor_unlocked)
	
	if not _floor_progression.active_floor_changed.is_connected(_on_active_floor_changed):
		_floor_progression.active_floor_changed.connect(_on_active_floor_changed)
	
	# Check current active floor
	var current_floor: int = _floor_progression._current_floor_number
	pass
	
	# If already on Floor 4+ (boss area), expand to full view immediately
	if current_floor >= 4:
		pass
		_current_limit_top = _initial_limit_top
		_target_limit_top = _initial_limit_top
		_camera.limit_top = int(_initial_limit_top)
		return
	
	# Otherwise, set initial limit based on start_at_floor_1_only
	if start_at_floor_1_only:
		var floor_1_ceiling: float = _get_ceiling_y_for_floor(1)
		pass
		
		# Force immediate application (no smooth transition) for initial setup
		_current_limit_top = floor_1_ceiling
		_target_limit_top = floor_1_ceiling
		_camera.limit_top = int(floor_1_ceiling)
		
		pass

func _on_floor_unlocked(floor_number: int) -> void:
	"""Called when a floor is unlocked - mark for expansion when player enters"""
	pass
	
	if not expand_on_player_enters_floor:
		pass
		return
	
	# Store the pending expansion - will apply when player enters the next floor
	var next_floor_num: int = floor_number + 1
	_pending_floor_expansion = next_floor_num
	pass

func _on_active_floor_changed(floor_number: int) -> void:
	"""Called when player enters a new floor - expand camera if pending or if entering boss area"""
	pass
	
	# Special case: Floor 4+ is boss area - always expand to full view
	if floor_number >= 4:
		pass
		expand_to_full_view()
		return
	
	# Check if there's a pending expansion for this floor
	if _pending_floor_expansion == floor_number:
		pass
		
		var next_floor_num: int = floor_number + 1
		var new_limit: float = _get_ceiling_y_for_floor(next_floor_num)
		pass
		
		_apply_limit(new_limit)
		_pending_floor_expansion = -1  # Clear pending expansion
	else:
		pass

func _get_ceiling_y_for_floor(floor_num: int) -> float:
	"""Get the ceiling Y position for a given floor number (works across all worlds)"""
	if _floor_progression == null:
		return _initial_limit_top
	
	# Floor 1 = gate_paths[0], Floor 2 = gate_paths[1], etc.
	var gate_index: int = floor_num - 1
	
	# Access the gates array from FloorProgressionController
	if gate_index < 0 or gate_index >= _floor_progression._gates.size():
		# Beyond defined gates (boss floor) - use world's full limit
		return _initial_limit_top
	
	var gate: Node = _floor_progression._gates[gate_index]
	if gate == null or not is_instance_valid(gate):
		# Gate not found, use world's full limit
		return _initial_limit_top
	
	# Cast to StaticBody2D (CeilingGate)
	var ceiling_gate: StaticBody2D = gate as StaticBody2D
	if ceiling_gate == null:
		return _initial_limit_top
	
	# Read the collision shape to get the ACTUAL ceiling boundary
	var collision: CollisionShape2D = ceiling_gate.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		# No collision shape, fall back to gate position
		var gate_node: Node2D = gate as Node2D
		if gate_node != null:
			return gate_node.global_position.y - vertical_padding
		return _initial_limit_top
	
	var shape = collision.shape
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		
		# Check if collision shape is centered on parent (0, 0) - simplified setup
		var collision_local_pos: Vector2 = collision.position
		var is_simplified_setup: bool = collision_local_pos.length() < 10.0  # Within 10 pixels of (0,0)
		
		var ceiling_top_y: float
		
		if is_simplified_setup:
			# SIMPLIFIED: Gate positioned at ceiling top, collision at (0,0)
			# Just use gate's Y position directly
			ceiling_top_y = ceiling_gate.global_position.y
			pass
		else:
			# COMPLEX: Gate has offset collision shape
			# Calculate the TOP edge from collision center
			var shape_top_y: float = collision.global_position.y - rect.size.y * 0.5
			ceiling_top_y = shape_top_y
			pass
		
		# Account for viewport height: camera CENTER must be positioned so the
		# TOP EDGE of the viewport aligns with the ceiling top edge
		var camera_limit: float = ceiling_top_y + (_viewport_height * 0.5) - vertical_padding
		
		pass
		return camera_limit
	else:
		# Unsupported shape, fall back to gate position + viewport offset
		var camera_limit: float = ceiling_gate.global_position.y + (_viewport_height * 0.5) - vertical_padding
		pass
		return camera_limit
