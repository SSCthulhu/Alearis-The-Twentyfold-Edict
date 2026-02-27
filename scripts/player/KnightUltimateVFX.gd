extends Node
## Knight Ultimate VFX Manager
## Spawns five types of VFX:
## 1. Charge-up + Defensive VFX on player (phase 1 - immediate, together)
## 2. Impact cut + Lightning strike on each enemy hit (at damage time - immediate, together, with stun)
## 3. Blue shock burst on each enemy hit (phase 2 - delayed after impact, with stun/interrupt)
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

@export var player_vfx_scene: PackedScene  # Lightning charge-up on player (plays first)
@export var player_defensive_vfx_scene: PackedScene  # Defensive VFX on player (plays with charge-up)
@export var enemy_lightning_vfx_scene: PackedScene  # Lightning strike on each enemy hit (immediate, with stun)
@export var enemy_impact_vfx_scene: PackedScene  # Impact cut on each enemy hit (immediate, at damage time)
@export var enemy_shock_burst_vfx_scene: PackedScene  # Blue shock burst on each enemy hit (delayed, with stun/interrupt)
@export var offset_y: float = 0.0  # Y offset from player center
@export var shock_burst_delay: float = 1.0  # Delay before shock burst spawns (after impact)
@export var cooldown: float = 0.5
@export var debug_logs: bool = true

@onready var _player_controller: Node = get_parent()

var _cooldown_left: float = 0.0
var _pending_enemy_hits: Array = []  # Stores enemy hit positions waiting for delay


func _ready() -> void:
	if _player_controller == null or not _player_controller.has_signal("knight_ultimate_started"):
		push_error("[KnightUltimateVFX] Parent must be PlayerControllerV3 with knight_ultimate_started signal!")
		return
	
	_player_controller.knight_ultimate_started.connect(_on_knight_ultimate_started)
	_player_controller.knight_ultimate_hit.connect(_on_knight_ultimate_hit)
	pass


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	
	# Handle delayed enemy hit spawns
	var i: int = _pending_enemy_hits.size() - 1
	while i >= 0:
		_pending_enemy_hits[i].timer -= delta
		if _pending_enemy_hits[i].timer <= 0.0:
			_spawn_enemy_hit_vfx(_pending_enemy_hits[i])
			_pending_enemy_hits.remove_at(i)
		i -= 1


func _on_knight_ultimate_started(_facing_direction: int) -> void:
	"""Spawn charge-up VFX on player immediately"""
	if debug_logs:
		pass
	
	if _cooldown_left > 0.0:
		if debug_logs:
			pass
		return
	
	if player_vfx_scene == null or player_defensive_vfx_scene == null or enemy_lightning_vfx_scene == null or enemy_impact_vfx_scene == null or enemy_shock_burst_vfx_scene == null:
		push_error("[KnightUltimateVFX] VFX scenes not assigned!")
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		push_error("[KnightUltimateVFX] Parent is not a Node2D")
		return
	
	# Spawn charge-up lightning and defensive VFX on player IMMEDIATELY
	_spawn_player_vfx(player_body.global_position)
	_spawn_player_defensive_vfx(player_body.global_position)
	
	if debug_logs:
		pass


func _spawn_player_vfx(player_pos: Vector2) -> void:
	"""Spawn charge-up lightning on player (phase 1)"""
	var vfx: Node2D = player_vfx_scene.instantiate()
	
	var world = get_tree().root
	world.add_child(vfx)
	VfxRenderUtil.promote(vfx, 220)
	
	vfx.global_position = Vector2(player_pos.x, player_pos.y + offset_y)
	
	if debug_logs:
		pass


func _spawn_player_defensive_vfx(player_pos: Vector2) -> void:
	"""Spawn defensive VFX on player (phase 1, with charge-up), scaled up for ultimate"""
	var vfx: Node2D = player_defensive_vfx_scene.instantiate()
	
	var world = get_tree().root
	world.add_child(vfx)
	VfxRenderUtil.promote(vfx, 220)
	
	vfx.global_position = Vector2(player_pos.x, player_pos.y + offset_y)
	vfx.scale = Vector2(2.0, 2.0)  # Scale up for ultimate (2x bigger than normal defensive)
	
	if debug_logs:
		pass


func _on_knight_ultimate_hit(enemy: Node, enemy_position: Vector2) -> void:
	"""Spawn impact + lightning VFX immediately (at damage time), schedule shock burst for later"""
	if debug_logs:
		pass
	
	if enemy_lightning_vfx_scene == null or enemy_impact_vfx_scene == null or enemy_shock_burst_vfx_scene == null:
		push_error("[KnightUltimateVFX] Enemy VFX scenes not assigned!")
		return
	
	var world = get_tree().root
	
	# 1. Spawn impact cut VFX IMMEDIATELY (at damage time)
	var impact_vfx: Node2D = enemy_impact_vfx_scene.instantiate()
	world.add_child(impact_vfx)
	VfxRenderUtil.promote(impact_vfx, 220)
	impact_vfx.global_position = enemy_position
	
	if debug_logs:
		pass
	
	# 2. Spawn lightning strike VFX IMMEDIATELY (at damage time, with stun)
	var lightning_vfx: Node2D = enemy_lightning_vfx_scene.instantiate()
	world.add_child(lightning_vfx)
	VfxRenderUtil.promote(lightning_vfx, 220)
	lightning_vfx.global_position = enemy_position
	
	# Pass enemy reference to VFX for stun
	if lightning_vfx.has_method("set_enemy") and enemy != null and is_instance_valid(enemy):
		lightning_vfx.call("set_enemy", enemy)
	
	if debug_logs:
		pass
	
	# 3. Schedule shock burst VFX for later
	_pending_enemy_hits.append({
		"timer": shock_burst_delay,
		"position": enemy_position,
		"enemy": enemy
	})
	
	if debug_logs:
		pass


func _spawn_enemy_hit_vfx(hit_data: Dictionary) -> void:
	"""Spawn shock burst VFX on enemy (phase 2) with stun/interrupt"""
	var enemy_pos: Vector2 = hit_data.position
	var enemy = hit_data.get("enemy", null)
	
	# Validate enemy before using it
	if enemy != null and not is_instance_valid(enemy):
		enemy = null  # Enemy was freed (died), clear reference
	
	var world = get_tree().root
	
	# Spawn shock burst VFX
	var shock_burst_vfx: Node2D = enemy_shock_burst_vfx_scene.instantiate()
	world.add_child(shock_burst_vfx)
	VfxRenderUtil.promote(shock_burst_vfx, 220)
	shock_burst_vfx.global_position = enemy_pos
	
	# Pass enemy reference to VFX for stun/interrupt (only if still valid)
	if enemy != null and shock_burst_vfx.has_method("set_enemy"):
		shock_burst_vfx.call("set_enemy", enemy)
	
	if debug_logs:
		pass
