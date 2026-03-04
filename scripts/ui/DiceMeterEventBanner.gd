extends Control
class_name DiceMeterEventBanner

@export var display_seconds: float = 2.2
@export var fade_in_seconds: float = 0.08
@export var fade_out_seconds: float = 0.2
@export var font_size: int = 50
@export var font_override: Font = null
@export var text_color: Color = Color(1.0, 0.95, 0.8, 1.0)
@export var band_danger_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var band_chaos_color: Color = Color(0.86, 0.55, 1.0, 1.0)
@export var band_neutral_color: Color = Color(0.95, 0.95, 0.95, 1.0)
@export var band_positive_color: Color = Color(0.55, 1.0, 0.75, 1.0)
@export var band_strong_color: Color = Color(0.45, 0.9, 1.0, 1.0)
@export var band_miracle_color: Color = Color(1.0, 0.9, 0.3, 1.0)

@onready var _event_label: Label = $EventLabel
var _hide_tween: Tween = null

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _get_dice_meter_singleton() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DiceMeterSingleton")

func _on_roll_resolved(roll_value: int, _event_id: StringName, _band: int) -> void:
	var event_name: String = "Event"
	var band_color: Color = _get_band_color(_band)
	if _event_label != null:
		_event_label.add_theme_color_override("font_color", band_color)
		_event_label.self_modulate = band_color
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter != null and "last_result" in dice_meter:
		var result: Dictionary = dice_meter.last_result
		event_name = String(result.get("display_name", event_name))

	if _event_label != null:
		_event_label.text = "Rolled %d\n%s" % [roll_value, event_name]

	_show_and_schedule_hide()

func _show_and_schedule_hide() -> void:
	if _hide_tween != null:
		_hide_tween.kill()
	visible = true
	modulate.a = 0.0
	_hide_tween = create_tween()
	_hide_tween.tween_property(self, "modulate:a", 1.0, maxf(fade_in_seconds, 0.01))
	_hide_tween.tween_interval(maxf(display_seconds, 0.05))
	_hide_tween.tween_property(self, "modulate:a", 0.0, maxf(fade_out_seconds, 0.01))
	_hide_tween.finished.connect(func() -> void:
		visible = false
	)

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
