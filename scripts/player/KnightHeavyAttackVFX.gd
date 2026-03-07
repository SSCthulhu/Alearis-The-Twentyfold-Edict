extends Node
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

## Knight Heavy Attack VFX Manager
## Spawns heavy attack VFX when Knight uses heavy attack (AOE spin)

@export var knight_heavy_vfx_scene: PackedScene
@export var offset_x: float = 0.0
@export var offset_y: float = 0.0
@export var cooldown: float = 0.3
@export var debug_logs: bool = false

@onready var _player_controller: Node = get_parent()

var _cooldown_left: float = 0.0


func _ready() -> void:
	if _player_controller == null or not _player_controller.has_signal("heavy_attack_started"):
		push_error("[KnightHeavyAttackVFX] Parent must be PlayerControllerV3 with heavy_attack_started signal!")
		return
	
	_player_controller.heavy_attack_started.connect(_on_heavy_attack_started)
	pass


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _on_heavy_attack_started(character_name: String, facing_direction: int) -> void:
	"""Spawn heavy attack VFX for Knight only"""
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
	
	if knight_heavy_vfx_scene == null:
		push_error("[KnightHeavyAttackVFX] VFX scene not assigned!")
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_knight_heavy_vfx(facing_direction)


func _spawn_knight_heavy_vfx(_facing_direction: int) -> void:
	"""Spawn Knight heavy attack spin VFX"""
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		push_error("[KnightHeavyAttackVFX] Parent is not a Node2D")
		return
	
	var vfx: Node2D = knight_heavy_vfx_scene.instantiate()
	
	var world = get_tree().root
	world.add_child(vfx)
	VfxRenderUtil.promote(vfx, 220)
	
	# Position at player center
	var vfx_position: Vector2 = player_body.global_position
	vfx_position.x += offset_x
	vfx_position.y += offset_y
	vfx.global_position = vfx_position
	
	if debug_logs:
		pass
