extends Node
class_name PlayerReflectionMeleeAgent

const ROGUE_HEAVY_VFX_SCENE: PackedScene = preload("res://scenes/vfx/HeavyAttackVFX.tscn")
const KNIGHT_HEAVY_VFX_SCENE: PackedScene = preload("res://scenes/vfx/KnightHeavyAttackVFX.tscn")

var _dice_meter: Node = null
var _player_root: Node = null
var _reflection: Node2D = null
var _params: Dictionary = {}

var _attack_cooldown_left: float = 0.0
var _retarget_left: float = 0.0
var _target_id: int = 0
var _debug_tick_left: float = 0.2

var _move_speed: float = 320.0
var _attack_range: float = 130.0
var _attack_vertical_range: float = 140.0
var _retarget_interval: float = 0.18
var _return_to_player_when_idle: bool = false
var _follow_player_offset: Vector2 = Vector2(0.0, 0.0)

func configure(dice_meter: Node, player_root: Node, params: Dictionary) -> void:
	_dice_meter = dice_meter
	_player_root = player_root
	_params = params.duplicate(true)
	_reflection = get_parent() as Node2D
	_attack_cooldown_left = maxf(float(_params.get("strike_delay", 0.16)), 0.01)
	_move_speed = maxf(float(_params.get("move_speed", 320.0)), 40.0)
	_attack_range = maxf(float(_params.get("attack_range", 130.0)), 32.0)
	_attack_vertical_range = maxf(float(_params.get("attack_vertical_range", 140.0)), 24.0)
	_retarget_interval = maxf(float(_params.get("retarget_interval", 0.18)), 0.05)
	_return_to_player_when_idle = bool(_params.get("return_to_player_when_idle", false))
	_follow_player_offset = _resolve_follow_offset()
	_debug_tick_left = 0.2
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if _reflection == null or not is_instance_valid(_reflection):
		queue_free()
		return
	if _player_root == null or not is_instance_valid(_player_root) or not (_player_root is Node2D):
		queue_free()
		return
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_retarget_left = maxf(_retarget_left - delta, 0.0)
	_debug_tick_left = maxf(_debug_tick_left - delta, 0.0)
	var target: Node2D = _resolve_target()
	if _debug_tick_left <= 0.0:
		_debug_tick_left = 0.8
		_debug_log_state(target)
	if target == null:
		_move_idle(delta)
		return
	var target_pos: Vector2 = target.global_position
	var to_target: Vector2 = target_pos - _reflection.global_position
	var adx: float = absf(to_target.x)
	var ady: float = absf(to_target.y)
	var in_attack_range: bool = adx <= _attack_range and ady <= _attack_vertical_range
	var facing: int = 1 if to_target.x >= 0.0 else -1
	if _reflection.has_method("set_facing"):
		_reflection.call("set_facing", facing)
	if in_attack_range and _attack_cooldown_left <= 0.0:
		_attack_target(target, facing)
		_attack_cooldown_left = maxf(float(_params.get("strike_interval", 0.9)), 0.08)
		return
	_move_toward(target_pos, delta)

func _resolve_target() -> Node2D:
	if _retarget_left <= 0.0:
		_target_id = _find_best_target_id()
		_retarget_left = _retarget_interval
	if _target_id == 0:
		return null
	var obj: Object = instance_from_id(_target_id)
	if obj == null or not is_instance_valid(obj) or not (obj is Node2D):
		_target_id = 0
		return null
	return obj as Node2D

func _find_best_target_id() -> int:
	var enemies: Array[Node] = _find_targets_from_dice_meter()
	if enemies.is_empty():
		enemies = _find_targets_from_groups()
	if enemies.is_empty():
		return 0
	var best_id: int = 0
	var best_dist_sq: float = INF
	for enemy_node: Node in enemies:
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d_sq: float = _reflection.global_position.distance_squared_to(enemy.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_id = enemy.get_instance_id()
	return best_id

func _find_targets_from_dice_meter() -> Array[Node]:
	var out: Array[Node] = []
	if _dice_meter == null or not is_instance_valid(_dice_meter):
		return out
	if not _dice_meter.has_method("_get_reflection_combo_enemy_targets"):
		return out
	var dm_targets: Variant = _dice_meter.call("_get_reflection_combo_enemy_targets")
	if not (dm_targets is Array):
		return out
	for item: Variant in (dm_targets as Array):
		if item is Node:
			out.append(item as Node)
	return out

func _find_targets_from_groups() -> Array[Node]:
	var tree: SceneTree = get_tree()
	if tree == null:
		return []
	var enemies: Array[Node] = []
	var seen: Dictionary = {}
	var groups: Array[StringName] = [
		&"floor1_enemies", &"floor2_enemies", &"floor3_enemies", &"floor4_enemies", &"floor5_enemies",
		&"subarena_enemies", &"elites", &"enemy", &"enemies", &"boss"
	]
	for g: StringName in groups:
		for n: Node in tree.get_nodes_in_group(g):
			if n == null or not is_instance_valid(n):
				continue
			if not (n is Node2D):
				continue
			if n.is_in_group(&"player"):
				continue
			if not n.has_node("Health") and not n.has_node("BossHealth"):
				continue
			var scene_path: String = String(n.scene_file_path)
			var is_enemy_scene: bool = scene_path.begins_with("res://scenes/enemies/")
			var is_boss_scene: bool = scene_path.begins_with("res://scenes/boss/")
			if not is_enemy_scene and not is_boss_scene:
				continue
			var id: int = n.get_instance_id()
			if id == 0 or seen.has(id):
				continue
			seen[id] = true
			enemies.append(n)
	return enemies

func _move_toward(target_pos: Vector2, delta: float) -> void:
	var next_pos: Vector2 = _reflection.global_position.move_toward(target_pos, _move_speed * maxf(delta, 0.0))
	_reflection.global_position = next_pos
	if _reflection.has_method("play_run"):
		_reflection.call("play_run")

func _move_idle(delta: float) -> void:
	if _return_to_player_when_idle:
		var anchor: Vector2 = (_player_root as Node2D).global_position + _follow_player_offset
		_reflection.global_position = _reflection.global_position.move_toward(anchor, _move_speed * maxf(delta, 0.0))
	if _reflection.has_method("play_idle"):
		_reflection.call("play_idle")

func _attack_target(target: Node2D, facing: int) -> void:
	if _reflection.has_method("set_facing_toward"):
		_reflection.call("set_facing_toward", target.global_position)
	if _reflection.has_method("play_heavy"):
		_reflection.call("play_heavy")
	_spawn_heavy_vfx(facing)
	if _dice_meter != null and is_instance_valid(_dice_meter):
		if _dice_meter.has_method("_apply_reflection_lunge"):
			_dice_meter.call("_apply_reflection_lunge", _reflection, target.global_position, _player_root)
		if _dice_meter.has_method("_apply_player_like_heavy_to_target"):
			_dice_meter.call("_apply_player_like_heavy_to_target", target, _params)

func _spawn_heavy_vfx(facing: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene: PackedScene = _resolve_heavy_vfx_scene()
	if scene == null:
		return
	var node: Node = scene.instantiate()
	var vfx: Node2D = node as Node2D
	if vfx == null:
		node.queue_free()
		return
	tree.current_scene.add_child(vfx)
	vfx.global_position = _reflection.global_position
	if vfx.has_method("set_facing"):
		vfx.call("set_facing", facing)

func _resolve_heavy_vfx_scene() -> PackedScene:
	var character_name: String = ""
	if _player_root != null and ("character_data" in _player_root):
		var cdata: Object = _player_root.get("character_data") as Object
		if cdata != null and ("character_name" in cdata):
			character_name = String(cdata.get("character_name"))
	if character_name == "":
		character_name = CharacterDatabase.get_selected_character()
	return KNIGHT_HEAVY_VFX_SCENE if character_name == "Knight" else ROGUE_HEAVY_VFX_SCENE

func _resolve_follow_offset() -> Vector2:
	var offset_x: float = float(_params.get("follow_offset_x", 72.0))
	var offset_y: float = float(_params.get("follow_offset_y", 0.0))
	if _player_root != null and is_instance_valid(_player_root):
		if "_facing_direction" in _player_root:
			var facing: float = signf(float(_player_root.get("_facing_direction")))
			if absf(facing) >= 0.5:
				offset_x *= -facing
	return Vector2(offset_x, offset_y)

func _debug_log_state(target: Node2D) -> void:
	if _dice_meter == null or not is_instance_valid(_dice_meter) or not _dice_meter.has_method("_log_debug"):
		return
	var target_id: int = target.get_instance_id() if target != null and is_instance_valid(target) else 0
	var target_pos: Vector2 = target.global_position if target != null and is_instance_valid(target) else Vector2.ZERO
	_dice_meter.call(
		"_log_debug",
		"11G agent state refl=%s target_id=%d target_pos=%s cd=%.2f rt=%.2f" % [
			str(_reflection.global_position),
			target_id,
			str(target_pos),
			_attack_cooldown_left,
			_retarget_left
		]
	)
