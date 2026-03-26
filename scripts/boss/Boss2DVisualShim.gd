extends Node2D
class_name Boss2DVisualShim

@export var sprite_path: NodePath = ^"Sprite2D"

var _current_anim: String = ""
var _is_playing_any: bool = false

func play_loop(anim_name: StringName, _restart: bool = true) -> void:
	_current_anim = String(anim_name)
	_is_playing_any = true

func play_one_shot(anim_name: String, _restart: bool = true, _speed_scale: float = 1.0) -> void:
	_current_anim = anim_name
	_is_playing_any = true

func is_playing_any() -> bool:
	return _is_playing_any

func get_current_anim() -> String:
	return _current_anim

func set_facing(_dir_x: int) -> void:
	# Tutorial boss should never auto-flip/facetarget.
	return
