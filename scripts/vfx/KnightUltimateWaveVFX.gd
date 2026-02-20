extends Node2D
## Knight Ultimate Wave VFX
## Lightning wave effect that plays in front of the player during Knight's ultimate

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
		# Flip horizontally based on direction
		sprite.flip_h = (direction < 0)
