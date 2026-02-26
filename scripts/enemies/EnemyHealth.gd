# res://scripts/EnemyHealth.gd
extends Node
class_name EnemyHealth
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

signal damaged(amount: int)                                   # legacy
signal damaged_tagged(amount: int, tag: StringName)           # preferred
signal damaged_tagged_crit(amount: int, tag: StringName, is_crit: bool) # NEW
signal died

@export var max_hp: int = 60

# Melee-only (ranged immunity) - used by Skeleton Golem
@export var melee_only: bool = false
@export var melee_damage_range: float = 100.0

# Hit VFX
@export var hit_vfx_scene: PackedScene
@export var crit_vfx_scene: PackedScene
@export var spawn_hit_vfx: bool = true

var hp: int = 0

# ⚡ OPTIMIZATION: Cache expensive lookups to avoid tree walks on every hit
var _player_cached: Node = null
var _visual_node_cached: Node2D = null

func _ready() -> void:
	hp = max_hp
	
	# ⚡ OPTIMIZATION: Cache player reference to avoid tree walks on damage
	_player_cached = get_tree().get_first_node_in_group("player")
	
	# ⚡ OPTIMIZATION: Cache visual node to avoid 6+ node lookups per VFX spawn
	var enemy: Node = get_parent()
	if enemy != null:
		_visual_node_cached = _find_visual_node(enemy)

func take_damage(amount: int, _source: Node = null, tag: StringName = &"", is_crit: bool = false) -> void:
	if amount <= 0 or hp <= 0:
		return
	
	# Melee-only check (ranged immunity for Golem-type enemies)
	if melee_only and _source != null:
		var player: Node = null
		
		# Check if source is player directly
		if _source.is_in_group("player"):
			player = _source
		# Check if source is a player hitbox
		elif _source is Area2D and _source.is_in_group("player_hitbox"):
			# ⚡ OPTIMIZATION: Use cached player (avoids tree walk on every damage)
			# Validate cache and refresh if needed
			if _player_cached != null and is_instance_valid(_player_cached):
				player = _player_cached
			else:
				_player_cached = get_tree().get_first_node_in_group("player")
				player = _player_cached
		
		# If player source found, check distance for ranged immunity
		if player != null and is_instance_valid(player):
			var enemy: Node = get_parent()
			if enemy != null and is_instance_valid(enemy):
				var dist: float = enemy.global_position.distance_to(player.global_position)
				if dist > melee_damage_range:
					# Too far - immune to ranged damage
					return

	hp = maxi(hp - amount, 0)
	
	# Spawn hit VFX at enemy position (crit VFX if applicable)
	if spawn_hit_vfx:
		_spawn_hit_vfx(is_crit)

	# NEW: crit-aware signal always
	damaged_tagged_crit.emit(amount, tag, is_crit)

	# Existing behavior preserved
	damaged_tagged.emit(amount, tag)

	# Legacy listeners only for non-tagged, non-crit hits
	if tag == &"" and not is_crit:
		damaged.emit(amount)

	if hp <= 0:
		# print("[EnemyHealth] died emit. amount=", amount, " final_hp=", hp)  # ✅ Disabled for clean logs
		died.emit()

func set_max_and_full_heal(new_max: int) -> void:
	max_hp = maxi(new_max, 1)
	hp = max_hp

func _find_visual_node(enemy: Node) -> Node2D:
	"""⚡ OPTIMIZATION: Find visual node once during init (called from _ready)"""
	if enemy.has_node("Enemy3DView"):
		return enemy.get_node("Enemy3DView") as Node2D
	elif enemy.has_node("SkeletonMage3DView"):
		return enemy.get_node("SkeletonMage3DView") as Node2D
	elif enemy.has_node("SkeletonGolem3DView"):
		return enemy.get_node("SkeletonGolem3DView") as Node2D
	elif enemy.has_node("SkeletonRogue3DView"):
		return enemy.get_node("SkeletonRogue3DView") as Node2D
	elif enemy.has_node("Necromancer3DView"):
		return enemy.get_node("Necromancer3DView") as Node2D
	elif enemy.has_node("Minion3DView"):
		return enemy.get_node("Minion3DView") as Node2D
	return null

func _spawn_hit_vfx(is_crit: bool = false) -> void:
	"""Spawn hit VFX at enemy's position (crit VFX if is_crit is true)"""
	var enemy: Node2D = get_parent() as Node2D
	if enemy == null:
		return
	
	# Choose VFX based on crit status
	var vfx_scene_to_use: PackedScene = null
	if is_crit and crit_vfx_scene != null:
		vfx_scene_to_use = crit_vfx_scene
	elif hit_vfx_scene != null:
		vfx_scene_to_use = hit_vfx_scene
	
	if vfx_scene_to_use == null:
		return
	
	var vfx_node: Node = vfx_scene_to_use.instantiate()
	var vfx: Node2D = vfx_node as Node2D
	if vfx == null:
		vfx_node.queue_free()
		return
	
	# Get visual node position (enemy 3D view may be offset from root)
	# ⚡ OPTIMIZATION: Use cached visual node (avoids 6+ node lookups per VFX spawn)
	var vfx_position: Vector2 = enemy.global_position
	
	# Use cached visual node position if available
	if _visual_node_cached != null and is_instance_valid(_visual_node_cached):
		vfx_position = _visual_node_cached.global_position
	
	# Add to world (same parent as enemy)
	var world_parent: Node = enemy.get_parent()
	if world_parent != null:
		world_parent.add_child(vfx)
		VfxRenderUtil.promote(vfx, 230)
		vfx.global_position = vfx_position
	else:
		vfx.queue_free()
