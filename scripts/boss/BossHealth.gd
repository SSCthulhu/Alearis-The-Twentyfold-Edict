# res://scripts/BossHealth.gd
extends Node
class_name BossHealth
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

signal health_changed(current: int, max_value: int)

# Damage-number compatible signals (match DamageNumberEmitter expectations)
signal damaged(amount: int)                                   # legacy/plain (no tag)
signal damaged_tagged(amount: int, tag: StringName)           # preferred
signal damaged_tagged_crit(amount: int, tag: StringName, is_crit: bool) # newest

# Optional: keep source for gameplay / analytics (NOT used by emitter)
signal damaged_with_source(amount: int, source: Node)

signal died

@export var max_hp: int = 1000

# Hit VFX
@export var hit_vfx_scene: PackedScene
@export var crit_vfx_scene: PackedScene
@export var spawn_hit_vfx: bool = true

var hp: int = 0

func _ready() -> void:
	hp = max_hp
	health_changed.emit(hp, max_hp)
	
	pass

# NOTE:
# - tag can be &"" for normal hits
# - is_crit only matters for your heavy crit system
func take_damage(amount: int, source: Node = null, tag: StringName = &"", is_crit: bool = false) -> void:
	if amount <= 0:
		return
	if hp <= 0:
		return

	var prev: int = hp
	hp = maxi(hp - amount, 0)

	var dealt: int = prev - hp
	if dealt > 0:
		pass
		
		# Spawn hit VFX at boss position (crit VFX if applicable)
		if spawn_hit_vfx:
			pass
			_spawn_hit_vfx(is_crit)
		else:
			pass
		
		# Optional source signal
		damaged_with_source.emit(dealt, source)

		# Always emit tagged_crit (even if tag is empty) so the emitter can drive crit visuals
		damaged_tagged_crit.emit(dealt, tag, is_crit)

		# Also emit tagged for older listeners
		damaged_tagged.emit(dealt, tag)

		# Also emit plain for non-tagged hits (legacy)
		if tag == &"":
			damaged.emit(dealt)

	health_changed.emit(hp, max_hp)

	if hp <= 0:
		died.emit()

func get_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)

func _spawn_hit_vfx(is_crit: bool = false) -> void:
	"""Spawn hit VFX at boss's position (crit VFX if is_crit is true)"""
	pass
	
	var boss: Node2D = get_parent() as Node2D
	if boss == null:
		pass
		return
	
	pass
	
	# Choose VFX based on crit status
	var vfx_scene_to_use: PackedScene = null
	if is_crit and crit_vfx_scene != null:
		vfx_scene_to_use = crit_vfx_scene
		pass
	elif hit_vfx_scene != null:
		vfx_scene_to_use = hit_vfx_scene
		pass
	
	if vfx_scene_to_use == null:
		pass
		return
	
	pass
	var vfx_node: Node = vfx_scene_to_use.instantiate()
	var vfx: Node2D = vfx_node as Node2D
	if vfx == null:
		pass
		vfx_node.queue_free()
		return
	
	pass
	
	# Add to world (same parent as boss)
	var world_parent: Node = boss.get_parent()
	if world_parent != null:
		pass
		world_parent.add_child(vfx)
		VfxRenderUtil.promote(vfx, 240)
		vfx.global_position = boss.global_position
		pass
	else:
		pass
		vfx.queue_free()
