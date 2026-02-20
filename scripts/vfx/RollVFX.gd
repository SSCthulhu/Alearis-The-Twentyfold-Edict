extends Node2D
## Roll VFX
## Smoke trail effect that plays behind the player during roll/dodge

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
		# Smoke is symmetrical, but flip for consistency
		sprite.flip_h = (direction < 0)
