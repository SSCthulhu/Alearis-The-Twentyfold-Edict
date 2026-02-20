extends Control
class_name BossHUDTop

# -----------------------------
# Public API (call from controllers)
# -----------------------------
func set_boss_name(v: String) -> void:
	boss_name = v
	queue_redraw()

func set_health(current: float, max_value: float) -> void:
	_health_target = 0.0 if max_value <= 0.0 else clampf(current / max_value, 0.0, 1.0)
	queue_redraw()

func start_cast(spell: String, cast_time: float) -> void:
	cast_name = spell
	_cast_total = maxf(cast_time, 0.01)
	_cast_elapsed = 0.0
	_casting = true
	_cast_target = 0.0 # start empty, fill up over time
	queue_redraw()

func stop_cast() -> void:
	_casting = false
	_cast_target = 0.0
	cast_name = "" # text disappears when no cast
	queue_redraw()

# Optional: if you want to drive cast progress yourself instead of time-based
func set_cast_progress01(p: float) -> void:
	_casting = true
	_cast_target = clampf(p, 0.0, 1.0)
	queue_redraw()

# -----------------------------
# Visual tuning (edit in Inspector)
# -----------------------------
@export var hud_width: float = 980.0
@export var hud_height: float = 92.0
@export var top_padding: float = 8.0
@export var bottom_extra_padding: float = 24.0

@export var show_health_percent_text: bool = true
@export var show_cast_bar: bool = true

# Keep this export, but we will also auto-disable it if icon_texture is null.
@export var show_icon_socket: bool = true

@export var always_show_cast_bar_frame: bool = true

@export var inner_padding: Vector2 = Vector2(18, 14)
@export var name_row_height: float = 28.0
@export var health_bar_height: float = 54.0
@export var cast_bar_height: float = 44.0
@export var bar_gap: float = 10.0
@export var icon_size: float = 54.0
@export var icon_gap: float = 12.0

@export var text_color: Color = Color(0.95, 0.95, 0.95, 1.0)
@export var subtext_color: Color = Color(0.92, 0.92, 0.92, 0.90)

# Fonts (assign FontFile / FontVariation in Inspector)
@export var title_font: Font
@export var bar_font: Font
@export var boss_name_font_size: int = 22
@export var bar_text_font_size: int = 14
@export var bar_right_text_inset: float = 10.0

@export var lerp_speed: float = 10.0

# -----------------------------
# Rounded styling to match PlayerHUD
# -----------------------------
@export var corner_radius_px: int = 14
@export var border_px: int = 2
@export var bar_inset_px: float = 3.0
@export var bar_inner_rounding_px: int = 10
@export var soften_border_alpha: float = 0.85

# -----------------------------
# Player-HUD-like panel style (no gold borders)
# -----------------------------
@export var panel_bg: Color = Color(0.05, 0.055, 0.06, 0.86)

@export var shadow_color: Color = Color(0, 0, 0, 0.30)
@export var shadow_offset: Vector2 = Vector2(0, 3)
@export var shadow_expand_px: float = 6.0

@export var highlight_color: Color = Color(1, 1, 1, 0.06)
@export var highlight_inset_px: float = 2.0

@export var health_track: Color = Color(0.09, 0.09, 0.10, 0.85)
@export var health_fill: Color = Color(0.85, 0.10, 0.12, 1.0)

@export var cast_track: Color = Color(0.09, 0.09, 0.10, 0.75)
@export var cast_fill: Color = Color(0.35, 0.70, 1.0, 1.0)

@export var bar_rounding_px: int = 12

# Optional textures (kept)
@export var frame_texture: Texture2D
@export var frame_left_cap: Texture2D
@export var frame_right_cap: Texture2D
@export var icon_texture: Texture2D

# -----------------------------
# Internal state
# -----------------------------
var boss_name: String = "BOSS"
var cast_name: String = ""

var _health_target: float = 1.0
var _health_display: float = 1.0

var _casting: bool = false
var _cast_total: float = 1.0
var _cast_elapsed: float = 0.0
var _cast_target: float = 0.0
var _cast_display: float = 0.0

# StyleBoxes (rounded drawing)
var _sb_fill_health: StyleBoxFlat
var _sb_fill_cast: StyleBoxFlat
var _sb_dirty: bool = true
var _sb_panel: StyleBoxFlat
var _sb_panel_highlight: StyleBoxFlat
var _sb_track_health: StyleBoxFlat
var _sb_track_cast: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(hud_width, hud_height + bottom_extra_padding)
	set_process(true)

func _process(delta: float) -> void:
	_health_display = lerpf(_health_display, _health_target, 1.0 - pow(0.001, delta * lerp_speed))

	if _casting:
		_cast_elapsed += delta
		var t: float = clampf(_cast_elapsed / _cast_total, 0.0, 1.0)
		_cast_target = t
		if t >= 1.0:
			_casting = false

	_cast_display = lerpf(_cast_display, _cast_target, 1.0 - pow(0.001, delta * lerp_speed))
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var vw: float = size.x
	var draw_w: float = minf(hud_width, vw)
	var x0: float = (vw - draw_w) * 0.5
	var y0: float = top_padding

	var frame_h: float = hud_height + bottom_extra_padding
	var r: Rect2 = Rect2(Vector2(x0, y0), Vector2(draw_w, frame_h))

	if _sb_dirty:
		_rebuild_styleboxes()

	_draw_frame(r)

	var inner: Rect2 = r.grow_individual(
		-inner_padding.x,
		-inner_padding.y,
		-inner_padding.x,
		-inner_padding.y
	)

	# Decide if we actually show the icon socket.
	# If the user wants it off OR there is no icon texture, do not reserve space.
	var use_icon: bool = show_icon_socket and icon_texture != null

	var content_left: float = inner.position.x
	if use_icon:
		var icon_rect := Rect2(inner.position, Vector2(icon_size, icon_size))
		_draw_icon_socket(icon_rect)
		content_left = icon_rect.end.x + icon_gap

	var content_right: float = inner.end.x
	var content_w: float = maxf(1.0, content_right - content_left)

	# Name row
	var name_rect: Rect2 = Rect2(Vector2(content_left, inner.position.y), Vector2(content_w, name_row_height))
	_draw_name_row(name_rect)

	# Health bar
	var health_rect: Rect2 = Rect2(
		Vector2(content_left, name_rect.end.y + 2.0),
		Vector2(content_w, health_bar_height)
	)
	_draw_bar(health_rect, _health_display, health_track, health_fill)

	if show_health_percent_text:
		var pct: int = int(round(_health_display * 100.0))
		_draw_right_text_inset(health_rect, "%d%%" % pct, bar_text_font_size, text_color, bar_right_text_inset)

	# Cast bar
	if show_cast_bar:
		var cast_rect: Rect2 = Rect2(
			Vector2(content_left, health_rect.end.y + bar_gap),
			Vector2(content_w, cast_bar_height)
		)

		if always_show_cast_bar_frame or _cast_display > 0.01 or _casting or cast_name != "":
			_draw_bar(cast_rect, _cast_display, cast_track, cast_fill)

		if _casting or cast_name != "":
			_draw_right_text_inset(cast_rect, cast_name, bar_text_font_size, subtext_color, bar_right_text_inset)

# -----------------------------
# Rounded frame + elements
# -----------------------------
func _rebuild_styleboxes() -> void:
	_sb_dirty = false

	# Main panel
	_sb_panel = StyleBoxFlat.new()
	_sb_panel.bg_color = panel_bg
	_sb_panel.corner_radius_top_left = corner_radius_px
	_sb_panel.corner_radius_top_right = corner_radius_px
	_sb_panel.corner_radius_bottom_left = corner_radius_px
	_sb_panel.corner_radius_bottom_right = corner_radius_px
	_sb_panel.anti_aliasing = true

	# Inner highlight (very subtle)
	_sb_panel_highlight = StyleBoxFlat.new()
	_sb_panel_highlight.bg_color = Color(0, 0, 0, 0)
	_sb_panel_highlight.border_color = highlight_color
	_sb_panel_highlight.border_width_left = 1
	_sb_panel_highlight.border_width_top = 1
	_sb_panel_highlight.border_width_right = 1
	_sb_panel_highlight.border_width_bottom = 1
	var hi_r := maxi(0, corner_radius_px - int(highlight_inset_px))
	_sb_panel_highlight.corner_radius_top_left = hi_r
	_sb_panel_highlight.corner_radius_top_right = hi_r
	_sb_panel_highlight.corner_radius_bottom_left = hi_r
	_sb_panel_highlight.corner_radius_bottom_right = hi_r
	_sb_panel_highlight.anti_aliasing = true

	# Tracks
	_sb_track_health = StyleBoxFlat.new()
	_sb_track_health.bg_color = health_track
	_sb_track_health.corner_radius_top_left = bar_rounding_px
	_sb_track_health.corner_radius_top_right = bar_rounding_px
	_sb_track_health.corner_radius_bottom_left = bar_rounding_px
	_sb_track_health.corner_radius_bottom_right = bar_rounding_px
	_sb_track_health.anti_aliasing = true

	_sb_track_cast = StyleBoxFlat.new()
	_sb_track_cast.bg_color = cast_track
	_sb_track_cast.corner_radius_top_left = bar_rounding_px
	_sb_track_cast.corner_radius_top_right = bar_rounding_px
	_sb_track_cast.corner_radius_bottom_left = bar_rounding_px
	_sb_track_cast.corner_radius_bottom_right = bar_rounding_px
	_sb_track_cast.anti_aliasing = true

	# Fills
	_sb_fill_health = StyleBoxFlat.new()
	_sb_fill_health.bg_color = health_fill
	_sb_fill_health.corner_radius_top_left = bar_rounding_px
	_sb_fill_health.corner_radius_top_right = bar_rounding_px
	_sb_fill_health.corner_radius_bottom_left = bar_rounding_px
	_sb_fill_health.corner_radius_bottom_right = bar_rounding_px
	_sb_fill_health.anti_aliasing = true

	_sb_fill_cast = StyleBoxFlat.new()
	_sb_fill_cast.bg_color = cast_fill
	_sb_fill_cast.corner_radius_top_left = bar_rounding_px
	_sb_fill_cast.corner_radius_top_right = bar_rounding_px
	_sb_fill_cast.corner_radius_bottom_left = bar_rounding_px
	_sb_fill_cast.corner_radius_bottom_right = bar_rounding_px
	_sb_fill_cast.anti_aliasing = true

func _draw_frame(r: Rect2) -> void:
	_sb_panel.draw(get_canvas_item(), r)

	if highlight_inset_px > 0.0:
		var rr := r.grow(-highlight_inset_px)
		if rr.size.x > 0.0 and rr.size.y > 0.0:
			_sb_panel_highlight.draw(get_canvas_item(), rr)

func _draw_icon_socket(r: Rect2) -> void:
	_sb_panel.draw(get_canvas_item(), r)
	var hi := r.grow(-highlight_inset_px)
	_sb_panel_highlight.draw(get_canvas_item(), hi)

	if icon_texture:
		var inset := 4.0
		var ir := r.grow_individual(-inset, -inset, -inset, -inset)
		draw_texture_rect(icon_texture, ir, true)

func _draw_name_row(r: Rect2) -> void:
	_draw_left_text(r, boss_name, boss_name_font_size, text_color)

func _draw_bar(r: Rect2, t01: float, track_col: Color, fill_col: Color) -> void:
	if track_col == health_track:
		_sb_track_health.draw(get_canvas_item(), r)
	else:
		_sb_track_cast.draw(get_canvas_item(), r)

	t01 = clampf(t01, 0.0, 1.0)
	var fill_r := Rect2(r.position, Vector2(r.size.x * t01, r.size.y))
	if fill_r.size.x > 0.0:
		if fill_col == health_fill:
			_sb_fill_health.draw(get_canvas_item(), fill_r)
		else:
			_sb_fill_cast.draw(get_canvas_item(), fill_r)

# -----------------------------
# Fonts + text helpers
# -----------------------------
func _font_title() -> Font:
	return title_font if title_font != null else get_theme_default_font()

func _font_bar() -> Font:
	return bar_font if bar_font != null else get_theme_default_font()

func _draw_left_text(r: Rect2, s: String, font_size: int, col: Color) -> void:
	if s == "":
		return
	var f: Font = _font_title()
	var y := r.position.y + (r.size.y * 0.5) + (font_size * 0.35)
	draw_string(f, Vector2(r.position.x, y), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, font_size, col)

func _draw_right_text_inset(r: Rect2, s: String, font_size: int, col: Color, inset: float = 8.0) -> void:
	if s == "":
		return
	var f: Font = _font_bar()
	var width: float = maxf(1.0, r.size.x - inset)
	var x: float = r.position.x
	var y: float = r.position.y + (r.size.y * 0.5) + (font_size * 0.35)

	draw_string(
		f,
		Vector2(x, y),
		s,
		HORIZONTAL_ALIGNMENT_RIGHT,
		width,
		font_size,
		col
	)
