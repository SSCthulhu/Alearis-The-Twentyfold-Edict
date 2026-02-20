extends Node2D
class_name PhraseDisplay

# Displays boss phrase above the boss during portal phase

@export var label_path: NodePath = ^"Label"
@export var fade_duration: float = 0.5
@export var stay_duration: float = 999.0  # Stay visible until hide_phrase() is called
@export var y_offset: float = -100.0  # How far above the PhraseDisplay node to show the text

var _label: Label = null
var _canvas_layer: CanvasLayer = null
var _visible_phrase: bool = false
var _camera: Camera2D = null

func _ready() -> void:
	# Find the player camera to convert world position to screen position
	await get_tree().process_frame  # Wait for scene to be ready
	_camera = get_viewport().get_camera_2d()
	
	if _camera == null:
		push_error("[PhraseDisplay] No Camera2D found in viewport!")
		return
	
	# Create a CanvasLayer to hold the label (so it renders in screen space)
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100  # Render on top
	add_child(_canvas_layer)
	
	_label = get_node_or_null(label_path)
	
	if _label == null:
		# Create label if not found
		_label = Label.new()
		_canvas_layer.add_child(_label)
		
		# Configure label - NO anchors, we'll position it manually
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size = Vector2(800, 100)  # Fixed size for the label
		_label.position = Vector2(0, 0)  # Will be updated in _process()
		
		# Style
		_label.add_theme_font_size_override("font_size", 48)
		_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_label.add_theme_constant_override("outline_size", 6)
	
	_label.modulate.a = 0.0
	_label.visible = false
	
	# Start with physics process disabled (will enable when showing phrase)
	set_physics_process(false)

func show_phrase(phrase: String) -> void:
	if _label == null or _camera == null:
		push_warning("[PhraseDisplay] Cannot show phrase - label or camera is null")
		return
	
	_label.text = phrase
	_label.visible = true
	_visible_phrase = true
	
	# Enable physics processing to update label position every frame
	set_physics_process(true)
	process_mode = Node.PROCESS_MODE_INHERIT
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, fade_duration)

func _physics_process(_delta: float) -> void:
	# Only update position if phrase is visible
	if not _visible_phrase or _label == null or _camera == null:
		return
	
	# Convert world position (with offset) to screen position
	var world_pos = global_position + Vector2(0, y_offset)
	var viewport_rect = get_viewport_rect()
	var screen_center = viewport_rect.size / 2.0
	
	# Calculate screen position accounting for camera position and zoom
	var camera_pos = _camera.get_screen_center_position()
	var offset_from_camera = (world_pos - camera_pos) * _camera.zoom
	var screen_pos = screen_center + offset_from_camera
	
	# Center the label on the target screen point
	_label.position = screen_pos - _label.size / 2.0

func hide_phrase() -> void:
	if _label == null or not _visible_phrase:
		return
	
	_visible_phrase = false
	set_physics_process(false)  # Stop updating position
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(_label, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func():
		_label.visible = false
	)
