extends Node
## Rogue Defensive Smoke VFX Manager
## Spawns smoke VFX on top of Rogue when defensive ability is activated

@export var vfx_scene: PackedScene
@export var target_character: String = "Rogue"  # Only triggers for Rogue
@export var offset_x: float = 0.0  # X offset from player center
@export var offset_y: float = 0.0  # Y offset from player center
@export var cooldown: float = 0.5
@export var debug_logs: bool = false

@onready var _player_controller: Node = get_parent()

var _cooldown_left: float = 0.0


func _ready() -> void:
	if _player_controller == null or not _player_controller.has_signal("defensive_activated"):
		push_error("[RogueDefensiveSmokeVFX] Parent must be PlayerControllerV3 with defensive_activated signal!")
		return
	
	_player_controller.defensive_activated.connect(_on_defensive_activated)
	pass


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _on_defensive_activated(character_name: String, facing_direction: int) -> void:
	"""Spawn smoke VFX when defensive ability is activated"""
	if debug_logs:
		pass
	
	# Filter by character
	if character_name != target_character:
		if debug_logs:
			pass
		return
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	if vfx_scene == null:
		push_error("[RogueDefensiveSmokeVFX] No VFX scene assigned!")
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_smoke_vfx(facing_direction)


func _spawn_smoke_vfx(facing_direction: int) -> void:
	"""Spawn smoke VFX at player center (on top of player)"""
	var vfx: Node2D = vfx_scene.instantiate()
	
	# Add to world (not as child of player)
	var world = get_tree().root
	world.add_child(vfx)
	
	# Position at player center with offset
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		vfx.queue_free()
		push_error("[RogueDefensiveSmokeVFX] Parent is not a Node2D")
		return
	
	var vfx_position: Vector2 = player_body.global_position
	vfx_position.x += offset_x
	vfx_position.y += offset_y
	vfx.global_position = vfx_position
	
	# Set facing direction if VFX supports it
	if vfx.has_method("set_facing"):
		vfx.set_facing(facing_direction)
	
	if debug_logs:
		pass
