extends Node

## Knight Light Attack VFX Manager
## Spawns light attack VFX when Knight uses light attack combo

@export var knight_light_vfx_scene: PackedScene
@export var offset_x: float = 0.0  # Base offset
@export var offset_y: float = 0.0
@export var forward_offset: float = 150.0  # Distance in front based on facing (matches Rogue)
@export var cooldown: float = 0.1
@export var debug_logs: bool = true

@onready var _player_controller: Node = get_parent()

var _cooldown_left: float = 0.0


func _ready() -> void:
	if _player_controller == null or not _player_controller.has_signal("light_attack_started"):
		push_error("[KnightLightAttackVFX] Parent must be PlayerControllerV3 with light_attack_started signal!")
		return
	
	_player_controller.light_attack_started.connect(_on_light_attack_started)
	pass


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _on_light_attack_started(character_name: String, _combo_step: int, facing_direction: int) -> void:
	"""Spawn light attack VFX for Knight only"""
	if debug_logs:
		pass
	
	# Filter by character - only Knight
	if character_name != "Knight":
		if debug_logs:
			pass
		return
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	if knight_light_vfx_scene == null:
		push_error("[KnightLightAttackVFX] VFX scene not assigned!")
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_knight_light_vfx(facing_direction)


func _spawn_knight_light_vfx(facing_direction: int) -> void:
	"""Spawn Knight light attack slash VFX"""
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		push_error("[KnightLightAttackVFX] Parent is not a Node2D")
		return
	
	var vfx: Node2D = knight_light_vfx_scene.instantiate()
	
	var world = get_tree().root
	world.add_child(vfx)
	
	# Position IN FRONT of player based on facing direction (matches Rogue positioning)
	var vfx_position: Vector2 = player_body.global_position
	vfx_position.y += offset_y
	vfx_position.x += offset_x + (facing_direction * forward_offset)
	vfx.global_position = vfx_position
	
	# Set facing direction
	if vfx.has_method("set_facing"):
		vfx.call("set_facing", facing_direction)
	
	if debug_logs:
		pass
