# res://scripts/OrbLight.gd
extends CharacterBody2D
class_name OrbLight

@export var idle_anim: StringName = &"idle"
@export var anim_player_path: NodePath = NodePath()

var _anim: AnimationPlayer = null

func _ready() -> void:
	_anim = get_node_or_null(anim_player_path) as AnimationPlayer
	if _anim != null and idle_anim != &"":
		if _anim.has_animation(String(idle_anim)):
			_anim.play(String(idle_anim))
