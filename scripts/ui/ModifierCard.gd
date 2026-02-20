extends Button
class_name ModifierCard

@export var style: HUDStyle
@export var design_height: float = 1440.0

@export var body_margin_px: int = 14      # interior padding in the body (like “breathing room”)
@export var card_outer_margin_px: int = 0 # usually keep 0 since you already have a Body panel

@export var extra_body_inset_px: int = 2

@onready var _tag: Label = $Tag
@onready var _body_panel: Panel = $Body
@onready var _body_margin: MarginContainer = $Body/Margin
@onready var _body_text: RichTextLabel = $Body/Margin/BodyText

var _ui_scale: float = 1.0
var _pad_outer: float = 0.0
var _pad_inner: float = 0.0
var _gap: float = 0.0

var _tween: Tween

# Small polish knobs
var _hover_scale: float = 1.03
var _press_scale: float = 0.985
var _anim_time: float = 0.10

func _ready() -> void:
	text = ""
	clip_text = false

	if _tag != null:
		_tag.z_index = 20

	# IMPORTANT: this Button must receive input
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

	# Click-through (children should NOT eat clicks)
	if _tag != null:
		_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _body_panel != null:
		_body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _body_margin != null:
		_body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _body_text != null:
		_body_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body_text.bbcode_enabled = true
		_body_text.scroll_active = false
		_body_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# KEY CHANGE:
		# Let the label measure its own content height so centering/wrapping stabilizes.
		_body_text.fit_content = true

		# Center the paragraph block
		_body_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP

		# Prevent glyphs drawing outside the rect
		_body_text.clip_contents = true

	# Tag readability
	if _tag != null:
		_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Ensure we re-evaluate after layout changes
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	get_viewport().size_changed.connect(_on_resized)

	# Hover/pressed micro-animations
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not focus_entered.is_connected(_on_mouse_entered):
		focus_entered.connect(_on_mouse_entered)
	if not focus_exited.is_connected(_on_mouse_exited):
		focus_exited.connect(_on_mouse_exited)
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)

	_apply_style()
	call_deferred("_update_body_min_size")
	#print("BodyText type=", _body_text.get_class(), " bbcode_enabled=", _body_text.bbcode_enabled)

func _on_resized() -> void:
	call_deferred("_update_body_min_size")
	call_deferred("_update_tag_layout")

func set_style(v: HUDStyle) -> void:
	style = v
	_apply_style()
	call_deferred("_update_body_min_size")

func set_card_data(tag_text: String, header: String, footer: String, lines: Array[String]) -> void:
	if _tag != null:
		_tag.text = tag_text

	var gold: Color = style.gold_accent if style != null else Color(1, 1, 1, 1)
	var dim: Color = style.text_dim if style != null else Color(0.75, 0.75, 0.78, 1)
	var white: Color = style.text if style != null else Color(1, 1, 1, 1)

	# Sizes (same idea as before)
	var header_px: int = 18
	var footer_px: int = 14
	var body_px: int = 13
	var body_title_px: int = 14

	if style != null:
		header_px = style.font_size_title(_ui_scale) + int(round(4.0 * _ui_scale))
		footer_px = style.font_size_body(_ui_scale) + int(round(2.0 * _ui_scale))
		body_px = style.font_size_body(_ui_scale) + int(round(1.0 * _ui_scale))
		body_title_px = body_px + maxi(1, roundi(1.0 * _ui_scale))

	var bb := ""

	# Center header/footer
	if header != "":
		bb += "[center][font_size=%d][color=%s][b]%s[/b][/color][/font_size][/center]\n" % [
			header_px, _to_bb(gold), header
		]
	if footer != "":
		bb += "[center][font_size=%d][color=%s]%s[/color][/font_size][/center]\n" % [
			footer_px, _to_bb(dim), footer
		]

	if header != "" or footer != "":
		bb += "\n"

	# Each modifier line: "Title: description" => two centered lines
	for s in lines:
		if s == "":
			continue

		var line := s.strip_edges()

		var title := ""
		var desc := ""

		var colon_i := line.find(":")
		if colon_i >= 0:
			title = line.substr(0, colon_i).strip_edges()
			desc = line.substr(colon_i + 1, line.length() - (colon_i + 1)).strip_edges()
		else:
			desc = line

		if title != "":
			bb += "[center][font_size=%d][color=%s][b]%s:[/b][/color][/font_size][/center]\n" % [
				body_title_px, _to_bb(white), title
			]
			if desc != "":
				bb += "[center][font_size=%d][color=%s]%s[/color][/font_size][/center]\n\n" % [
					body_px, _to_bb(white), desc
				]
			else:
				bb += "\n"
		else:
			bb += "[center][font_size=%d][color=%s]%s[/color][/font_size][/center]\n\n" % [
				body_px, _to_bb(white), desc
			]

	if _body_text != null:
		_body_text.bbcode_enabled = true
		_body_text.clear()
		_body_text.parse_bbcode(bb)

	call_deferred("_update_body_min_size")
	call_deferred("_update_tag_layout")

func _apply_style() -> void:
	if style == null:
		return

	_ui_scale = style.ui_scale_for_viewport(get_viewport().get_visible_rect().size, design_height)

	_pad_outer = style.s(style.pad_outer, _ui_scale)
	_pad_inner = style.s(style.pad_inner, _ui_scale)
	_gap = style.s(style.gap, _ui_scale)

	var border_px: int = style.si(style.border_px, _ui_scale, 1)
	var radius: int = maxi(0, roundi(style.s(style.corner_radius, _ui_scale)))
	var pad_outer_i: int = style.si(style.pad_outer, _ui_scale, 0)
	var pad_inner_i: int = style.si(style.pad_inner, _ui_scale, 0)

	# Small safety inset (tweak in inspector)
	var extra_i: int = style.si(float(extra_body_inset_px), _ui_scale, extra_body_inset_px)

	# Containers respect these flags
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	if _body_margin != null:
		_body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if _body_text != null:
		_body_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Card minimum size
	custom_minimum_size = Vector2(style.s(280.0, _ui_scale), style.s(260.0, _ui_scale))

	# ---- Button outer frame ----
	var sb_card := StyleBoxFlat.new()
	sb_card.bg_color = style.frame_bg
	sb_card.border_color = style.frame_border
	sb_card.border_width_left = border_px
	sb_card.border_width_top = border_px
	sb_card.border_width_right = border_px
	sb_card.border_width_bottom = border_px
	sb_card.corner_radius_top_left = radius
	sb_card.corner_radius_top_right = radius
	sb_card.corner_radius_bottom_left = radius
	sb_card.corner_radius_bottom_right = radius
	sb_card.content_margin_left = pad_outer_i
	sb_card.content_margin_right = pad_outer_i
	sb_card.content_margin_top = pad_outer_i
	sb_card.content_margin_bottom = pad_outer_i
	sb_card.anti_aliasing = true

	# Stronger hover/pressed frame contrast
	var sb_hover := sb_card.duplicate() as StyleBoxFlat
	sb_hover.border_color = style.gold_dim
	sb_hover.bg_color = Color(
		style.frame_bg.r,
		style.frame_bg.g,
		style.frame_bg.b,
		minf(1.0, style.frame_bg.a + 0.04)
	)

	var sb_pressed := sb_card.duplicate() as StyleBoxFlat
	sb_pressed.border_color = style.gold_accent
	sb_pressed.bg_color = Color(
		style.frame_bg.r,
		style.frame_bg.g,
		style.frame_bg.b,
		minf(1.0, style.frame_bg.a + 0.06)
	)

	add_theme_stylebox_override("normal", sb_card)
	add_theme_stylebox_override("hover", sb_hover)
	add_theme_stylebox_override("pressed", sb_pressed)
	add_theme_stylebox_override("focus", sb_hover)

	# ---- Tag strip ----
	if _tag != null:
		_tag.add_theme_color_override("font_color", style.gold_accent)
		_tag.add_theme_font_size_override("font_size", style.font_size_title(_ui_scale) + int(round(3.0 * _ui_scale)))
		if style.font_title != null:
			_tag.add_theme_font_override("font", style.font_title)

		var sb_tag := StyleBoxFlat.new()
		sb_tag.bg_color = Color(style.frame_bg.r, style.frame_bg.g, style.frame_bg.b, minf(1.0, style.frame_bg.a + 0.08))
		sb_tag.border_color = style.frame_border
		sb_tag.border_width_left = border_px
		sb_tag.border_width_top = border_px
		sb_tag.border_width_right = border_px
		sb_tag.border_width_bottom = border_px
		var tag_r := maxi(0, radius - 2)
		sb_tag.corner_radius_top_left = tag_r
		sb_tag.corner_radius_top_right = tag_r
		sb_tag.corner_radius_bottom_left = tag_r
		sb_tag.corner_radius_bottom_right = tag_r
		sb_tag.content_margin_left = pad_inner_i
		sb_tag.content_margin_right = pad_inner_i
		sb_tag.content_margin_top = pad_inner_i
		sb_tag.content_margin_bottom = pad_inner_i
		sb_tag.anti_aliasing = true
		_tag.add_theme_stylebox_override("normal", sb_tag)

		# Taller tag to look more “chip-like”
		_tag.custom_minimum_size = Vector2(0.0, style.s(52.0, _ui_scale))

	# ---- Inner body panel ----
	if _body_panel != null:
		var sb_body := StyleBoxFlat.new()
		sb_body.bg_color = Color(style.frame_bg.r, style.frame_bg.g, style.frame_bg.b, minf(1.0, style.frame_bg.a + 0.03))
		sb_body.border_color = style.frame_border
		sb_body.border_width_left = border_px
		sb_body.border_width_top = border_px
		sb_body.border_width_right = border_px
		sb_body.border_width_bottom = border_px
		var body_r := maxi(0, radius - 2)
		sb_body.corner_radius_top_left = body_r
		sb_body.corner_radius_top_right = body_r
		sb_body.corner_radius_bottom_left = body_r
		sb_body.corner_radius_bottom_right = body_r
		sb_body.anti_aliasing = true

		# IMPORTANT: padding comes from MarginContainer ONLY
		sb_body.content_margin_left = 0
		sb_body.content_margin_right = 0
		sb_body.content_margin_top = 0
		sb_body.content_margin_bottom = 0

		_body_panel.add_theme_stylebox_override("panel", sb_body)

	# ---- Margin inside body ----
	if _body_margin != null:
		_body_margin.add_theme_constant_override("margin_left", pad_inner_i + extra_i)
		_body_margin.add_theme_constant_override("margin_right", pad_inner_i + extra_i)
		_body_margin.add_theme_constant_override("margin_top", pad_inner_i + extra_i)
		_body_margin.add_theme_constant_override("margin_bottom", pad_inner_i + extra_i)

	# ---- Body text theme baseline ----
	if _body_text != null:
		_body_text.add_theme_color_override("default_color", style.text)
		_body_text.add_theme_font_size_override("normal_font_size", style.font_size_body(_ui_scale))
		_body_text.add_theme_font_size_override("bold_font_size", style.font_size_body(_ui_scale))

		if style.font_body != null:
			_body_text.add_theme_font_override("normal_font", style.font_body)
			_body_text.add_theme_font_override("bold_font", style.font_body)

		_body_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_body_text.clip_contents = true

		call_deferred("_update_tag_layout")

func _update_body_min_size() -> void:
	if _body_text == null or _body_panel == null or _body_margin == null:
		return
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if _body_panel.size.x <= 1.0:
		return

	# KEY CHANGE:
	# Don't force RichTextLabel min width to the full card width.
	# Instead, constrain it to the *actual available width inside Body/Margin*,
	# so the center alignment is honest and stable.

	var ml: int = int(_body_margin.get_theme_constant("margin_left"))
	var mr: int = int(_body_margin.get_theme_constant("margin_right"))
	var mt: int = int(_body_margin.get_theme_constant("margin_top"))
	var mb: int = int(_body_margin.get_theme_constant("margin_bottom"))

	var available_w: float = maxf(1.0, _body_panel.size.x - float(ml + mr))
	var available_h: float = maxf(1.0, _body_panel.size.y - float(mt + mb))

	# Set only the width floor so wrapping/centering is consistent.
	# Height is allowed to grow naturally because fit_content=true and scroll_active=false.
	_body_text.custom_minimum_size = Vector2(available_w, available_h)

# -----------------------------
# Input feedback (does NOT block clicking)
# -----------------------------
func _on_mouse_entered() -> void:
	_play_scale(_hover_scale)

func _on_mouse_exited() -> void:
	if not button_pressed:
		_play_scale(1.0)

func _on_button_down() -> void:
	_play_scale(_press_scale)

func _on_button_up() -> void:
	var over: bool = get_global_rect().has_point(get_viewport().get_mouse_position())
	_play_scale(_hover_scale if over else 1.0)

func _play_scale(s: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(s, s), _anim_time)

func _update_tag_layout() -> void:
	if _tag == null or style == null:
		return
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var pad_x: float = _pad_inner
	var min_sz: Vector2 = _tag.get_minimum_size()

	var chip_h: float = _tag.custom_minimum_size.y
	if chip_h <= 1.0:
		chip_h = style.s(44.0, _ui_scale)

	var max_chip_w: float = maxf(style.s(120.0, _ui_scale), size.x * 0.42)

	var chip_w: float = min_sz.x + (pad_x * 2.0)
	chip_w = clampf(chip_w, style.s(110.0, _ui_scale), max_chip_w)

	_tag.size = Vector2(chip_w, chip_h)

	var inset: float = style.s(10.0, _ui_scale)
	var x := (size.x - chip_w) * 0.5
	var y := size.y - chip_h - inset
	_tag.position = Vector2(x, y)

func _to_bb(c: Color) -> String:
	return "#%02X%02X%02X%02X" % [
		int(c.r * 255.0),
		int(c.g * 255.0),
		int(c.b * 255.0),
		int(c.a * 255.0)
	]
