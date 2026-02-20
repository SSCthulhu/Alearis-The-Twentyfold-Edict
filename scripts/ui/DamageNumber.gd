# res://scripts/DamageNumber.gd
extends Node2D
class_name DamageNumber

@export var float_speed: float = 40.0
@export var lifetime: float = 0.6

@export var font_scale: float = 1.6
@export var default_color: Color = Color(1, 0.85, 0.2)

# Special colors
@export var shock_color: Color = Color(0.35, 0.75, 1.0) # blue
@export var bleed_color: Color = Color(0.85, 0.1, 0.1)  # blood red

# NEW: crit styling
@export var crit_color: Color = Color(1.0, 0.35, 0.35) # punchy red (tweak to taste)
@export var crit_scale_mult: float = 1.35            # multiplies on top of font_scale
@export var crit_punch: bool = true
@export var crit_punch_extra: float = 0.18           # extra scale during punch
@export var crit_punch_time: float = 0.08

const TAG_SHOCK: StringName = &"shock"
const TAG_BLEED: StringName = &"bleed"
const TAG_CRIT: StringName = &"crit"

func setup(amount: int) -> void:
	# Back-compat: normal damage
	setup_text(str(amount), default_color, 1.0)

# NEW: one unified entry point (recommended)
func setup_damage(amount: int, tag: StringName = &"", is_crit: bool = false) -> void:
	setup_amount_tagged(amount, tag, is_crit)

func setup_amount_tagged(amount: int, tag: StringName, is_crit: bool = false) -> void:
	var c: Color = default_color
	var scale_mult: float = 1.0

	# Crit overrides look (you can choose to still tint by tag if you prefer)
	if is_crit or tag == TAG_CRIT:
		c = crit_color
		scale_mult = crit_scale_mult
	else:
		match tag:
			TAG_SHOCK:
				c = shock_color
			TAG_BLEED:
				c = bleed_color
			_:
				c = default_color

	setup_text(str(amount), c, scale_mult)

	if (is_crit or tag == TAG_CRIT) and crit_punch:
		_apply_crit_punch()

func setup_text(text: String, color: Color = Color(1, 1, 1), scale_mult: float = 1.0) -> void:
	var lbl: Label = $Label
	lbl.text = text

	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.reset_size()

	var half: Vector2 = lbl.size * 0.5
	lbl.position = -half
	lbl.pivot_offset = half

	lbl.scale = Vector2(font_scale, font_scale) * scale_mult
	lbl.modulate = color

func _apply_crit_punch() -> void:
	var lbl: Label = $Label
	var base: Vector2 = lbl.scale
	var up: Vector2 = base * (1.0 + maxf(crit_punch_extra, 0.0))

	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "scale", up, maxf(crit_punch_time, 0.01))
	t.tween_property(lbl, "scale", base, maxf(crit_punch_time, 0.01))

func _ready() -> void:
	var t := create_tween()
	t.tween_property(self, "position:y", position.y - float_speed, lifetime)
	t.parallel().tween_property(self, "modulate:a", 0.0, lifetime)
	t.finished.connect(queue_free)

# Compatibility for DamageNumberEmitter (preferred call)
func setup_amount_tagged_crit(amount: int, tag: StringName, is_crit: bool) -> void:
	setup_amount_tagged(amount, tag, is_crit)
