extends CharacterBody2D
class_name PlayerReflectionSummonActor

signal summon_finished

const ReflectionSummonHealthScript = preload("res://scripts/vfx/ReflectionSummonHealth.gd")
const ROGUE_LIGHT_VFX_SCENE: PackedScene = preload("res://scenes/vfx/LightAttackVFX.tscn")
const KNIGHT_LIGHT_VFX_SCENE: PackedScene = preload("res://scenes/vfx/KnightLightAttackVFX.tscn")

@export var move_speed: float = 340.0
@export var accel: float = 1800.0
@export var friction: float = 2200.0
@export var gravity: float = 1250.0
@export var max_fall_speed: float = 900.0
@export var jump_strength: float = -1080.0
@export var jump_cooldown: float = 0.45
@export var jump_vertical_threshold: float = 56.0
@export var jump_horizontal_range: float = 260.0
@export var jump_forward_boost: float = 220.0
@export var floor_snap_length_px: float = 24.0
@export var obstacle_jump_probe_distance: float = 30.0
@export var obstacle_jump_probe_height: float = 22.0
@export var stuck_jump_delay: float = 0.16
@export var stuck_speed_threshold: float = 22.0
@export var world_collision_mask: int = 9
@export var prevent_falling_off_ledges: bool = true
@export var ground_probe_forward: float = 18.0
@export var ground_probe_distance: float = 180.0
@export var ground_probe_origin_y: float = 28.0
@export var safe_drop_max_distance: float = 1200.0
@export var enable_drop_through_platforms: bool = true
@export var drop_through_world_collision_layer_bit: int = 1
@export var drop_through_duration: float = 0.14
@export var drop_through_downward_boost: float = 320.0
@export var drop_through_cooldown: float = 0.65
@export var drop_through_vertical_min_distance: float = 90.0
@export var drop_through_horizontal_max_distance: float = 520.0
@export var drop_through_horizontal_deadzone: float = 28.0
@export var drop_through_trigger_horizontal_max: float = 64.0
@export var drop_through_max_safe_landing_delta: float = 320.0
@export var drop_through_min_disable_time: float = 0.05
@export var drop_through_max_disable_fall_distance: float = 72.0
@export var drop_through_restore_after_leaving_platform: bool = true
@export var gap_jump_probe_forward: float = 42.0
@export var gap_jump_landing_probe_forward: float = 128.0
@export var gap_jump_landing_probe_depth: float = 320.0
@export var gap_jump_max_downward_landing_delta: float = 180.0
@export var gap_jump_max_upward_landing_delta: float = 120.0
@export var gap_jump_min_target_dx: float = 64.0
@export var drop_surface_name_tokens: PackedStringArray = PackedStringArray(["dropthrough", "oneway", "one_way", "platform", "platforms", "bridge", "ledge"])
@export var forbidden_drop_surface_name_tokens: PackedStringArray = PackedStringArray(["lava", "magma", "acid", "death", "deathzone", "kill", "killzone", "void", "hazard", "damage"])
@export var attack_range: float = 110.0
@export var attack_vertical_range: float = 120.0
@export var retarget_interval: float = 0.16
@export var combo_interval: float = 0.33
@export var fade_out_seconds: float = 0.22
@export var damage_scale: float = 0.75
@export var hit_delay_seconds: float = 0.08

var _dice_meter: Node = null
var _visual: Node2D = null
var _health: ReflectionSummonHealth = null
var _target_id: int = 0
var _retarget_left: float = 0.0
var _attack_left: float = 0.0
var _hit_delay_left: float = 0.0
var _pending_target_id: int = 0
var _combo_step: int = 0
var _dying: bool = false
var _jump_cd_left: float = 0.0
var _stuck_left: float = 0.0
var _spawn_character_name: String = ""
var _drop_through_timer: float = 0.0
var _drop_through_cd: float = 0.0
var _drop_restore_collision_mask: int = 0
var _drop_restore_floor_snap_length: float = 0.0
var _drop_through_elapsed: float = 0.0
var _drop_through_start_y: float = 0.0

func _ready() -> void:
	top_level = true
	floor_snap_length = maxf(floor_snap_length_px, 0.0)
	set_process(true)
	set_physics_process(true)
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	_visual = get_node_or_null("Visual") as Node2D
	_bind_visual_to_actor()
	_health = get_node_or_null("Health") as ReflectionSummonHealth
	if _health != null and not _health.died.is_connected(_on_health_died):
		_health.died.connect(_on_health_died)

func configure_from_player(
	dice_meter: Node,
	player_root: Node,
	spawn_character_name: String,
	max_hp_value: int,
	params: Dictionary
) -> void:
	_dice_meter = dice_meter
	_spawn_character_name = spawn_character_name
	move_speed = maxf(float(params.get("move_speed", move_speed)), 10.0)
	attack_range = maxf(float(params.get("attack_range", attack_range)), 16.0)
	attack_vertical_range = maxf(float(params.get("attack_vertical_range", attack_vertical_range)), 16.0)
	retarget_interval = maxf(float(params.get("retarget_interval", retarget_interval)), 0.05)
	combo_interval = maxf(float(params.get("combo_interval", combo_interval)), 0.05)
	fade_out_seconds = maxf(float(params.get("fade_out_seconds", fade_out_seconds)), 0.05)
	damage_scale = clampf(float(params.get("damage_scale", damage_scale)), 0.0, 10.0)
	hit_delay_seconds = clampf(float(params.get("hit_delay_seconds", hit_delay_seconds)), 0.0, 1.0)
	if _health != null:
		_health.set_max_and_full_heal(maxi(max_hp_value, 1))
	if _visual != null and _visual.has_method("configure_character"):
		_bind_visual_to_actor()
		var alpha: float = clampf(float(params.get("clone_alpha", 0.95)), 0.05, 1.0)
		var scale_val: float = maxf(float(params.get("clone_scale", 1.0)), 0.1)
		_visual.call("configure_character", spawn_character_name, alpha, scale_val)
		if _visual.has_method("configure_render_profile") and player_root != null:
			var body_view: Node = player_root.get_node_or_null("Visual/Body3DView")
			if body_view != null:
				var viewport_px: Vector2i = Vector2i(512, 512)
				var screen_px: Vector2i = Vector2i(256, 256)
				if "viewport_size" in body_view:
					var vp_v: Variant = body_view.get("viewport_size")
					if vp_v is Vector2i:
						viewport_px = vp_v as Vector2i
				if "screen_pixels" in body_view:
					var sp_v: Variant = body_view.get("screen_pixels")
					if sp_v is Vector2i:
						screen_px = sp_v as Vector2i
				_visual.call("configure_render_profile", viewport_px, screen_px)
		if _visual.has_method("play_idle"):
			_visual.call("play_idle")
	_bind_visual_to_actor()

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_retarget_left = maxf(_retarget_left - delta, 0.0)
	_attack_left = maxf(_attack_left - delta, 0.0)
	_hit_delay_left = maxf(_hit_delay_left - delta, 0.0)
	_jump_cd_left = maxf(_jump_cd_left - delta, 0.0)
	_drop_through_cd = maxf(_drop_through_cd - delta, 0.0)
	_update_drop_through_state(delta)
	if _hit_delay_left <= 0.0 and _pending_target_id != 0:
		_apply_pending_hit()
	var desired_vx: float = 0.0
	var target: Node2D = _resolve_or_pick_target()
	if target == null:
		if _dice_meter != null and _dice_meter.has_method("_get_reflection_combo_enemy_targets"):
			var enemies_v: Variant = _dice_meter.call("_get_reflection_combo_enemy_targets")
			if enemies_v is Array and (enemies_v as Array).is_empty():
				_fade_and_finish()
				return
		if _visual != null and _visual.has_method("play_idle"):
			_visual.call("play_idle")
	else:
		var to_target: Vector2 = target.global_position - global_position
		var adx: float = absf(to_target.x)
		var ady: float = absf(to_target.y)
		var in_range: bool = adx <= attack_range and ady <= attack_vertical_range
		if _visual != null and _visual.has_method("set_facing_toward"):
			_visual.call("set_facing_toward", target.global_position)
		if in_range:
			if _attack_left <= 0.0:
				_start_combo_attack(target)
		else:
			# If target is below, prefer drop-through behavior over lateral jitter.
			if _should_drop_through_toward_target(target):
				_start_drop_through()
				desired_vx = 0.0
			else:
				if absf(to_target.x) <= drop_through_horizontal_deadzone:
					desired_vx = 0.0
				else:
					desired_vx = signf(to_target.x) * move_speed
			if _visual != null and _visual.has_method("play_run"):
				_visual.call("play_run")
			if is_on_floor() and _jump_cd_left <= 0.0:
				var should_jump: bool = (
					target.global_position.y < (global_position.y - jump_vertical_threshold) and
					absf(to_target.x) <= jump_horizontal_range
				)
				if should_jump:
					velocity.y = jump_strength
					velocity.x = signf(to_target.x) * maxf(absf(velocity.x), jump_forward_boost)
					_jump_cd_left = jump_cooldown
	# Stuck/lip recovery jump: if trying to move but blocked, hop over ledges/lips.
	if is_on_floor() and _jump_cd_left <= 0.0 and absf(desired_vx) > 0.01:
		if target != null:
			var gap_dir: int = 1 if desired_vx >= 0.0 else -1
			if _should_commit_gap_jump_toward_target(target, gap_dir):
				velocity.y = jump_strength
				velocity.x = float(gap_dir) * maxf(absf(velocity.x), jump_forward_boost)
				_jump_cd_left = jump_cooldown
				_stuck_left = 0.0
				if _visual != null and _visual.has_method("play_jump_idle"):
					_visual.call("play_jump_idle")
				move_and_slide()
				return
		if absf(velocity.x) < stuck_speed_threshold:
			_stuck_left += maxf(delta, 0.0)
		else:
			_stuck_left = 0.0
		var dir_sign: int = 1 if desired_vx >= 0.0 else -1
		var blocked_forward: bool = _is_forward_blocked(dir_sign)
		if blocked_forward or _stuck_left >= stuck_jump_delay:
			velocity.y = jump_strength
			velocity.x = float(dir_sign) * maxf(absf(velocity.x), jump_forward_boost)
			_jump_cd_left = jump_cooldown
			_stuck_left = 0.0
	else:
		_stuck_left = 0.0

	# Enemy-like ledge/death-zone guard:
	# never walk into forbidden drops; prefer a committed jump across.
	if prevent_falling_off_ledges and is_on_floor() and _drop_through_timer <= 0.0 and absf(desired_vx) > 0.01:
		var guard_dir: int = 1 if desired_vx >= 0.0 else -1
		if _is_forbidden_drop_ahead(guard_dir):
			if _jump_cd_left <= 0.0:
				velocity.y = jump_strength
				velocity.x = float(guard_dir) * maxf(absf(velocity.x), jump_forward_boost)
				_jump_cd_left = jump_cooldown
				if _visual != null and _visual.has_method("play_jump_idle"):
					_visual.call("play_jump_idle")
			else:
				desired_vx = 0.0

	if absf(desired_vx) > 0.01:
		velocity.x = move_toward(velocity.x, desired_vx, accel * maxf(delta, 0.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * maxf(delta, 0.0))

	if not is_on_floor() or velocity.y < 0.0:
		velocity.y = minf(velocity.y + gravity * maxf(delta, 0.0), max_fall_speed)
	else:
		velocity.y = maxf(velocity.y, 0.0)

	move_and_slide()

func _is_forward_blocked(dir_sign: int) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return false
	var dir: float = -1.0 if dir_sign < 0 else 1.0
	var probe_heights: Array[float] = [obstacle_jump_probe_height, 8.0]
	for h: float in probe_heights:
		var from: Vector2 = global_position + Vector2(0.0, -h)
		var to: Vector2 = from + Vector2(obstacle_jump_probe_distance * dir, 0.0)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
		query.exclude = [self]
		query.collision_mask = world_collision_mask
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			return true
	return false

func _is_forbidden_drop_ahead(dir_sign: int) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return false
	var dir: float = -1.0 if dir_sign < 0 else 1.0
	var from: Vector2 = global_position + Vector2(float(dir) * ground_probe_forward, ground_probe_origin_y)
	var to: Vector2 = from + Vector2(0.0, maxf(ground_probe_distance, 40.0))
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		# No floor detected ahead -> treat as unsafe drop.
		return true
	var collider_v: Variant = hit.get("collider", null)
	if not (collider_v is Node):
		return false
	var collider_node: Node = collider_v as Node
	if _is_forbidden_drop_surface(collider_node):
		return true
	var deeper_from: Vector2 = Vector2(from.x, (hit.get("position", from) as Vector2).y + 8.0)
	var deeper_to: Vector2 = deeper_from + Vector2(0.0, maxf(safe_drop_max_distance, 120.0))
	var deeper_q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(deeper_from, deeper_to)
	deeper_q.exclude = [self]
	deeper_q.collision_mask = world_collision_mask
	var deeper_hit: Dictionary = space.intersect_ray(deeper_q)
	if deeper_hit.is_empty():
		return false
	var deeper_collider_v: Variant = deeper_hit.get("collider", null)
	if deeper_collider_v is Node and _is_forbidden_drop_surface(deeper_collider_v as Node):
		return true
	return false

func _is_forbidden_drop_surface(collider_node: Node) -> bool:
	if collider_node == null or not is_instance_valid(collider_node):
		return false
	var n: Node = collider_node
	var climb: int = 0
	while n != null and climb < 3:
		var name_l: String = String(n.name).to_lower()
		for token: String in forbidden_drop_surface_name_tokens:
			var t: String = token.to_lower()
			if t != "" and name_l.contains(t):
				return true
		n = n.get_parent()
		climb += 1
	return false

func _should_drop_through_toward_target(target: Node2D) -> bool:
	if not enable_drop_through_platforms:
		return false
	if target == null or not is_instance_valid(target):
		return false
	if _drop_through_cd > 0.0 or _drop_through_timer > 0.0:
		return false
	if not is_on_floor():
		return false
	var dy: float = target.global_position.y - global_position.y
	if dy < maxf(drop_through_vertical_min_distance, 24.0):
		return false
	var dx: float = absf(target.global_position.x - global_position.x)
	if dx > maxf(drop_through_horizontal_max_distance, 80.0):
		return false
	var trigger_dx: float = maxf(drop_through_trigger_horizontal_max, 24.0)
	if dx > trigger_dx:
		# Only drop when target is roughly below us; otherwise traverse/jump laterally.
		return false
	var landing: Dictionary = _get_first_landing_below()
	if landing.is_empty():
		return false
	var landing_y: float = float(landing.get("y", global_position.y))
	var landing_delta: float = landing_y - global_position.y
	if landing_delta <= 6.0:
		return false
	if landing_delta > maxf(drop_through_max_safe_landing_delta, 24.0):
		return false
	var landing_node: Node = landing.get("collider", null) as Node
	if _is_forbidden_drop_surface(landing_node):
		return false
	return true

func _is_dropthrough_platform_surface() -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return false
	var from: Vector2 = global_position + Vector2(0.0, 6.0)
	var to: Vector2 = from + Vector2(0.0, 90.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider_v: Variant = hit.get("collider", null)
	if not (collider_v is Node):
		return false
	var n: Node = collider_v as Node
	var name_l: String = String(n.name).to_lower()
	for token: String in drop_surface_name_tokens:
		if token != "" and name_l.contains(token.to_lower()):
			return true
	return false

func _start_drop_through() -> void:
	if _drop_through_timer > 0.0:
		return
	_drop_restore_collision_mask = collision_mask
	_drop_restore_floor_snap_length = floor_snap_length
	# Robust drop-through: disable all world-collision mask bits temporarily.
	# This avoids map-specific one-way platform layer mismatches.
	collision_mask = collision_mask & ~world_collision_mask
	floor_snap_length = 0.0
	_drop_through_timer = maxf(drop_through_duration, 0.05)
	_drop_through_cd = maxf(drop_through_cooldown, 0.0)
	_drop_through_elapsed = 0.0
	_drop_through_start_y = global_position.y
	velocity.y = maxf(velocity.y, drop_through_downward_boost)
	if _visual != null and _visual.has_method("play_jump_idle"):
		_visual.call("play_jump_idle")

func _update_drop_through_state(delta: float) -> void:
	if _drop_through_timer <= 0.0:
		return
	_drop_through_elapsed += maxf(delta, 0.0)
	_drop_through_timer = maxf(_drop_through_timer - maxf(delta, 0.0), 0.0)
	if _visual != null and _visual.has_method("play_jump_idle"):
		_visual.call("play_jump_idle")
	var can_restore_early: bool = _drop_through_elapsed >= maxf(drop_through_min_disable_time, 0.01)
	if can_restore_early:
		if drop_through_restore_after_leaving_platform and not _is_dropthrough_platform_surface():
			collision_mask = _drop_restore_collision_mask
			floor_snap_length = _drop_restore_floor_snap_length
			_drop_through_timer = 0.0
			return
		var max_fall_dist: float = maxf(drop_through_max_disable_fall_distance, 24.0)
		if absf(global_position.y - _drop_through_start_y) >= max_fall_dist:
			collision_mask = _drop_restore_collision_mask
			floor_snap_length = _drop_restore_floor_snap_length
			_drop_through_timer = 0.0
			return
	if _drop_through_timer <= 0.0:
		collision_mask = _drop_restore_collision_mask
		floor_snap_length = _drop_restore_floor_snap_length

func _resolve_or_pick_target() -> Node2D:
	if _retarget_left <= 0.0:
		_target_id = _pick_nearest_target_id()
		_retarget_left = retarget_interval
	if _target_id == 0:
		return null
	var obj: Object = instance_from_id(_target_id)
	if obj == null or not is_instance_valid(obj) or not (obj is Node2D):
		_target_id = 0
		return null
	var target_node: Node2D = obj as Node2D
	if not _is_target_alive(target_node):
		_target_id = 0
		return null
	return target_node

func _pick_nearest_target_id() -> int:
	if _dice_meter == null or not _dice_meter.has_method("_get_reflection_combo_enemy_targets"):
		return 0
	var enemies_v: Variant = _dice_meter.call("_get_reflection_combo_enemy_targets")
	if not (enemies_v is Array):
		return 0
	var best_id: int = 0
	var best_dist: float = INF
	for n: Variant in (enemies_v as Array):
		if not (n is Node2D):
			continue
		var e: Node2D = n as Node2D
		if e == null or not is_instance_valid(e):
			continue
		if not _is_target_alive(e):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best_id = e.get_instance_id()
	return best_id

func _start_combo_attack(target: Node2D) -> void:
	if target == null or not is_instance_valid(target) or not _is_target_alive(target):
		_target_id = 0
		return
	_attack_left = combo_interval
	_pending_target_id = target.get_instance_id()
	_hit_delay_left = hit_delay_seconds
	_combo_step = (_combo_step % 3) + 1
	if _visual != null and _visual.has_method("play_light_combo_step"):
		_visual.call("play_light_combo_step", _combo_step)
	_spawn_light_combo_vfx(target)

func _apply_pending_hit() -> void:
	var target_obj: Object = instance_from_id(_pending_target_id)
	_pending_target_id = 0
	if target_obj == null or not is_instance_valid(target_obj) or not (target_obj is Node):
		_target_id = 0
		return
	if not _is_target_alive(target_obj as Node):
		_target_id = 0
		return
	if _dice_meter != null and _dice_meter.has_method("_apply_player_like_light_to_target"):
		_dice_meter.call("_apply_player_like_light_to_target", target_obj as Node, damage_scale)
	if not _is_target_alive(target_obj as Node):
		_target_id = 0

func _get_first_landing_below() -> Dictionary:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return {}
	var from: Vector2 = global_position + Vector2(0.0, ground_probe_origin_y + 8.0)
	var to: Vector2 = from + Vector2(0.0, maxf(safe_drop_max_distance, 120.0))
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var pos: Vector2 = hit.get("position", from) as Vector2
	return {
		"y": pos.y,
		"collider": hit.get("collider", null)
	}

func _should_commit_gap_jump_toward_target(target: Node2D, dir_sign: int) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var to_target: Vector2 = target.global_position - global_position
	if absf(to_target.x) < maxf(gap_jump_min_target_dx, 8.0):
		return false
	var desired_dir: int = 1 if to_target.x >= 0.0 else -1
	if desired_dir != dir_sign:
		return false
	if _has_ground_close_ahead(dir_sign):
		return false
	var landing: Dictionary = _get_gap_jump_landing(dir_sign)
	if landing.is_empty():
		return false
	var landing_node: Node = landing.get("collider", null) as Node
	if _is_forbidden_drop_surface(landing_node):
		return false
	var landing_y: float = float(landing.get("y", global_position.y))
	var dy: float = landing_y - global_position.y
	if dy > maxf(gap_jump_max_downward_landing_delta, 0.0):
		return false
	if dy < -maxf(gap_jump_max_upward_landing_delta, 0.0):
		return false
	return true

func _has_ground_close_ahead(dir_sign: int) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return true
	var dir: float = -1.0 if dir_sign < 0 else 1.0
	var from: Vector2 = global_position + Vector2(dir * maxf(gap_jump_probe_forward, 8.0), ground_probe_origin_y)
	var to: Vector2 = from + Vector2(0.0, maxf(ground_probe_distance, 60.0))
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()

func _get_gap_jump_landing(dir_sign: int) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return {}
	var dir: float = -1.0 if dir_sign < 0 else 1.0
	var forward: float = maxf(gap_jump_landing_probe_forward, gap_jump_probe_forward + 20.0)
	var from: Vector2 = global_position + Vector2(dir * forward, ground_probe_origin_y - 6.0)
	var to: Vector2 = from + Vector2(0.0, maxf(gap_jump_landing_probe_depth, 80.0))
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var pos: Vector2 = hit.get("position", from) as Vector2
	return {
		"y": pos.y,
		"collider": hit.get("collider", null)
	}

func _is_target_alive(target_node: Node) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	var hp_node: Node = target_node.get_node_or_null("Health")
	if hp_node == null:
		hp_node = target_node.get_node_or_null("BossHealth")
	if hp_node == null:
		return false
	if "hp" in hp_node:
		return int(hp_node.get("hp")) > 0
	return true

func _on_health_died() -> void:
	_fade_and_finish()

func _fade_and_finish() -> void:
	if _dying:
		return
	_dying = true
	set_physics_process(false)
	set_process(false)
	if _visual != null and _visual.has_method("play_idle"):
		_visual.call("play_idle")
	var t: Tween = create_tween()
	t.tween_property(self, "modulate:a", 0.0, fade_out_seconds)
	t.finished.connect(func() -> void:
		summon_finished.emit()
		queue_free()
	)

func _bind_visual_to_actor() -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	# Keep summon visual anchored to this actor (prevents detached/glued visuals).
	_visual.set_deferred("top_level", false)
	_visual.position = Vector2.ZERO

func _spawn_light_combo_vfx(target: Node2D) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	if target == null or not is_instance_valid(target):
		return
	var character_key: String = _spawn_character_name.to_lower()
	var scene: PackedScene = KNIGHT_LIGHT_VFX_SCENE if character_key == "knight" else ROGUE_LIGHT_VFX_SCENE
	if scene == null:
		return
	var node: Node = scene.instantiate()
	var vfx: Node2D = node as Node2D
	if vfx == null:
		node.queue_free()
		return
	tree.current_scene.add_child(vfx)
	var facing: int = 1 if target.global_position.x >= global_position.x else -1
	vfx.global_position = global_position + Vector2(150.0 * float(facing), 0.0)
	if vfx.has_method("set_facing"):
		vfx.call("set_facing", facing)
