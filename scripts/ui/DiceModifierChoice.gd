extends CanvasLayer
class_name DiceModifierChoice

signal modifier_chosen()

@export var pause_game: bool = true
@export var boss_group: StringName = &"boss"

@export var card_width_design: float = 360.0
@export var card_height_design: float = 320.0 # was 280.0
@export var active_panel_width_design: float = 320.0

@export var card_block_top_inset_px: float = 14.0

@export var header_title_boost_px: int = 18  # was effectively +10
@export var header_range_boost_px: int = 8   # was effectively +4

@export var style: HUDStyle
@export var design_height: float = 1440.0

@onready var _overlay: ColorRect = $Overlay
@onready var _root: Control = $Root
@onready var _title: Label = $Root/PanelTitle
@onready var _range: Label = $Root/PanelRange

@onready var _card_a: ModifierCard = $Root/CardA # -2
@onready var _card_b: ModifierCard = $Root/CardB # -1
@onready var _card_c: ModifierCard = $Root/CardC # 0
@onready var _card_d: ModifierCard = $Root/CardD # +1
@onready var _card_e: ModifierCard = $Root/CardE # +2

@onready var _active_panel: Panel = $Root/ActiveModsPanel
@onready var _active_margin: MarginContainer = $Root/ActiveModsPanel/Margin
@onready var _active_text: RichTextLabel = $Root/ActiveModsPanel/Margin/ActiveModsText

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _options: Array[Dictionary] = []
var _is_open: bool = false

var _pending_floor: int = 0
var _source_chest: Node = null

# ---------------------------------------------------------
# Effect pools
# ---------------------------------------------------------
const MINOR_BLESSINGS := [
	&"b_fleetfoot", &"b_sharpened", &"b_coolheaded", &"b_heavyhand", &"b_clean_cuts",
	&"b_bulwark_start", &"b_surge_on_kill", &"b_perfect_step", &"b_stagger_training", &"b_orb_handler"
]

const MAJOR_BLESSINGS := [
	&"m_berserker_pact", &"m_ironblood", &"m_flow_engine", &"m_executioner", &"m_shockwave",
	&"m_second_wind", &"m_predator", &"m_guardian_shell", &"m_orb_overcharge", &"m_cleanse_mastery"
]

const MINOR_DANGERS := [
	&"d_overcharged_foes", &"d_reinforced_foes", &"d_hunted", &"d_sniper_winds", &"d_elite_presence"
]

const MAJOR_DANGERS := [
	&"x_brutal_foes", &"x_unstable_ground", &"x_cursed_recovery", &"x_marked", &"x_elite_pack"
]

const GREED_PLUS1 := [
	&"g_loot_quality_small", &"g_shop_extra_slot", &"g_shop_free_reroll",
	&"g_boss_currency", &"g_rare_relic_chance_small"
]

const GREED_PLUS2 := [
	&"bg_boss_extra_choice", &"bg_loot_quality_big", &"bg_shop_discount",
	&"bg_free_dice_tool", &"bg_rare_relic_chance_big"
]

func _ready() -> void:
	_rng.randomize()

	for c in [_card_a, _card_b, _card_c, _card_d, _card_e]:
		if c != null:
			c.disabled = false

	# Make UI work while paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Overlay default look (you can tweak in editor too)
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.mouse_filter = Control.MOUSE_FILTER_STOP

	# Active modifiers: should not block clicks, should support bbcode and wrapping.
	if _active_panel != null:
		_active_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _active_margin != null:
		_active_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Active modifiers list should not eat clicks (same rule as cards)
	if _active_text != null:
		_active_text.bbcode_enabled = true
		_active_text.scroll_active = true
		_active_text.fit_content = false
		_active_text.clip_contents = true
		_active_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_active_text.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Cards should run while paused and use style
	for c in [_card_a, _card_b, _card_c, _card_d, _card_e]:
		if c != null:
			c.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
			c.set_style(style)

	# Make sure labels render above overlay
	_title.text = "Choose a Modifier"
	visible = false

	# Connect presses
	if _card_a != null and not _card_a.pressed.is_connected(_on_pick_a): _card_a.pressed.connect(_on_pick_a)
	if _card_b != null and not _card_b.pressed.is_connected(_on_pick_b): _card_b.pressed.connect(_on_pick_b)
	if _card_c != null and not _card_c.pressed.is_connected(_on_pick_c): _card_c.pressed.connect(_on_pick_c)
	if _card_d != null and not _card_d.pressed.is_connected(_on_pick_d): _card_d.pressed.connect(_on_pick_d)
	if _card_e != null and not _card_e.pressed.is_connected(_on_pick_e): _card_e.pressed.connect(_on_pick_e)

	_apply_active_panel_style()
	_apply_text_style()
	_apply_layout()

	get_viewport().size_changed.connect(func() -> void:
		_apply_text_style()
		_apply_layout()
		_apply_active_panel_style()
		# Resize pass for active panel text
		call_deferred("_recalc_active_mods_min_size")
	)

	_refresh_ui()
	_refresh_active_mods()
	call_deferred("_recalc_active_mods_min_size")

func _apply_active_panel_style() -> void:
	if style == null or _active_panel == null:
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ui_scale: float = style.ui_scale_for_viewport(vp, design_height)

	var border_px: int = style.si(style.border_px, ui_scale, 1)
	var radius: int = maxi(0, roundi(style.s(style.corner_radius, ui_scale)))

	# Match your card vibe: same bg, faint gold border, rounded corners
	var sb := StyleBoxFlat.new()
	sb.bg_color = style.frame_bg # keeps same opacity look you already like
	sb.border_color = style.gold_dim # faint gold
	sb.border_width_left = border_px
	sb.border_width_top = border_px
	sb.border_width_right = border_px
	sb.border_width_bottom = border_px
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.anti_aliasing = true

	_active_panel.add_theme_stylebox_override("panel", sb)

	# Optional: make the inside padding match your other UI spacing
	if _active_margin != null:
		var pad: int = style.si(style.pad_inner, ui_scale, 10)
		_active_margin.add_theme_constant_override("margin_left", pad)
		_active_margin.add_theme_constant_override("margin_right", pad)
		_active_margin.add_theme_constant_override("margin_top", maxi(0, pad - style.si(8, ui_scale, 0)))
		_active_margin.add_theme_constant_override("margin_bottom", pad)

# ---------------------------------------------------------
# Open from chest interaction
# ---------------------------------------------------------
func open_from_chest(floor_number: int, chest: Node) -> void:
	if _is_open:
		return

	_pending_floor = floor_number
	_source_chest = chest

	_is_open = true
	_generate_options()
	_refresh_ui()
	_refresh_active_mods()

	visible = true

	# Pause boss combat BEFORE pausing tree
	_set_boss_combat_paused(true)

	if pause_game:
		get_tree().paused = true

func close() -> void:
	visible = false
	set_process(false) # optional, if you don't need processing while closed

	if pause_game:
		get_tree().paused = false

	_set_boss_combat_paused(false)

	_is_open = false
	_pending_floor = 0
	_source_chest = null


# ---------------------------------------------------------
# UI refresh => populate cards
# ---------------------------------------------------------
func _refresh_ui() -> void:
	if RunStateSingleton != null:
		_range.text = "Dice Range: %d–%d" % [RunStateSingleton.dice_min, RunStateSingleton.dice_max]
	else:
		_range.text = "Dice Range: ?–?"

	if _options.size() < 5:
		return

	# A=-2, B=-1, C=0, D=+1, E=+2
	_apply_card(_card_a, _options[0])
	_apply_card(_card_b, _options[1])
	_apply_card(_card_c, _options[2])
	_apply_card(_card_d, _options[3])
	_apply_card(_card_e, _options[4])

	_apply_layout()
	_refresh_active_mods()

func _apply_card(card: ModifierCard, opt: Dictionary) -> void:
	if card == null:
		return

	var value: int = int(opt.get("value", 0))
	var header: String = String(opt.get("header", ""))
	var footer: String = String(opt.get("footer", ""))

	var lines: Array[String] = []
	var effect_line: String = String(opt.get("effect_line", ""))
	var greed_line: String = String(opt.get("greed_line", ""))
	if effect_line != "":
		lines.append(effect_line)
	if greed_line != "":
		lines.append(greed_line)

	# Build tag like: "+1 (10–11)" or "-2 (8–10)" or "0 (10–10)"
	var sign_text: String = ("+%d" % value) if value > 0 else ("%d" % value)

	var pr: Vector2i = _preview_range_for_value(value)
	var range_text: String = ""
	if RunStateSingleton != null:
		range_text = " (%d–%d)" % [pr.x, pr.y]

	var tag_text: String = sign_text + range_text

	card.set_style(style)
	card.set_card_data(tag_text, header, footer, lines)

func _preview_range_for_value(value: int) -> Vector2i:
	var cur_min: int = 0
	var cur_max: int = 0

	if RunStateSingleton != null:
		cur_min = int(RunStateSingleton.dice_min)
		cur_max = int(RunStateSingleton.dice_max)
	else:
		return Vector2i(0, 0)

	var new_min := cur_min
	var new_max := cur_max

	# Match your rules:
	#  +value => expands max
	#  -value => expands downwards (min decreases)
	if value > 0:
		new_max += value
	elif value < 0:
		new_min += value

	# Clamp using your hard limits if present
	var hard_min: int = 1
	var hard_max: int = 99
	if RunStateSingleton != null:
		hard_min = int(RunStateSingleton.dice_hard_min)
		hard_max = int(RunStateSingleton.dice_hard_max)

	new_min = clampi(new_min, hard_min, hard_max)
	new_max = clampi(new_max, hard_min, hard_max)

	# Fix inverted ranges
	if new_min > new_max:
		var t := new_min
		new_min = new_max
		new_max = t

	return Vector2i(new_min, new_max)

# ---------------------------------------------------------
# Active modifiers panel
# ---------------------------------------------------------
func _refresh_active_mods() -> void:
	if _active_panel == null or _active_text == null or style == null:
		return

	var ids: Array[StringName] = _get_active_modifier_ids()

	var gold := style.gold_accent
	var dim := style.text_dim
	var white := style.text

	var ui_scale: float = style.ui_scale_for_viewport(get_viewport().get_visible_rect().size, design_height)
	var header_px: int = style.font_size_title(ui_scale) + style.si(4, ui_scale, 0)

	var bb := ""
	bb += "[center][font_size=%d][color=%s][b]Current Modifiers[/b][/color][/font_size][/center]\n" % [header_px, _to_bb(gold)]
	bb += "[center][color=%s]Pick to stack or diversify.[/color][/center]\n\n" % _to_bb(dim)
	
	if ids.is_empty():
		bb += "[center][color=%s]None yet.[/color][/center]\n" % _to_bb(dim)
		_active_text.clear()
		_active_text.parse_bbcode(bb)
		call_deferred("_recalc_active_mods_min_size")
		return

	var counts: Dictionary = {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1

	var rows: Array[String] = []
	for id in counts.keys():
		var desc: String = _describe_effect(id)
		if desc == "":
			continue

		var title := ""
		var detail := desc
		var idx := desc.find(":")
		if idx != -1:
			title = desc.substr(0, idx + 1)
			detail = desc.substr(idx + 1, desc.length() - (idx + 1)).strip_edges()
		else:
			title = String(id) + ":"
			detail = desc

		var n: int = int(counts[id])
		var stack := (" [color=%s](x%d)[/color]" % [_to_bb(dim), n]) if n > 1 else ""

		rows.append(
			"[center][color=%s][b]%s[/b][/color]%s[/center]\n[center][color=%s]%s[/color][/center]" %
			[_to_bb(white), title, stack, _to_bb(dim), detail]
		)

	rows.sort()
	for r in rows:
		bb += r + "\n\n"

	_active_text.clear()
	_active_text.parse_bbcode(bb)
	call_deferred("_recalc_active_mods_min_size")

func _recalc_active_mods_min_size() -> void:
	# If we're being freed or not in the tree, bail early.
	if not is_inside_tree():
		return

	if _active_panel == null or _active_margin == null or _active_text == null or style == null:
		return

	# Viewport can be null during scene shutdown / retry transitions.
	var vp := get_viewport()
	if vp == null:
		return

	# Let font/layout settle (but still safe if we get freed mid-wait)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return

	# Only compute scale if viewport is valid
	var ui_scale: float = style.ui_scale_for_viewport(vp.get_visible_rect().size, design_height)

	# Ensure the text can't collapse too narrow; height is governed by panel and scroll.
	var panel_w: float = _active_panel.size.x
	if panel_w <= 1.0:
		return

	_active_text.custom_minimum_size = Vector2(maxf(style.s(180.0, ui_scale), panel_w * 0.70), 0.0)

	# MarginContainer is a Container => this is valid
	_active_margin.queue_sort()

func _get_active_modifier_ids() -> Array[StringName]:
	var out: Array[StringName] = []

	if RunStateSingleton == null:
		return out

	# 1) Preferred: method you add on RunStateSingleton
	if RunStateSingleton.has_method("get_active_modifier_ids"):
		var v = RunStateSingleton.call("get_active_modifier_ids")
		if v is Array:
			for x in v:
				out.append(StringName(x))
			return out

	# 2) Fallbacks: likely property names
	for prop_name in ["active_modifier_ids", "applied_modifier_ids", "run_modifier_ids", "modifiers_applied"]:
		if prop_name in RunStateSingleton:
			var arr = RunStateSingleton.get(prop_name)
			if arr is Array:
				for x in arr:
					out.append(StringName(x))
				return out

	return out

func _to_bb(c: Color) -> String:
	return "#%02X%02X%02X%02X" % [
		int(c.r * 255.0),
		int(c.g * 255.0),
		int(c.b * 255.0),
		int(c.a * 255.0)
	]

# ---------------------------------------------------------
# Generate options (same logic as before)
# ---------------------------------------------------------
func _generate_options() -> void:
	_options.clear()

	var neg2_effect: StringName = _pick_unique(MAJOR_BLESSINGS, [])
	var neg1_effect: StringName = _pick_unique(MINOR_BLESSINGS, [neg2_effect])

	var pos1_danger: StringName = _pick_unique(MINOR_DANGERS, [])
	var pos2_danger: StringName = _pick_unique(MAJOR_DANGERS, [pos1_danger])

	var greed1: StringName = _pick_unique(GREED_PLUS1, [])
	var greed2: StringName = _pick_unique(GREED_PLUS2, [])

	_options.append(_make_option(-2, neg2_effect, &"", "Condense", "Major Blessing"))
	_options.append(_make_option(-1, neg1_effect, &"", "Condense", "Minor Blessing"))
	_options.append(_make_option(0, &"", &"", "Stabilize", "Full Heal + Cleanse"))
	_options[2]["effect_line"] = "Rest Hero: Take a moment to breathe."
	_options.append(_make_option(+1, pos1_danger, greed1, "Expand +1", "Affliction + Greed"))
	_options.append(_make_option(+2, pos2_danger, greed2, "Expand +2", "Major Affliction + Big Greed"))

func _make_option(value: int, effect_id: StringName, greed_id: StringName, header: String, footer: String) -> Dictionary:
	return {
		"value": value,
		"effect_id": effect_id,
		"greed_id": greed_id,
		"header": header,
		"footer": footer,
		"effect_line": _describe_effect(effect_id),
		"greed_line": _describe_effect(greed_id)
	}

func _pick_unique(pool: Array, avoid: Array) -> StringName:
	if pool.is_empty():
		return &""
	for _i in range(20):
		var pick: StringName = pool[_rng.randi_range(0, pool.size() - 1)]
		if not avoid.has(pick):
			return pick
	return StringName(pool[0])

# ---------------------------------------------------------
# Descriptions (your mapping)
# ---------------------------------------------------------
func _describe_effect(id: StringName) -> String:
	if id == &"":
		return ""

	match id:
		&"b_fleetfoot": return "Fleetfoot: +10% Movement Speed"
		&"b_sharpened": return "Sharpened: +12% dmg to non-boss enemies"
		&"b_coolheaded": return "Coolheaded: -15% cooldowns"
		&"b_heavyhand": return "Heavy Hand: +18% Heavy dmg"
		&"b_clean_cuts": return "Clean Cuts: Light Attacks apply Bleed (3 stacks max)"
		&"b_bulwark_start": return "Bulwark Start: Begin each floor with a +15% HP shield"
		&"b_surge_on_kill": return "Surge on Kill: Killing an enemy restores 2% Health (cap at 10% pe floor)"
		&"b_perfect_step": return "Perfect Step: Perfect Dodge grants +15% dmg for 3s (cooldown 5s)"
		&"b_stagger_training": return "Stagger Training: +20% stagger dmg to boss"
		&"b_orb_handler": return "Orb Handler: +15% charge speed"

		&"m_berserker_pact": return "Berserker Pact: +25% dmg, +10% dmg taken"
		&"m_ironblood": return "Ironblood: +20% max HP, -10% dmg taken"
		&"m_flow_engine": return "Flow Engine: -25% cooldowns, +10% ult gain"
		&"m_executioner": return "Executioner: Heavy deals 35% increased dmg vs enemies below 50% HP"
		&"m_shockwave": return "Shockwave: Every 6s, next Heavy attack creates a short range AOE shockwave"
		&"m_second_wind": return "Second Wind: Cheat death once per world, upon death revert to 25% HP and gain invuln for 2s"
		&"m_predator": return "Predator: +20% Movement Speed for 4s upon killing an enemy"
		&"m_guardian_shell": return "Guardian Shell: Defensive Ability also grants a 20% max HP shield"
		&"m_orb_overcharge": return "Orb Overcharge: +3s to Boss DPS window, boss gains 5% dmg after each DPS phase"
		&"m_cleanse_mastery": return "Cleanse Mastery: Defensive Ability cleanses all debuffs and gain 2s immunity to new debuffs"

		&"d_overcharged_foes": return "Overcharged Foes: Enemies deal +12% damage"
		&"d_reinforced_foes": return "Reinforced Foes: Enemies have +18% HP"
		&"d_hunted": return "Hunted: Hazard rises +15% faster"
		&"d_sniper_winds": return "Sniper Winds: Enemy projectiles travel 15% faster"
		&"d_elite_presence": return "Elite Presence: +1 elite spawns"

		&"x_brutal_foes": return "Brutal Foes: Enemies deal +22% damage"
		&"x_unstable_ground": return "Unstable Ground: Hazard +30% faster"
		&"x_cursed_recovery": return "Cursed Recovery: Healing reduced by 40%"
		&"x_marked": return "Marked: Getting hit applies Marked for 6s, you take 15% damage"
		&"x_elite_pack": return "Elite Pack: +2 elites spawn"

		&"g_loot_quality_small": return "Greed: +10% loot quality"
		&"g_shop_extra_slot": return "Greed: Shop offers +1 extra relic choice"
		&"g_shop_free_reroll": return "Greed: +1 free shop reroll token"
		&"g_boss_currency": return "Greed: Boss drops 10% more currency"
		&"g_rare_relic_chance_small": return "Greed: 5% chance for Boss to drop rare Relic"

		&"bg_boss_extra_choice": return "Big Greed: Boss drops +1 extra relic choice"
		&"bg_loot_quality_big": return "Big Greed: +25% loot quality"
		&"bg_shop_discount": return "Big Greed: 15% Discount from shop"
		&"bg_free_dice_tool": return "Big Greed: Gain 1 Dice Tool for free"
		&"bg_rare_relic_chance_big": return "Big Greed: 15% chance for Boss to drop rare Relic"

		_:
			return "Effect: %s" % String(id)

# ---------------------------------------------------------
# Apply selection
# ---------------------------------------------------------
func _apply_option(opt: Dictionary) -> void:
	var value: int = int(opt.get("value", 0))
	var effect_id: StringName = opt.get("effect_id", &"")
	var greed_id: StringName = opt.get("greed_id", &"")

	#print("[DiceChoice] ===== MODIFIER PICKED =====")
	#print("[DiceChoice] value=%d, effect=%s, greed=%s" % [value, effect_id, greed_id])
	
	if effect_id == &"d_elite_presence" or effect_id == &"x_elite_pack":
		pass

	if RunStateSingleton != null:
		RunStateSingleton.apply_floor_modifier_payload(value, effect_id, greed_id)
		
		if effect_id == &"d_elite_presence" or effect_id == &"x_elite_pack":
			pass
	else:
		pass

	# Update active list immediately (so you can see it was applied)
	_refresh_active_mods()

	# Do NOT delete the chest; just lock it open.
	if _source_chest != null and is_instance_valid(_source_chest):
		if _source_chest.has_method("lock_open_state"):
			_source_chest.call("lock_open_state")

	close()
	modifier_chosen.emit()

func _on_pick_a() -> void: if _options.size() >= 1: _apply_option(_options[0])
func _on_pick_b() -> void: if _options.size() >= 2: _apply_option(_options[1])
func _on_pick_c() -> void: if _options.size() >= 3: _apply_option(_options[2])
func _on_pick_d() -> void: if _options.size() >= 4: _apply_option(_options[3])
func _on_pick_e() -> void: if _options.size() >= 5: _apply_option(_options[4])

# ---------------------------------------------------------
# Styling + Layout
# ---------------------------------------------------------
func _apply_text_style() -> void:
	if style == null:
		return

	var ui_scale: float = style.ui_scale_for_viewport(get_viewport().get_visible_rect().size, design_height)

	_title.add_theme_color_override("font_color", style.gold_accent)
	var title_px: int = style.font_size_title(ui_scale) + style.si(header_title_boost_px, ui_scale, 0)
	_title.add_theme_font_size_override("font_size", title_px)
	if style.font_title != null:
		_title.add_theme_font_override("font", style.font_title)

	_range.add_theme_color_override("font_color", style.text_dim)
	var range_px: int = style.font_size_body(ui_scale) + style.si(header_range_boost_px, ui_scale, 0)
	_range.add_theme_font_size_override("font_size", range_px)
	if style.font_body != null:
		_range.add_theme_font_override("font", style.font_body)

func _apply_layout() -> void:
	if style == null:
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ui_scale: float = style.ui_scale_for_viewport(vp, design_height)

	var card_w: float = style.s(card_width_design, ui_scale)
	var card_h: float = style.s(card_height_design, ui_scale)
	var gap_x: float = style.s(18.0, ui_scale)
	var gap_y: float = style.s(18.0, ui_scale)

	var title_gap: float = style.s(10.0, ui_scale)
	var header_to_cards_gap: float = style.s(14.0, ui_scale)

	for c in [_card_a, _card_b, _card_c, _card_d, _card_e]:
		if c != null:
			c.custom_minimum_size = Vector2(card_w, card_h)
			c.size = Vector2(card_w, card_h)

	var top_w: float = (card_w * 3.0) + (gap_x * 2.0)
	var block_w: float = top_w
	var block_h: float = (card_h * 2.0) + gap_y

	var title_size: Vector2 = _title.get_minimum_size()
	var range_size: Vector2 = _range.get_minimum_size()
	_title.size = title_size
	_range.size = range_size

	var header_h: float = title_size.y + title_gap + range_size.y + header_to_cards_gap
	var total_h: float = header_h + block_h

	var origin_x: float = (vp.x - block_w) * 0.5
	var origin_y: float = (vp.y - total_h) * 0.5

	var center_x: float = origin_x + (block_w * 0.5)
	_title.position = Vector2(center_x - (title_size.x * 0.5), origin_y)
	_range.position = Vector2(center_x - (range_size.x * 0.5), origin_y + title_size.y + title_gap)

	var top_y: float = origin_y + header_h + style.s(card_block_top_inset_px, ui_scale)

	_card_b.position = Vector2(origin_x + (card_w + gap_x) * 0.0, top_y)
	_card_c.position = Vector2(origin_x + (card_w + gap_x) * 1.0, top_y)
	_card_d.position = Vector2(origin_x + (card_w + gap_x) * 2.0, top_y)

	var bottom_y: float = top_y + card_h + gap_y
	_card_a.position = Vector2(origin_x + (card_w + gap_x) * 0.5, bottom_y)
	_card_e.position = Vector2(origin_x + (card_w + gap_x) * 1.5, bottom_y)

	# --- Active modifiers panel (left side of the card block) ---
	if _active_panel != null:
		var panel_w: float = style.s(active_panel_width_design, ui_scale)
		var panel_h: float = block_h  # match the two-row card block height

		_active_panel.size = Vector2(panel_w, panel_h)

		var panel_gap: float = style.s(18.0, ui_scale)
		_active_panel.position = Vector2(origin_x - panel_w - panel_gap, top_y)

		if _active_panel.position.x < style.s(10.0, ui_scale):
			_active_panel.visible = false
		else:
			_active_panel.visible = true
			# Force inner controls to actually fill this panel (prevents “vertical wrapping”)
			_layout_active_panel(panel_w, panel_h)

	# After layout, re-measure active text
	call_deferred("_recalc_active_mods_min_size")

func _layout_active_panel(panel_w: float, _panel_h: float) -> void:
	if _active_panel == null:
		return

	# ActiveModsPanel itself is manually sized elsewhere (_active_panel.size = ...)
	# So children can just FULL_RECT fill it.

	if _active_margin != null:
		_active_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		_active_margin.position = Vector2.ZERO
		# Do NOT set size when anchors stretch.
		# Give it padding via offsets instead:
		var pad: float = style.s(14.0, style.ui_scale_for_viewport(get_viewport().get_visible_rect().size, design_height)) if style != null else 14.0
		_active_margin.offset_left = pad
		_active_margin.offset_top = pad
		_active_margin.offset_right = -pad
		_active_margin.offset_bottom = -pad

	if _active_text != null:
		_active_text.set_anchors_preset(Control.PRESET_FULL_RECT)
		_active_text.position = Vector2.ZERO
		# Do NOT set size when anchors stretch.

		# Prevent the “vertical letters” look by ensuring it can’t collapse too narrow.
		_active_text.custom_minimum_size = Vector2(maxf(140.0, panel_w * 0.75), 0.0)

# ---------------------------------------------------------
# Boss pause helper (unchanged)
# ---------------------------------------------------------
func _set_boss_combat_paused(p: bool) -> void:
	var boss: Node = get_tree().get_first_node_in_group(boss_group)
	if boss != null and boss.has_method("set_combat_paused"):
		boss.call("set_combat_paused", p)
		return

	var b2: Node = _find_first_boss(get_tree().current_scene)
	if b2 != null and b2.has_method("set_combat_paused"):
		b2.call("set_combat_paused", p)

func _find_first_boss(n: Node) -> Node:
	if n == null:
		return null
	if n.get_class() == "BossController":
		return n
	var as_boss := n as BossController
	if as_boss != null:
		return as_boss

	for child in n.get_children():
		var found := _find_first_boss(child)
		if found != null:
			return found
	return null
