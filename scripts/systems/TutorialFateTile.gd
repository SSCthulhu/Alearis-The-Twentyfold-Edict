extends Node2D
class_name TutorialFateTile

@export var animated_sprite_path: NodePath = ^"AnimatedSprite2D"
@export var trigger_area_path: NodePath = ^"Area2D"
@export var animation_name: StringName = &"fate"
@export var frame_rate: float = 30.0
@export var debug_tile_log: bool = false
@export_range(0.0, 1.0, 0.01) var color_mix_strength: float = 1.0

@export var color_idle: Color = Color(0.38, 0.62, 0.92, 0.62)
@export var color_correct: Color = Color(0.20, 1.0, 0.36, 0.98)
@export var color_wrong: Color = Color(1.0, 0.17, 0.17, 0.98)
@export var color_warning: Color = Color(1.0, 0.92, 0.08, 0.98)
@export var scale_idle: Vector2 = Vector2.ONE
@export var scale_correct: Vector2 = Vector2(1.08, 1.08)
@export var scale_warning: Vector2 = Vector2(1.10, 1.10)
@export var scale_wrong: Vector2 = Vector2(1.03, 1.03)
@export var scale_fail: Vector2 = Vector2(1.14, 1.14)

var is_correct_tile: bool = false
var player_overlapping: bool = false
var _player_overlap_count: int = 0
var _visual_state: int = 0

var _anim: AnimatedSprite2D = null
var _area: Area2D = null
var _state_material: ShaderMaterial = null

const TILE_TINT_SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 state_color : source_color = vec4(1.0);
uniform float state_mix : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 mixed = mix(tex.rgb, state_color.rgb, state_mix);
	COLOR = vec4(mixed, tex.a * state_color.a);
}
"""

enum VisualState {
	BASE = 0,
	WRONG_WARNING = 1,
	WRONG_FAIL = 2,
	RIGHT_CONFIRM = 3
}

func _ready() -> void:
	_anim = get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	_area = get_node_or_null(trigger_area_path) as Area2D
	if _area != null:
		if not _area.body_entered.is_connected(_on_body_entered):
			_area.body_entered.connect(_on_body_entered)
		if not _area.body_exited.is_connected(_on_body_exited):
			_area.body_exited.connect(_on_body_exited)
	_ensure_tint_material()
	set_base_visual()
	_refresh_overlap_cache()
	_play_loop_if_possible()

func configure(correct_tile: bool) -> void:
	is_correct_tile = correct_tile
	_player_overlap_count = 0
	_refresh_overlap_cache()
	set_base_visual()
	_play_loop_if_possible()

func mark_wrong_warning() -> void:
	_visual_state = VisualState.WRONG_WARNING
	_set_visual(color_warning, scale_warning)

func mark_wrong_fail() -> void:
	_visual_state = VisualState.WRONG_FAIL
	_set_visual(color_wrong, scale_fail)

func mark_right_confirm() -> void:
	_visual_state = VisualState.RIGHT_CONFIRM
	_set_visual(color_correct, scale_correct)

func set_base_visual() -> void:
	_visual_state = VisualState.BASE
	_set_visual(color_idle, scale_idle)

func _set_visual(c: Color, target_scale: Vector2) -> void:
	if _anim != null:
		_ensure_tint_material()
		if _state_material != null:
			_state_material.set_shader_parameter("state_color", c)
			_state_material.set_shader_parameter("state_mix", clampf(color_mix_strength, 0.0, 1.0))
			_anim.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			_anim.modulate = c
		_anim.scale = target_scale

func _play_loop_if_possible() -> void:
	if _anim == null:
		return
	if _anim.sprite_frames == null:
		return
	var anim_name: String = String(animation_name)
	if not _anim.sprite_frames.has_animation(anim_name):
		return
	_anim.sprite_frames.set_animation_loop(anim_name, true)
	_anim.sprite_frames.set_animation_speed(anim_name, maxf(frame_rate, 1.0))
	_anim.play(anim_name)

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group(&"player"):
		_player_overlap_count += 1
		player_overlapping = true
		_tile_dbg("body_entered", {
			"overlap_count": _player_overlap_count,
			"is_correct_tile": is_correct_tile
		})

func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group(&"player"):
		_player_overlap_count = maxi(_player_overlap_count - 1, 0)
		player_overlapping = _player_overlap_count > 0
		_tile_dbg("body_exited", {
			"overlap_count": _player_overlap_count,
			"is_correct_tile": is_correct_tile
		})
		if not player_overlapping:
			_refresh_overlap_cache()

func _refresh_overlap_cache() -> void:
	if _area == null:
		player_overlapping = false
		_player_overlap_count = 0
		return
	var overlap_count: int = 0
	var bodies: Array = _area.get_overlapping_bodies()
	for body: Variant in bodies:
		var n: Node = body as Node
		if n != null and n.is_in_group(&"player"):
			overlap_count += 1
	_player_overlap_count = overlap_count
	player_overlapping = _player_overlap_count > 0
	_tile_dbg("refresh_overlap_cache", {
		"overlap_count": _player_overlap_count,
		"is_correct_tile": is_correct_tile
	})

func get_visual_state() -> int:
	return _visual_state

func _tile_dbg(event_name: String, payload: Dictionary = {}) -> void:
	if not debug_tile_log:
		return
	var event_payload: Dictionary = {
		"event": event_name,
		"tile": String(name),
		"is_correct_tile": is_correct_tile,
		"player_overlapping": player_overlapping,
		"visual_state": _visual_state
	}
	for key: Variant in payload.keys():
		event_payload[key] = payload[key]
	print("[TutorialFateTileDebug] ", event_payload)

func _ensure_tint_material() -> void:
	if _anim == null:
		return
	if _state_material != null and is_instance_valid(_state_material):
		return
	var shader: Shader = Shader.new()
	shader.code = TILE_TINT_SHADER_CODE
	_state_material = ShaderMaterial.new()
	_state_material.shader = shader
	_anim.material = _state_material
