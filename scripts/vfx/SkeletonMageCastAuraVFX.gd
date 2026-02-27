extends Node2D

signal drain_finished

const AURA_CLIP_SHADER: Shader = preload("res://shaders/vfx/aura_clip_box.gdshader")

@export var aura_v1_path: NodePath = ^"AuraV1"
@export var aura_v2_path: NodePath = ^"AuraV2"
@export var aura_v3b_path: NodePath = ^"AuraV3B"
@export var aura_v3loop_path: NodePath = ^"AuraV3Loop"

@export_range(1, 16, 1) var aura_v1_hframes: int = 8
@export_range(1, 16, 1) var aura_v1_vframes: int = 8
@export_range(1.0, 120.0, 1.0) var aura_v1_fps: float = 24.0

@export_range(1, 16, 1) var aura_v2_hframes: int = 8
@export_range(1, 16, 1) var aura_v2_vframes: int = 8
@export_range(1.0, 120.0, 1.0) var aura_v2_fps: float = 24.0

@export_range(1, 16, 1) var aura_v3b_hframes: int = 8
@export_range(1, 16, 1) var aura_v3b_vframes: int = 8
@export_range(1.0, 120.0, 1.0) var aura_v3b_fps: float = 24.0

@export_range(1, 16, 1) var aura_v3loop_hframes: int = 8
@export_range(1, 16, 1) var aura_v3loop_vframes: int = 8
@export_range(1.0, 120.0, 1.0) var aura_v3loop_fps: float = 24.0

@export_range(0.1, 3.0, 0.01) var aura_v1_size_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.01) var aura_v2_size_multiplier: float = 1.08
@export_range(0.1, 3.0, 0.01) var aura_v3b_size_multiplier: float = 1.02
@export_range(0.1, 3.0, 0.01) var aura_v3loop_size_multiplier: float = 1.1
@export var clip_to_enemy_box: bool = true

class AuraAnimState:
	var sprite: Sprite2D = null
	var fps: float = 24.0
	var total_frames: int = 1
	var cursor: float = 0.0


var _state_v1: AuraAnimState = AuraAnimState.new()
var _state_v2: AuraAnimState = AuraAnimState.new()
var _state_v3b: AuraAnimState = AuraAnimState.new()
var _state_v3loop: AuraAnimState = AuraAnimState.new()
var _ending: bool = false


func _ready() -> void:
	_state_v1.sprite = get_node_or_null(aura_v1_path) as Sprite2D
	_state_v2.sprite = get_node_or_null(aura_v2_path) as Sprite2D
	_state_v3b.sprite = get_node_or_null(aura_v3b_path) as Sprite2D
	_state_v3loop.sprite = get_node_or_null(aura_v3loop_path) as Sprite2D

	_configure_sprite(_state_v1.sprite, aura_v1_hframes, aura_v1_vframes)
	_configure_sprite(_state_v2.sprite, aura_v2_hframes, aura_v2_vframes)
	_configure_sprite(_state_v3b.sprite, aura_v3b_hframes, aura_v3b_vframes)
	_configure_sprite(_state_v3loop.sprite, aura_v3loop_hframes, aura_v3loop_vframes)
	_state_v1.fps = aura_v1_fps
	_state_v2.fps = aura_v2_fps
	_state_v3b.fps = aura_v3b_fps
	_state_v3loop.fps = aura_v3loop_fps
	_state_v1.total_frames = maxi(1, aura_v1_hframes * aura_v1_vframes)
	_state_v2.total_frames = maxi(1, aura_v2_hframes * aura_v2_vframes)
	_state_v3b.total_frames = maxi(1, aura_v3b_hframes * aura_v3b_vframes)
	_state_v3loop.total_frames = maxi(1, aura_v3loop_hframes * aura_v3loop_vframes)

	set_process(true)


func _process(delta: float) -> void:
	var done_v1: bool = _advance_state(_state_v1, delta)
	var done_v2: bool = _advance_state(_state_v2, delta)
	var done_v3b: bool = _advance_state(_state_v3b, delta)
	var done_v3loop: bool = _advance_state(_state_v3loop, delta)

	if _ending and done_v1 and done_v2 and done_v3b and done_v3loop:
		drain_finished.emit()
		queue_free()


func end_cast_gracefully() -> void:
	_ending = true


func stop_immediately() -> void:
	queue_free()


func set_target_diameter(diameter: float) -> void:
	_fit_sprite_to_diameter(_state_v1.sprite, aura_v1_hframes, aura_v1_vframes, diameter, aura_v1_size_multiplier)
	_fit_sprite_to_diameter(_state_v2.sprite, aura_v2_hframes, aura_v2_vframes, diameter, aura_v2_size_multiplier)
	_fit_sprite_to_diameter(_state_v3b.sprite, aura_v3b_hframes, aura_v3b_vframes, diameter, aura_v3b_size_multiplier)
	_fit_sprite_to_diameter(_state_v3loop.sprite, aura_v3loop_hframes, aura_v3loop_vframes, diameter, aura_v3loop_size_multiplier)


func _configure_sprite(sprite: Sprite2D, hframes: int, vframes: int) -> void:
	if sprite == null:
		return
	sprite.centered = true
	sprite.hframes = maxi(1, hframes)
	sprite.vframes = maxi(1, vframes)
	sprite.frame = 0
	if clip_to_enemy_box:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = AURA_CLIP_SHADER
		mat.set_shader_parameter("half_extent_uv", Vector2(0.5, 0.5))
		sprite.material = mat


func _advance_state(state: AuraAnimState, delta: float) -> bool:
	var sprite: Sprite2D = state.sprite
	if sprite == null:
		return true

	var count: int = maxi(1, state.total_frames)
	var speed: float = maxf(1.0, state.fps)
	state.cursor += delta * speed

	if _ending:
		if state.cursor >= float(count - 1):
			state.cursor = float(count - 1)
			sprite.frame = count - 1
			return true
		sprite.frame = clampi(int(floor(state.cursor)), 0, count - 1)
		return false

	state.cursor = fmod(state.cursor, float(count))
	if state.cursor < 0.0:
		state.cursor += float(count)
	sprite.frame = clampi(int(floor(state.cursor)), 0, count - 1)
	return false


func _fit_sprite_to_diameter(
	sprite: Sprite2D,
	hframes: int,
	vframes: int,
	diameter: float,
	size_multiplier: float
) -> void:
	if sprite == null or sprite.texture == null:
		return

	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var frame_w: float = tex_size.x / float(maxi(1, hframes))
	var frame_h: float = tex_size.y / float(maxi(1, vframes))
	var frame_max: float = maxf(frame_w, frame_h)
	if frame_max <= 0.0:
		return

	var target: float = maxf(1.0, diameter) * maxf(0.01, size_multiplier)
	var uniform_scale: float = target / frame_max
	sprite.scale = Vector2.ONE * uniform_scale

	if clip_to_enemy_box and sprite.material is ShaderMaterial:
		var clip_factor: float = maxf(1.0, size_multiplier)
		var clip_half_extent: float = 0.5 / clip_factor
		(sprite.material as ShaderMaterial).set_shader_parameter(
			"half_extent_uv",
			Vector2(clip_half_extent, clip_half_extent)
		)
