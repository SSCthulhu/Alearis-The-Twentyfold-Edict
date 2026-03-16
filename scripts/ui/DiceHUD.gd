extends PanelContainer
class_name DiceHUD

# -----------------------------
# Anchoring / sizing
# -----------------------------
@export var safe_margin_px: int = 20
@export var panel_width_px: int = 300
@export var use_fixed_width: bool = true

# -----------------------------
# Padding / layout
# -----------------------------
@export var padding_h_px: int = 18
@export var padding_v_px: int = 12
@export var vbox_spacing_px: int = 8

# -----------------------------
# Typography
# -----------------------------
@export var header_text: String = "DICE RANGE"
@export var header_font_size: int = 16
@export var value_font_size: int = 28
@export var sub_font_size: int = 14

@export var header_letter_spacing: int = 1
@export var value_letter_spacing: int = 0
@export var sub_letter_spacing: int = 0

@export var font_override: Font = null

# -----------------------------
# Colors (match your HUD language)
# -----------------------------
@export var panel_color: Color = Color(0.05, 0.06, 0.08, 0.65)
@export var header_text_color: Color = Color(0.92, 0.93, 0.95, 0.95)
@export var value_text_color: Color = Color(0.95, 0.96, 0.98, 1.0)
@export var sub_text_color: Color = Color(0.85, 0.86, 0.90, 0.90)

# Gold accent (optional usage)
@export var use_gold_on_max_20: bool = true
@export var gold_color: Color = Color(0.95, 0.78, 0.20, 1.0)
@export var meter_ready_glow_enabled: bool = true
@export var meter_ready_panel_color: Color = Color(0.16, 0.12, 0.03, 0.84)
@export var meter_ready_border_color: Color = Color(1.0, 0.84, 0.18, 0.95)
@export var meter_ready_border_width: int = 2
@export var meter_ready_pulse_min: float = 0.92
@export var meter_ready_pulse_max: float = 1.08
@export var meter_ready_pulse_speed: float = 1.1

@export var corner_radius_px: int = 16

# -----------------------------
# Dividers
# -----------------------------
@export var show_dividers: bool = true
@export var divider_color: Color = Color(1, 1, 1, 0.12)
@export var divider_thickness: int = 1
@export var divider_margin_top_px: int = 4
@export var divider_margin_bottom_px: int = 4

# -----------------------------
# Content behavior
# -----------------------------
@export var show_last_roll: bool = false
@export var show_meter_status: bool = true
@export var meter_ready_text: String = "Dice Meter: READY"
@export var show_alignment_hint: bool = true
@export var alignment_hint_text: String = "MIN - BALANCE - MAX"

# Optional: if you want to reuse your existing DiceLabel (will be repurposed as VALUE)
@export var label_path: NodePath = ^"VBoxContainer/DiceLabel"

# -----------------------------
# State
# -----------------------------
var _min_value: int = 1
var _max_value: int = 20
var _last_roll: int = 0
var _meter_charge: float = 0.0
var _meter_max: float = 100.0
var _meter_ready: bool = false

# -----------------------------
# Node refs
# -----------------------------
var _vbox: VBoxContainer = null
var _header_label: Label = null
var _value_label: Label = null
var _sub_label: Label = null
var _alignment_label: Label = null
var _sep_top: HSeparator = null
var _pulse_t: float = 0.0
var _ready_glow_active: bool = false


func _ready() -> void:
	_ensure_nodes()
	_apply_anchor_top_left()
	_apply_panel_style()
	_apply_typography()
	_apply_layout_metrics()
	_apply_divider_style()
	set_process(true)

	# Initial draw (defensive if singleton not ready in editor)
	if Engine.is_editor_hint():
		_update_text(_min_value, _max_value, _last_roll)
	else:
		_update_text(RunStateSingleton.dice_min, RunStateSingleton.dice_max, RunStateSingleton.last_roll)

		if not RunStateSingleton.dice_changed.is_connected(_on_dice_changed):
			RunStateSingleton.dice_changed.connect(_on_dice_changed)
		_connect_meter_signals()
		_pull_meter_snapshot()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		if RunStateSingleton != null and RunStateSingleton.dice_changed.is_connected(_on_dice_changed):
			RunStateSingleton.dice_changed.disconnect(_on_dice_changed)
		_disconnect_meter_signals()

func _process(delta: float) -> void:
	if meter_ready_glow_enabled and _ready_glow_active:
		_pulse_t += delta * meter_ready_pulse_speed
		var wave: float = 0.5 + (0.5 * sin(_pulse_t * TAU))
		var s: float = lerpf(meter_ready_pulse_min, meter_ready_pulse_max, wave)
		scale = Vector2(s, s)


func _on_dice_changed(min_value: int, max_value: int, current_roll: int) -> void:
	_update_text(min_value, max_value, current_roll)

func _on_meter_charge_changed(current_charge: float, max_charge: float) -> void:
	_meter_charge = current_charge
	_meter_max = maxf(max_charge, 1.0)
	_meter_ready = _meter_charge >= _meter_max
	_set_ready_visual_state(_meter_ready)
	_update_text(_min_value, _max_value, _last_roll)

func _on_meter_filled() -> void:
	_meter_ready = true
	_set_ready_visual_state(true)
	_update_text(_min_value, _max_value, _last_roll)

func _on_meter_roll_resolved(roll_value: int, _event_id: StringName, _band: int) -> void:
	_meter_ready = false
	_last_roll = roll_value
	_set_ready_visual_state(false)
	_update_text(_min_value, _max_value, _last_roll)


# -----------------------------
# Node setup
# -----------------------------
func _ensure_nodes() -> void:
	_vbox = get_node_or_null("VBoxContainer") as VBoxContainer
	if _vbox == null:
		_vbox = VBoxContainer.new()
		_vbox.name = "VBoxContainer"
		add_child(_vbox)

	# Header
	_header_label = _vbox.get_node_or_null("HeaderLabel") as Label
	if _header_label == null:
		_header_label = Label.new()
		_header_label.name = "HeaderLabel"
		_vbox.add_child(_header_label)

	# Divider
	_sep_top = _vbox.get_node_or_null("SepTop") as HSeparator
	if _sep_top == null:
		_sep_top = HSeparator.new()
		_sep_top.name = "SepTop"
		_vbox.add_child(_sep_top)

	# Value label: try to reuse existing DiceLabel if provided
	_value_label = get_node_or_null(label_path) as Label
	if _value_label == null:
		_value_label = _vbox.get_node_or_null("ValueLabel") as Label
	if _value_label == null:
		_value_label = Label.new()
		_value_label.name = "ValueLabel"
		_vbox.add_child(_value_label)
		
	# Sub label (optional last roll)
	_sub_label = _vbox.get_node_or_null("SubLabel") as Label
	if _sub_label == null:
		_sub_label = Label.new()
		_sub_label.name = "SubLabel"
		_vbox.add_child(_sub_label)
	_alignment_label = _vbox.get_node_or_null("AlignmentLabel") as Label
	if _alignment_label == null:
		_alignment_label = Label.new()
		_alignment_label.name = "AlignmentLabel"
		_vbox.add_child(_alignment_label)
		
	# Force the exact visual order in the VBox:
	# Header -> Divider -> Value -> Sub
	if _header_label != null:
		_vbox.move_child(_header_label, 0)

	if _sep_top != null:
		_vbox.move_child(_sep_top, 1)

	if _value_label != null:
		_vbox.move_child(_value_label, 2)

	if _sub_label != null:
		_vbox.move_child(_sub_label, 4)
	if _alignment_label != null:
		_vbox.move_child(_alignment_label, 3)

	# Alignment
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# -----------------------------
# Layout / anchoring
# -----------------------------
func _apply_anchor_top_left() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT, true)

	offset_left = safe_margin_px
	offset_top = safe_margin_px

	if use_fixed_width:
		custom_minimum_size.x = panel_width_px
	else:
		custom_minimum_size.x = 0


func _apply_layout_metrics() -> void:
	if _vbox != null:
		_vbox.add_theme_constant_override("separation", vbox_spacing_px)


# -----------------------------
# Style
# -----------------------------
func _apply_panel_style() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = panel_color

	sb.corner_radius_top_left = corner_radius_px
	sb.corner_radius_top_right = corner_radius_px
	sb.corner_radius_bottom_left = corner_radius_px
	sb.corner_radius_bottom_right = corner_radius_px

	sb.border_width_top = 0
	sb.border_width_bottom = 0
	sb.border_width_left = 0
	sb.border_width_right = 0

	sb.content_margin_left = padding_h_px
	sb.content_margin_right = padding_h_px
	sb.content_margin_top = padding_v_px
	sb.content_margin_bottom = padding_v_px

	add_theme_stylebox_override("panel", sb)


func _apply_typography() -> void:
	if _header_label == null or _value_label == null or _sub_label == null:
		return

	if font_override != null:
		_header_label.add_theme_font_override("font", font_override)
		_value_label.add_theme_font_override("font", font_override)
		_sub_label.add_theme_font_override("font", font_override)

	_header_label.add_theme_font_size_override("font_size", header_font_size)
	_value_label.add_theme_font_size_override("font_size", value_font_size)
	_sub_label.add_theme_font_size_override("font_size", sub_font_size)

	_header_label.add_theme_color_override("font_color", header_text_color)
	_value_label.add_theme_color_override("font_color", value_text_color)
	_sub_label.add_theme_color_override("font_color", sub_text_color)
	if _alignment_label != null:
		_alignment_label.add_theme_font_size_override("font_size", sub_font_size)
		_alignment_label.add_theme_color_override("font_color", sub_text_color)

	_header_label.add_theme_constant_override("spacing_char", header_letter_spacing)
	_value_label.add_theme_constant_override("spacing_char", value_letter_spacing)
	_sub_label.add_theme_constant_override("spacing_char", sub_letter_spacing)

	_header_label.text = header_text


func _apply_divider_style() -> void:
	if _sep_top == null:
		return

	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = divider_color
	line.thickness = divider_thickness
	line.vertical = false

	_sep_top.add_theme_stylebox_override("separator", line)
	_sep_top.visible = show_dividers

	var h: int = divider_margin_top_px + divider_thickness + divider_margin_bottom_px
	_sep_top.custom_minimum_size.y = h


# -----------------------------
# Text update
# -----------------------------
func _update_text(min_value: int, max_value: int, current_roll: int) -> void:
	_min_value = min_value
	_max_value = max_value
	_last_roll = current_roll

	if _header_label != null:
		_header_label.text = header_text

	if _value_label != null:
		var midpoint: float = (float(_min_value) + float(_max_value)) * 0.5
		_value_label.text = "%d - %s - %d" % [_min_value, _format_midpoint(midpoint), _max_value]

		# Optional: gold highlight when the range includes 20 (your “important/ready” gold language)
		if use_gold_on_max_20 and _max_value >= 20:
			_value_label.add_theme_color_override("font_color", gold_color)
		else:
			_value_label.add_theme_color_override("font_color", value_text_color)

	if _sub_label != null:
		_sub_label.visible = show_last_roll or show_meter_status
		var meter_text: String = ""
		if show_meter_status:
			if _meter_ready:
				meter_text = meter_ready_text
			else:
				var pct: int = int(round((_meter_charge / maxf(_meter_max, 1.0)) * 100.0))
				meter_text = "Dice Meter: %d%%" % clampi(pct, 0, 100)
		var roll_text: String = ""
		if show_last_roll and _last_roll > 0:
			roll_text = "Last Roll: %d" % _last_roll
		if meter_text != "" and roll_text != "":
			_sub_label.text = "%s | %s" % [meter_text, roll_text]
		elif meter_text != "":
			_sub_label.text = meter_text
		else:
			_sub_label.text = roll_text
	if _alignment_label != null:
		_alignment_label.visible = show_alignment_hint
		if show_alignment_hint:
			_alignment_label.text = alignment_hint_text

func _format_midpoint(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	var lo: int = int(floor(value))
	var hi: int = int(ceil(value))
	if lo != hi:
		return "%d/%d" % [lo, hi]
	return "%.1f" % value

func _get_dice_meter_singleton() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DiceMeterSingleton")

func _connect_meter_signals() -> void:
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter == null:
		return
	if dice_meter.has_signal("charge_changed"):
		if not dice_meter.charge_changed.is_connected(_on_meter_charge_changed):
			dice_meter.charge_changed.connect(_on_meter_charge_changed)
	if dice_meter.has_signal("meter_filled"):
		if not dice_meter.meter_filled.is_connected(_on_meter_filled):
			dice_meter.meter_filled.connect(_on_meter_filled)
	if dice_meter.has_signal("roll_resolved"):
		if not dice_meter.roll_resolved.is_connected(_on_meter_roll_resolved):
			dice_meter.roll_resolved.connect(_on_meter_roll_resolved)

func _disconnect_meter_signals() -> void:
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter == null:
		return
	if dice_meter.has_signal("charge_changed"):
		if dice_meter.charge_changed.is_connected(_on_meter_charge_changed):
			dice_meter.charge_changed.disconnect(_on_meter_charge_changed)
	if dice_meter.has_signal("meter_filled"):
		if dice_meter.meter_filled.is_connected(_on_meter_filled):
			dice_meter.meter_filled.disconnect(_on_meter_filled)
	if dice_meter.has_signal("roll_resolved"):
		if dice_meter.roll_resolved.is_connected(_on_meter_roll_resolved):
			dice_meter.roll_resolved.disconnect(_on_meter_roll_resolved)

func _pull_meter_snapshot() -> void:
	var dice_meter: Node = _get_dice_meter_singleton()
	if dice_meter == null:
		return
	if "current_charge" in dice_meter:
		_meter_charge = float(dice_meter.current_charge)
	if "max_charge" in dice_meter:
		_meter_max = maxf(float(dice_meter.max_charge), 1.0)
	_meter_ready = _meter_charge >= _meter_max
	_set_ready_visual_state(_meter_ready)
	_update_text(_min_value, _max_value, _last_roll)

func _set_ready_visual_state(is_meter_ready: bool) -> void:
	if not meter_ready_glow_enabled:
		return
	_ready_glow_active = is_meter_ready
	if not is_meter_ready:
		scale = Vector2.ONE
		_apply_panel_style()
		return
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = meter_ready_panel_color
	sb.corner_radius_top_left = corner_radius_px
	sb.corner_radius_top_right = corner_radius_px
	sb.corner_radius_bottom_left = corner_radius_px
	sb.corner_radius_bottom_right = corner_radius_px
	sb.border_width_top = meter_ready_border_width
	sb.border_width_bottom = meter_ready_border_width
	sb.border_width_left = meter_ready_border_width
	sb.border_width_right = meter_ready_border_width
	sb.border_color = meter_ready_border_color
	sb.content_margin_left = padding_h_px
	sb.content_margin_right = padding_h_px
	sb.content_margin_top = padding_v_px
	sb.content_margin_bottom = padding_v_px
	add_theme_stylebox_override("panel", sb)
