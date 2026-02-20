extends Control
class_name PlayerUltimateHUD

@export var style: HUDStyle
@export var lerp_speed: float = 10.0

# Top label lane (like ability tiles)
@export var show_label: bool = true
@export var label: String = "ULTIMATE"
@export var label_gap_px: float = 6.0

# NEW: Cooldown timer text (like abilities)
@export var show_time: bool = true
@export var time_left_in_bar: bool = true # if false, you can later draw it elsewhere
@export var time_left_inset_px: float = 6.0

# Optional ready text (usually OFF)
@export var show_ready_text: bool = false
@export var ready_text: String = "" # if empty and show_ready_text=true, uses "READY"

@export var show_ticks: bool = true
@export var tick_count: int = 10

@export var ready_pulse_enabled: bool = true
@export var ready_pulse_speed: float = 1.0
@export_range(0.0, 5.0, 0.01) var ready_pulse_strength: float = 2.0

@export var draw_track: bool = true
@export_range(0.0, 1.0, 0.01) var track_darkening: float = 0.32

@export var min_fill_px: float = 3.0

@export var draw_leading_edge: bool = true
@export var leading_edge_px: float = 2.0
@export_range(0.0, 1.0, 0.01) var leading_edge_alpha: float = 0.65

var _ui_scale: float = 1.0
var _cd_duration: float = 0.0
var _cd_remaining: float = 0.0

var _target: float = 1.0
var _display: float = 1.0

var _is_ready: bool = true
var _t: float = 0.0
var _pulse: float = 0.0

var _sb_border: StyleBoxFlat
var _sb_fill: StyleBoxFlat
var _sb_fill_dim: StyleBoxFlat
var _sb_pulse: StyleBoxFlat
var _sb_dirty: bool = true


func _style_ready() -> bool:
	if style == null:
		return false
	if Engine.is_editor_hint():
		return false
	return true

func _s(px: float) -> float:
	if _style_ready() and style.has_method("s"):
		return float(style.call("s", px, _ui_scale))
	return px * _ui_scale

func _si(px: float) -> int:
	if _style_ready() and style.has_method("si"):
		return int(style.call("si", px, _ui_scale))
	return int(round(px * _ui_scale))

func _font_small() -> int:
	if _style_ready() and style.has_method("font_size_small"):
		return int(style.call("font_size_small", _ui_scale))
	return int(round(12.0 * _ui_scale))

func _font_body() -> int:
	if _style_ready() and style.has_method("font_size_body"):
		return int(style.call("font_size_body", _ui_scale))
	return int(round(14.0 * _ui_scale))

func set_style(v: HUDStyle) -> void:
	style = v
	_sb_dirty = true
	queue_redraw()

func set_ui_scale(v: float) -> void:
	_ui_scale = maxf(v, 0.01)
	_sb_dirty = true
	queue_redraw()

func set_label_text(v: String) -> void:
	label = v
	queue_redraw()

func set_ready(is_ready: bool) -> void:
	_is_ready = is_ready
	if _is_ready:
		_target = 1.0
	queue_redraw()

func set_cooldown(remaining: float, duration: float) -> void:
	_cd_duration = maxf(duration, 0.0)
	_cd_remaining = maxf(remaining, 0.0)

	if _cd_duration <= 0.0:
		_target = 1.0
		_is_ready = true
	else:
		_target = clampf(1.0 - (_cd_remaining / _cd_duration), 0.0, 1.0)
		_is_ready = (_cd_remaining <= 0.001)

	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return

	_t += dt
	_display = lerpf(_display, _target, 1.0 - exp(-lerp_speed * dt))

	if ready_pulse_enabled and _is_ready:
		_pulse = sin(_t * ready_pulse_speed * TAU) * 0.5 + 0.5
	else:
		_pulse = 0.0

	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		return
	if style == null:
		return

	if _sb_dirty:
		_rebuild_styleboxes()

	var border: int = _si(style.border_px)
	var pad_in: float = _s(style.pad_inner)

	var font_small: Font = _pick_font(style.font_small, style.font_body)
	var font_body: Font = _pick_font(style.font_body, style.font_small)
	var small_size: int = _font_small()
	var body_size: int = _font_body()

	var outer: Rect2 = Rect2(Vector2.ZERO, size)
	_sb_border.draw(get_canvas_item(), outer)

	var inner: Rect2 = outer.grow(-float(border) - pad_in)

	# -----------------------------
	# Top label lane
	# -----------------------------
	var label_lane_h: float = 0.0
	if show_label and label != "":
		label_lane_h = float(font_small.get_ascent(small_size) + font_small.get_descent(small_size))
		label_lane_h += _s(4.0)

		var lx: float = inner.position.x + _s(6.0)
		var ly: float = inner.position.y + _s(2.0) + float(font_small.get_ascent(small_size))
		draw_string(font_small, Vector2(lx, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size, style.text_dim)

	# Bar sits below label lane
	var bar: Rect2 = inner
	bar.position.y += label_lane_h + _s(label_gap_px)
	bar.size.y = maxf(0.0, inner.size.y - label_lane_h - _s(label_gap_px))

	if bar.size.x <= 1.0 or bar.size.y <= 1.0:
		return

	# Track/fill capsule
	var inset: float = minf(_s(1.0), (bar.size.y * 0.35))
	var fill_area: Rect2 = bar.grow(-inset)

	if draw_track and fill_area.size.x > 0.0 and fill_area.size.y > 0.0:
		var track_col: Color = style.frame_bg.darkened(track_darkening)
		track_col.a = 1.0
		draw_rect(fill_area, track_col, true)

	var fill_sb: StyleBoxFlat = _sb_fill_dim
	if _is_ready or _target >= 0.999:
		fill_sb = _sb_fill

	var fill_w: float = floor(fill_area.size.x * _display)
	if _display > 0.001:
		fill_w = maxf(fill_w, _s(min_fill_px))
	fill_w = clampf(fill_w, 0.0, fill_area.size.x)

	var fill_rect: Rect2 = Rect2(fill_area.position, Vector2(fill_w, fill_area.size.y))
	if fill_rect.size.x > 0.0 and fill_rect.size.y > 0.0:
		fill_sb.draw(get_canvas_item(), fill_rect)

	# Leading edge while charging
	if draw_leading_edge and not _is_ready and fill_rect.size.x < fill_area.size.x - 0.5:
		var edge_w: float = _s(leading_edge_px)
		edge_w = clampf(edge_w, 1.0, maxf(1.0, fill_area.size.x))
		var edge_x: float = fill_rect.position.x + fill_rect.size.x
		var edge_rect := Rect2(Vector2(edge_x - edge_w, fill_rect.position.y), Vector2(edge_w, fill_rect.size.y))

		var edge_col: Color = style.gold_accent
		edge_col.a = clampf(leading_edge_alpha, 0.0, 1.0)
		draw_rect(edge_rect, edge_col, true)

	# Ticks
	if show_ticks and tick_count > 1 and fill_area.size.x > 0.0:
		_draw_ticks(fill_area, tick_count)

	# NEW: Cooldown timer text (like abilities) — only while not ready
	if show_time and not _is_ready and time_left_in_bar:
		var txt: String = _format_seconds_short(_cd_remaining)
		if txt != "":
			var tx: float = fill_area.position.x + _s(time_left_inset_px)
			var ty: float = fill_area.position.y + fill_area.size.y * 0.5
			_draw_text_vcenter(font_body, txt, Vector2(tx, ty), body_size, style.text, HORIZONTAL_ALIGNMENT_LEFT)

	# Ready pulse overlay (rounded)
	if ready_pulse_enabled and _is_ready and _sb_pulse != null and _pulse > 0.001:
		var a := clampf(_pulse * ready_pulse_strength, 0.0, 0.9)
		if a > 0.001:
			var c := style.fill_ult.lightened(0.35).lerp(style.gold_accent, 0.55)
			c.a = a
			_sb_pulse.bg_color = c
			_sb_pulse.draw(get_canvas_item(), fill_area)

	# Optional ready text (if you ever want it)
	if show_ready_text and _is_ready:
		var txt_r := ready_text if ready_text != "" else "READY"
		var txr: float = fill_area.position.x + _s(time_left_inset_px)
		var tyr: float = fill_area.position.y + fill_area.size.y * 0.5
		_draw_text_vcenter(font_body, txt_r, Vector2(txr, tyr), body_size, style.text, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_ticks(r: Rect2, count: int) -> void:
	var c: Color = style.gold_dim
	c.a = 0.22
	var w: float = r.size.x
	var h: float = r.size.y
	if w <= 0.0 or h <= 0.0:
		return

	var step: float = w / float(count)
	var tick_w: float = maxf(1.0, _s(1.0))

	for i in range(1, count):
		var x: float = r.position.x + step * float(i)
		var tick := Rect2(Vector2(x - tick_w * 0.5, r.position.y + _s(2.0)), Vector2(tick_w, h - _s(4.0)))
		draw_rect(tick, c, true)

func _rebuild_styleboxes() -> void:
	_sb_dirty = false

	var border_px: int = _si(style.border_px)
	var radius: int = maxi(0, roundi(_s(style.corner_radius)))

	_sb_border = StyleBoxFlat.new()
	_sb_border.bg_color = style.frame_bg
	_sb_border.border_color = style.frame_border
	_sb_border.border_width_left = border_px
	_sb_border.border_width_top = border_px
	_sb_border.border_width_right = border_px
	_sb_border.border_width_bottom = border_px
	_sb_border.corner_radius_top_left = radius
	_sb_border.corner_radius_top_right = radius
	_sb_border.corner_radius_bottom_left = radius
	_sb_border.corner_radius_bottom_right = radius
	_sb_border.anti_aliasing = true

	_sb_fill = StyleBoxFlat.new()
	_sb_fill.bg_color = style.fill_ult
	var fill_r: int = maxi(0, radius - border_px)
	_sb_fill.corner_radius_top_left = fill_r
	_sb_fill.corner_radius_top_right = fill_r
	_sb_fill.corner_radius_bottom_left = fill_r
	_sb_fill.corner_radius_bottom_right = fill_r
	_sb_fill.anti_aliasing = true

	_sb_fill_dim = StyleBoxFlat.new()
	var dim: Color = style.fill_ult
	dim.a = 0.55
	_sb_fill_dim.bg_color = dim
	_sb_fill_dim.corner_radius_top_left = fill_r
	_sb_fill_dim.corner_radius_top_right = fill_r
	_sb_fill_dim.corner_radius_bottom_left = fill_r
	_sb_fill_dim.corner_radius_bottom_right = fill_r
	_sb_fill_dim.anti_aliasing = true

	_sb_pulse = StyleBoxFlat.new()
	_sb_pulse.corner_radius_top_left = fill_r
	_sb_pulse.corner_radius_top_right = fill_r
	_sb_pulse.corner_radius_bottom_left = fill_r
	_sb_pulse.corner_radius_bottom_right = fill_r
	_sb_pulse.anti_aliasing = true

func _pick_font(primary: Font, secondary: Font) -> Font:
	if primary != null:
		return primary
	if secondary != null:
		return secondary
	return get_theme_default_font()

func _draw_text_vcenter(font: Font, s: String, center_pos: Vector2, font_size: int, col: Color, align: HorizontalAlignment) -> void:
	if s == "":
		return
	var ascent: float = float(font.get_ascent(font_size))
	var pos := Vector2(center_pos.x, center_pos.y + ascent * 0.5)
	draw_string(font, pos, s, align, -1, font_size, col)

func _format_seconds_short(sec: float) -> String:
	if sec <= 0.0:
		return ""
	if sec < 10.0:
		return String.num(sec, 1) + "s"
	return str(int(ceil(sec))) + "s"
