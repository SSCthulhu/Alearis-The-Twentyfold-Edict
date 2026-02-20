extends Control
class_name AbilityCooldownUI

# -----------------------------
# Data sources (optional)
# -----------------------------
@export var combat_path: NodePath = NodePath()
@export var player_path: NodePath = NodePath()

@export var light_cd_total: float = 0.8
@export var heavy_cd_total: float = 2.0
@export var defend_cd_total: float = 3.0
@export var ultimate_cd_total: float = 20.0
@export var dodge_recharge_total_fallback: float = 10.0

# -----------------------------
# Desired size inside layout
# -----------------------------
@export var widget_size: Vector2 = Vector2(740.0, 260.0)
@export var widget_scale: float = 1.0

# -----------------------------
# Layout / look tuning
# -----------------------------
@export var diamond_size: float = 56.0
@export var diamond_line: float = 4.0
@export var arc_thickness: float = 10.0

@export var diamonds_y_offset: float = 10.0
@export var top_arc_gap: float = 22.0
@export var bottom_arc_gap: float = 22.0
@export var dodge_label_gap: float = 34.0

@export var ultimate_curve_height: float = 55.0
@export var dodge_curve_height: float = 45.0

@export var dodge_tick_length: float = 18.0
@export var dodge_tick_thickness: float = 4.0

@export var ready_pulse_duration: float = 0.35
@export var ready_pulse_extra_thickness: float = 6.0
@export var ready_pulse_alpha: float = 0.85

@export var ultimate_edge_thickness: float = 2.0
@export var ultimate_edge_alpha: float = 0.9

# Colors
@export var col_outline: Color = Color(1, 1, 1, 0.92)
@export var col_muted: Color = Color(1, 1, 1, 0.22)

@export var col_ultimate_ready: Color = Color.from_string("#FFC24A", Color(1, 0.85, 0.25, 1))
@export var col_ultimate_cooling: Color = Color.from_string("#FFC24ACC", Color(1, 0.85, 0.25, 0.9))

@export var col_dodge_ready: Color = Color.from_string("#2E8BD9", Color(0.2, 0.6, 0.9, 1))
@export var col_dodge_cooling: Color = Color.from_string("#2E8BD9CC", Color(0.2, 0.6, 0.9, 0.9))

@export var col_diamond_ready: Color = Color(1, 1, 1, 0.20)
@export var col_diamond_cooling: Color = Color(1, 1, 1, 0.10)

# Text
@export var text_color: Color = Color.from_string("#F2F6FF", Color(1, 1, 1, 1))
@export var text_outline_color: Color = Color.from_string("#0B0D12CC", Color(0, 0, 0, 0.8))
@export var text_outline_px: int = 2

@export var ui_font: Font
@export var title_font_size: int = 16
@export var value_font_size: int = 16
@export var small_font_size: int = 12

# -----------------------------
# Runtime
# -----------------------------
var _combat: Node = null
var _player: Node = null
var _font: Font = null

var _learned_total := { &"light": 0.0, &"heavy": 0.0, &"defend": 0.0, &"ultimate": 0.0 }
var _prev_left := { &"light": 0.0, &"heavy": 0.0, &"defend": 0.0, &"ultimate": 0.0 }

var _prev_ready_light: bool = true
var _prev_ready_heavy: bool = true
var _prev_ready_defend: bool = true
var _prev_ready_ultimate: bool = true
var _prev_roll_charges: int = 0

var _pulse_light: float = 0.0
var _pulse_heavy: float = 0.0
var _pulse_defend: float = 0.0
var _pulse_ultimate: float = 0.0
var _pulse_dodge_seg0: float = 0.0
var _pulse_dodge_seg1: float = 0.0

func _ready() -> void:
	_font = get_theme_default_font()

	# IMPORTANT: do NOT force anchors/offsets here.
	# This node is now positioned by your BottomRight/PlayerStack containers.

	custom_minimum_size = widget_size * maxf(widget_scale, 0.01)
	set_process(true)

	_player = _resolve_player()
	_combat = _resolve_combat(_player)

	if _combat == null:
		push_warning("[AbilityCooldownUI] Combat not found. Set combat_path OR ensure Player has child 'Combat' and is in group 'player'.")
		return

	for k in _prev_left.keys():
		_prev_left[k] = _get_cd_left(k)

	_prev_ready_light = _get_cd_left(&"light") <= 0.0
	_prev_ready_heavy = _get_cd_left(&"heavy") <= 0.0
	_prev_ready_defend = _get_cd_left(&"defend") <= 0.0
	_prev_ready_ultimate = _get_cd_left(&"ultimate") <= 0.0
	_prev_roll_charges = _get_roll_charges()

	queue_redraw()

func _resolve_player() -> Node:
	if player_path != NodePath():
		var p: Node = get_node_or_null(player_path)
		if p != null:
			return p
	return get_tree().get_first_node_in_group("player")

func _resolve_combat(p: Node) -> Node:
	if combat_path != NodePath():
		var c: Node = get_node_or_null(combat_path)
		if c != null:
			return c

	if p != null and p.has_node("Combat"):
		return p.get_node("Combat")

	return null

func _process(delta: float) -> void:
	if _combat == null:
		return

	_learn_total_if_started(&"light", light_cd_total)
	_learn_total_if_started(&"heavy", heavy_cd_total)
	_learn_total_if_started(&"defend", defend_cd_total)
	_learn_total_if_started(&"ultimate", ultimate_cd_total)

	var r_light: bool = _get_cd_left(&"light") <= 0.0
	var r_heavy: bool = _get_cd_left(&"heavy") <= 0.0
	var r_def: bool = _get_cd_left(&"defend") <= 0.0
	var r_ult: bool = _get_cd_left(&"ultimate") <= 0.0

	if r_light and not _prev_ready_light:
		_pulse_light = ready_pulse_duration
	if r_heavy and not _prev_ready_heavy:
		_pulse_heavy = ready_pulse_duration
	if r_def and not _prev_ready_defend:
		_pulse_defend = ready_pulse_duration
	if r_ult and not _prev_ready_ultimate:
		_pulse_ultimate = ready_pulse_duration

	_prev_ready_light = r_light
	_prev_ready_heavy = r_heavy
	_prev_ready_defend = r_def
	_prev_ready_ultimate = r_ult

	var cur_charges: int = _get_roll_charges()
	if cur_charges > _prev_roll_charges:
		if _prev_roll_charges == 0 and cur_charges >= 1:
			_pulse_dodge_seg0 = ready_pulse_duration
		if _prev_roll_charges <= 1 and cur_charges >= 2:
			_pulse_dodge_seg1 = ready_pulse_duration
	_prev_roll_charges = cur_charges

	_pulse_light = maxf(_pulse_light - delta, 0.0)
	_pulse_heavy = maxf(_pulse_heavy - delta, 0.0)
	_pulse_defend = maxf(_pulse_defend - delta, 0.0)
	_pulse_ultimate = maxf(_pulse_ultimate - delta, 0.0)
	_pulse_dodge_seg0 = maxf(_pulse_dodge_seg0 - delta, 0.0)
	_pulse_dodge_seg1 = maxf(_pulse_dodge_seg1 - delta, 0.0)

	queue_redraw()

func _learn_total_if_started(key: StringName, fallback_total: float) -> void:
	var cur_left: float = _get_cd_left(key)
	var prev_left: float = float(_prev_left.get(key, 0.0))

	if cur_left > 0.0 and (cur_left > prev_left + 0.05 or prev_left <= 0.0):
		_learned_total[key] = maxf(cur_left, maxf(fallback_total, 0.01))

	_prev_left[key] = cur_left

# ------------------------------------------------------------
# Drawing (draw inside THIS Control's rect)
# ------------------------------------------------------------
func _draw() -> void:
	if _combat == null:
		return

	var scale_mul: float = maxf(widget_scale, 0.01)

	# Use our own local rect so VBox/anchors control placement
	var ws: Vector2 = custom_minimum_size
	var rect := Rect2(Vector2.ZERO, ws)

	var center: Vector2 = rect.size * 0.5

	var row_y: float = center.y + diamonds_y_offset * scale_mul
	var spacing: float = (diamond_size * 1.9) * scale_mul
	var x0: float = center.x - spacing
	var x1: float = center.x
	var x2: float = center.x + spacing

	var left_center: Vector2 = Vector2(x0, row_y)
	var mid_center: Vector2 = Vector2(x1, row_y)
	var right_center: Vector2 = Vector2(x2, row_y)

	var half_d: float = (diamond_size * 0.5) * scale_mul
	var arc_left_x: float = left_center.x - half_d
	var arc_right_x: float = right_center.x + half_d

	# Ultimate top curve
	var ult_left: float = _get_cd_left(&"ultimate")
	var ult_total: float = _get_effective_total(&"ultimate", ultimate_cd_total)
	var ult_fill: float = _fill_from_cd(ult_left, ult_total)

	var top_y: float = row_y - half_d - (top_arc_gap * scale_mul)
	var top_p0: Vector2 = Vector2(arc_left_x, top_y)
	var top_p2: Vector2 = Vector2(arc_right_x, top_y)
	var top_pc: Vector2 = Vector2((top_p0.x + top_p2.x) * 0.5, top_y - (ultimate_curve_height * scale_mul))

	_draw_bezier_bar(top_p0, top_pc, top_p2, arc_thickness * scale_mul, col_muted, 1.0)
	_draw_bezier_bar(top_p0, top_pc, top_p2, arc_thickness * scale_mul, (col_ultimate_ready if ult_left <= 0.0 else col_ultimate_cooling), ult_fill)
	_draw_bezier_edge(top_p0, top_pc, top_p2, ultimate_edge_thickness * scale_mul, col_ultimate_ready, ult_fill)
	_draw_ready_glow_bezier(top_p0, top_pc, top_p2, col_ultimate_ready, _pulse_ultimate, scale_mul)

	_draw_text_centered("Ultimate", Vector2(center.x, top_y - (ultimate_curve_height * scale_mul) - 12.0), int(round(float(title_font_size) * scale_mul)))

	# Diamonds
	_draw_diamond_cd(left_center, "Light", &"light", light_cd_total, _pulse_light, scale_mul)
	_draw_diamond_cd(mid_center, "Heavy", &"heavy", heavy_cd_total, _pulse_heavy, scale_mul)
	_draw_diamond_cd(right_center, "Defensive", &"defend", defend_cd_total, _pulse_defend, scale_mul)

	# Dodge bottom curve
	var charges_cur: int = _get_roll_charges()
	var charges_max: int = _get_roll_max_charges()
	if charges_max < 1:
		charges_max = 2

	var dodge_total: float = _get_roll_recharge_time()
	var dodge_next_left: float = _get_roll_next_charge_left()

	var bot_y: float = row_y + half_d + (bottom_arc_gap * scale_mul)
	var bot_p0: Vector2 = Vector2(arc_left_x, bot_y)
	var bot_p2: Vector2 = Vector2(arc_right_x, bot_y)
	var bot_pc: Vector2 = Vector2((bot_p0.x + bot_p2.x) * 0.5, bot_y + (dodge_curve_height * scale_mul))

	_draw_bezier_bar(bot_p0, bot_pc, bot_p2, arc_thickness * scale_mul, col_muted, 1.0)
	_draw_dodge_bezier_segments(bot_p0, bot_pc, bot_p2, arc_thickness * scale_mul, charges_cur, charges_max, dodge_next_left, dodge_total)
	_draw_bezier_tick(bot_p0, bot_pc, bot_p2, 0.5, dodge_tick_length * scale_mul, dodge_tick_thickness * scale_mul, col_outline)

	_draw_ready_glow_bezier_segment(bot_p0, bot_pc, bot_p2, 0.0, 0.5, col_dodge_ready, _pulse_dodge_seg0, scale_mul)
	_draw_ready_glow_bezier_segment(bot_p0, bot_pc, bot_p2, 0.5, 1.0, col_dodge_ready, _pulse_dodge_seg1, scale_mul)

	var label_y: float = bot_y + (dodge_curve_height * scale_mul) + (dodge_label_gap * scale_mul)
	var left_label_pos: Vector2 = Vector2(lerp(bot_p0.x, bot_p2.x, 0.25), label_y)
	var right_label_pos: Vector2 = Vector2(lerp(bot_p0.x, bot_p2.x, 0.75), label_y)

	_draw_text_centered("Dodge 1", left_label_pos, int(round(float(small_font_size) * scale_mul)))
	_draw_text_centered("Dodge 2", right_label_pos, int(round(float(small_font_size) * scale_mul)))

# ------------------------------------------------------------
# Diamonds
# ------------------------------------------------------------
func _draw_diamond_cd(pos: Vector2, title: String, key: StringName, _fallback_total: float, pulse_timer: float, scale_mul: float) -> void:
	var left: float = _get_cd_left(key)
	var fill_col: Color = col_diamond_ready if left <= 0.0 else col_diamond_cooling
	_draw_diamond(pos, diamond_size * scale_mul, diamond_line * scale_mul, col_outline, fill_col)

	var inside: String = "READY" if left <= 0.0 else _format_seconds_short(left)
	_draw_text_centered(inside, pos, int(round(float(value_font_size) * scale_mul)))
	_draw_text_centered(title, pos + Vector2(0, (diamond_size * 0.78) * scale_mul), int(round(float(small_font_size) * scale_mul)))

	_draw_ready_glow_diamond(pos, pulse_timer, scale_mul)

func _draw_diamond(center: Vector2, size_px: float, line_px: float, outline: Color, fill: Color) -> void:
	var h: float = size_px * 0.5
	var p0: Vector2 = center + Vector2(0, -h)
	var p1: Vector2 = center + Vector2(h, 0)
	var p2: Vector2 = center + Vector2(0, h)
	var p3: Vector2 = center + Vector2(-h, 0)

	draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), fill)
	draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), outline, line_px, true)

# ------------------------------------------------------------
# Bezier helpers
# ------------------------------------------------------------
func _quad_bezier(p0: Vector2, pc: Vector2, p2: Vector2, t: float) -> Vector2:
	var a: Vector2 = p0.lerp(pc, t)
	var b: Vector2 = pc.lerp(p2, t)
	return a.lerp(b, t)

func _quad_bezier_tangent(p0: Vector2, pc: Vector2, p2: Vector2, t: float) -> Vector2:
	return (pc - p0) * (2.0 * (1.0 - t)) + (p2 - pc) * (2.0 * t)

func _draw_bezier_bar(p0: Vector2, pc: Vector2, p2: Vector2, thickness: float, col: Color, fill01: float) -> void:
	fill01 = clampf(fill01, 0.0, 1.0)
	if fill01 <= 0.0:
		return
	var segs: int = 72
	var pts := PackedVector2Array()
	pts.resize(segs + 1)
	var max_t: float = fill01
	for i in range(segs + 1):
		var t: float = (float(i) / float(segs)) * max_t
		pts[i] = _quad_bezier(p0, pc, p2, t)
	draw_polyline(pts, col, thickness, true)

func _draw_bezier_edge(p0: Vector2, pc: Vector2, p2: Vector2, thickness: float, col: Color, fill01: float) -> void:
	if fill01 <= 0.0:
		return
	var c := col
	c.a *= ultimate_edge_alpha
	var segs: int = 72
	var pts := PackedVector2Array()
	pts.resize(segs + 1)
	var max_t: float = clampf(fill01, 0.0, 1.0)
	for i in range(segs + 1):
		var t: float = (float(i) / float(segs)) * max_t
		pts[i] = _quad_bezier(p0, pc, p2, t)
	draw_polyline(pts, c, thickness, true)

func _draw_bezier_segment(p0: Vector2, pc: Vector2, p2: Vector2, t0: float, t1: float, thickness: float, col: Color, fill01: float) -> void:
	fill01 = clampf(fill01, 0.0, 1.0)
	if fill01 <= 0.0:
		return
	var segs: int = 36
	var pts := PackedVector2Array()
	pts.resize(segs + 1)
	var span: float = (t1 - t0) * fill01
	var t_to: float = t0 + span
	for i in range(segs + 1):
		var t: float = lerp(t0, t_to, float(i) / float(segs))
		pts[i] = _quad_bezier(p0, pc, p2, t)
	draw_polyline(pts, col, thickness, true)

func _draw_dodge_bezier_segments(p0: Vector2, pc: Vector2, p2: Vector2, thickness: float, cur: int, mx: int, next_left: float, total: float) -> void:
	mx = maxi(mx, 1)
	cur = clampi(cur, 0, mx)
	for i in range(mx):
		var t0: float = float(i) / float(mx)
		var t1: float = float(i + 1) / float(mx)
		if i < cur:
			_draw_bezier_segment(p0, pc, p2, t0, t1, thickness, col_dodge_ready, 1.0)
		elif i == cur and cur < mx:
			var pct: float = 0.0
			if total > 0.0:
				pct = clampf(1.0 - (next_left / total), 0.0, 1.0)
			if pct > 0.01:
				_draw_bezier_segment(p0, pc, p2, t0, t1, thickness, col_dodge_cooling, pct)

func _draw_bezier_tick(p0: Vector2, pc: Vector2, p2: Vector2, t: float, length_px: float, thickness_px: float, col: Color) -> void:
	t = clampf(t, 0.0, 1.0)
	var pt: Vector2 = _quad_bezier(p0, pc, p2, t)
	var tangent: Vector2 = _quad_bezier_tangent(p0, pc, p2, t)
	if tangent.length() < 0.001:
		return
	tangent = tangent.normalized()
	var n: Vector2 = Vector2(-tangent.y, tangent.x)
	draw_line(pt - n * (length_px * 0.5), pt + n * (length_px * 0.5), col, thickness_px, true)

# ------------------------------------------------------------
# Ready glow pulse
# ------------------------------------------------------------
func _pulse_strength(pulse_timer: float) -> float:
	if pulse_timer <= 0.0:
		return 0.0
	var t: float = clampf(pulse_timer / maxf(ready_pulse_duration, 0.01), 0.0, 1.0)
	return 1.0 - pow(t, 2.2)

func _draw_ready_glow_bezier(p0: Vector2, pc: Vector2, p2: Vector2, base_col: Color, pulse_timer: float, scale_mul: float) -> void:
	var s: float = _pulse_strength(pulse_timer)
	if s <= 0.0:
		return
	var c: Color = base_col
	c.a = clampf(ready_pulse_alpha * s, 0.0, 1.0)
	_draw_bezier_bar(p0, pc, p2, (arc_thickness + ready_pulse_extra_thickness) * scale_mul, c, 1.0)

func _draw_ready_glow_bezier_segment(p0: Vector2, pc: Vector2, p2: Vector2, t0: float, t1: float, base_col: Color, pulse_timer: float, scale_mul: float) -> void:
	var s: float = _pulse_strength(pulse_timer)
	if s <= 0.0:
		return
	var c: Color = base_col
	c.a = clampf(ready_pulse_alpha * s, 0.0, 1.0)
	_draw_bezier_segment(p0, pc, p2, t0, t1, (arc_thickness + ready_pulse_extra_thickness) * scale_mul, c, 1.0)

func _draw_ready_glow_diamond(center: Vector2, pulse_timer: float, scale_mul: float) -> void:
	var s: float = _pulse_strength(pulse_timer)
	if s <= 0.0:
		return
	var h: float = (diamond_size * scale_mul) * 0.5
	var p0: Vector2 = center + Vector2(0, -h)
	var p1: Vector2 = center + Vector2(h, 0)
	var p2: Vector2 = center + Vector2(0, h)
	var p3: Vector2 = center + Vector2(-h, 0)
	var glow: Color = col_outline
	glow.a = clampf(ready_pulse_alpha * s, 0.0, 1.0)
	draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), glow, (diamond_line + ready_pulse_extra_thickness) * scale_mul, true)

# ------------------------------------------------------------
# Data helpers
# ------------------------------------------------------------
func _get_cd_left(key: StringName) -> float:
	if _combat != null and _combat.has_method("get_cooldown_left"):
		return float(_combat.call("get_cooldown_left", key))
	return 0.0

func _get_effective_total(key: StringName, fallback_total: float) -> float:
	var learned: float = float(_learned_total.get(key, 0.0))
	if learned > 0.0:
		return learned
	return maxf(fallback_total, 0.01)

func _fill_from_cd(left: float, total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - (left / total), 0.0, 1.0)

func _get_roll_charges() -> int:
	if _player != null and _player.has_method("get_roll_charges"):
		return int(_player.call("get_roll_charges"))
	return 0

func _get_roll_max_charges() -> int:
	if _player != null and _player.has_method("get_roll_max_charges"):
		return int(_player.call("get_roll_max_charges"))
	return 2

func _get_roll_next_charge_left() -> float:
	if _player != null and _player.has_method("get_roll_next_charge_time_left"):
		return float(_player.call("get_roll_next_charge_time_left"))
	return 0.0

func _get_roll_recharge_time() -> float:
	if _player != null and _player.has_method("get_roll_recharge_time"):
		return float(_player.call("get_roll_recharge_time"))
	return maxf(dodge_recharge_total_fallback, 0.01)

# ------------------------------------------------------------
# Text helpers
# ------------------------------------------------------------
func _get_font_to_use() -> Font:
	if ui_font != null:
		return ui_font
	if _font == null:
		_font = get_theme_default_font()
	return _font

func _draw_text_centered(txt: String, pos: Vector2, font_size: int) -> void:
	var f: Font = _get_font_to_use()
	if f == null:
		return

	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var h: float = float(font_size)
	var base_pos: Vector2 = pos - Vector2(w * 0.5, -h * 0.35)

	var o: int = maxi(text_outline_px, 0)
	if o > 0:
		var offs := [
			Vector2(-o, 0), Vector2(o, 0), Vector2(0, -o), Vector2(0, o),
			Vector2(-o, -o), Vector2(-o, o), Vector2(o, -o), Vector2(o, o)
		]
		for off in offs:
			draw_string(f, base_pos + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_outline_color)

	draw_string(f, base_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _format_seconds_short(sec: float) -> String:
	if sec <= 0.0:
		return "READY"
	if sec < 10.0:
		return String.num(sec, 1) + "s"
	return str(int(ceil(sec))) + "s"
