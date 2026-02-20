extends Resource
class_name HUDStyle

# -----------------------------
# Fonts (match BossHUDTop approach)
# -----------------------------
@export var font_title: Font
@export var font_body: Font
@export var font_small: Font

@export var font_title_size: int = 18
@export var font_body_size: int = 14
@export var font_small_size: int = 12

# -----------------------------
# Geometry (design-time values, scaled at runtime)
# -----------------------------
@export var border_px: float = 2.0
@export var corner_radius: float = 10.0

@export var pad_outer: float = 18.0
@export var pad_inner: float = 10.0
@export var gap: float = 8.0

@export var shadow_px: float = 0.0 # keep 0 for your flat premium look; you can add later

# Component sizing (design-time @ 2560x1440)
@export var health_height: float = 34.0
@export var ultimate_height: float = 14.0
@export var abilities_height: float = 44.0

@export var cluster_width: float = 520.0

# -----------------------------
# Colors (premium flat + gold accents)
# -----------------------------
@export var frame_bg: Color = Color(0.07, 0.07, 0.09, 0.92)
@export var frame_border: Color = Color(0.18, 0.18, 0.22, 1.0)

@export var gold_accent: Color = Color(0.86, 0.72, 0.33, 1.0)
@export var gold_dim: Color = Color(0.58, 0.49, 0.25, 1.0)

@export var fill_hp: Color = Color(0.85, 0.10, 0.12, 1.0)
@export var fill_hp_low: Color = Color(0.92, 0.27, 0.22, 1.0)

# Abilities (separate from HP so HP can be red)
@export var fill_ability_ready: Color = Color(0.23, 0.78, 0.41, 1.0) # original HP green

@export var fill_ult: Color = Color(0.86, 0.72, 0.33, 1.0)
@export var fill_cd: Color = Color(0.40, 0.45, 0.55, 1.0)

@export var text: Color = Color(0.95, 0.95, 0.97, 1.0)
@export var text_dim: Color = Color(0.70, 0.72, 0.78, 1.0)

# -----------------------------
# Scaling helpers
# -----------------------------
func ui_scale_for_viewport(viewport_size: Vector2, design_height: float = 1440.0) -> float:
	if viewport_size.y <= 0.0:
		return 1.0
	# Uniform scale by height; clamped for readability
	return clamp(viewport_size.y / design_height, 0.75, 1.35)

func s(value: float, ui_scale: float) -> float:
	# Generic scaler (keeps floats)
	return value * ui_scale

func si(value: float, ui_scale: float, min_value: int = 1) -> int:
	# Integer scaler, good for pixel-aligned borders
	return maxi(min_value, roundi(value * ui_scale))

func font_size_title(ui_scale: float) -> int:
	return maxi(10, roundi(float(font_title_size) * ui_scale))

func font_size_body(ui_scale: float) -> int:
	return maxi(9, roundi(float(font_body_size) * ui_scale))

func font_size_small(ui_scale: float) -> int:
	return maxi(8, roundi(float(font_small_size) * ui_scale))
