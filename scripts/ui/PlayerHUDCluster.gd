@tool
extends Control
class_name PlayerHUDCluster

@export var style: HUDStyle
@export var design_resolution: Vector2 = Vector2(2560, 1440)

@export var safe_margin_px: float = 22.0
@export var element_gap_px: float = 8.0

# Right column (bars + abilities) sizes (INSPECTOR DRIVES THESE)
@export var cluster_width_px: float = 380.0
@export var ultimate_height_px: float = 44.0
@export var health_height_px: float = 54.0
@export var abilities_height_px: float = 44.0

# Left dodge pillar column (spans full height of the stack)
@export var dodge_pillar_width_px: float = 120.0
@export var dodge_gap_px: float = 12.0

# Only when true can HUDStyle override the inspector sizes (runtime only)
@export var style_overrides_sizes: bool = false

var ui_scale: float = 1.0
var _last_viewport_size: Vector2 = Vector2.ZERO

var ultimate_hud: PlayerUltimateHUD
var health_hud: PlayerHealthHUD
var ability_hud: PlayerAbilityHUD
var dodge_hud: DodgeChargeHUD

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anchor to bottom-right
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0

	_ensure_children()
	_apply_layout()
	set_process(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()

func _process(_dt: float) -> void:
	var vs := get_viewport_rect().size
	if vs != _last_viewport_size:
		_apply_layout()

	# In-editor: reflect inspector changes immediately
	if Engine.is_editor_hint():
		_apply_layout()

# -----------------------------
# Public API used by PlayerHUDWiring
# -----------------------------
func set_health(current: float, max_value: float) -> void:
	if health_hud != null:
		health_hud.set_health(current, max_value)

func set_shield(current_shield: float, max_hp_ref: float) -> void:
	if health_hud != null:
		health_hud.set_shield(current_shield, max_hp_ref)

func set_health_text_mode(mode: int) -> void:
	if health_hud != null:
		health_hud.set_text_mode(mode)

func set_ultimate_cooldown(remaining: float, duration: float) -> void:
	if ultimate_hud != null:
		ultimate_hud.set_cooldown(remaining, duration)

func set_dodge_state(cur: int, mx: int, next_left: float, total: float) -> void:
	if dodge_hud != null:
		dodge_hud.set_dodge_state(cur, mx, next_left, total)

# -----------------------------
# Children
# -----------------------------
func _ensure_children() -> void:
	ultimate_hud = _ensure_child("PlayerUltimateHUD", PlayerUltimateHUD) as PlayerUltimateHUD
	health_hud   = _ensure_child("PlayerHealthHUD",   PlayerHealthHUD) as PlayerHealthHUD
	ability_hud  = _ensure_child("PlayerAbilityHUD",  PlayerAbilityHUD) as PlayerAbilityHUD
	dodge_hud    = _ensure_child("DodgeChargeHUD",    DodgeChargeHUD) as DodgeChargeHUD

	# Push style (safe: children will ignore in editor)
	if ultimate_hud != null:
		ultimate_hud.set_style(style)
	if health_hud != null:
		health_hud.set_style(style)
	if ability_hud != null:
		ability_hud.set_style(style)
	if dodge_hud != null:
		dodge_hud.set_style(style)

func _ensure_child(node_name: String, expected_class: Variant) -> Control:
	var n := get_node_or_null(node_name)

	# Replace if wrong class
	if n != null:
		var ok := false
		match node_name:
			"PlayerUltimateHUD":
				ok = (n is PlayerUltimateHUD)
			"PlayerHealthHUD":
				ok = (n is PlayerHealthHUD)
			"PlayerAbilityHUD":
				ok = (n is PlayerAbilityHUD)
			"DodgeChargeHUD":
				ok = (n is DodgeChargeHUD)
			_:
				ok = (n is Control)

		if not ok:
			n.queue_free()
			n = null

	if n == null:
		var inst: Control = (expected_class as Variant).new() as Control
		inst.name = node_name
		inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(inst)
		return inst

	return n as Control

# -----------------------------
# Layout
# -----------------------------
func _apply_layout() -> void:
	_last_viewport_size = get_viewport_rect().size
	var vs := _last_viewport_size

	_ensure_children()
	if ultimate_hud == null or health_hud == null or ability_hud == null or dodge_hud == null:
		return

	# Scale (do NOT call style methods in editor)
	if (not Engine.is_editor_hint()) and style != null and style.has_method("ui_scale_for_viewport"):
		ui_scale = float(style.call("ui_scale_for_viewport", vs, design_resolution.y))
	else:
		ui_scale = clamp(vs.y / design_resolution.y, 0.75, 1.35)

	var safe: float = safe_margin_px * ui_scale
	var gap: float = element_gap_px * ui_scale
	var dodge_gap: float = dodge_gap_px * ui_scale

	# Inspector-driven sizes (source of truth)
	var right_w: float = cluster_width_px * ui_scale
	var ult_h: float = ultimate_height_px * ui_scale
	var hp_h: float = health_height_px * ui_scale
	var ab_h: float = abilities_height_px * ui_scale
	var dodge_w: float = dodge_pillar_width_px * ui_scale

	# Optional style override (runtime only)
	if (not Engine.is_editor_hint()) and style_overrides_sizes and style != null and style.has_method("s"):
		# Only do these if your HUDStyle actually defines the properties
		if style.get("cluster_width") != null:
			right_w = float(style.call("s", float(style.get("cluster_width")), ui_scale))
		if style.get("ultimate_height") != null:
			ult_h = float(style.call("s", float(style.get("ultimate_height")), ui_scale))
		if style.get("health_height") != null:
			hp_h = float(style.call("s", float(style.get("health_height")), ui_scale))
		if style.get("abilities_height") != null:
			ab_h = float(style.call("s", float(style.get("abilities_height")), ui_scale))
		if style.get("dodge_pillar_width") != null:
			dodge_w = float(style.call("s", float(style.get("dodge_pillar_width")), ui_scale))

	var total_h: float = ult_h + gap + hp_h + gap + ab_h
	var total_w: float = dodge_w + dodge_gap + right_w

	# Bottom-right offsets (anchored)
	offset_left = -safe - total_w
	offset_top = -safe - total_h
	offset_right = -safe
	offset_bottom = -safe

	# Left column: dodge spans full height
	dodge_hud.position = Vector2(0.0, 0.0)
	dodge_hud.size = Vector2(dodge_w, total_h)
	dodge_hud.set_ui_scale(ui_scale)

	# Right column: stacked bars + abilities
	var x_right: float = dodge_w + dodge_gap
	var y: float = 0.0

	ultimate_hud.position = Vector2(x_right, y)
	ultimate_hud.size = Vector2(right_w, ult_h)
	ultimate_hud.set_ui_scale(ui_scale)
	y += ult_h + gap

	health_hud.position = Vector2(x_right, y)
	health_hud.size = Vector2(right_w, hp_h)
	health_hud.set_ui_scale(ui_scale)
	y += hp_h + gap

	ability_hud.position = Vector2(x_right, y)
	ability_hud.size = Vector2(right_w, ab_h)
	ability_hud.set_ui_scale(ui_scale)
