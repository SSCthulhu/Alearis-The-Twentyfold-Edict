extends Node
## Ultimate Attack VFX Manager
## Spawns VFX when player's ultimate attack hits an enemy

@export var vfx_scene: PackedScene
@export var target_character: String = "Rogue"  # Which character this VFX is for
@export var offset_x: float = 0.0  # X offset from enemy position
@export var offset_y: float = 0.0  # Y offset from enemy position

@onready var _player_controller: Node = get_parent()


func _ready() -> void:
	if _player_controller == null or not _player_controller.has_signal("ultimate_attack_hit"):
		push_error("[UltimateAttackVFX] Parent must be PlayerControllerV3 with ultimate_attack_hit signal!")
		return
	
	_player_controller.ultimate_attack_hit.connect(_on_ultimate_attack_hit)
	pass


func _on_ultimate_attack_hit(character_name: String, enemy_position: Vector2, facing_direction: int) -> void:
	"""Spawn VFX when ultimate hits an enemy"""
	# Filter by character
	if character_name != target_character:
		return
	
	if vfx_scene == null:
		push_error("[UltimateAttackVFX] No VFX scene assigned!")
		return
	
	_spawn_ultimate_vfx(enemy_position, facing_direction)


func _spawn_ultimate_vfx(enemy_position: Vector2, facing_direction: int) -> void:
	"""Spawn ultimate attack VFX at enemy position"""
	var vfx: Node2D = vfx_scene.instantiate()
	
	# Add to world (not as child of player)
	var world = get_tree().root
	world.add_child(vfx)
	
	# Position at enemy location with offset
	var vfx_position: Vector2 = enemy_position
	vfx_position.x += offset_x
	vfx_position.y += offset_y
	vfx.global_position = vfx_position
	
	# Set facing direction if VFX supports it
	if vfx.has_method("set_facing"):
		vfx.set_facing(facing_direction)
	
	pass
