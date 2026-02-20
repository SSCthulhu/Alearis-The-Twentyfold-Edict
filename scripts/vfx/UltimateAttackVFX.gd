extends Node2D
## Rogue Ultimate Attack VFX
## Visual effect that plays when Rogue's ultimate hits an enemy

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Auto-play handled by autoplay in scene
	# Auto-free handled by signal connection in scene
	pass


func set_facing(direction: int) -> void:
	"""Set VFX facing direction and flip sprite horizontally if needed
	Args:
		direction: -1 for left, 1 for right
	"""
	if sprite != null:
		# Assuming sprite sheet faces RIGHT by default
		sprite.flip_h = (direction < 0)
