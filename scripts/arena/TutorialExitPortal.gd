extends Node2D
class_name TutorialExitPortal

@export var interact_action: StringName = &"interact"
@export var world1_scene_path: String = "res://scenes/world/World1.tscn"
@export var anim_fps: float = 10.0
@export var total_frames: int = 15

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _interaction_area: Area2D = $InteractionArea

var _player_nearby: bool = false
var _used: bool = false
var _anim_accum: float = 0.0

func _ready() -> void:
	if _interaction_area != null:
		if not _interaction_area.body_entered.is_connected(_on_body_entered):
			_interaction_area.body_entered.connect(_on_body_entered)
		if not _interaction_area.body_exited.is_connected(_on_body_exited):
			_interaction_area.body_exited.connect(_on_body_exited)
	add_to_group(&"portal")
	add_to_group(&"interactable")
	set_process(true)

func _process(delta: float) -> void:
	_tick_anim(delta)
	if _used or not _player_nearby:
		return
	if Input.is_action_just_pressed(interact_action):
		_used = true
		if RunStateSingleton != null and RunStateSingleton.has_method("mark_tutorial_completed"):
			RunStateSingleton.call("mark_tutorial_completed")
		if TransitionLayer != null and TransitionLayer.has_method("fade_to_scene"):
			TransitionLayer.call("fade_to_scene", world1_scene_path)
		else:
			get_tree().change_scene_to_file(world1_scene_path)

func _tick_anim(delta: float) -> void:
	if _sprite == null:
		return
	var fps: float = maxf(anim_fps, 0.01)
	var frames_count: int = maxi(total_frames, 1)
	_anim_accum += maxf(delta, 0.0)
	var step: float = 1.0 / fps
	while _anim_accum >= step:
		_anim_accum -= step
		_sprite.frame = (_sprite.frame + 1) % frames_count

func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if body.is_in_group(&"player"):
		_player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return
	if body.is_in_group(&"player"):
		_player_nearby = false
