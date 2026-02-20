extends Node2D

## VFX script for Knight ultimate shock burst
## This creates a blue shock burst at each enemy's position and stuns/interrupts them

var enemy: Node = null
var stun_duration: float = 0.5  # Stun duration for shock burst

func set_enemy(enemy_node: Node) -> void:
	"""Store reference to enemy and apply stun/interrupt"""
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
