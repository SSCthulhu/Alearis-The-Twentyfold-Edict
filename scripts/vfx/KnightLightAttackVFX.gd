extends Node2D

## VFX script for Knight light attack combo
## This creates a blue slash effect at the player's position

func _ready() -> void:
	# Play the animation automatically (set in scene)
	pass

func set_facing(direction: int) -> void:
	"""Set facing direction: -1=left, 1=right"""
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	if sprite != null:
		# Flip horizontally for left-facing attacks
		sprite.flip_h = (direction < 0)
