extends Node2D
## Blood Explosion VFX
## Explosion effect when player is hit by blood projectile

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Auto-play handled by autoplay in scene
	# Auto-free handled by signal connection in scene
	pass
