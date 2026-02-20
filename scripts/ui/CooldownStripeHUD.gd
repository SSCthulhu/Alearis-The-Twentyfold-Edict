extends Control
class_name CooldownStripeHUD

@export var style: HUDStyle
@export var lerp_speed: float = 14.0

@export var show_label: bool = true
@export var label: String = "SKILL"
@export var show_time: bool = true

@export var draw_track: bool = true
@export_range(0.0, 1.0, 0.01) var track_darkening: float = 0.35
@export var min_fill_px: float = 3.0

# NEW: Stripe thickness controls
@export var stripe_height_px: float = 14.0 # thinner stripe (design px)
@export var stripe_inset_px: float = 1.0   # small inset inside stripe lane

var _ui_scale: float = 1.0

var _cd_total: float = 1.0
var _cd_left: float = 0.0

# progress 0..1 where 1 == ready
var _target: float = 1.0
var _display: float = 1.0

var _sb_border: StyleBoxFlat
var _sb_fill: StyleBoxFlat
var _sb_fill_dim: StyleBoxFlat
var _sb_dirty: bool = true


func _style_ready() -> bool:
	# In editor, exported Resources can be placeholder instances.
	# Placeholder doesn't have your methods, so don't call them.
	if style == null:
		return false
	if Engine.is_editor_hint() and not style.has_method("s"):
		return false
	return true

func _s(v: float) -> float:
	if _style_ready() and style.has_method("s"):
		return float(style.call("s", v, _ui_scale))
	return v * _ui_scale

func _si(v: float) -> int:
	if _style_ready() and style.has_method("si"):
		return int(style.call("si", v, _ui_scale))
	return int(round(v * _ui_scale))

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

func set_label(v: String) -> void:
	label = v
	queue_redraw()

func set_cooldown(left: float, total: float) -> void:
	_cd_left = maxf(left, 0.0)
	_cd_total = maxf(total, 0.01)
	_target = clampf(1.0 - (_cd_left / _cd_total), 0.0, 1.0)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	_display = lerpf(_display, _target, 1.0 - exp(-lerp_speed * dt))
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		return
	if not _style_ready():
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

	# --- Compute a real label lane height ---
	var label_lane_h: float = 0.0
	if show_label and label != "":
		# ascent+descent gives stable lane height across fonts
		label_lane_h = float(font_small.get_ascent(small_size) + font_small.get_descent(small_size))
		label_lane_h += _s(4.0) # padding

		# draw label near top-left of inner
		var lx: float = inner.position.x + _s(6.0)
		var ly: float = inner.position.y + _s(2.0) + float(font_small.get_ascent(small_size))
		draw_string(font_small, Vector2(lx, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size, style.text_dim)

	# --- Stripe bar lane in remaining area ---
	var stripe_lane: Rect2 = inner
	stripe_lane.position.y += label_lane_h
	stripe_lane.size.y = maxf(0.0, inner.size.y - label_lane_h)

	# NEW: force stripe to be thinner + centered in lane
	var desired_h: float = _s(stripe_height_px)
	desired_h = clampf(desired_h, _s(8.0), stripe_lane.size.y) # safety clamp
	var stripe_y: float = stripe_lane.position.y + (stripe_lane.size.y - desired_h) * 0.5

	var stripe: Rect2 = Rect2(
		Vector2(stripe_lane.position.x, stripe_y),
		Vector2(stripe_lane.size.x, desired_h)
	)

	# Inset inside the stripe itself
	var inset: float = _s(stripe_inset_px)
	inset = clampf(inset, 0.0, minf(stripe.size.x * 0.25, stripe.size.y * 0.45))
	var fill_area: Rect2 = stripe.grow(-inset)

	if draw_track and fill_area.size.x > 0.0 and fill_area.size.y > 0.0:
		var track_col: Color = style.frame_bg.darkened(track_darkening)
		track_col.a = 1.0
		draw_rect(fill_area, track_col, true)

	var is_ready: bool = (_cd_left <= 0.001)
	var fill_sb: StyleBoxFlat = _sb_fill if is_ready else _sb_fill_dim

	var fill_w: float = floor(fill_area.size.x * _display)
	if _display > 0.001:
		fill_w = maxf(fill_w, _s(min_fill_px))
	fill_w = clampf(fill_w, 0.0, fill_area.size.x)

	var fill_rect: Rect2 = Rect2(fill_area.position, Vector2(fill_w, fill_area.size.y))
	if fill_rect.size.x > 0.0 and fill_rect.size.y > 0.0:
		fill_sb.draw(get_canvas_item(), fill_rect)

	# Time text inside stripe (left aligned) - only while on cooldown
	if show_time and not is_ready:
		var txt: String = _format_seconds_short(_cd_left)
		if txt != "":
			var tx: float = fill_area.position.x + _s(6.0)
			var ty: float = fill_area.position.y + fill_area.size.y * 0.5
			_draw_text_vcenter(font_body, txt, Vector2(tx, ty), body_size, style.text, HORIZONTAL_ALIGNMENT_LEFT)


func _rebuild_styleboxes() -> void:
	if not _style_ready():
		return

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

	# NEW: Use the ORIGINAL health green for cooldown tiles
	var green: Color = style.fill_ability_ready if ("fill_ability_ready" in style) else Color(0.23, 0.78, 0.41, 1.0)


	_sb_fill = StyleBoxFlat.new()
	_sb_fill.bg_color = green
	var fill_r: int = maxi(0, radius - border_px)
	_sb_fill.corner_radius_top_left = fill_r
	_sb_fill.corner_radius_top_right = fill_r
	_sb_fill.corner_radius_bottom_left = fill_r
	_sb_fill.corner_radius_bottom_right = fill_r
	_sb_fill.anti_aliasing = true

	_sb_fill_dim = StyleBoxFlat.new()
	var dim: Color = green
	dim.a = 0.45
	_sb_fill_dim.bg_color = dim
	_sb_fill_dim.corner_radius_top_left = fill_r
	_sb_fill_dim.corner_radius_top_right = fill_r
	_sb_fill_dim.corner_radius_bottom_left = fill_r
	_sb_fill_dim.corner_radius_bottom_right = fill_r
	_sb_fill_dim.anti_aliasing = true


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
