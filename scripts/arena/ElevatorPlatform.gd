extends Node2D
class_name ElevatorPlatform

# Simple elevator platform using Godot's built-in platform carrying
# AnimatableBody2D automatically pushes CharacterBody2D when sync_to_physics is enabled

@export var floor_progression_path: NodePath = ^"../../../FloorProgressionController"
@export var required_floor: int = 3
@export var top_position_y: float = -7340.0
@export var bottom_position_y: float = -6423.0
@export var move_duration: float = 3.0
@export var pause_duration: float = 5.0
@export var initial_delay: float = 5.0
@export var debug_logs: bool = true

var _floor_progression: Node = null
var _active: bool = false
var _floor_cleared: bool = false
var _chest_looted: bool = false
var _body: AnimatableBody2D = null
var _move_tween: Tween = null

func _ready() -> void:
	visible = false
	_find_and_setup_body()
	_disable_collision()
	
	_floor_progression = get_node_or_null(floor_progression_path)
	if _floor_progression == null:
		push_error("[ElevatorPlatform] FloorProgressionController not found at path: ", floor_progression_path)
		return
	
	if _floor_progression.has_signal("floor_unlocked"):
		_floor_progression.floor_unlocked.connect(_on_floor_unlocked)
	
	if _floor_progression.has_signal("chest_opened"):
		_floor_progression.chest_opened.connect(_on_chest_opened)

func _find_and_setup_body() -> void:
	for child in get_children():
		if child is AnimatableBody2D:
			_body = child
			# CRITICAL: Enable sync_to_physics so it automatically pushes CharacterBody2D
			_body.sync_to_physics = true
			if debug_logs:
				pass
			break
	
	if _body == null:
		push_error("[ElevatorPlatform] No AnimatableBody2D child found!")

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
	
	if debug_logs:
		pass
	
	await get_tree().create_timer(initial_delay).timeout
	_start_elevator_cycle()

func _start_elevator_cycle() -> void:
	while _active and is_inside_tree():
		await _move_to_top()
		await get_tree().create_timer(pause_duration).timeout
		await _move_to_bottom()
		await get_tree().create_timer(pause_duration).timeout

func _move_to_top() -> void:
	if not _body:
		return
	
	if debug_logs:
		pass
	
	await _tween_body_to(top_position_y)

func _move_to_bottom() -> void:
	if not _body:
		return
	
	if debug_logs:
		pass
	
	await _tween_body_to(bottom_position_y)

func _tween_body_to(target_global_y: float) -> void:
	if not _body:
		return

	# Ensure only one movement tween is active at a time.
	if _move_tween != null:
		_move_tween.kill()
		_move_tween = null
	
	# Move the root node so body + visuals remain perfectly in sync.
	# Keep target semantics based on body Y so existing inspector values continue to work.
	var body_to_root_offset_y: float = _body.global_position.y - global_position.y
	var target_root_global_y: float = target_global_y - body_to_root_offset_y

	# Create physics-timed tween for stable CharacterBody carrying.
	_move_tween = create_tween()
	_move_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_move_tween.set_trans(Tween.TRANS_LINEAR)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	
	_move_tween.tween_property(self, "global_position:y", target_root_global_y, move_duration)
	
	await _move_tween.finished
	_move_tween = null
	
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
