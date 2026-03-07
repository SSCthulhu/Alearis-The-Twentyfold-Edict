extends Node2D
class_name PhraseDisplay

# Displays boss phrase above the boss during portal phase

@export var label_path: NodePath = ^"Label"
@export var fade_duration: float = 0.5
@export var stay_duration: float = 999.0  # Stay visible until hide_phrase() is called
@export var y_offset: float = -100.0  # How far above the PhraseDisplay node to show the text
@export var debug_logs: bool = false
@export var screen_margin: float = 24.0
@export var fallback_screen_y_ratio: float = 0.22

var _label: Label = null
var _canvas_layer: CanvasLayer = null
var _visible_phrase: bool = false
var _camera: Camera2D = null
var _pending_phrase: String = ""

func _ready() -> void:
	# Find camera after scene settles.
	await get_tree().process_frame  # Wait for scene to be ready
	var ready_now: bool = _ensure_runtime_ready()
	if debug_logs:
		print("[PhraseDisplay] _ready runtime_ready=", ready_now)
	if _pending_phrase != "":
		var phrase_to_show: String = _pending_phrase
		_pending_phrase = ""
		show_phrase(phrase_to_show)

	# Start with physics process disabled (enabled only while phrase visible)
	set_physics_process(false)
	set_process(false)

func show_phrase(phrase: String) -> void:
	if debug_logs:
		print("[PhraseDisplay] show_phrase request='", phrase, "'")
	_pending_phrase = phrase
	if not _ensure_runtime_ready():
		# Retry automatically until camera/label become available.
		if debug_logs:
			print("[PhraseDisplay] Runtime not ready. Queued pending phrase.")
		set_process(true)
		return
	_pending_phrase = ""
	
	_label.text = phrase
	_label.visible = true
	_visible_phrase = true
	
	# Enable physics processing to update label position every frame
	set_physics_process(true)
	process_mode = Node.PROCESS_MODE_INHERIT
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, fade_duration)
	if debug_logs:
		print("[PhraseDisplay] Phrase visible + fade in started.")

func _process(_delta: float) -> void:
	if _pending_phrase == "":
		set_process(false)
		return
	if not _ensure_runtime_ready():
		return
	var phrase_to_show: String = _pending_phrase
	_pending_phrase = ""
	show_phrase(phrase_to_show)
	set_process(false)

func _physics_process(_delta: float) -> void:
	# Only update position if phrase is visible
	if not _visible_phrase or _label == null or _camera == null:
		return
	
	# Convert world position (with offset) to screen position using canvas transform.
	# This is more reliable than manual camera math across zoom/smoothing modes.
	var world_pos = global_position + Vector2(0, y_offset)
	var viewport_rect = get_viewport_rect()
	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	var screen_pos: Vector2 = canvas_xform * world_pos

	# Fallback if conversion yields off-screen/invalid values.
	var bad_x: bool = is_nan(screen_pos.x) or is_inf(screen_pos.x)
	var bad_y: bool = is_nan(screen_pos.y) or is_inf(screen_pos.y)
	if bad_x or bad_y:
		screen_pos = Vector2(viewport_rect.size.x * 0.5, viewport_rect.size.y * fallback_screen_y_ratio)
	elif screen_pos.x < -2000.0 or screen_pos.x > viewport_rect.size.x + 2000.0 or screen_pos.y < -2000.0 or screen_pos.y > viewport_rect.size.y + 2000.0:
		screen_pos = Vector2(viewport_rect.size.x * 0.5, viewport_rect.size.y * fallback_screen_y_ratio)

	# Keep phrase within visible region.
	var half: Vector2 = _label.size * 0.5
	var min_x: float = screen_margin + half.x
	var max_x: float = viewport_rect.size.x - screen_margin - half.x
	var min_y: float = screen_margin + half.y
	var max_y: float = viewport_rect.size.y - screen_margin - half.y
	screen_pos.x = clampf(screen_pos.x, min_x, max_x)
	screen_pos.y = clampf(screen_pos.y, min_y, max_y)
	
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
	if debug_logs:
		print("[PhraseDisplay] hide_phrase called.")

func _ensure_runtime_ready() -> bool:
	if _camera == null:
		_camera = get_viewport().get_camera_2d()
	if _camera == null:
		if debug_logs:
			print("[PhraseDisplay] No camera yet.")
		return false

	if _canvas_layer == null:
		_canvas_layer = CanvasLayer.new()
		_canvas_layer.layer = 100
		add_child(_canvas_layer)

	if _label == null:
		_label = get_node_or_null(label_path)
		if _label == null:
			_label = Label.new()
		if _label.get_parent() != _canvas_layer:
			if _label.get_parent() != null:
				_label.reparent(_canvas_layer)
			else:
				_canvas_layer.add_child(_label)

		# Configure label - no anchors, screen-space positioned.
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size = Vector2(800, 100)
		_label.position = Vector2.ZERO
		_label.add_theme_font_size_override("font_size", 48)
		_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_label.add_theme_constant_override("outline_size", 6)
		_label.modulate.a = 0.0
		_label.visible = false

	return _label != null and _camera != null
