extends Area2D
class_name DeathZone

# Death zone that kills the player if they fall below a certain floor
# Activates once player reaches a certain height (like reaching Floor 3)
# OR can be set to always_active for arenas like World3

@export var always_active: bool = false  # If true, death zone is active immediately (for World3)
@export var activation_y: float = -14000.0  # Activate when player reaches this Y or higher (for World2)
@export var player_path: NodePath = ^"../../Player"
@export var debug_logs: bool = false
@export var enable_fire_vfx: bool = true  # Spawn fire VFX when player touches lava (World3)

const FIRE_VFX_SCENE: PackedScene = preload("res://scenes/vfx/LavaFireVFX.tscn")

var _active: bool = false
var _player: Node2D = null
var _player_health: Node = null

func _ready() -> void:
	# Set collision to only detect player (Area2D doesn't physically block, only detects)
	collision_layer = 0  # This Area2D is not on any layer (nothing can detect it)
	collision_mask = 2   # This Area2D detects bodies on layer 2 (player)
	
	# Ensure monitoring is enabled
	monitoring = true
	monitorable = false  # Other bodies don't need to detect this
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Find player
	_player = get_node_or_null(player_path)
	if _player == null:
		push_error("[DeathZone] Player not found at: ", player_path)
		return
	
	# Find player's health component
	if _player.has_node("Health"):
		_player_health = _player.get_node("Health")
	
	# If always_active is true, activate immediately (for World3)
	if always_active:
		_activate()
		if debug_logs:
			pass
	else:
		if debug_logs:
			pass
	
	if debug_logs:
		pass
		pass
		pass
		pass

func _process(_delta: float) -> void:
	# Skip processing if already active, no player, or always_active mode is enabled
	if _active or not _player or always_active:
		return
	
	# Check if player has reached the activation height (World2 behavior)
	if _player.global_position.y <= activation_y:
		_activate()

func _activate() -> void:
	_active = true
	if debug_logs:
		pass
		pass

func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	
	if body == _player:
		# Spawn fire VFX on the player
		if enable_fire_vfx:
			_spawn_fire_vfx()
		_kill_player()

func _kill_player() -> void:
	if not _player_health:
		if debug_logs:
			pass
		return
	
	if debug_logs:
		pass
		pass
	
	# Make player invisible (simpler than z_index management)
	_player.visible = false
	if debug_logs:
		pass
	
	# Set a tag on the player to indicate this is a fall death (to keep falling during death)
	if _player.has_method("set_meta"):
		_player.set_meta("death_is_falling", true)
	
	# Deal massive damage to kill the player instantly (ignore invulnerability)
	_player_health.take_damage(9999, self, true)
	
	# Re-enable gravity/physics during death so player keeps falling
	if _player.has_method("set_physics_process"):
		_player.set_physics_process(true)
	
	# Keep the player's collision active so they continue to fall
	if _player.has_method("set_collision_layer"):
		_player.set_collision_layer(2)  # Keep on player layer
	if _player.has_method("set_collision_mask"):
		_player.set_collision_mask(1)  # Keep world collision

func _spawn_fire_vfx() -> void:
	"""Spawn fire VFX at player's position when they touch lava"""
	if FIRE_VFX_SCENE == null:
		return
	
	var vfx: Node2D = FIRE_VFX_SCENE.instantiate()
	if vfx == null:
		return
	
	# Spawn VFX in world space (not as child of player, since player becomes invisible)
	var world = get_tree().current_scene
	if world != null:
		world.add_child(vfx)
		vfx.global_position = _player.global_position
		
		if debug_logs:
			pass
