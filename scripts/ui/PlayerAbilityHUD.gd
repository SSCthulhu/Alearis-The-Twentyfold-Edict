extends Control
class_name PlayerAbilityHUD

@export var style: HUDStyle

# Ability IDs (must match Combat.get_cooldown_left keys)
@export var light_id: StringName = &"light"
@export var heavy_id: StringName = &"heavy"
@export var defend_id: StringName = &"defend"
@export var ult_id: StringName = &"ultimate" # optional

# Fallback totals (used until we learn a spike)
@export var light_total_fallback: float = 0.8
@export var heavy_total_fallback: float = 2.0
@export var defend_total_fallback: float = 60.0

@export var show_ultimate_tile: bool = false

# Layout
@export var tile_gap_px: float = 8.0
@export var dodge_block_w_px: float = 90.0

var _ui_scale: float = 1.0

var _tiles: Dictionary = {} # StringName -> CooldownStripeHUD

# Learned totals for better accuracy
var _learned_total: Dictionary = {
	&"light": 0.0,
	&"heavy": 0.0,
	&"defend": 0.0,
	&"ultimate": 0.0,
}

func _style_ready() -> bool:
	# In the editor, exported Resources can be placeholder instances.
	# Even if has_method() returns true, calling can still error.
	if style == null:
		return false
	if Engine.is_editor_hint():
		return false
	return true

func _s(px: float) -> float:
	if _style_ready():
		return float(style.call("s", px, _ui_scale))
	return px * _ui_scale


func set_style(v: HUDStyle) -> void:
	style = v
	for k in _tiles.keys():
		(_tiles[k] as CooldownStripeHUD).set_style(style)
	queue_redraw()

func set_ui_scale(v: float) -> void:
	_ui_scale = maxf(v, 0.01)
	for k in _tiles.keys():
		(_tiles[k] as CooldownStripeHUD).set_ui_scale(_ui_scale)
	_apply_layout()

func set_cooldown(key: StringName, left: float, total_fallback: float) -> void:
	var t: float = _get_effective_total(key, total_fallback, left)
	if _tiles.has(key):
		(_tiles[key] as CooldownStripeHUD).set_cooldown(left, t)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_children()
	_apply_layout()

func reset_learned_totals() -> void:
	for k in _learned_total.keys():
		_learned_total[k] = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()

func _create_children() -> void:
	# Light
	var light: CooldownStripeHUD = CooldownStripeHUD.new()
	light.name = "LightCD"
	light.style = style
	light.label = "LIGHT"
	add_child(light)
	_tiles[light_id] = light

	# Heavy
	var heavy: CooldownStripeHUD = CooldownStripeHUD.new()
	heavy.name = "HeavyCD"
	heavy.style = style
	heavy.label = "HEAVY"
	add_child(heavy)
	_tiles[heavy_id] = heavy

	# Defend
	var defend: CooldownStripeHUD = CooldownStripeHUD.new()
	defend.name = "DefendCD"
	defend.style = style
	defend.label = "DEF"
	add_child(defend)
	_tiles[defend_id] = defend

	# Optional ult tile (usually OFF since you have ult bar above)
	if show_ultimate_tile:
		var ult: CooldownStripeHUD = CooldownStripeHUD.new()
		ult.name = "UltCD"
		ult.style = style
		ult.label = "ULT"
		add_child(ult)
		_tiles[ult_id] = ult

func _apply_layout() -> void:
	# Prevent placeholder-resource spam while editing scenes (PlayerHUDCluster is @tool)
	if Engine.is_editor_hint() and not _style_ready():
		return

	var gap: float = _s(tile_gap_px)


	var keys: Array[StringName] = [light_id, heavy_id, defend_id]
	if show_ultimate_tile:
		keys.append(ult_id)

	var tiles_count: int = keys.size()
	var usable_w: float = maxf(0.0, size.x)

	var tile_w: float = 0.0
	if tiles_count > 0:
		tile_w = (usable_w - gap * float(tiles_count - 1)) / float(tiles_count)
	tile_w = maxf(tile_w, 10.0)

	var x: float = 0.0
	for k in keys:
		var tile_node: Variant = _tiles.get(k, null)
		if tile_node == null:
			continue
		var tile: Control = tile_node as Control
		tile.position = Vector2(x, 0.0)
		tile.size = Vector2(tile_w, size.y)
		x += tile_w + gap



func _get_effective_total(key: StringName, fallback_total: float, cur_left: float) -> float:
	var learned: float = float(_learned_total.get(key, 0.0))

	# Learn once from spike (left becomes big)
	if cur_left > 0.0 and learned <= 0.0:
		_learned_total[key] = maxf(cur_left, maxf(fallback_total, 0.01))
		learned = float(_learned_total[key])

	if learned > 0.0:
		return learned
	return maxf(fallback_total, 0.01)
	
func set_ability_name(key: StringName, display_name: String) -> void:
	if _tiles.has(key):
		(_tiles[key] as CooldownStripeHUD).set_label(display_name)
