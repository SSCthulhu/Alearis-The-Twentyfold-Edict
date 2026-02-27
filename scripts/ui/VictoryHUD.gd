extends CanvasLayer
class_name VictoryHUD

signal relic_chosen(index: int)
signal proceed_pressed()
signal input_lock_changed(locked: bool)

@export var pause_game: bool = true # (kept, but you’re not pausing anymore)
@export var style: HUDStyle
@export var design_height: float = 1440.0

# Layout knobs (match DiceModifierChoice vibe)
@export var card_width_design: float = 360.0
@export var card_height_design: float = 320.0
@export var card_gap_x_design: float = 18.0

@export var header_title_boost_px: int = 18
@export var header_sub_boost_px: int = 8

# How many relic choices BEFORE modifiers
@export var base_relic_choices: int = 3

# Modifier IDs that increase relic choices
@export var extra_relic_choice_modifier_ids: Array[StringName] = [
	&"bg_boss_extra_choice"
]

# Open animation polish
@export var open_fade_time: float = 0.18
@export var open_scale_from: float = 0.98
@export var open_delay: float = 0.06

# RunSummary placement (Victory: under relic row)
@export var summary_gap_y_design: float = 18.0
@export var summary_width_cap_pct: float = 0.92 # don’t span whole screen width

# Loaded Fate row placement
@export var loaded_fate_gap_y_design: float = 10.0
@export var loaded_fate_row_height_design: float = 44.0

@onready var _overlay: ColorRect = $Overlay
@onready var _root: Control = $Root
@onready var _title: Label = $Root/PanelTitle
@onready var _subtitle: Label = $Root/PanelRange

# ✅ Reusable RunSummaryPanel instance
@onready var _run_summary: RunSummaryPanel = $Root/RunSummaryPanel

var _is_open: bool = false
var _tween: Tween
var _cards: Array[ModifierCard] = []

# Rolled choices for this victory screen open
var _rolled_relics: Array[RelicData] = []

# Cached count for this open (after clamping to what actually rolled)
var _visible_choice_count: int = 0

# -----------------------------
# Loaded Fate runtime UI (no scene edits)
# -----------------------------
var _loaded_fate_row: HBoxContainer = null
var _loaded_fate_spin: SpinBox = null
var _loaded_fate_btn: Button = null
var _loaded_fate_label: Label = null

var _pending_loaded_fate_choice: bool = false
var _desired_choice_count_cache: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS

	_force_full_rect(_overlay)
	_force_full_rect(_root)

	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.mouse_filter = Control.MOUSE_FILTER_STOP

	_title.text = "WORLD COMPLETE"
	_subtitle.text = "Choose your relic"

	# Collect cards ONCE
	_cards.clear()
	for n in ["CardA","CardB","CardC","CardD","CardE","CardF","CardG"]:
		var c := _root.get_node_or_null(n)
		if c != null and c is ModifierCard:
			_cards.append(c as ModifierCard)

	_connect_card_presses()

	_build_loaded_fate_ui()

	# Configure run summary panel instance
	if _run_summary != null:
		_run_summary.visible = false
		_run_summary.style = style
		_run_summary.design_height = design_height
		_run_summary.show_subtitle = true
		_run_summary.subtitle_text = "Pick a relic from the choices above to continue."

	visible = false

	get_viewport().size_changed.connect(func() -> void:
		_force_full_rect(_overlay)
		_force_full_rect(_root)
		_apply_text_style()
		_apply_layout()
	)

	if style == null:
		push_error("[VictoryUI] style is NULL. Assign your HUDStyle resource in the Inspector.")
		return

	_apply_text_style()
	_apply_layout()

# -----------------------------
# Public API
# -----------------------------
func open_victory() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true

	_force_full_rect(_overlay)
	_force_full_rect(_root)

	# ✅ DO NOT PAUSE. Lock gameplay input instead.
	input_lock_changed.emit(true)

	_apply_text_style()

	var desired_count: int = _get_relic_choice_count()
	_desired_choice_count_cache = desired_count

	# If Loaded Fate is available, let player choose roll first
	var loaded_fate_available: bool = false
	if RunStateSingleton != null and RunStateSingleton.has_method("is_loaded_fate_available_this_world"):
		loaded_fate_available = bool(RunStateSingleton.call("is_loaded_fate_available_this_world"))

	if loaded_fate_available:
		_pending_loaded_fate_choice = true

		var mn: int = int(RunStateSingleton.dice_min)
		var mx: int = int(RunStateSingleton.dice_max)

		if _loaded_fate_row != null:
			_loaded_fate_spin.min_value = mn
			_loaded_fate_spin.max_value = mx
			_loaded_fate_spin.value = clampi(int(RunStateSingleton.call("get_victory_reward_roll")), mn, mx)
			_loaded_fate_row.visible = true

		pass

		# Disable cards until locked (show placeholder)
		_rolled_relics.clear()
		_visible_choice_count = 0
		_show_choice_cards(0)

		# Summary messaging
		if _run_summary != null:
			_run_summary.style = style
			_run_summary.design_height = design_height
			_run_summary.show_subtitle = true
			_run_summary.visible = true
			_run_summary.subtitle_text = "Loaded Fate: choose your roll, then lock it to reveal relic choices."

		_apply_layout()
		_play_open_anim()
		return

	# Normal path
	_pending_loaded_fate_choice = false
	if _loaded_fate_row != null:
		_loaded_fate_row.visible = false

	# ✅ Reward roll used to select relic band for THIS victory screen
	var reward_roll: int = int(RunStateSingleton.call("get_victory_reward_roll"))
	var _forced_reward_roll: int = int(RunStateSingleton.forced_reward_roll) if ("forced_reward_roll" in RunStateSingleton) else -1

	_roll_relic_choices(desired_count, reward_roll)

	# Clamp visible choices to what actually rolled
	_visible_choice_count = mini(desired_count, _rolled_relics.size())

	# Populate cards with rolled relics (or disabled placeholders if none)
	_show_choice_cards(_visible_choice_count)

	# Show + configure run summary
	if _run_summary != null:
		_run_summary.style = style
		_run_summary.design_height = design_height
		_run_summary.show_subtitle = true
		_run_summary.visible = true

		if _visible_choice_count <= 0:
			_run_summary.subtitle_text = "No relics available (database empty or all relics owned)."
		else:
			_run_summary.subtitle_text = "Pick a relic from the choices above to continue."

	_apply_layout()
	_play_open_anim()

func close() -> void:
	visible = false
	_is_open = false

	_pending_loaded_fate_choice = false
	if _loaded_fate_row != null:
		_loaded_fate_row.visible = false

	_rolled_relics.clear()
	_visible_choice_count = 0

	if _run_summary != null:
		_run_summary.visible = false

	# ✅ Re-enable input when closing
	input_lock_changed.emit(false)

# -----------------------------
# Loaded Fate UI
# -----------------------------
func _build_loaded_fate_ui() -> void:
	_loaded_fate_row = HBoxContainer.new()
	_loaded_fate_row.name = "LoadedFateRow"
	_loaded_fate_row.visible = false
	_loaded_fate_row.mouse_filter = Control.MOUSE_FILTER_STOP

	_loaded_fate_label = Label.new()
	_loaded_fate_label.text = "Loaded Fate:"
	_loaded_fate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_loaded_fate_spin = SpinBox.new()
	_loaded_fate_spin.step = 1
	_loaded_fate_spin.allow_lesser = false
	_loaded_fate_spin.allow_greater = false
	_loaded_fate_spin.rounded = true
	_loaded_fate_spin.mouse_filter = Control.MOUSE_FILTER_STOP

	_loaded_fate_btn = Button.new()
	_loaded_fate_btn.text = "Lock Roll"
	_loaded_fate_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	_loaded_fate_row.add_child(_loaded_fate_label)
	_loaded_fate_row.add_child(_loaded_fate_spin)
	_loaded_fate_row.add_child(_loaded_fate_btn)

	_root.add_child(_loaded_fate_row)

	if not _loaded_fate_btn.pressed.is_connected(_on_loaded_fate_lock_pressed):
		_loaded_fate_btn.pressed.connect(_on_loaded_fate_lock_pressed)

func _on_loaded_fate_lock_pressed() -> void:
	if not _pending_loaded_fate_choice:
		return
	if RunStateSingleton == null:
		return
	if not RunStateSingleton.has_method("consume_loaded_fate_roll"):
		push_warning("[VictoryUI] RunStateSingleton missing consume_loaded_fate_roll(chosen_roll).")
		return

	var chosen: int = int(_loaded_fate_spin.value)
	var final_roll: int = int(RunStateSingleton.call("consume_loaded_fate_roll", chosen))

	_pending_loaded_fate_choice = false
	if _loaded_fate_row != null:
		_loaded_fate_row.visible = false

	_roll_relic_choices(_desired_choice_count_cache, final_roll)

	_visible_choice_count = mini(_desired_choice_count_cache, _rolled_relics.size())
	_show_choice_cards(_visible_choice_count)

	if _run_summary != null:
		if _visible_choice_count <= 0:
			_run_summary.subtitle_text = "No relics available (database empty or all relics owned)."
		else:
			_run_summary.subtitle_text = "Pick a relic from the choices above to continue."

	_apply_layout()

# -----------------------------
# Cards: connect
# -----------------------------
func _connect_card_presses() -> void:
	for i in range(_cards.size()):
		var card := _cards[i]
		if card == null:
			continue

		card.process_mode = Node.PROCESS_MODE_ALWAYS
		card.mouse_filter = Control.MOUSE_FILTER_STOP

		if not card.pressed.is_connected(_on_card_pressed):
			card.pressed.connect(_on_card_pressed.bind(i))

func _on_card_pressed(i: int) -> void:
	if _visible_choice_count <= 0:
		push_warning("[VictoryUI] No relic choices available; selection ignored.")
		return

	if i < 0 or i >= _visible_choice_count:
		push_warning("[VictoryUI] Pressed card index out of visible range: %d (visible=%d)" % [i, _visible_choice_count])
		return

	if not _apply_relic_choice(i):
		return

	relic_chosen.emit(i)

	close()
	call_deferred("_emit_proceed")

func _emit_proceed() -> void:
	proceed_pressed.emit()

# -----------------------------
# Relic rolling + applying
# -----------------------------
func _roll_relic_choices(choice_count: int, reward_roll: int) -> void:
	_rolled_relics.clear()

	if RunStateSingleton == null:
		push_warning("[VictoryUI] RunStateSingleton is NULL; cannot roll relics.")
		return

	if RelicDatabaseSingleton == null:
		push_error("[VictoryUI] RelicDatabaseSingleton is NULL. Add RelicDatabase.gd as an AutoLoad.")
		return

	# Deterministic RNG based on reward_roll
	var rng: RandomNumberGenerator
	if RunStateSingleton.has_method("make_rng_for_victory_relic_choices_for_roll"):
		rng = RunStateSingleton.call("make_rng_for_victory_relic_choices_for_roll", reward_roll) as RandomNumberGenerator
	elif RunStateSingleton.has_method("make_rng_for_victory_relic_choices"):
		rng = RunStateSingleton.call("make_rng_for_victory_relic_choices") as RandomNumberGenerator
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var owned: Array[StringName] = []
	if RunStateSingleton.has_method("get_owned_relic_ids"):
		var v = RunStateSingleton.call("get_owned_relic_ids")
		if v is Array:
			for x in v:
				owned.append(StringName(x))

	var rare_bonus: float = 0.0
	if "rare_relic_bonus" in RunStateSingleton:
		rare_bonus = float(RunStateSingleton.get("rare_relic_bonus"))

	# Target band
	var target_band: int = int(RelicData.Band.CORE)
	if RunStateSingleton.has_method("get_target_relic_band_from_roll"):
		target_band = int(RunStateSingleton.call("get_target_relic_band_from_roll", reward_roll))
	elif RunStateSingleton.has_method("get_target_relic_band_from_last_roll"):
		target_band = int(RunStateSingleton.call("get_target_relic_band_from_last_roll"))

	pass

	_rolled_relics = RelicDatabaseSingleton.roll_choices(rng, owned, choice_count, rare_bonus, target_band)

	if _rolled_relics.is_empty():
		push_warning("[VictoryUI] Rolled 0 relics. Check RelicDatabaseSingleton.relics is populated and RelicData.is_valid() passes.")

func _apply_relic_choice(i: int) -> bool:
	if RunStateSingleton == null:
		return false

	if i < 0 or i >= _rolled_relics.size():
		push_warning("[VictoryUI] Choice index out of range: %d (rolled=%d)" % [i, _rolled_relics.size()])
		return false

	var relic: RelicData = _rolled_relics[i]
	if relic == null:
		push_warning("[VictoryUI] Rolled relic is NULL at index %d" % i)
		return false

	if RunStateSingleton.has_method("can_add_relic"):
		if not bool(RunStateSingleton.call("can_add_relic")):
			push_warning("[VictoryUI] Cannot add relic: RunState relic inventory is full.")
			return false

	if RunStateSingleton.has_method("add_relic"):
		var ok: bool = bool(RunStateSingleton.call("add_relic", relic.id))
		if not ok:
			push_warning("[VictoryUI] add_relic failed for id=%s" % String(relic.id))
			return false
	else:
		push_warning("[VictoryUI] RunStateSingleton missing add_relic(id).")
		return false

	if RunStateSingleton.has_method("advance_world"):
		pass
		print("[VictoryUI] Before advance_world: world_index = ", RunStateSingleton.world_index)
		RunStateSingleton.call("advance_world")
		print("[VictoryUI] After advance_world: world_index = ", RunStateSingleton.world_index)
		pass
	else:
		if RunStateSingleton.has_method("clear_world_modifiers"):
			RunStateSingleton.call("clear_world_modifiers")

	return true

# -----------------------------
# Choice count logic
# -----------------------------
func _get_relic_choice_count() -> int:
	var count: int = base_relic_choices

	var active_ids: Array[StringName] = _get_active_modifier_ids()
	for id in active_ids:
		if extra_relic_choice_modifier_ids.has(id):
			count += 1

	count = mini(count, 7)
	count = clampi(count, 1, maxi(1, _cards.size()))
	return count

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

# -----------------------------
# Show/hide cards (ModifierCard content)
# -----------------------------
func _show_choice_cards(n: int) -> void:
	var show_count: int = maxi(n, 0)

	for i in range(_cards.size()):
		var card := _cards[i]
		if card == null:
			continue

		var show_i: bool = i < maxi(show_count, 1 if show_count == 0 and i == 0 else show_count)
		if show_count == 0:
			show_i = (i == 0)

		card.visible = show_i
		card.disabled = true if show_count == 0 else not show_i

		if not show_i:
			continue

		if show_count == 0:
			card.set_style(style)
			card.set_card_data("RELIC", "No Relics Available", "Database Empty", ["Lock a roll (Loaded Fate) or add RelicData resources to the database."])
			continue

		var relic: RelicData = null
		if i < _rolled_relics.size():
			relic = _rolled_relics[i]

		if relic == null:
			card.set_style(style)
			card.set_card_data("RELIC", "Unknown Relic", "Common", ["No relic data found."])
			continue

		var tag_text: String = _rarity_tag(relic.rarity)
		var header: String = relic.display_name
		var footer: String = _rarity_footer(relic.rarity)
		var lines: Array[String] = relic.description_lines.duplicate()

		card.set_style(style)
		card.set_card_data(tag_text, header, footer, lines)

func _rarity_tag(r: int) -> String:
	match r:
		RelicData.Rarity.COMMON: return "COMMON"
		RelicData.Rarity.RARE: return "RARE"
		RelicData.Rarity.EPIC: return "EPIC"
		RelicData.Rarity.LEGENDARY: return "LEGENDARY"
		_: return "RELIC"

func _rarity_footer(r: int) -> String:
	match r:
		RelicData.Rarity.COMMON: return "Common"
		RelicData.Rarity.RARE: return "Rare"
		RelicData.Rarity.EPIC: return "Epic"
		RelicData.Rarity.LEGENDARY: return "Legendary"
		_: return "Relic"

# -----------------------------
# Styling + Layout
# -----------------------------
func _apply_text_style() -> void:
	if style == null:
		return

	var ui_scale: float = style.ui_scale_for_viewport(get_viewport().get_visible_rect().size, design_height)

	_title.add_theme_color_override("font_color", style.gold_accent)
	var title_px: int = style.font_size_title(ui_scale) + style.si(header_title_boost_px, ui_scale, 0)
	_title.add_theme_font_size_override("font_size", title_px)
	if style.font_title != null:
		_title.add_theme_font_override("font", style.font_title)

	_subtitle.add_theme_color_override("font_color", style.text_dim)
	var sub_px: int = style.font_size_body(ui_scale) + style.si(header_sub_boost_px, ui_scale, 0)
	_subtitle.add_theme_font_size_override("font_size", sub_px)
	if style.font_body != null:
		_subtitle.add_theme_font_override("font", style.font_body)

	# Loaded Fate row styling (use body font)
	if _loaded_fate_label != null:
		if style.font_body != null:
			_loaded_fate_label.add_theme_font_override("font", style.font_body)
		_loaded_fate_label.add_theme_color_override("font_color", style.text_dim)

func _apply_layout() -> void:
	if style == null:
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ui_scale: float = style.ui_scale_for_viewport(vp, design_height)

	var card_w: float = style.s(card_width_design, ui_scale)
	var card_h: float = style.s(card_height_design, ui_scale)
	var gap_x: float = style.s(card_gap_x_design, ui_scale)

	var title_gap: float = style.s(10.0, ui_scale)
	var header_to_cards_gap: float = style.s(14.0, ui_scale)

	var loaded_fate_gap_y: float = style.s(loaded_fate_gap_y_design, ui_scale)
	var loaded_fate_row_h: float = style.s(loaded_fate_row_height_design, ui_scale)

	var visible_count: int = maxi(_visible_choice_count, 1 if _visible_choice_count == 0 else _visible_choice_count)

	# Header sizes
	var title_size: Vector2 = _title.get_minimum_size()
	var sub_size: Vector2 = _subtitle.get_minimum_size()
	_title.size = title_size
	_subtitle.size = sub_size

	# If Loaded Fate row visible, reserve extra space between header and cards
	var has_loaded_fate_row: bool = (_loaded_fate_row != null and _loaded_fate_row.visible)

	var extra_header_h: float = 0.0
	if has_loaded_fate_row:
		extra_header_h = loaded_fate_gap_y + loaded_fate_row_h

	var header_h: float = title_size.y + title_gap + sub_size.y + header_to_cards_gap + extra_header_h

	# Size + hide/show cards
	for i in range(_cards.size()):
		var c := _cards[i]
		if c == null:
			continue

		var show_i: bool = i < visible_count
		if _visible_choice_count == 0:
			show_i = (i == 0)

		c.visible = show_i
		c.disabled = true if _visible_choice_count == 0 else not show_i
		if show_i:
			c.custom_minimum_size = Vector2(card_w, card_h)
			c.size = Vector2(card_w, card_h)

	# Row width of visible cards
	var row_w: float = (card_w * float(visible_count)) + (gap_x * float(maxi(0, visible_count - 1)))

	# Cards start Y
	var top_y: float = ((vp.y - (header_h + card_h)) * 0.5) + header_h
	var origin_x: float = (vp.x - row_w) * 0.5
	var origin_y: float = top_y - header_h

	# Header centered
	var center_x: float = vp.x * 0.5
	_title.position = Vector2(center_x - title_size.x * 0.5, origin_y)
	_subtitle.position = Vector2(center_x - sub_size.x * 0.5, origin_y + title_size.y + title_gap)

	# Place Loaded Fate row (centered) under subtitle
	if has_loaded_fate_row:
		var row_y: float = origin_y + title_size.y + title_gap + sub_size.y + header_to_cards_gap + loaded_fate_gap_y
		_loaded_fate_row.position = Vector2(center_x - (_loaded_fate_row.get_combined_minimum_size().x * 0.5), row_y)
		_loaded_fate_row.custom_minimum_size = Vector2(0, loaded_fate_row_h)

	# Place visible cards
	for i in range(visible_count):
		var c := _cards[i]
		if c == null:
			continue
		if _visible_choice_count == 0 and i != 0:
			continue
		c.position = Vector2(origin_x + (card_w + gap_x) * float(i), top_y)

	# RunSummaryPanel under cards
	if _run_summary != null:
		if not _run_summary.visible:
			return

		_run_summary.style = style
		_run_summary.design_height = design_height
		_run_summary.show_subtitle = true

		var panel_gap_y: float = style.s(summary_gap_y_design, ui_scale)
		var panel_top_y: float = top_y + card_h + panel_gap_y

		var max_cap_px: float = vp.x * summary_width_cap_pct
		_run_summary.layout_under_row(origin_x, row_w, panel_top_y, max_cap_px)

# -----------------------------
# Open animation (less jarring)
# -----------------------------
func _play_open_anim() -> void:
	_overlay.modulate.a = 0.0
	_root.modulate.a = 0.0
	_root.scale = Vector2(open_scale_from, open_scale_from)

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)

	if open_delay > 0.0:
		_tween.tween_interval(open_delay)

	_tween.tween_property(_overlay, "modulate:a", 1.0, open_fade_time)
	_tween.parallel().tween_property(_root, "modulate:a", 1.0, open_fade_time)
	_tween.parallel().tween_property(_root, "scale", Vector2(1.0, 1.0), open_fade_time)

# -----------------------------
# Helpers
# -----------------------------
func _force_full_rect(c: Control) -> void:
	if c == null:
		return
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
