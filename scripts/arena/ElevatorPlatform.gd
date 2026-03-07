extends Node2D
class_name ElevatorPlatform

# Deterministic moving platform:
# - AnimatableBody2D moves in _physics_process (stable carry for CharacterBody2D)
# - Visual children are explicitly synced to body Y (no drift)
# - Top/bottom targets are fixed globals (no cumulative offset errors)

@export var floor_progression_path: NodePath = ^"../../../FloorProgressionController"
@export var required_floor: int = 3
@export var top_position_y: float = -7340.0
@export var bottom_position_y: float = -6423.0
@export var move_duration: float = 3.0
@export var pause_duration: float = 5.0
@export var initial_delay: float = 5.0
@export var debug_logs: bool = false

var _floor_progression: Node = null
var _active: bool = false
var _floor_cleared: bool = false
var _chest_looted: bool = false
var _body: AnimatableBody2D = null
var _move_speed: float = 0.0
var _pause_timer: float = 0.0

enum MoveState {
	IDLE,
	MOVING_UP,
	PAUSING_TOP,
	MOVING_DOWN,
	PAUSING_BOTTOM
}
var _move_state: MoveState = MoveState.IDLE

var _visual_offsets_y: Dictionary = {} # Node2D -> float offset from body global Y

func _ready() -> void:
	visible = false
	_find_and_setup_body()
	_cache_visual_offsets()
	_move_speed = absf(top_position_y - bottom_position_y) / maxf(move_duration, 0.01)
	_snap_body_and_visuals(bottom_position_y)
	_disable_collision()
	
	_floor_progression = get_node_or_null(floor_progression_path)
	if _floor_progression == null:
		push_error("[ElevatorPlatform] FloorProgressionController not found at path: ", floor_progression_path)
		return
	
	if _floor_progression.has_signal("floor_unlocked"):
		_floor_progression.floor_unlocked.connect(_on_floor_unlocked)
	
	if _floor_progression.has_signal("chest_opened"):
		_floor_progression.chest_opened.connect(_on_chest_opened)

func _physics_process(delta: float) -> void:
	if not _active or _body == null:
		return

	match _move_state:
		MoveState.MOVING_UP:
			if _move_body_toward(top_position_y, delta):
				_move_state = MoveState.PAUSING_TOP
				_pause_timer = maxf(pause_duration, 0.0)

		MoveState.PAUSING_TOP:
			_pause_timer = maxf(_pause_timer - delta, 0.0)
			if _pause_timer <= 0.0:
				_move_state = MoveState.MOVING_DOWN

		MoveState.MOVING_DOWN:
			if _move_body_toward(bottom_position_y, delta):
				_move_state = MoveState.PAUSING_BOTTOM
				_pause_timer = maxf(pause_duration, 0.0)

		MoveState.PAUSING_BOTTOM:
			_pause_timer = maxf(_pause_timer - delta, 0.0)
			if _pause_timer <= 0.0:
				_move_state = MoveState.MOVING_UP

		_:
			pass

func _find_and_setup_body() -> void:
	for child in get_children():
		if child is AnimatableBody2D:
			_body = child
			# CRITICAL: required for moving platform carry.
			_body.sync_to_physics = true
			if debug_logs:
				pass
			break
	
	if _body == null:
		push_error("[ElevatorPlatform] No AnimatableBody2D child found!")

func _cache_visual_offsets() -> void:
	_visual_offsets_y.clear()
	if _body == null:
		return
	for child: Node in get_children():
		if child == _body:
			continue
		var n2d: Node2D = child as Node2D
		if n2d == null:
			continue
		_visual_offsets_y[n2d] = n2d.global_position.y - _body.global_position.y

func _apply_visual_sync() -> void:
	if _body == null:
		return
	for key: Variant in _visual_offsets_y.keys():
		var n2d: Node2D = key as Node2D
		if n2d == null or not is_instance_valid(n2d):
			continue
		var off_y: float = float(_visual_offsets_y[key])
		var p: Vector2 = n2d.global_position
		p.y = _body.global_position.y + off_y
		n2d.global_position = p

func _snap_body_and_visuals(target_body_global_y: float) -> void:
	if _body == null:
		return
	var p: Vector2 = _body.global_position
	p.y = target_body_global_y
	_body.global_position = p
	_apply_visual_sync()

func _move_body_toward(target_body_global_y: float, delta: float) -> bool:
	if _body == null:
		return true
	var current_y: float = _body.global_position.y
	var next_y: float = move_toward(current_y, target_body_global_y, _move_speed * delta)
	if not is_equal_approx(next_y, current_y):
		var p: Vector2 = _body.global_position
		p.y = next_y
		_body.global_position = p
		_apply_visual_sync()
	return is_equal_approx(next_y, target_body_global_y)

func _on_floor_unlocked(floor_number: int) -> void:
	if floor_number == required_floor:
		_floor_cleared = true
		_check_activation()

func _on_chest_opened(floor_number: int) -> void:
	if floor_number == required_floor:
		_chest_looted = true
		_check_activation()

func _check_activation() -> void:
	if _floor_cleared and _chest_looted and not _active:
		_activate_elevator()

func _activate_elevator() -> void:
	_active = true
	visible = true
	_enable_collision()
	_snap_body_and_visuals(bottom_position_y)
	_move_state = MoveState.IDLE
	_pause_timer = 0.0
	
	if debug_logs:
		pass
	
	await get_tree().create_timer(initial_delay).timeout
	if not _active:
		return
	_move_state = MoveState.MOVING_UP
	
	if debug_logs:
		pass

func _disable_collision() -> void:
	if _body:
		for child in _body.get_children():
			if child is CollisionShape2D:
				child.disabled = true

func _enable_collision() -> void:
	if _body:
		for child in _body.get_children():
			if child is CollisionShape2D:
				child.disabled = false
