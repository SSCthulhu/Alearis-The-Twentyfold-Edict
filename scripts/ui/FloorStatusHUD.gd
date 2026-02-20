extends PanelContainer
class_name FloorStatusHUD

# -----------------------------
# Anchoring / sizing
# -----------------------------
@export var safe_margin_px: int = 20
@export var panel_width_px: int = 240
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
@export var header_font_size: int = 16
@export var footer_font_size: int = 16
@export var header_letter_spacing: int = 1
@export var footer_letter_spacing: int = 0
@export var font_override: Font = null

@export var boss_floor_text: String = "DEFEAT BOSS"
@export var boss_floor_text_color: Color = Color(0.95, 0.78, 0.20, 1.0)

# -----------------------------
# Colors
# -----------------------------
@export var panel_color: Color = Color(0.05, 0.06, 0.08, 0.65)
@export var header_text_color: Color = Color(0.92, 0.93, 0.95, 0.95)
@export var footer_text_color: Color = Color(0.90, 0.91, 0.94, 0.95)

@export var dot_on_color: Color = Color(0.95, 0.78, 0.20, 1.0)  # Yellow for normal enemies
@export var dot_elite_color: Color = Color(0.95, 0.20, 0.25, 1.0)  # Red for elites
@export var dot_off_color: Color = Color(0.60, 0.62, 0.68, 0.22)
@export var hide_off_dots: bool = true

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
# Dots (targets)
# -----------------------------
@export var dot_size_px: int = 14
@export var dot_spacing_px: int = 10
@export var dot_max_visible: int = 8
@export var show_header: bool = true
@export var header_text: String = "TARGETS"

@export var complete_text: String = "FLOOR COMPLETE"
@export var complete_text_color: Color = Color(0.95, 0.96, 0.98, 1.0)
@export var complete_font_size: int = 16

# -----------------------------
# Public state
# -----------------------------
var _floor_index: int = 1
var _floor_total: int = 5
var _enemies_left: int = 0
var _enemies_total: int = 0
var _floor_complete: bool = false
var _is_boss_floor: bool = false
var _elites_left: int = 0  # ✅ NEW: Count of elites remaining on current floor

# -----------------------------
# Node refs
# -----------------------------
var _vbox: VBoxContainer = null
var _header_label: Label = null
var _footer_label: Label = null
var _dot_row: HBoxContainer = null
var _dot_texture: Texture2D = null
var _complete_label: Label = null
var _sep_top: HSeparator = null
var _sep_bottom: HSeparator = null


func _ready() -> void:
	_ensure_nodes()
	_apply_anchor_top_right()
	_apply_panel_style()
	_apply_typography()
	_apply_layout_metrics()
	_build_dot_texture()
	_apply_divider_style()
	_refresh_all()


# -----------------------------
# Public API
# -----------------------------
func set_floor(floor_index: int) -> void:
	_floor_index = max(1, floor_index)
	_refresh_footer()

func set_floor_total(total: int) -> void:
	_floor_total = max(1, total)
	_refresh_footer()

func set_enemies_left(count: int) -> void:
	_enemies_left = max(0, count)
	_refresh_targets()

func set_enemies_total(total: int) -> void:
	_enemies_total = max(0, total)
	_refresh_targets()

func set_floor_complete(v: bool) -> void:
	_floor_complete = v
	_refresh_targets()
	_refresh_footer()

func set_is_boss_floor(v: bool) -> void:
	_is_boss_floor = v
	_refresh_targets()

func set_elites_count(count: int) -> void:
	_elites_left = max(0, count)
	_refresh_targets()


# -----------------------------
# Internal: node setup
# -----------------------------
func _ensure_nodes() -> void:
	_vbox = get_node_or_null("VBoxContainer") as VBoxContainer
	if _vbox == null:
		_vbox = VBoxContainer.new()
		_vbox.name = "VBoxContainer"
		add_child(_vbox)

	_header_label = _vbox.get_node_or_null("FloorLabel") as Label
	if _header_label == null:
		_header_label = Label.new()
		_header_label.name = "FloorLabel"
		_vbox.add_child(_header_label)

	_footer_label = _vbox.get_node_or_null("EnemiesLabel") as Label
	if _footer_label == null:
		_footer_label = Label.new()
		_footer_label.name = "EnemiesLabel"
		_vbox.add_child(_footer_label)

	_dot_row = _vbox.get_node_or_null("DotRow") as HBoxContainer
	if _dot_row == null:
		_dot_row = HBoxContainer.new()
		_dot_row.name = "DotRow"

		var footer_idx: int = _footer_label.get_index()
		_vbox.add_child(_dot_row)
		_vbox.move_child(_dot_row, footer_idx)

	_complete_label = _vbox.get_node_or_null("CompleteLabel") as Label
	if _complete_label == null:
		_complete_label = Label.new()
		_complete_label.name = "CompleteLabel"
		_complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_complete_label.visible = false

		var footer_idx2: int = _footer_label.get_index()
		_vbox.add_child(_complete_label)
		_vbox.move_child(_complete_label, footer_idx2)

	_sep_top = _vbox.get_node_or_null("SepTop") as HSeparator
	if _sep_top == null:
		_sep_top = HSeparator.new()
		_sep_top.name = "SepTop"
		_vbox.add_child(_sep_top)
		_vbox.move_child(_sep_top, _header_label.get_index() + 1)

	_sep_bottom = _vbox.get_node_or_null("SepBottom") as HSeparator
	if _sep_bottom == null:
		_sep_bottom = HSeparator.new()
		_sep_bottom.name = "SepBottom"
		_vbox.add_child(_sep_bottom)
		_vbox.move_child(_sep_bottom, _footer_label.get_index())

	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# -----------------------------
# Dividers
# -----------------------------
func _apply_divider_style() -> void:
	if _sep_top == null or _sep_bottom == null:
		return

	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = divider_color
	line.thickness = divider_thickness
	line.vertical = false

	_sep_top.add_theme_stylebox_override("separator", line)
	_sep_bottom.add_theme_stylebox_override("separator", line)

	_sep_top.visible = show_dividers and show_header
	_sep_bottom.visible = show_dividers

	var h: int = divider_margin_top_px + divider_thickness + divider_margin_bottom_px
	_sep_top.custom_minimum_size.y = h
	_sep_bottom.custom_minimum_size.y = h


# -----------------------------
# Internal: anchoring / layout
# -----------------------------
func _apply_anchor_top_right() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT, true)

	if use_fixed_width:
		offset_right = -safe_margin_px
		offset_left = offset_right - panel_width_px
	else:
		offset_right = -safe_margin_px
		offset_left = -safe_margin_px - panel_width_px

	offset_top = safe_margin_px
	offset_bottom = offset_top


func _apply_layout_metrics() -> void:
	if _vbox != null:
		_vbox.add_theme_constant_override("separation", vbox_spacing_px)

	if _dot_row != null:
		_dot_row.add_theme_constant_override("separation", dot_spacing_px)
		_dot_row.alignment = BoxContainer.ALIGNMENT_CENTER

	if use_fixed_width:
		custom_minimum_size.x = panel_width_px
	else:
		custom_minimum_size.x = 0


# -----------------------------
# Panel style
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


# -----------------------------
# Typography
# -----------------------------
func _apply_typography() -> void:
	if _header_label == null or _footer_label == null:
		return

	if font_override != null:
		_header_label.add_theme_font_override("font", font_override)
		_footer_label.add_theme_font_override("font", font_override)

	if _complete_label != null:
		if font_override != null:
			_complete_label.add_theme_font_override("font", font_override)
		_complete_label.add_theme_font_size_override("font_size", complete_font_size)
		_complete_label.add_theme_color_override("font_color", complete_text_color)
		_complete_label.add_theme_constant_override("spacing_char", header_letter_spacing)

	_header_label.add_theme_font_size_override("font_size", header_font_size)
	_footer_label.add_theme_font_size_override("font_size", footer_font_size)

	_header_label.add_theme_color_override("font_color", header_text_color)
	_footer_label.add_theme_color_override("font_color", footer_text_color)

	_header_label.add_theme_constant_override("spacing_char", header_letter_spacing)
	_footer_label.add_theme_constant_override("spacing_char", footer_letter_spacing) # <-- FIXED


# -----------------------------
# Dots: procedural texture
# -----------------------------
func _build_dot_texture() -> void:
	var s: int = max(2, dot_size_px)
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var r: float = float(s) * 0.5
	var center: Vector2 = Vector2(r, r)
	var rr: float = r * r

	for y: int in range(s):
		for x: int in range(s):
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			if center.distance_squared_to(p) <= rr:
				img.set_pixel(x, y, Color(1, 1, 1, 1))

	_dot_texture = ImageTexture.create_from_image(img)


# -----------------------------
# Refresh
# -----------------------------
func _refresh_all() -> void:
	_refresh_header()
	_refresh_targets()
	_refresh_footer()

func _refresh_header() -> void:
	if _header_label == null:
		return
	_header_label.visible = show_header
	_header_label.text = header_text

	if _sep_top != null:
		_sep_top.visible = show_dividers and show_header

func _refresh_footer() -> void:
	if _footer_label == null:
		return
	_footer_label.text = "FLOOR: %d / %d" % [_floor_index, _floor_total]

func _refresh_targets() -> void:
	# ✅ Boss floor: Show elite dots FIRST, then "DEFEAT BOSS" after elites are cleared
	if _is_boss_floor:
		if _elites_left > 0:
			# Show elite dots (all red since boss floor only has elites in golem phase)
			if _dot_row != null:
				_dot_row.visible = true
			if _complete_label != null:
				_complete_label.visible = false
			# ✅ CRITICAL: Skip the normal floor complete check below!
			# Continue to normal dot rendering at the bottom
		else:
			# No elites left - show "DEFEAT BOSS"
			if _dot_row != null:
				_dot_row.visible = false
			if _complete_label != null:
				_complete_label.visible = true
				_complete_label.text = boss_floor_text
				_complete_label.add_theme_color_override("font_color", boss_floor_text_color)
			return
	
	# Normal "floor complete" (but skip if boss floor with elites)
	elif _floor_complete:
		if _dot_row != null:
			_dot_row.visible = false
		if _complete_label != null:
			_complete_label.visible = true
			_complete_label.text = complete_text
			_complete_label.add_theme_color_override("font_color", complete_text_color)
		return

	# Normal active floor
	if _dot_row != null:
		_dot_row.visible = true
	if _complete_label != null:
		_complete_label.visible = false
		_complete_label.add_theme_color_override("font_color", complete_text_color)

	if _dot_row == null:
		return

	# ✅ On boss floor with elites, use elite count instead of enemy count
	var total: int
	var left: int
	
	if _is_boss_floor and _elites_left > 0:
		# Boss floor Golem phase - show only elite dots
		total = clampi(_elites_left, 0, dot_max_visible)
		left = total  # All remaining enemies are elites
	else:
		# Normal floor or boss floor after elites
		total = clampi(_enemies_total, 0, dot_max_visible)
		left = clampi(_enemies_left, 0, total)
		
		if total == 0:
			total = clampi(_enemies_left, 0, dot_max_visible)
			left = total

	# Ensure child count == total (safe: remove immediately)
	while _dot_row.get_child_count() > total:
		var last_child: Node = _dot_row.get_child(_dot_row.get_child_count() - 1)
		_dot_row.remove_child(last_child)
		last_child.queue_free()

	while _dot_row.get_child_count() < total:
		var dot: TextureRect = TextureRect.new()
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.custom_minimum_size = Vector2(dot_size_px, dot_size_px)
		dot.texture = _dot_texture
		_dot_row.add_child(dot)

	# Apply on/off state with individual elite coloring
	# ✅ First N dots are elites (red), remaining are regular (yellow)
	# Example: 5 enemies (2 elite + 3 regular) → [Red, Red, Yellow, Yellow, Yellow]
	
	for i: int in range(_dot_row.get_child_count()):
		var child: Node = _dot_row.get_child(i)
		var dot_rect: TextureRect = child as TextureRect
		if dot_rect == null:
			continue

		var is_on: bool = i < left
		if is_on:
			dot_rect.visible = true
			# ✅ First _elites_left dots are red, rest are yellow
			if i < _elites_left:
				dot_rect.modulate = dot_elite_color  # Red for elites
			else:
				dot_rect.modulate = dot_on_color  # Yellow for regular
		else:
			if hide_off_dots:
				dot_rect.visible = false
			else:
				dot_rect.visible = true
				dot_rect.modulate = dot_off_color
