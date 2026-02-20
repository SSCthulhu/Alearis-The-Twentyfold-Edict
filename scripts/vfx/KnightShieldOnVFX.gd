extends Node2D

## VFX script for Knight shield activation
## Plays "on" animation when defensive ability is activated

signal animation_complete()  # Emitted when shield_on animation finishes

func _ready() -> void:
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	if sprite != null:
		sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	animation_complete.emit()
	queue_free()
