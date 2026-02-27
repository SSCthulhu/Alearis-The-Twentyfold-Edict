extends Node
## Rogue Defensive Aura VFX Manager
## Spawns continuous looping smoke aura that follows Rogue during defensive buff
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

@export var vfx_scene: PackedScene
@export var target_character: String = "Rogue"  # Only triggers for Rogue
@export var buff_duration: float = 10.0  # Duration of the defensive buff
@export var offset_x: float = 0.0  # X offset from player center
@export var offset_y: float = 0.0  # Y offset from player center
@export var cooldown: float = 0.5  # Anti-spam cooldown
@export var debug_logs: bool = false

@onready var _player_controller: Node = get_parent()

var _cooldown_left: float = 0.0
var _current_aura: Node2D = null  # Track current active aura


func _ready() -> void:
	if _player_controller == null or not _player_controller.has_signal("defensive_activated"):
		push_error("[RogueDefensiveAuraVFX] Parent must be PlayerControllerV3 with defensive_activated signal!")
		return
	
	_player_controller.defensive_activated.connect(_on_defensive_activated)
	pass


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _on_defensive_activated(character_name: String, facing_direction: int) -> void:
	"""Spawn continuous aura VFX when defensive ability is activated"""
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
		push_error("[RogueDefensiveAuraVFX] No VFX scene assigned!")
		return
	
	# Remove existing aura if somehow still active
	if _current_aura != null and is_instance_valid(_current_aura):
		_current_aura.queue_free()
		_current_aura = null
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_aura_vfx(facing_direction)


func _spawn_aura_vfx(facing_direction: int) -> void:
	"""Spawn continuous aura VFX as child of player (follows player)"""
	var vfx: Node2D = vfx_scene.instantiate()
	
	# Add as child of player (NOT world) so it follows player
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		vfx.queue_free()
		push_error("[RogueDefensiveAuraVFX] Parent is not a Node2D")
		return
	
	player_body.add_child(vfx)
	VfxRenderUtil.promote(vfx, 220)
	
	# Position relative to player center with offset
	vfx.position.x = offset_x
	vfx.position.y = offset_y
	
	# Set duration if VFX supports it
	if vfx.has_method("set_duration"):
		vfx.set_duration(buff_duration)
	
	# Set facing direction if VFX supports it
	if vfx.has_method("set_facing"):
		vfx.set_facing(facing_direction)
	
	# Track current aura
	_current_aura = vfx
	
	if debug_logs:
		pass
