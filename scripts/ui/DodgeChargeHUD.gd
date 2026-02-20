extends Control
class_name DodgeChargeHUD

@export var style: HUDStyle
@export var lerp_speed: float = 14.0

@export var charges_max: int = 2
@export var diamond_size_px: float = 60.0
@export var diamond_line_px: float = 3.0
@export var gap_px: float = 16.0

@export var outline_thickness_mult: float = 1.6
@export var recharge_thickness_mult: float = 1.9

@export var stack_vertical: bool = true

# -----------------------------
# Crystal palette (darker)
# -----------------------------
@export var crystal_base: Color = Color(0.10, 0.28, 0.55, 1.0)   # darker blue
@export var crystal_reflect: Color = Color(0.18, 0.45, 0.85, 1.0) # highlight blue
@export var crystal_dim: Color = Color(0.10, 0.28, 0.55, 0.18)    # depleted interior

@export var silver: Color = Color(0.72, 0.78, 0.86, 1.0)          # darker silver
@export var silver_flash: Color = Color(0.92, 0.96, 1.0, 1.0)     # bright flash/spark

# -----------------------------
# Completion FX tuning
# -----------------------------
@export var flash_duration: float = 0.14
@export var spark_duration: float = 0.10
@export var spark_size_px: float = 7.0

var _ui_scale: float = 1.0

var _charges_cur: int = 2
var _next_left: float = 0.0
var _recharge_total: float = 1.0

var _target_fill: float = 0.0
var _display_fill: float = 0.0

# completion tracking
var _last_charges_cur: int = -1
var _last_display_fill: float = 0.0

var _flash_t: float = 0.0
var _spark_t: float = 0.0
var _fx_index: int = -1 # which diamond to flash/spark

func _style_ready() -> bool:
	if style == null:
		return false
	if Engine.is_editor_hint():
		return false
	return true

func _s(px: float) -> float:
	# Safe scaling even if style isn't usable
	if _style_ready() and style.has_method("s"):
		return float(style.call("s", px, _ui_scale))
	return px * _ui_scale

func set_style(v: HUDStyle) -> void:
	style = v
	queue_redraw()

func set_ui_scale(v: float) -> void:
	_ui_scale = maxf(v, 0.01)
	queue_redraw()

func set_dodge_state(cur: int, mx: int, next_left: float, total: float) -> void:
	charges_max = maxi(mx, 1)
	_charges_cur = clampi(cur, 0, charges_max)
	_next_left = maxf(next_left, 0.0)
	_recharge_total = maxf(total, 0.01)

	if _charges_cur < charges_max:
		_target_fill = clampf(1.0 - (_next_left / _recharge_total), 0.0, 1.0)
	else:
		_target_fill = 0.0

	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return

	# Smooth progress
	_display_fill = lerpf(_display_fill, _target_fill, 1.0 - exp(-lerp_speed * dt))

	# Detect "charge completed" moments for FX
	# 1) If the game updated charges_cur (most reliable)
	if _last_charges_cur == -1:
		_last_charges_cur = _charges_cur

	if _charges_cur > _last_charges_cur:
		_fx_index = _charges_cur - 1 # the diamond that just became ready
		_flash_t = flash_duration
		_spark_t = spark_duration

	# 2) Fallback: progress hits full while we're recharging (in case charges update lags)
	if _charges_cur < charges_max:
		if _last_display_fill < 0.98 and _display_fill >= 0.98:
			_fx_index = _charges_cur
			_flash_t = maxf(_flash_t, flash_duration)
			_spark_t = maxf(_spark_t, spark_duration)

	_last_charges_cur = _charges_cur
	_last_display_fill = _display_fill

	# Decay FX timers
	_flash_t = maxf(_flash_t - dt, 0.0)
	_spark_t = maxf(_spark_t - dt, 0.0)

	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		return
	if style == null:
		return

	var d: float = _s(diamond_size_px)
	var g: float = _s(gap_px)
	var line: float = _s(diamond_line_px)

	if stack_vertical:
		var total_h: float = d * float(charges_max) + g * float(charges_max - 1)
		var start_y: float = (size.y - total_h) * 0.5
		var cx: float = size.x * 0.5

		for i in range(charges_max):
			var cy: float = start_y + (d + g) * float(i) + d * 0.5
			_draw_one_diamond(i, Vector2(cx, cy), d, line)
	else:
		var total_w: float = d * float(charges_max) + g * float(charges_max - 1)
		var start_x: float = (size.x - total_w) * 0.5
		var cy2: float = size.y * 0.5

		for i in range(charges_max):
			var cx2: float = start_x + (d + g) * float(i) + d * 0.5
			_draw_one_diamond(i, Vector2(cx2, cy2), d, line)

func _draw_one_diamond(i: int, center: Vector2, d: float, line: float) -> void:
	var is_ready_charge: bool = (i < _charges_cur)

	var outline_w: float = line * outline_thickness_mult
	var recharge_w: float = line * recharge_thickness_mult

	# Diamond points
	var h: float = d * 0.5
	var p0: Vector2 = center + Vector2(0, -h)
	var p1: Vector2 = center + Vector2(h, 0)
	var p2: Vector2 = center + Vector2(0, h)
	var p3: Vector2 = center + Vector2(-h, 0)

	# Shared
	var no_outline := silver
	no_outline.a = 0.0

	# -----------------------------
	# READY (crystal + silver outline)
	# -----------------------------
	if is_ready_charge:
		# Base crystal
		draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), crystal_base)

		# Refraction split (two-tone)
		# Diagonal-ish shard overlay: (top -> right -> center)
		var mid: Vector2 = center
		var refr := crystal_reflect
		refr.a = 0.85
		draw_colored_polygon(PackedVector2Array([p0, p1, mid]), refr)

		# Thin inner sheen (subtle)
		var sheen := crystal_reflect
		sheen.a = 0.20
		var p0i := center + Vector2(0, -h * 0.78)
		var p1i := center + Vector2(h * 0.78, 0)
		var p2i := center + Vector2(0, h * 0.78)
		var p3i := center + Vector2(-h * 0.78, 0)
		draw_polyline(PackedVector2Array([p0i, p1i, p2i, p3i, p0i]), sheen, maxf(1.0, outline_w * 0.35), true)

		# Silver outline
		var outline_ready := silver
		outline_ready.a = 1.0

		# Flash overlay on completion (same capsule/diamond, not a rectangle)
		if _flash_t > 0.0 and i == _fx_index:
			var t := clampf(_flash_t / maxf(flash_duration, 0.001), 0.0, 1.0)
			var flash_col := silver_flash
			flash_col.a = 0.35 * t
			draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), flash_col)
			outline_ready = outline_ready.lerp(silver_flash, 0.65 * t)

		draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), outline_ready, outline_w, true)

		# Spark tick (tiny star at 12:00)
		if _spark_t > 0.0 and i == _fx_index:
			var t2 := clampf(_spark_t / maxf(spark_duration, 0.001), 0.0, 1.0)
			var s := _s(spark_size_px) * (0.7 + 0.3 * t2)
			var sc := silver_flash
			sc.a = 0.90 * t2
			draw_line(p0 + Vector2(-s, 0), p0 + Vector2(s, 0), sc, maxf(1.0, outline_w * 0.55), true)
			draw_line(p0 + Vector2(0, -s), p0 + Vector2(0, s), sc, maxf(1.0, outline_w * 0.55), true)

		return

	# -----------------------------
	# DEPLETED (dim interior, NO outline)
	# -----------------------------
	draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), crystal_dim)
	draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), no_outline, outline_w, true)

	# -----------------------------
	# RECHARGING (silver outline grows CCW from 12:00)
	# -----------------------------
	if i == _charges_cur:
		var prog_outline := silver
		prog_outline.a = 1.0
		_draw_diamond_outline_progress(center, d, recharge_w, no_outline, prog_outline, _display_fill)

# --- Outline progress helpers ---
func _draw_diamond_outline_progress(center: Vector2, size_px: float, line_px: float, base_outline: Color, prog_outline: Color, pct: float) -> void:
	pct = clampf(pct, 0.0, 1.0)

	var h: float = size_px * 0.5
	# CCW order: Top -> Left -> Bottom -> Right -> Top
	var p0: Vector2 = center + Vector2(0, -h)
	var p1: Vector2 = center + Vector2(-h, 0)
	var p2: Vector2 = center + Vector2(0, h)
	var p3: Vector2 = center + Vector2(h, 0)

	var pts := PackedVector2Array([p0, p1, p2, p3, p0])

	draw_polyline(pts, base_outline, line_px, true)

	if pct <= 0.001:
		return

	var total_len: float = _polyline_length(pts)
	var draw_len: float = total_len * pct
	_draw_polyline_length(pts, draw_len, prog_outline, line_px)

func _polyline_length(pts: PackedVector2Array) -> float:
	var total_len: float = 0.0
	for i in range(pts.size() - 1):
		total_len += pts[i].distance_to(pts[i + 1])
	return total_len

func _draw_polyline_length(pts: PackedVector2Array, max_len: float, col: Color, width: float) -> void:
	if max_len <= 0.0:
		return

	var acc: float = 0.0
	var out := PackedVector2Array()
	out.append(pts[0])

	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg_len: float = a.distance_to(b)

		if acc + seg_len <= max_len:
			out.append(b)
			acc += seg_len
		else:
			var remain: float = max_len - acc
			var t: float = (remain / seg_len) if seg_len > 0.0001 else 0.0
			out.append(a.lerp(b, t))
			break

	if out.size() >= 2:
		draw_polyline(out, col, width, true)
