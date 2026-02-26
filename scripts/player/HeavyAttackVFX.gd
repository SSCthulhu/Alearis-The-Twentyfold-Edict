extends Node
class_name HeavyAttackVFX
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

## Spawns heavy attack VFX when Rogue uses heavy attack
## Only triggers for Rogue character

@export var player_controller_path: NodePath = ^".."
@export var heavy_attack_vfx_scene: PackedScene

# VFX positioning (no offset - centered on player)
@export var offset_x: float = 0.0
@export var offset_y: float = 0.0

# Character filter
@export var target_character: String = "Rogue"  # Only trigger for this character

# Anti-spam
@export var cooldown: float = 0.3
@export var debug_logs: bool = false

var _player_controller: Node = null
var _cooldown_left: float = 0.0

func _ready() -> void:
	if debug_logs:
		pass
		pass
		pass
	
	_player_controller = get_node_or_null(player_controller_path)
	
	if heavy_attack_vfx_scene == null:
		push_warning("[HeavyAttackVFX] heavy_attack_vfx_scene not assigned.")
		return
	
	if _player_controller == null:
		push_warning("[HeavyAttackVFX] PlayerController not found at: %s" % String(player_controller_path))
		return
	
	if debug_logs:
		pass
	
	# Connect to the heavy_attack_started signal
	if _player_controller.has_signal("heavy_attack_started"):
		if not _player_controller.heavy_attack_started.is_connected(_on_heavy_attack_started):
			_player_controller.heavy_attack_started.connect(_on_heavy_attack_started)
			pass
	else:
		push_warning("[HeavyAttackVFX] PlayerController missing signal: heavy_attack_started")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func _on_heavy_attack_started(character_name: String, facing_direction: int) -> void:
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
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_heavy_attack_vfx(character_name, facing_direction)

func _spawn_heavy_attack_vfx(_character_name: String, facing_direction: int) -> void:
	if heavy_attack_vfx_scene == null:
		if debug_logs:
			pass
		return
	
	# Get player body position
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		if debug_logs:
			pass
		return
	
	if debug_logs:
		pass
	
	# Instantiate VFX
	var vfx_node: Node = heavy_attack_vfx_scene.instantiate()
	var vfx: Node2D = vfx_node as Node2D
	if vfx == null:
		push_warning("[HeavyAttackVFX] VFX scene root must be a Node2D.")
		vfx_node.queue_free()
		return
	
	# Add to world (same parent as player, so it's in world space)
	var world_parent: Node = player_body.get_parent()
	if world_parent != null:
		world_parent.add_child(vfx)
		VfxRenderUtil.promote(vfx, 220)
		
		# Position at player center (no offset)
		var vfx_position: Vector2 = player_body.global_position
		vfx_position.y += offset_y
		vfx_position.x += offset_x
		
		vfx.global_position = vfx_position
		
		# Set facing direction
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", facing_direction)
			if debug_logs:
				pass
	else:
		vfx.queue_free()
		push_warning("[HeavyAttackVFX] Could not find world parent to spawn VFX")
