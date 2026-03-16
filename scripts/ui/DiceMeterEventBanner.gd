extends Control
class_name DiceMeterEventBanner

@export var display_seconds: float = 2.2
@export var fade_in_seconds: float = 0.08
@export var fade_out_seconds: float = 0.2
@export var font_size: int = 34
@export var font_override: Font = null
@export var text_color: Color = Color(1.0, 0.95, 0.8, 1.0)
@export var band_danger_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var band_chaos_color: Color = Color(0.86, 0.55, 1.0, 1.0)
@export var band_neutral_color: Color = Color(0.95, 0.95, 0.95, 1.0)
@export var band_positive_color: Color = Color(0.55, 1.0, 0.75, 1.0)
@export var band_strong_color: Color = Color(0.45, 0.9, 1.0, 1.0)
@export var band_miracle_color: Color = Color(1.0, 0.9, 0.3, 1.0)
@export var update_rate_seconds: float = 0.05
@export var backdrop_enabled: bool = true
@export var backdrop_color: Color = Color(0.04, 0.05, 0.07, 0.72)
@export var backdrop_border_color: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var backdrop_padding: Vector2 = Vector2(48.0, 34.0)
@export var backdrop_size_scale: float = 1.2
@export var backdrop_min_size: Vector2 = Vector2(920.0, 220.0)

@onready var _event_label: Label = $EventLabel
var _hide_tween: Tween = null
var _refresh_accum: float = 0.0
var _tracking_effect: bool = false
var _roll_value: int = 0
var _event_name: String = ""
var _summary_text: String = ""

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	if _event_label != null:
		_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_event_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_event_label.add_theme_font_size_override("font_size", font_size)
		_event_label.add_theme_color_override("font_color", text_color)
		if font_override != null:
			_event_label.add_theme_font_override("font", font_override)

	_connect_dice_meter()

func _exit_tree() -> void:
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter != null and dice_meter.has_signal("roll_resolved"):
		if dice_meter.roll_resolved.is_connected(_on_roll_resolved):
			dice_meter.roll_resolved.disconnect(_on_roll_resolved)

func _connect_dice_meter() -> void:
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter == null:
		return
	if dice_meter.has_signal("roll_resolved"):
		if not dice_meter.roll_resolved.is_connected(_on_roll_resolved):
			dice_meter.roll_resolved.connect(_on_roll_resolved)

func _process(delta: float) -> void:
	if not _tracking_effect:
		return
	_refresh_accum += delta
	if _refresh_accum < update_rate_seconds:
		return
	_refresh_accum = 0.0
	_refresh_banner_text()
	queue_redraw()

func _get_dice_meter_singleton() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DiceMeterSingleton")

func _on_roll_resolved(roll_value: int, _event_id: StringName, event_band: int) -> void:
	var event_name: String = "Event"
	var brief_text: String = ""
	var description: String = ""
	var band_color: Color = _get_band_color(event_band)
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter != null and "last_result" in dice_meter:
		var result: Dictionary = dice_meter.last_result
		event_name = String(result.get("display_name", event_name))
		brief_text = String(result.get("brief_text", ""))
		description = String(result.get("description", ""))

	_roll_value = roll_value
	_event_name = event_name
	_summary_text = _build_summary_text(brief_text, description)
	_tracking_effect = true
	if _event_label != null:
		_event_label.add_theme_color_override("font_color", band_color)
		_event_label.self_modulate = band_color

	_show_and_keep_visible()
	_refresh_banner_text()
	queue_redraw()

func _build_summary_text(brief_text: String, description: String) -> String:
	var out: String = brief_text.strip_edges()
	if out == "":
		out = description.strip_edges()
	if out.length() > 120:
		out = out.substr(0, 117) + "..."
	return out

func _show_and_keep_visible() -> void:
	if _hide_tween != null:
		_hide_tween.kill()
		_hide_tween = null
	visible = true
	modulate.a = 0.0
	var show_tween: Tween = create_tween()
	show_tween.tween_property(self, "modulate:a", 1.0, maxf(fade_in_seconds, 0.01))

func _refresh_banner_text() -> void:
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter == null:
		_tracking_effect = false
		_fade_and_hide()
		return
	var time_left: float = 0.0
	if "active_effect_time_left" in dice_meter:
		time_left = float(dice_meter.active_effect_time_left)
	var timer_text: String = ""
	if time_left > 0.0:
		timer_text = "Time Left: %.1fs" % time_left
	elif display_seconds > 0.0:
		timer_text = "Time Left: %.1fs" % 0.0
	if _event_label != null:
		var lines: Array[String] = []
		lines.append("Rolled %d" % _roll_value)
		lines.append(_event_name)
		if _summary_text != "":
			lines.append(_summary_text)
		if timer_text != "":
			lines.append(timer_text)
		_event_label.text = "\n".join(lines)
	if time_left <= 0.0:
		_tracking_effect = false
		_fade_and_hide()

func _fade_and_hide() -> void:
	if _hide_tween != null:
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_interval(maxf(display_seconds, 0.05))
	_hide_tween.tween_property(self, "modulate:a", 0.0, maxf(fade_out_seconds, 0.01))
	_hide_tween.finished.connect(func() -> void:
		visible = false
		_hide_tween = null
		queue_redraw()
	)

func _draw() -> void:
	if not backdrop_enabled:
		return
	if not visible:
		return
	if _event_label == null:
		return
	if _event_label.text.strip_edges() == "":
		return
	var label_size: Vector2 = _measure_label_text_size()
	if label_size.x <= 0.0 or label_size.y <= 0.0:
		label_size = Vector2(360.0, 120.0)
	var box_size: Vector2 = Vector2(
		minf(size.x - 20.0, (label_size.x * backdrop_size_scale) + (backdrop_padding.x * 2.0)),
		(label_size.y * backdrop_size_scale) + (backdrop_padding.y * 2.0)
	)
	box_size.x = maxf(box_size.x, backdrop_min_size.x)
	box_size.y = maxf(box_size.y, backdrop_min_size.y)
	var box_pos: Vector2 = Vector2((size.x - box_size.x) * 0.5, (size.y - box_size.y) * 0.5)
	var r: Rect2 = Rect2(box_pos, box_size)
	draw_rect(r, backdrop_color, true)
	draw_rect(r, backdrop_border_color, false, 2.0)

func _measure_label_text_size() -> Vector2:
	if _event_label == null:
		return Vector2.ZERO
	var txt: String = _event_label.text
	if txt.strip_edges() == "":
		return Vector2.ZERO
	var font: Font = _event_label.get_theme_font("font")
	if font == null:
		return Vector2(420.0, 140.0)
	var text_font_size: int = _event_label.get_theme_font_size("font_size")
	if text_font_size <= 0:
		text_font_size = font_size
	var lines: PackedStringArray = txt.split("\n")
	var max_width: float = 0.0
	for line: String in lines:
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, text_font_size).x
		max_width = maxf(max_width, w)
	var line_count: int = maxi(lines.size(), 1)
	var height: float = (font.get_height(text_font_size) * float(line_count)) + (6.0 * float(maxi(line_count - 1, 0)))
	return Vector2(max_width, height)

func _get_band_color(band: int) -> Color:
	match band:
		0:
			return band_danger_color
		1:
			return band_chaos_color
		2:
			return band_neutral_color
		3:
			return band_positive_color
		4:
			return band_strong_color
		5:
			return band_miracle_color
		_:
			return text_color
