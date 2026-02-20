# res://scripts/PlatformResizable.gd
@tool
extends Node2D
class_name PlatformResizable

@export var texture: Texture2D

@export_range(16, 10000, 1) var width_px: int = 443:
	set(v):
		width_px = max(1, v)
		_apply()

@export_range(16, 10000, 1) var height_px: int = 420:
	set(v):
		height_px = max(1, v)
		_apply()

@export_range(1, 10000, 1) var collision_height_px: int = 64:
	set(v):
		collision_height_px = max(1, v)
		_apply()

@export var collision_offset_y_px: float = 0.0:
	set(v):
		collision_offset_y_px = v
		_apply()

@export var patch_left: int = 80:
	set(v): patch_left = max(0, v); _apply()
@export var patch_right: int = 80:
	set(v): patch_right = max(0, v); _apply()
@export var patch_top: int = 120:
	set(v): patch_top = max(0, v); _apply()
@export var patch_bottom: int = 40:
	set(v): patch_bottom = max(0, v); _apply()

@onready var _visual: NinePatchRect = $Visual as NinePatchRect
@onready var _col_shape: CollisionShape2D = $Body/Collision as CollisionShape2D

func _ready() -> void:
	_apply()

func _notification(what: int) -> void:
	# Keep editor view in sync when you tweak values.
	if Engine.is_editor_hint() and what == NOTIFICATION_TRANSFORM_CHANGED:
		_apply()

func _apply() -> void:
	if _visual == null or _col_shape == null:
		return

	# --- VISUAL ---
	_visual.texture = texture
	_visual.size = Vector2(float(width_px), float(height_px))

	# Center the visual on this Node2D origin (nice for placement).
	_visual.position = Vector2(-_visual.size.x * 0.5, -_visual.size.y * 0.5)

	# --- COLLISION ---
	var rect := _col_shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		_col_shape.shape = rect

	rect.size = Vector2(float(width_px), float(collision_height_px))

	# Center collision too, then apply optional Y offset.
	_col_shape.position = Vector2(0.0, collision_offset_y_px)

	_visual.patch_margin_left = patch_left
	_visual.patch_margin_right = patch_right
	_visual.patch_margin_top = patch_top
	_visual.patch_margin_bottom = patch_bottom

	_visual.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_visual.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
