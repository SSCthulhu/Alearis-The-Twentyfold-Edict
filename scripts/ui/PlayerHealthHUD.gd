extends Control
class_name PlayerHealthHUD

enum TextMode { NONE, PERCENT, NUMERIC }

@export var style: HUDStyle
@export var label: String = ""
@export var text_mode: int = TextMode.NUMERIC
@export var lerp_speed: float = 12.0

@export var show_label: bool = true
@export var label_text: String = "HEALTH"
@export var label_gap_px: float = 6.0 # space between label and bar

# Shield visual (UI-only)
@export var show_shield_overlay: bool = true
@export var shield_color: Color = Color(0.18, 0.55, 1.0, 0.85)

# --- Smooth distortion field (no shaders) ---
@export var shield_distort_strength: float = 0.35 # 0..1 overall intensity
@export var shield_distort_band_count: int = 4     # number of distortion bands
@export var shield_distort_thickness_px: float = 7.0
@export var shield_distort_amp_px: float = 6.0     # wave amplitude in px
@export var shield_distort_freq: float = 0.065     # wave frequency (lower = smoother)
@export var shield_distort_speed: float = 1.15     # animation speed
@export var shield_distort_step_px: float = 8.0    # sampling step along X (bigger = cheaper)

# Optional subtle haze wash (0 disables)
@export var shield_haze_strength: float = 0.0 # 0..1

@export var shield_sheen_strength: float = 0.18
@export var shield_animate: bool = true
@export var shield_anim_speed: float = 0.85

var _shield_anim_t: float = 0.0

@export_range(0.0, 1.0, 0.01)
var low_hp_threshold: float = 0.25

var _ui_scale: float = 1.0
var _hp_target: float = 1.0
var _hp_display: float = 1.0

var _shield_target: float = 0.0
var _shield_display: float = 0.0

var _current_hp: float = 0.0
var _max_hp: float = 0.0

var _current_shield: float = 0.0
var _shield_ref_max_hp: float = 0.0

var _text_cache: String = ""
var _text_dirty: bool = true

var _sb_border: StyleBoxFlat
var _sb_fill: StyleBoxFlat
var _sb_fill_low: StyleBoxFlat
var _sb_shield: StyleBoxFlat
var _sb_dirty: bool = true

# -----------------------------
# Style helpers
# -----------------------------
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

func _font_body() -> int:
	if _style_ready() and style.has_method("font_size_body"):
		return int(style.call("font_size_body", _ui_scale))
	return int(round(14.0 * _ui_scale))

func _font_small() -> int:
	if _style_ready() and style.has_method("font_size_small"):
		return int(style.call("font_size_small", _ui_scale))
	return int(round(12.0 * _ui_scale))

# -----------------------------
# Public API
# -----------------------------
func set_style(v: HUDStyle) -> void:
	style = v
	_sb_dirty = true
	queue_redraw()

func set_ui_scale(v: float) -> void:
	_ui_scale = maxf(v, 0.01)
	_sb_dirty = true
	queue_redraw()

func set_text_mode(v: int) -> void:
	text_mode = v
	_text_dirty = true
	queue_redraw()

func set_health(current: float, max_value: float) -> void:
	_current_hp = maxf(current, 0.0)
	_max_hp = maxf(max_value, 0.0)
	_hp_target = 0.0 if _max_hp <= 0.0 else clampf(_current_hp / _max_hp, 0.0, 1.0)
	_recompute_shield_ratio()
	_text_dirty = true
	queue_redraw()

func set_shield(current_shield: float, max_hp_ref: float) -> void:
	_current_shield = maxf(current_shield, 0.0)
	_shield_ref_max_hp = maxf(max_hp_ref, 0.0)
	_recompute_shield_ratio()
	queue_redraw()

func _recompute_shield_ratio() -> void:
	var denom: float = _max_hp
	if denom <= 0.0:
		denom = _shield_ref_max_hp
	if denom <= 0.0:
		_shield_target = 0.0
		return
	_shield_target = clampf(_current_shield / denom, 0.0, 1.0)

# -----------------------------
# Lifecycle
# -----------------------------
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return

	if shield_animate:
		_shield_anim_t += dt * maxf(shield_anim_speed, 0.0)

	_hp_display = lerpf(_hp_display, _hp_target, 1.0 - exp(-lerp_speed * dt))
	_shield_display = lerpf(_shield_display, _shield_target, 1.0 - exp(-lerp_speed * dt))
	queue_redraw()

# -----------------------------
# Draw
# -----------------------------
func _draw() -> void:
	if Engine.is_editor_hint():
		return
	if style == null:
		return

	if _sb_dirty:
		_rebuild_styleboxes()

	var border: int = _si(style.border_px)
	var pad_in: float = _s(style.pad_inner)

	var font_value: Font = _pick_font(style.font_body, style.font_small)
	var value_size: int = _font_body()

	var outer: Rect2 = Rect2(Vector2.ZERO, size)
	_sb_border.draw(get_canvas_item(), outer)

	var inner: Rect2 = outer.grow(-float(border) - pad_in)

	var font_small: Font = _pick_font(style.font_small, style.font_body)
	var small_size: int = _font_small()

	# Label lane
	var label_lane_h: float = 0.0
	if show_label and label_text != "":
		label_lane_h = float(font_small.get_ascent(small_size) + font_small.get_descent(small_size))
		label_lane_h += _s(4.0)

		var lx: float = inner.position.x + _s(6.0)
		var ly: float = inner.position.y + _s(2.0) + float(font_small.get_ascent(small_size))
		draw_string(font_small, Vector2(lx, ly), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size, style.text_dim)

	# Bar rect (inside the frame)
	var bar: Rect2 = inner
	bar.position.y += label_lane_h + _s(label_gap_px)
	bar.size.y = maxf(0.0, inner.size.y - label_lane_h - _s(label_gap_px))

	# Bar content rect (this is the ONLY area HP/shield draw into)
	var content_inset: float = _s(1.0)
	var bar_content: Rect2 = bar.grow(-content_inset)

	# HP fill (red)
	var hp_w: float = floor(bar_content.size.x * _hp_display)
	var hp_rect: Rect2 = Rect2(bar_content.position, Vector2(hp_w, bar_content.size.y))

	if hp_rect.size.x > 0.0 and hp_rect.size.y > 0.0:
		if _hp_display <= low_hp_threshold:
			_sb_fill_low.draw(get_canvas_item(), hp_rect)
		else:
			_sb_fill.draw(get_canvas_item(), hp_rect)

	# Shield overlay (blue) + FX clipped to shield rect
	if show_shield_overlay and _shield_display > 0.0:
		var shield_w: float = floor(bar_content.size.x * _shield_display)
		var shield_rect: Rect2 = Rect2(bar_content.position, Vector2(shield_w, bar_content.size.y))

		if shield_rect.size.x > 0.0 and shield_rect.size.y > 0.0:
			_sb_shield.draw(get_canvas_item(), shield_rect)

			# Inset clip so polylines / AA can't bleed into frame background
			var fx_clip: Rect2 = _shield_fx_clip_rect(shield_rect)

			if shield_haze_strength > 0.0:
				_draw_shield_haze_wash(fx_clip)

			_draw_shield_distortion(fx_clip)
			_draw_shield_sheen(fx_clip)

	# Text
	if text_mode != TextMode.NONE:
		if _text_dirty:
			_text_cache = _build_value_text()
			_text_dirty = false

		var left_inset: float = _s(14.0)
		var fill_left: float = bar_content.position.x + left_inset
		var fill_right: float = bar_content.position.x + maxf(left_inset, floor(bar_content.size.x * _hp_display) - _s(1.0))
		var text_x: float = clampf(fill_left, fill_left, fill_right)

		var text_pos := Vector2(text_x, bar_content.position.y + bar_content.size.y * 0.5 - 2.0)
		_draw_text_vcenter(font_value, _text_cache, text_pos, value_size, style.text, HORIZONTAL_ALIGNMENT_LEFT)

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
	_sb_fill.bg_color = style.fill_hp
	var fill_r := maxi(0, radius - border_px)
	_sb_fill.corner_radius_top_left = fill_r
	_sb_fill.corner_radius_top_right = fill_r
	_sb_fill.corner_radius_bottom_left = fill_r
	_sb_fill.corner_radius_bottom_right = fill_r
	_sb_fill.anti_aliasing = true

	_sb_fill_low = StyleBoxFlat.new()
	_sb_fill_low.bg_color = style.fill_hp_low
	_sb_fill_low.corner_radius_top_left = fill_r
	_sb_fill_low.corner_radius_top_right = fill_r
	_sb_fill_low.corner_radius_bottom_left = fill_r
	_sb_fill_low.corner_radius_bottom_right = fill_r
	_sb_fill_low.anti_aliasing = true

	_sb_shield = StyleBoxFlat.new()
	_sb_shield.bg_color = shield_color
	_sb_shield.corner_radius_top_left = fill_r
	_sb_shield.corner_radius_top_right = fill_r
	_sb_shield.corner_radius_bottom_left = fill_r
	_sb_shield.corner_radius_bottom_right = fill_r
	_sb_shield.anti_aliasing = true

# -----------------------------
# Text helpers
# -----------------------------
func _build_value_text() -> String:
	match text_mode:
		TextMode.PERCENT:
			return "%d%%" % int(round(_hp_target * 100.0))
		TextMode.NUMERIC:
			return "%d / %d" % [int(round(_current_hp)), int(round(_max_hp))]
		_:
			return ""

func _pick_font(primary: Font, secondary: Font) -> Font:
	if primary != null:
		return primary
	if secondary != null:
		return secondary
	return get_theme_default_font()

func _draw_text_vcenter(font: Font, s: String, center_pos: Vector2, font_size: int, col: Color, align: HorizontalAlignment) -> void:
	if s == "":
		return
	var ascent := float(font.get_ascent(font_size))
	var pos := Vector2(center_pos.x, center_pos.y + ascent * 0.5)
	draw_string(font, pos, s, align, -1, font_size, col)

# -----------------------------
# Shield FX (clipping + drawing)
# -----------------------------
func _shield_fx_clip_rect(r: Rect2) -> Rect2:
	# Inset enough to contain polyline thickness + AA safety.
	var th: float = maxf(_s(shield_distort_thickness_px), 1.0)
	var safety: float = maxf(th * 0.6, _s(2.0))
	return r.grow(-safety)

func _draw_shield_haze_wash(r: Rect2) -> void:
	var s: float = clampf(shield_haze_strength, 0.0, 1.0)
	if s <= 0.0:
		return
	if r.size.x <= 2.0 or r.size.y <= 2.0:
		return

	var c: Color = shield_color.lerp(Color(1, 1, 1, shield_color.a), 0.35)
	c.a = clampf(shield_color.a * 0.18 * s, 0.0, 0.22)
	draw_rect(r, c, true)

func _hash01(v: float) -> float:
	return fposmod(sin(v) * 43758.5453, 1.0)

func _draw_shield_distortion(r: Rect2) -> void:
	if shield_distort_strength <= 0.0:
		return
	if r.size.x <= 12.0 or r.size.y <= 8.0:
		return

	var strength: float = clampf(shield_distort_strength, 0.0, 1.0)

	var band_count: int = clampi(shield_distort_band_count, 1, 8)
	var th: float = maxf(_s(shield_distort_thickness_px), 1.0)
	var amp: float = maxf(_s(shield_distort_amp_px), 0.0)
	var step: float = maxf(_s(shield_distort_step_px), 3.0)

	var freq: float = maxf(shield_distort_freq, 0.0001)
	var t: float = (_shield_anim_t * shield_distort_speed) if shield_animate else 0.0

	var col: Color = shield_color.lerp(Color(1, 1, 1, shield_color.a), 0.55)
	col.a = clampf(shield_color.a * 0.28 * strength, 0.0, 0.45)

	var x0: float = r.position.x
	var x1: float = r.position.x + r.size.x
	var w: float = r.size.x

	var sample_count: int = int(ceil(w / step)) + 1
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(sample_count)

	# Clamp band lines so thickness never crosses top/bottom
	var y_min: float = r.position.y + th * 0.55
	var y_max: float = r.position.y + r.size.y - th * 0.55

	for bi in band_count:
		var bseed: float = float(bi) * 91.7 + 13.3
		var y_base: float = r.position.y + (float(bi) + 0.5) / float(band_count) * r.size.y

		var drift: float = (sin(t * 0.9 + bseed) * 0.12 + cos(t * 0.6 + bseed * 0.7) * 0.10) * r.size.y
		y_base += drift

		var a_mul: float = lerpf(0.55, 1.15, _hash01(bseed * 1.9))
		var phase: float = _hash01(bseed * 2.7) * TAU

		var a_band: float = col.a * lerpf(0.55, 1.0, _hash01(bseed * 3.1))
		var c0: Color = col
		c0.a = a_band

		var idx: int = 0
		var x: float = x0
		while idx < sample_count:
			var xn: float = (x - x0)

			var wave1: float = sin((xn * freq) + (t * 2.2) + phase)
			var wave2: float = sin((xn * freq * 0.57) - (t * 1.4) + phase * 0.6)

			var y_off: float = (wave1 * 0.70 + wave2 * 0.30) * amp * a_mul
			var yy: float = clampf(y_base + y_off, y_min, y_max)

			points[idx] = Vector2(x, yy)

			idx += 1
			x = minf(x + step, x1)

		# Soft edge layering
		var soft_px: float = maxf(_s(1.5), 1.0)

		var c_main: Color = c0
		c_main.a = a_band * 0.90
		draw_polyline(points, c_main, th, true)

		var c_soft1: Color = c0
		c_soft1.a = a_band * 0.40
		_draw_polyline_offset(points, Vector2(0.0, -soft_px), c_soft1, maxf(th * 0.70, 1.0))
		_draw_polyline_offset(points, Vector2(0.0, +soft_px), c_soft1, maxf(th * 0.70, 1.0))

		var c_soft2: Color = c0
		c_soft2.a = a_band * 0.22
		_draw_polyline_offset(points, Vector2(0.0, -soft_px * 2.0), c_soft2, maxf(th * 0.45, 1.0))
		_draw_polyline_offset(points, Vector2(0.0, +soft_px * 2.0), c_soft2, maxf(th * 0.45, 1.0))

func _draw_polyline_offset(src: PackedVector2Array, off: Vector2, col: Color, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(src.size())
	for i in src.size():
		pts[i] = src[i] + off
	draw_polyline(pts, col, width, true)

func _draw_shield_sheen(r: Rect2) -> void:
	if shield_sheen_strength <= 0.0:
		return
	if r.size.x <= 8.0 or r.size.y <= 6.0:
		return

	var base: Color = Color(1, 1, 1, 1)
	base.a = clampf(shield_color.a * shield_sheen_strength, 0.0, 0.5)

	var t: float = _shield_anim_t if shield_animate else 0.0
	var sweep1: float = fposmod(t * 42.0, r.size.x + r.size.y)
	var sweep2: float = fposmod(t * 31.0 + 120.0, r.size.x + r.size.y)

	_draw_diagonal_sheen_clipped(r, sweep1, base, 2.0)
	_draw_diagonal_sheen_clipped(r, sweep2, base * Color(0.8, 0.9, 1.0, 1.0), 1.0)

func _draw_diagonal_sheen_clipped(r: Rect2, offset: float, col: Color, thickness: float) -> void:
	var th: float = maxf(_s(thickness), 1.0)

	# Inset rect so line thickness can't bleed out
	var rr: Rect2 = r.grow(-th * 0.6)
	if rr.size.x <= 2.0 or rr.size.y <= 2.0:
		return

	# Long diagonal segment, then clip into rr
	var p0 := Vector2(rr.position.x - rr.size.y + offset, rr.position.y)
	var p1 := Vector2(rr.position.x + offset, rr.position.y + rr.size.y)

	var ok: bool = false
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var clipped: Array = _clip_segment_to_rect(p0, p1, rr)
	ok = bool(clipped[0])
	if not ok:
		return
	a = clipped[1]
	b = clipped[2]

	var c: Color = col
	c.a = col.a * 0.85
	draw_line(a, b, c, th, true)

	c.a = col.a * 0.45
	draw_line(a + Vector2(_s(2.0), 0.0), b + Vector2(_s(2.0), 0.0), c, th, true)

	c.a = col.a * 0.25
	draw_line(a + Vector2(_s(4.0), 0.0), b + Vector2(_s(4.0), 0.0), c, th, true)

# Returns [ok(bool), a(Vector2), b(Vector2)]
func _clip_segment_to_rect(p0: Vector2, p1: Vector2, r: Rect2) -> Array:
	# Liang–Barsky clipping without local lambdas.
	var x_min: float = r.position.x
	var y_min: float = r.position.y
	var x_max: float = r.position.x + r.size.x
	var y_max: float = r.position.y + r.size.y

	var dx: float = p1.x - p0.x
	var dy: float = p1.y - p0.y

	var t0: float = 0.0
	var t1: float = 1.0

	# Helper: update [t0,t1] given p,q
	var ok: bool = true

	# LEFT:  -dx * t <= p0.x - x_min  => p = -dx, q = p0.x - x_min
	ok = ok and _lb_clip(-dx, p0.x - x_min, t0, t1)
	if ok:
		t0 = _lb_t0
		t1 = _lb_t1

	# RIGHT: dx * t <= x_max - p0.x
	ok = ok and _lb_clip(dx, x_max - p0.x, t0, t1)
	if ok:
		t0 = _lb_t0
		t1 = _lb_t1

	# BOTTOM: -dy * t <= p0.y - y_min
	ok = ok and _lb_clip(-dy, p0.y - y_min, t0, t1)
	if ok:
		t0 = _lb_t0
		t1 = _lb_t1

	# TOP: dy * t <= y_max - p0.y
	ok = ok and _lb_clip(dy, y_max - p0.y, t0, t1)
	if ok:
		t0 = _lb_t0
		t1 = _lb_t1

	if not ok:
		return [false, Vector2.ZERO, Vector2.ZERO]

	var a: Vector2 = p0 + Vector2(dx, dy) * t0
	var b: Vector2 = p0 + Vector2(dx, dy) * t1
	return [true, a, b]

# Internal scratch (avoids tuple returns to keep allocations low)
var _lb_t0: float = 0.0
var _lb_t1: float = 1.0

func _lb_clip(p: float, q: float, t0_in: float, t1_in: float) -> bool:
	_lb_t0 = t0_in
	_lb_t1 = t1_in

	if absf(p) < 0.000001:
		# Parallel: accept only if inside
		return q >= 0.0

	var t: float = q / p
	if p < 0.0:
		if t > _lb_t1:
			return false
		if t > _lb_t0:
			_lb_t0 = t
	else:
		if t < _lb_t0:
			return false
		if t < _lb_t1:
			_lb_t1 = t

	return true
