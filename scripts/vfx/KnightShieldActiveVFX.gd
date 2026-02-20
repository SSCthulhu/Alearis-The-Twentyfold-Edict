extends Node2D

## VFX script for Knight active shield
## Shows continuous shield while defensive buff is active
## Follows the player position

var player: Node2D = null

func set_player(player_node: Node2D) -> void:
	"""Set the player node to follow"""
	player = player_node

func _process(_delta: float) -> void:
	"""Follow player position every frame"""
	if player != null and is_instance_valid(player):
		global_position = player.global_position
