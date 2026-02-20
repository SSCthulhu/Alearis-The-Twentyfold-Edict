extends Node2D
## Rogue Defensive Aura VFX
## Continuous looping smoke effect that stays with the player during defensive buff

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var duration_timer: Timer = $DurationTimer


func _ready() -> void:
	# Auto-play handled by autoplay in scene
	# Auto-free handled by timer timeout signal
	pass


func set_duration(seconds: float) -> void:
	"""Override the default duration (10 seconds)"""
	if duration_timer != null:
		duration_timer.wait_time = seconds
		duration_timer.start()


func set_facing(direction: int) -> void:
	"""Set VFX facing direction and flip sprite horizontally if needed
	Args:
		direction: -1 for left, 1 for right
	"""
	if sprite != null:
		sprite.flip_h = (direction < 0)
