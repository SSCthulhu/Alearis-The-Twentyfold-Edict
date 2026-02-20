# res://scripts/CeilingGate.gd
extends StaticBody2D
class_name CeilingGate

@export var collider_path: NodePath = ^"CollisionShape2D"
@export var visual_path: NodePath = ^"Sprite2D"

@onready var _collider := get_node_or_null(collider_path) as CollisionShape2D
@onready var _visual := get_node_or_null(visual_path) as CanvasItem

func set_open(open: bool) -> void:
	# open = allow pass through
	if _collider:
		_collider.disabled = open
	if _visual:
		_visual.visible = not open

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var cam := body.get_node("PlayerCameraController") as PlayerCameraController
		if cam:
			cam.set_ceiling_from_gate(self)

