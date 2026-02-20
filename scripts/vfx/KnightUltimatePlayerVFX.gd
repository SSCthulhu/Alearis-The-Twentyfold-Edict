extends Node2D
## Knight Ultimate Player VFX
## Lightning effect that plays on the player during Knight's ultimate

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Auto-play handled by autoplay in scene
	# Auto-free handled by signal connection in scene
	pass
