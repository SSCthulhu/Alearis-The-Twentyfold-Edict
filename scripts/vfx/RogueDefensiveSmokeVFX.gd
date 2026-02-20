extends Node2D
## Rogue Defensive Smoke VFX
## Visual smoke effect that plays on top of Rogue when defensive ability is activated

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
		# Smoke burst is typically symmetrical, but flip for consistency
		sprite.flip_h = (direction < 0)
