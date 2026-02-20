extends Panel
class_name RunSummaryPanel

@export var style: HUDStyle
@export var design_height: float = 1440.0

@export var min_width_design: float = 760.0
@export var max_width_design: float = 1400.0
@export var height_design: float = 225.0
@export var pad_design: float = 14.0

@export var stats_col_width_design: float = 210.0
@export var mod_col_min_width_design: float = 230.0
@export var relic_col_min_width_design: float = 230.0

@export var gap_stats_to_mods_px: float = 125.0
@export var gap_mod_cols_px: float = 50.0
@export var gap_mods_to_relics_px: float = 125.0
@export var gap_relic_cols_px: float = 50.0

@export var per_col: int = 3

@export var show_subtitle: bool = true
@export var subtitle_text: String = "Pick a relic from the choices above to continue."

@onready var _margin: MarginContainer = $Margin
@onready var _text: RichTextLabel = $Margin/RunSummaryText # ✅ FIXED PATH

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _margin == null:
		push_warning("[RunSummaryPanel] Missing child node: Margin")
	else:
		_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		_margin.position = Vector2.ZERO

	if _text == null:
		push_warning("[RunSummaryPanel] Missing child node: Margin/RichSummaryText (check node name)")
	else:
		_text.bbcode_enabled = true
		_text.scroll_active = false
		_text.fit_content = false
		_text.clip_contents = true
		_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text.mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh_and_layout(max_width_px: float, top_left: Vector2) -> void:
	# 1) build bbcode
	_refresh_text()

	# 2) size panel
	_layout_size(max_width_px)

	# 3) position panel
	position = top_left

func layout_top_center(max_width_px: float, top_y_px: float) -> void:
	_refresh_text()
	_layout_size(max_width_px)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	position = Vector2((vp.x - size.x) * 0.5, top_y_px)

func layout_under_row(row_left_x: float, row_width: float, top_y_px: float, max_width_cap_px: float) -> void:
	_refresh_text()
	var cap: float = minf(max_width_cap_px, row_width)
	_layout_size(cap)

	var row_center_x: float = row_left_x + row_width * 0.5
	position = Vector2(row_center_x - size.x * 0.5, top_y_px)

func _layout_size(max_width_px: float) -> void:
	if style == null:
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ui_scale: float = style.ui_scale_for_viewport(vp, design_height)

	var panel_h: float = style.s(height_design, ui_scale)

	# estimate needed width based on modifiers and relics
	var body_px: int = style.font_size_body(ui_scale) + style.si(4, ui_scale, 0)

	# Modifiers
	var mod_ids: Array[StringName] = _get_active_modifier_ids()
	var mod_cols: int = maxi(int(ceil(float(mod_ids.size()) / float(per_col))), 1)

	var longest_mod_chars: int = 0
	for id in mod_ids:
		var s: String = _pretty_modifier_name(id)
		longest_mod_chars = maxi(longest_mod_chars, s.length())

	var stats_w: float = style.s(stats_col_width_design, ui_scale)
	var gap_stats_w: float = style.s(gap_stats_to_mods_px, ui_scale)

	var min_mod_w: float = style.s(mod_col_min_width_design, ui_scale)
	var est_mod_w: float = _estimate_text_width_px(longest_mod_chars, body_px) + style.s(28.0, ui_scale) # bullet + padding
	var mod_w: float = maxf(min_mod_w, est_mod_w)

	var gap_mod_w: float = style.s(gap_mod_cols_px, ui_scale)
	var mods_w: float = (mod_w * float(mod_cols)) + (gap_mod_w * float(maxi(0, mod_cols - 1)))

	# Relics
	var relic_ids: Array[StringName] = _get_owned_relic_ids()
	var relic_cols: int = maxi(int(ceil(float(relic_ids.size()) / float(per_col))), 1) if not relic_ids.is_empty() else 0

	var longest_relic_chars: int = 0
	for id in relic_ids:
		var s: String = _get_relic_display_name(id)
		longest_relic_chars = maxi(longest_relic_chars, s.length())

	var gap_mods_to_relics_w: float = style.s(gap_mods_to_relics_px, ui_scale) if not relic_ids.is_empty() else 0.0
	var min_relic_w: float = style.s(relic_col_min_width_design, ui_scale)
	var est_relic_w: float = _estimate_text_width_px(longest_relic_chars, body_px) + style.s(28.0, ui_scale)
	var relic_w: float = maxf(min_relic_w, est_relic_w) if not relic_ids.is_empty() else 0.0

	var gap_relic_w: float = style.s(gap_relic_cols_px, ui_scale)
	var relics_w: float = (relic_w * float(relic_cols)) + (gap_relic_w * float(maxi(0, relic_cols - 1))) if not relic_ids.is_empty() else 0.0

	var pad_w: float = style.s(pad_design, ui_scale) * 2.0
	var desired_w: float = stats_w + gap_stats_w + mods_w + gap_mods_to_relics_w + relics_w + pad_w

	var min_w: float = style.s(min_width_design, ui_scale)
	var max_w: float = style.s(max_width_design, ui_scale)

	# clamp to caller max_width_px
	var hard_max: float = minf(max_w, max_width_px)
	var panel_w: float = clampf(desired_w, min_w, hard_max)

	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(panel_w, panel_h)
	size = Vector2(panel_w, panel_h)

	# margins padding
	if _margin != null:
		var pad: float = style.s(pad_design, ui_scale)
		_margin.offset_left = pad
		_margin.offset_top = pad
		_margin.offset_right = -pad
		_margin.offset_bottom = -pad

func _refresh_text() -> void:
	if _text == null or style == null:
		return

	_text.bbcode_enabled = true

	var gold: Color = style.gold_accent
	var dim: Color = style.text_dim

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ui_scale: float = style.ui_scale_for_viewport(vp, design_height)

	var header_px: int = style.font_size_title(ui_scale) + style.si(6, ui_scale, 0)
	var body_px: int = style.font_size_body(ui_scale) + style.si(4, ui_scale, 0)

	# Run info
	var world_i: int = 1
	var floor_i: int = 1
	var dmin: int = 0
	var dmax: int = 0
	if RunStateSingleton != null:
		if "world_index" in RunStateSingleton: world_i = int(RunStateSingleton.world_index)
		if "floor_index" in RunStateSingleton: floor_i = int(RunStateSingleton.floor_index)
		if "dice_min" in RunStateSingleton: dmin = int(RunStateSingleton.dice_min)
		if "dice_max" in RunStateSingleton: dmax = int(RunStateSingleton.dice_max)

	# Modifiers (prevent wrapping inside names)
	var mod_ids: Array[StringName] = _get_active_modifier_ids()
	var mod_names: Array[String] = []
	for id in mod_ids:
		var pretty: String = _pretty_modifier_name(id)
		pretty = pretty.replace(" ", "\u00A0")
		mod_names.append(pretty)

	var mod_cols: int = maxi(int(ceil(float(mod_names.size()) / float(per_col))), 1)

	# Relics (prevent wrapping inside names)
	var relic_ids: Array[StringName] = _get_owned_relic_ids()
	var relic_names: Array[String] = []
	for id in relic_ids:
		var display: String = _get_relic_display_name(id)
		display = display.replace(" ", "\u00A0")
		relic_names.append(display)

	var relic_cols: int = maxi(int(ceil(float(relic_names.size()) / float(per_col))), 1) if not relic_names.is_empty() else 0

	# gaps -> NBSP strings
	var gap_stats_to_mods: String = _gap_spaces_for_px(style.s(gap_stats_to_mods_px, ui_scale), body_px)
	var gap_mod_cols: String = _gap_spaces_for_px(style.s(gap_mod_cols_px, ui_scale), body_px)
	var gap_mods_to_relics: String = _gap_spaces_for_px(style.s(gap_mods_to_relics_px, ui_scale), body_px) if not relic_names.is_empty() else ""
	var gap_relic_cols: String = _gap_spaces_for_px(style.s(gap_relic_cols_px, ui_scale), body_px)

	var bb: String = ""

	# Header
	bb += "[center][font_size=%d][color=%s][b]Run Summary[/b][/color][/font_size][/center]\n" % [header_px, _to_bb(gold)]
	if show_subtitle:
		bb += "[center][font_size=%d][color=%s]%s[/color][/font_size][/center]\n" % [body_px, _to_bb(dim), subtitle_text]

	bb += "[font_size=%d]" % body_px

	# OUTER TABLE: stats | gap | mods | gap | relics (5 columns if relics exist, 3 otherwise)
	var table_cols: int = 5 if not relic_names.is_empty() else 3
	bb += "[table=%d]\n" % table_cols

	bb += "[cell]\n"
	bb += "[color=%s][b]World:[/b][/color] %d\n" % [_to_bb(dim), world_i]
	bb += "[color=%s][b]Floor:[/b][/color] %d\n" % [_to_bb(dim), floor_i]
	bb += "[color=%s][b]Dice Range:[/b][/color] %d–%d\n" % [_to_bb(dim), dmin, dmax]
	bb += "[/cell]\n"

	bb += "[cell]%s[/cell]\n" % gap_stats_to_mods

	bb += "[cell]\n"
	bb += "[color=%s][b]Active Modifiers[/b][/color]\n" % _to_bb(gold)

	if mod_names.is_empty():
		bb += "[color=%s]None[/color]\n" % _to_bb(dim)
	else:
		var mod_inner_cols: int = (mod_cols * 2) - 1
		bb += "[table=%d]\n" % mod_inner_cols

		for r in range(per_col):
			for c in range(mod_cols):
				var idx: int = c * per_col + r

				bb += "[cell]"
				if idx < mod_names.size():
					bb += "• [color=%s]%s[/color]" % [_to_bb(dim), mod_names[idx]]
				bb += "[/cell]\n"

				if c != mod_cols - 1:
					bb += "[cell]%s[/cell]\n" % gap_mod_cols

		bb += "[/table]\n"

	bb += "[/cell]\n"

	# Relics column (only if relics exist)
	if not relic_names.is_empty():
		bb += "[cell]%s[/cell]\n" % gap_mods_to_relics

		bb += "[cell]\n"
		bb += "[color=%s][b]Relics[/b][/color]\n" % _to_bb(gold)

		var relic_inner_cols: int = (relic_cols * 2) - 1
		bb += "[table=%d]\n" % relic_inner_cols

		for r in range(per_col):
			for c in range(relic_cols):
				var idx: int = c * per_col + r

				bb += "[cell]"
				if idx < relic_names.size():
					bb += "• [color=%s]%s[/color]" % [_to_bb(dim), relic_names[idx]]
				bb += "[/cell]\n"

				if c != relic_cols - 1:
					bb += "[cell]%s[/cell]\n" % gap_relic_cols

		bb += "[/table]\n"

		bb += "[/cell]\n"

	bb += "[/table]\n"
	bb += "[/font_size]\n"

	_text.clear()
	_text.parse_bbcode(bb)
	_text.scroll_to_line(0)
	_text.scroll_active = false

func _estimate_text_width_px(char_count: int, font_px: int) -> float:
	return float(char_count) * float(font_px) * 0.56

func _gap_spaces_for_px(px: float, body_px: int) -> String:
	var char_w: float = maxf(1.0, float(body_px) * 0.55)
	var count: int = clampi(int(ceil(px / char_w)), 1, 50)
	var s := ""
	for _i in range(count):
		s += "\u00A0"
	return s

func _to_bb(c: Color) -> String:
	return "#%02X%02X%02X%02X" % [
		int(c.r * 255.0),
		int(c.g * 255.0),
		int(c.b * 255.0),
		int(c.a * 255.0)
	]

func _get_active_modifier_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if RunStateSingleton == null:
		return out

	if RunStateSingleton.has_method("get_active_modifier_ids"):
		var v = RunStateSingleton.call("get_active_modifier_ids")
		if v is Array:
			for x in v:
				out.append(StringName(x))
			return out

	for prop_name in ["active_modifier_ids", "applied_modifier_ids", "run_modifier_ids", "modifiers_applied"]:
		if prop_name in RunStateSingleton:
			var arr = RunStateSingleton.get(prop_name)
			if arr is Array:
				for x in arr:
					out.append(StringName(x))
				return out

	return out

func _pretty_modifier_name(id: StringName) -> String:
	var s: String = String(id)
	for p in ["m_", "b_", "d_", "x_", "g_", "bg_"]:
		if s.begins_with(p):
			s = s.substr(p.length())
			break
	s = s.replace("_", " ")
	var words: PackedStringArray = s.split(" ", false)
	for i in range(words.size()):
		var w: String = words[i]
		if w.length() > 0:
			words[i] = w.left(1).to_upper() + w.substr(1)
	return " ".join(words)

func _get_owned_relic_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if RunStateSingleton == null:
		return out
	
	if RunStateSingleton.has_method("get_owned_relic_ids"):
		var v = RunStateSingleton.call("get_owned_relic_ids")
		if v is Array:
			for x in v:
				out.append(StringName(x))
			return out
	
	if "owned_relic_ids" in RunStateSingleton:
		var arr = RunStateSingleton.get("owned_relic_ids")
		if arr is Array:
			for x in arr:
				out.append(StringName(x))
			return out
	
	return out

func _get_relic_display_name(id: StringName) -> String:
	if RelicDatabaseSingleton == null:
		return String(id)
	
	if RelicDatabaseSingleton.has_method("get_relic"):
		var relic_data = RelicDatabaseSingleton.call("get_relic", id)
		if relic_data != null and "display_name" in relic_data:
			return String(relic_data.get("display_name"))
	
	return String(id)
