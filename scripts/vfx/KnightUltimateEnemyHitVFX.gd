extends Node2D

## VFX script for Knight ultimate enemy hit lightning
## This creates a lightning strike at each enemy's position and stuns them

var enemy: Node = null
var stun_duration: float = 0.65  # Duration of animation / FPS (16 frames at 60fps ~= 0.27s, adding buffer)

func set_enemy(enemy_node: Node) -> void:
	"""Store reference to enemy and apply stun"""
	enemy = enemy_node
	if enemy != null and is_instance_valid(enemy):
		_apply_stun()

func _apply_stun() -> void:
	"""Apply stun effect to the enemy"""
	# Check if enemy has status effects node
	var status_effects = enemy.get_node_or_null("StatusEffects")
	if status_effects != null and status_effects.has_method("apply_stun"):
		status_effects.call("apply_stun", stun_duration)
		pass

func _on_animation_finished() -> void:
	queue_free()
