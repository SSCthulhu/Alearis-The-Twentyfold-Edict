extends Control
class_name DiceMeterActiveEffectHUD

@export var update_rate_seconds: float = 0.05
@export var use_combined_banner_mode: bool = true
@export var danger_color: Color = Color(1.0, 0.40, 0.40, 1.0)
@export var chaos_color: Color = Color(0.85, 0.60, 1.0, 1.0)
@export var neutral_color: Color = Color(0.95, 0.95, 0.95, 1.0)
@export var positive_color: Color = Color(0.65, 1.0, 0.75, 1.0)
@export var strong_color: Color = Color(0.45, 0.9, 1.0, 1.0)
@export var miracle_color: Color = Color(1.0, 0.9, 0.35, 1.0)

@onready var _label: Label = $EffectLabel
var _refresh_accum: float = 0.0
var _suppress_left: float = 0.0
@export var suppress_after_roll_seconds: float = 2.4

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	if _label != null:
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_connect_dice_meter()

func _exit_tree() -> void:
	var meter: Node = _get_dice_meter_singleton()
	if meter != null and meter.has_signal("roll_resolved"):
		if meter.roll_resolved.is_connected(_on_roll_resolved):
			meter.roll_resolved.disconnect(_on_roll_resolved)

func _process(delta: float) -> void:
	if use_combined_banner_mode:
		visible = false
		return
	if _suppress_left > 0.0:
		_suppress_left = maxf(_suppress_left - delta, 0.0)
		visible = false
		return
	_refresh_accum += delta
	if _refresh_accum < update_rate_seconds:
		return
	_refresh_accum = 0.0
	_refresh_from_meter()

func _refresh_from_meter() -> void:
	var meter: Node = _get_dice_meter_singleton()
	if meter == null:
		visible = false
		return
	if not ("active_effect_name" in meter):
		visible = false
		return

	var effect_name: String = String(meter.active_effect_name)
	var brief_text: String = String(meter.active_effect_brief_text)
	var time_left: float = float(meter.active_effect_time_left)
	var band: int = int(meter.active_effect_band)

	if effect_name == "" or time_left <= 0.0:
		visible = false
		return

	if _label != null:
		_label.text = "%s  %.1fs\n%s" % [effect_name, time_left, brief_text]
		var band_color: Color = _get_band_color(band)
		_label.add_theme_color_override("font_color", band_color)
		_label.self_modulate = band_color
	visible = true

func _connect_dice_meter() -> void:
	var meter: Node = _get_dice_meter_singleton()
	if meter == null:
		return
	if meter.has_signal("roll_resolved"):
		if not meter.roll_resolved.is_connected(_on_roll_resolved):
			meter.roll_resolved.connect(_on_roll_resolved)

func _on_roll_resolved(_roll_value: int, _event_id: StringName, _band: int) -> void:
	_suppress_left = maxf(suppress_after_roll_seconds, 0.0)

func _get_dice_meter_singleton() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DiceMeterSingleton")

func _get_band_color(band: int) -> Color:
	match band:
		0:
			return danger_color
		1:
			return chaos_color
		2:
			return neutral_color
		3:
			return positive_color
		4:
			return strong_color
		5:
			return miracle_color
		_:
			return neutral_color
