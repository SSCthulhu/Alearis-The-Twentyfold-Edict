extends Node2D
class_name IdleBreathVFX

@export var particles_path: NodePath = ^"BreathParticles"
@export var mouth_offset: Vector2 = Vector2(24.0, -56.0)
@export var interval_seconds: float = 0.75

var _player_body: CharacterBody2D = null
var _controller: Node = null
var _particles: CPUParticles2D = null
var _timer: float = 0.0
var _spawn_layer: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_body = get_parent() as CharacterBody2D
	_controller = get_parent()
	_particles = get_node_or_null(particles_path) as CPUParticles2D
	_spawn_layer = get_tree().current_scene
	_timer = _next_interval()
	if _particles != null:
		_particles.emitting = false
		_particles.visible = false

func _process(delta: float) -> void:
	if _particles == null or _controller == null or _player_body == null:
		return

	var can_emit: bool = _should_emit_breath()

	if not can_emit:
		_timer = _next_interval()
		return

	_timer -= delta
	if _timer > 0.0:
		return

	var world_pos: Vector2 = _get_breath_world_position()
	var direction: Vector2 = _get_breath_direction()
	_spawn_breath_puff(world_pos, direction)
	_timer = _next_interval()

func _should_emit_breath() -> bool:
	if not _player_body.is_on_floor():
		return false
	if _controller == null or not _controller.has_method("get_current_state"):
		return false
	# PlayerControllerV3.STATE.IDLE is enum value 0.
	return int(_controller.call("get_current_state")) == 0

func _get_breath_world_position() -> Vector2:
	if _player_body == null:
		return global_position
	var facing: int = 1
	if _controller != null and _controller.has_method("get_facing_direction"):
		facing = int(_controller.call("get_facing_direction"))
	var local_offset: Vector2 = Vector2(mouth_offset.x * float(facing), mouth_offset.y)
	return _player_body.global_position + local_offset

func _get_breath_direction() -> Vector2:
	var facing: int = 1
	if _controller != null and _controller.has_method("get_facing_direction"):
		facing = int(_controller.call("get_facing_direction"))
	return Vector2(float(facing), -0.08).normalized()

func _spawn_breath_puff(world_pos: Vector2, direction: Vector2) -> void:
	if _particles == null:
		return
	var spawn_parent: Node = _spawn_layer
	if spawn_parent == null or not is_instance_valid(spawn_parent):
		spawn_parent = get_tree().current_scene
	if spawn_parent == null:
		return

	var puff: CPUParticles2D = _particles.duplicate() as CPUParticles2D
	if puff == null:
		return
	puff.visible = true
	puff.global_position = world_pos
	puff.direction = direction
	puff.emitting = false
	spawn_parent.add_child(puff)
	puff.restart()
	puff.emitting = true

	var ttl: float = maxf(puff.lifetime * 1.25, 0.4)
	get_tree().create_timer(ttl).timeout.connect(func() -> void:
		if puff != null and is_instance_valid(puff):
			puff.queue_free()
	)

func _next_interval() -> float:
	return maxf(interval_seconds, 0.1)
