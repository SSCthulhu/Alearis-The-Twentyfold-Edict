extends CharacterBody2D
class_name EnemyKnightAdd

@export var move_speed: float = 140.0
@export var accel: float = 1800.0
@export var friction: float = 2200.0

@export var gravity: float = 1250.0
@export var max_fall_speed: float = 900.0

# Jump
@export var can_jump: bool = true
@export var jump_strength: float = -450.0
@export var jump_check_distance: float = 150.0
@export var jump_cooldown: float = 2.0

# Debug
@export var debug_chase: bool = false

@export var debug_logs: bool = false
@export var debug_floor3_falling: bool = false  # Special debug for Floor 3 falling issues

# --- Melee reach tuning (must match EnemyMeleeHitbox) ---
@export var melee_forward_bias_px: float = 55.0
@export var melee_width_px: float = 50.0
@export var melee_spawn_forward_px: float = 0.0

@export var max_hp: int = 60

@export var edge_aggro_lockout_time: float = 0.75
var _aggro_lockout: float = 0.0

var _home_initialized: bool = false

@export var aggro_range: float = 1360.0
@export var lose_aggro_range: float = 2080.0
@export var patrol_enabled: bool = true
@export var patrol_distance: float = 220.0

@export var standoff_deadzone: float = 4.0
@export var sprite_faces_right: bool = false

@export var contact_damage: int = 10
@export var contact_damage_cooldown: float = 0.6

# -----------------------------
# Attack
# -----------------------------
@export var strikezone_scene: PackedScene
@export var attack_cooldown: float = 1.25
@export var attack_active_time: float = 0.12
@export var attack_damage: int = 12
@export var attack_hit_time: float = 0.70
@export var attack_min_cycle_time: float = 0.0
@export var melee_vertical_range: float = 100.0

# Attack VFX
@export var enable_attack_vfx: bool = true  # Toggle to enable/disable attack VFX
const ATTACK_VFX_SCENE: PackedScene = preload("res://scenes/vfx/BlueSlashVFX.tscn")

# -----------------------------
# Floor activation gating
# -----------------------------
@export var use_floor_activation: bool = true
@export_enum("Vertical (Y-axis)", "Horizontal (X-axis)") var floor_activation_mode: int = 0  # 0 = vertical (World2), 1 = horizontal (World3)
@export var floor_activation_y: float = 999999.0  # For vertical mode (World2)
@export var floor_activation_x: float = -999999.0  # For horizontal mode (World3)
@export var wake_on_damage: bool = true

# -----------------------------
# Same-platform chasing
# -----------------------------
@export var chase_only_when_same_platform: bool = false
@export var same_platform_y_tolerance: float = 48.0
@export var aggro_only_when_same_platform: bool = false
@export var same_platform_floor_y_tolerance: float = 24.0

# -----------------------------
# Ledge safety
# -----------------------------
@export var prevent_falling_off_ledges: bool = true
@export var strict_ledge_guard: bool = false  # World3 mode: Always prevent ledge falls (ignore vertical chase)
@export var ground_probe_forward: float = 18.0
@export var ground_probe_distance: float = 80.0
@export var ground_probe_origin_y: float = 28.0
@export var world_collision_mask: int = 9  # Layers 1 (world) + 8 (enemy-only walls)

@export var platform_probe_distance: float = 140.0
@export var platform_probe_mask: int = 1

# -----------------------------
# Animations
# -----------------------------
@export var anim_attack: StringName = &"Player/Melee_1H_Attack_Stab"
@export var anim_dead: StringName = &"Player/Skeletons_Death"
@export var anim_hit: StringName = &"Player/Hit_B"
@export var anim_idle: StringName = &"Player/Skeletons_Idle"
@export var anim_react: StringName = &"Player/Skeletons_Taunt"
@export var anim_walk: StringName = &"Player/Skeletons_Walking"
@export var anim_jump_start: StringName = &"Player/Jump_Start"
@export var anim_jump_idle: StringName = &"Player/Jump_Idle"
@export var anim_jump_land: StringName = &"Player/Jump_Land"

@export var play_hit_reaction: bool = true

# -----------------------------
# Node refs
# -----------------------------
@onready var view_3d: Enemy3DView = $Enemy3DView
@onready var hurtbox: Area2D = $Hurtbox
@onready var health: EnemyHealth = $Health
@onready var health_bar: ProgressBar = $HealthBar
@onready var run_scaler: RunScaler = $RunScaler
@onready var status_effects: EnemyStatusEffects = get_node_or_null("StatusEffects")

# -----------------------------
# Runtime
# -----------------------------
var _home_x: float
var _patrol_dir: int = 1
var _target: Node2D = null
var _face_target: Node2D = null
var _player_cached: Node2D = null  # ⚡ OPTIMIZATION: Cache player to avoid tree walks

var _contact_cd: float = 0.0
var _attack_cd: float = 0.0
var _jump_cd: float = 0.0

var _intent_dir: int = 0
var _facing_dir: int = 1
var _active: bool = true
var _has_been_damaged: bool = false
var _is_jumping: bool = false
var _was_on_floor: bool = false

# Vertical pathfinding
var _target_ledge_direction: int = 0  # -1 left, 0 none, 1 right
var _ledge_search_cooldown: float = 0.0  # Re-evaluate ledge every X seconds
var _direction_flip_cooldown: float = 0.0  # Prevent rapid direction flipping

var _base_contact_damage: int = 0
var _base_attack_damage: int = 0
var _base_max_hp: int = 0

var _anim_locked: bool = false
var _death_started: bool = false

var _attack_id: int = 0


func _apply_scaling_once() -> void:
	if run_scaler != null:
		run_scaler.apply_once()


func _ready() -> void:
	# Set collision mask to check layers 1 (world) + 8 (enemy-only walls)
	collision_mask = 9
	
	_base_contact_damage = contact_damage
	_base_attack_damage = attack_damage
	_base_max_hp = max_hp

	_active = not use_floor_activation
	if _active:
		_apply_scaling_once()

	if health != null:
		health.max_hp = _base_max_hp
		health.hp = _base_max_hp

	health_bar.max_value = health.max_hp
	health_bar.value = health.hp

	if health != null:
		# Keep death hookup
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

		# ✅ Update HP bar on damage (tagged + legacy)
		if health.has_signal("damaged_tagged"):
			if not health.damaged_tagged.is_connected(_on_health_damaged_tagged):
				health.damaged_tagged.connect(_on_health_damaged_tagged)
		if health.has_signal("damaged"):
			if not health.damaged.is_connected(_on_health_damaged_plain):
				health.damaged.connect(_on_health_damaged_plain)

		# Ensure max stays correct (in case scaling/heals change it)
		health_bar.max_value = health.max_hp
		health_bar.value = health.hp

	_active = not use_floor_activation

	if view_3d != null:
		if not view_3d.stage_animation_finished.is_connected(_on_anim_finished):
			view_3d.stage_animation_finished.connect(_on_anim_finished)
		_play_anim(anim_idle, false)
		view_3d.set_facing(_facing_dir)

	# ✅ Signals (death only here; DamageNumberEmitter handles damaged signals)
	if health != null:
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)
	
	# ⚡ OPTIMIZATION: Cache player reference to avoid tree walks every frame
	_player_cached = get_tree().get_first_node_in_group("player")

func _on_health_damaged_plain(_amount: int) -> void:
	_refresh_health_bar()
	# Play hit animation when damaged (don't lock to allow walking to resume)
	if not _death_started and anim_hit != &"":
		_play_anim(anim_hit, false)

func _on_health_damaged_tagged(_amount: int, _tag: StringName) -> void:
	_refresh_health_bar()
	# Play hit animation when damaged (don't lock to allow walking to resume)
	if not _death_started and anim_hit != &"":
		_play_anim(anim_hit, false)

func _refresh_health_bar() -> void:
	if health == null or health_bar == null:
		return
	health_bar.max_value = health.max_hp
	health_bar.value = health.hp

func _physics_process(delta: float) -> void:
	_aggro_lockout = maxf(0.0, _aggro_lockout - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_jump_cd = maxf(0.0, _jump_cd - delta)
	_ledge_search_cooldown = maxf(0.0, _ledge_search_cooldown - delta)
	_direction_flip_cooldown = maxf(0.0, _direction_flip_cooldown - delta)

	# DEBUG: Track Floor 3 enemies falling
	if debug_floor3_falling:
		# Floor 3 actual Y range is approximately -15500 to -14700
		var on_floor3 = global_position.y >= -15600 and global_position.y <= -14600
		if on_floor3:
			# Log if falling fast or off floor
			if not is_on_floor() and velocity.y > 200:
				pass
			
			# Check if near edge walls (X should be between -1100 on left, 1400 on right)
			if global_position.x < -1000 or global_position.x > 1300:
				pass

	if _death_started:
		_apply_gravity(delta)
		move_and_slide()
		return
	
	# Check for stun - enemy can't act while stunned
	# ⚡ OPTIMIZATION: Use cached status_effects (no node lookup, no reflection)
	if status_effects != null and status_effects.is_stunned():
		_apply_gravity(delta)
		velocity.x = 0.0  # Stop all horizontal movement
		move_and_slide()
		return

	if use_floor_activation and not _active:
		_apply_gravity(delta)
		move_and_slide()

		var player := _get_player()
		if player != null:
			var should_activate: bool = false
			if floor_activation_mode == 1:  # Horizontal (X-axis) mode for World3
				should_activate = player.global_position.x >= floor_activation_x
			else:  # Vertical (Y-axis) mode for World2
				should_activate = player.global_position.y <= floor_activation_y
			
			if should_activate:
				_active = true
				_apply_scaling_once()
		return

	if not _home_initialized and is_on_floor():
		_home_x = global_position.x
		_home_initialized = true

	_apply_gravity(delta)
	_update_target()
	
	# Track floor state for jump landing
	var on_floor_now: bool = is_on_floor()
	if not _was_on_floor and on_floor_now and _is_jumping:
		# Just landed from a jump
		_is_jumping = false
		_play_anim(anim_jump_land, false)
	_was_on_floor = on_floor_now
	
	# Try to jump to reach target on different platform
	if can_jump and _target != null:
		_try_jump_to_target()

	var desired_vx: float = 0.0
	var in_attack_range: bool = false

	if _target != null:
		var dx: float = _target.global_position.x - global_position.x
		var adx: float = absf(dx)
		var dy: float = _target.global_position.y - global_position.y
		var ady: float = absf(dy)
		var melee_reach: float = melee_forward_bias_px + (melee_width_px * 0.5) + melee_spawn_forward_px
		
		# In range only if BOTH horizontally close AND vertically close
		in_attack_range = (adx <= (melee_reach + standoff_deadzone)) and (ady <= melee_vertical_range)

		desired_vx = _chase_desired_velocity()

		# Only stop movement if truly in melee range (both X and Y)
		if in_attack_range:
			velocity.x = 0.0
	else:
		desired_vx = _patrol_desired_velocity() if patrol_enabled else 0.0

	# Ledge prevention - completely disabled when chasing different vertical level (unless strict mode)
	if prevent_falling_off_ledges and absf(desired_vx) > 0.01 and is_on_floor() and not _is_jumping:
		# Check if we're chasing vertically
		var chasing_vertically: bool = false
		if _target != null and is_instance_valid(_target) and not strict_ledge_guard:
			var vertical_diff: float = absf(_target.global_position.y - global_position.y)
			chasing_vertically = vertical_diff > 50.0
		
		# In strict mode, ALWAYS check ledge. Otherwise only check if NOT chasing vertically
		if strict_ledge_guard or not chasing_vertically:
			var guard_dir: int = 1 if desired_vx > 0.0 else -1
			var has_ground: bool = _has_ground_ahead(guard_dir)
			
			if not has_ground:
				# Stop at ledge
				if patrol_enabled:
					_patrol_dir = -guard_dir
				desired_vx = 0.0
				velocity.x = 0.0
				
				if debug_logs and strict_ledge_guard:
					pass

	_intent_dir = 0
	if desired_vx > 0.0:
		_intent_dir = 1
	elif desired_vx < 0.0:
		_intent_dir = -1

	if _intent_dir != 0:
		if (velocity.x > 0.0 and _intent_dir < 0) or (velocity.x < 0.0 and _intent_dir > 0):
			velocity.x = 0.0

	_move_horizontal(desired_vx, delta)
	move_and_slide()
	
	# Wall detection - if we hit a wall while searching for a ledge, try opposite direction
	if _target_ledge_direction != 0 and _direction_flip_cooldown <= 0.0 and get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision := get_slide_collision(i)
			var normal := collision.get_normal()
			
			# Check if we hit a vertical wall (not floor/ceiling)
			# Normal points away from wall: left wall has normal (1,0), right wall has normal (-1,0)
			if absf(normal.y) < 0.3:  # Stricter check - more clearly vertical
				# Check if wall is blocking our search direction
				var wall_blocks_left: bool = normal.x > 0.5  # Wall to our left (normal points right)
				var wall_blocks_right: bool = normal.x < -0.5  # Wall to our right (normal points left)
				
				if (_target_ledge_direction == -1 and wall_blocks_left) or (_target_ledge_direction == 1 and wall_blocks_right):
					# Wall is blocking our current search direction - flip and commit
					_target_ledge_direction = -_target_ledge_direction
					_direction_flip_cooldown = 2.0  # Commit to new direction for 2 seconds
					if debug_logs:
						pass
					break

	_update_facing()
	_update_locomotion_anim()

	if _target != null and in_attack_range:
		_try_attack()

	_try_contact_damage()

# -----------------------------
# Animation helpers
# -----------------------------
func _has_anim(anim: StringName) -> bool:
	if view_3d == null:
		return false
	# Enemy3DView will check if animation exists internally
	return anim != &""

func _get_anim_length(anim: StringName) -> float:
	if view_3d == null:
		return 0.0
	return view_3d.get_anim_length(anim)

func _play_anim(anim: StringName, lock: bool) -> void:
	if view_3d == null:
		return
	if anim == &"":
		return

	if _anim_locked:
		if anim == anim_walk or anim == anim_idle:
			return

	# Use play_one_shot for locked animations (attack, hit, death)
	# Use play_loop for locomotion (walk, idle)
	if lock:
		view_3d.play_one_shot(anim, true, 1.0)
		_anim_locked = true
	else:
		view_3d.play_loop(anim, false)

func _on_anim_finished(anim_name: StringName) -> void:
	if view_3d == null:
		return

	if anim_name == anim_dead:
		queue_free()
		return

	if anim_name == anim_attack:
		_anim_locked = false
		return

	if anim_name == anim_hit or anim_name == anim_react:
		_anim_locked = false
	
	if anim_name == anim_jump_land:
		_anim_locked = false

func _update_locomotion_anim() -> void:
	if _death_started:
		return
	if _anim_locked:
		return
	
	# Jump animation states
	if _is_jumping:
		if velocity.y < -50.0:
			_play_anim(anim_jump_start, false)
		else:
			_play_anim(anim_jump_idle, false)
		return

	var moving: bool = absf(velocity.x) > 2.0
	if moving:
		_play_anim(anim_walk, false)
	else:
		_play_anim(anim_idle, false)

# -----------------------------
# Death handling
# -----------------------------
func _start_death() -> void:
	# print("[EnemyKnightAdd] _start_death called")  # ✅ Disabled for clean logs
	if _death_started:
		return
	_death_started = true

	velocity = Vector2.ZERO
	_target = null
	_face_target = null
	_anim_locked = true

	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	_play_anim(anim_dead, true)

	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)

# -----------------------------
# Existing logic (unchanged)
# -----------------------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	else:
		velocity.y = 0.0

func _update_target() -> void:
	var player: Node2D = _get_player()
	if player == null:
		_target = null
		_face_target = null
		return

	# Floor activation gating
	var not_activated: bool = false
	if floor_activation_mode == 1:  # Horizontal (X-axis) mode for World3
		not_activated = player.global_position.x < floor_activation_x
	else:  # Vertical (Y-axis) mode for World2
		not_activated = player.global_position.y > floor_activation_y
	
	if use_floor_activation and not_activated and not _has_been_damaged:
		_target = null
		_face_target = null
		return

	var d: float = global_position.distance_to(player.global_position)
	var same_platform: bool = _is_same_platform(player)

	# Always face player if close enough
	if d <= aggro_range:
		_face_target = player
	else:
		if _face_target != null and not is_instance_valid(_face_target):
			_face_target = null

	# NEVER break aggro once acquired - chase forever!
	# No lose_aggro_range check, no aggro_lockout check when target exists

	# Maintain existing target - NEVER drop it!
	if _target != null:
		if not is_instance_valid(_target):
			_target = null
			return
		# Once we have a target, keep chasing forever
		return

	# Acquire target only if allowed
	if d <= aggro_range:
		if aggro_only_when_same_platform and not same_platform:
			return
		if chase_only_when_same_platform and not same_platform:
			return
		_target = player

func _get_player() -> Node2D:
	# ⚡ OPTIMIZATION: Use cached player reference (avoids expensive tree walk every frame)
	# Validate cache and refresh if invalid
	if _player_cached != null and is_instance_valid(_player_cached):
		return _player_cached
	
	# Refresh cache if invalid
	_player_cached = get_tree().get_first_node_in_group("player")
	return _player_cached

func _floor_hit_under(node: Node2D) -> Dictionary:
	if node == null:
		return {}
	var space := get_world_2d().direct_space_state
	var from: Vector2 = node.global_position + Vector2(0.0, 6.0)
	var to: Vector2 = from + Vector2(0.0, platform_probe_distance)
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [node]
	params.collision_mask = platform_probe_mask
	return space.intersect_ray(params)

func _is_same_platform(player: Node2D) -> bool:
	if player == null:
		return false
	if not is_on_floor():
		return false
	if player is CharacterBody2D and not (player as CharacterBody2D).is_on_floor():
		return false

	var my_hit: Dictionary = _floor_hit_under(self)
	var pl_hit: Dictionary = _floor_hit_under(player)
	if my_hit.is_empty() or pl_hit.is_empty():
		return false

	var my_y: float = (my_hit["position"] as Vector2).y
	var pl_y: float = (pl_hit["position"] as Vector2).y
	return absf(my_y - pl_y) <= same_platform_floor_y_tolerance

## Distance keeping helper for ranged enemies
## Override this in subclasses to implement distance keeping behavior
func _distance_keeping_velocity(target_pos: Vector2, min_dist: float, preferred_dist: float, max_dist: float) -> float:
	var dx: float = target_pos.x - global_position.x
	var dist: float = absf(dx)
	
	if dist < min_dist:
		# Too close - back away
		return -signf(dx) * move_speed * 0.8
	elif dist > max_dist:
		# Too far - move closer
		return signf(dx) * move_speed * 0.6
	elif dist < preferred_dist:
		# Still a bit close - gentle retreat
		return -signf(dx) * move_speed * 0.4
	else:
		# In ideal range - hold position
		return 0.0

func _chase_desired_velocity() -> float:
	if _target == null:
		return 0.0
	if chase_only_when_same_platform and not _is_same_platform(_target):
		return 0.0

	var dx: float = _target.global_position.x - global_position.x
	var adx: float = absf(dx)
	var dy: float = _target.global_position.y - global_position.y
	var ady: float = absf(dy)

	var to_player_dir: int = 0
	if dx > 0.0:
		to_player_dir = 1
	elif dx < 0.0:
		to_player_dir = -1

	var melee_reach: float = melee_forward_bias_px + (melee_width_px * 0.5) + melee_spawn_forward_px
	var max_dist: float = melee_reach + standoff_deadzone

	# ABSOLUTE PRIORITY: Vertical movement ONLY when on different levels
	# SKIP THIS ENTIRELY in strict ledge guard mode (World3 horizontal)
	var vertical_threshold: float = 50.0
	
	# If on different vertical level, ONLY focus on finding a way down/up
	if not strict_ledge_guard and ady > vertical_threshold:
		# STICKY DIRECTION: Only search for path if we haven't committed yet
		if _target_ledge_direction == 0 and _ledge_search_cooldown <= 0.0:
			_ledge_search_cooldown = 0.3
			
			# PRIORITY 1: Check for ramps first (easier and more natural than jumping)
			var target_y: float = _target.global_position.y
			var left_has_ramp: bool = _has_ramp_toward_target(-1, target_y, 250.0)
			var right_has_ramp: bool = _has_ramp_toward_target(1, target_y, 250.0)
			
			if left_has_ramp or right_has_ramp:
				# Found a ramp! Use it
				if left_has_ramp and right_has_ramp:
					# Both directions have ramps - pick closest to player or nearest ledge
					var left_ledge_dist: float = _find_ledge_distance(-1, 800.0)
					var right_ledge_dist: float = _find_ledge_distance(1, 800.0)
					if left_ledge_dist > 0.0 and right_ledge_dist > 0.0:
						_target_ledge_direction = -1 if left_ledge_dist < right_ledge_dist else 1
					else:
						_target_ledge_direction = to_player_dir if to_player_dir != 0 else -1
				elif left_has_ramp:
					_target_ledge_direction = -1
				else:
					_target_ledge_direction = 1
				
				if debug_logs:
					pass
			else:
				# PRIORITY 2: No ramps found, search for ledges to jump from
				var left_ledge_dist: float = _find_ledge_distance(-1, 800.0)
				var right_ledge_dist: float = _find_ledge_distance(1, 800.0)
				
				if debug_logs:
					pass
				
				# Choose the nearest valid ledge
				if left_ledge_dist > 0.0 and right_ledge_dist > 0.0:
					# Both valid - pick closest, with player direction as tiebreaker
					if absf(left_ledge_dist - right_ledge_dist) < 50.0:
						# Too close to call - use player direction to break tie
						_target_ledge_direction = to_player_dir if to_player_dir != 0 else -1
					else:
						_target_ledge_direction = -1 if left_ledge_dist < right_ledge_dist else 1
				elif left_ledge_dist > 0.0:
					_target_ledge_direction = -1
				elif right_ledge_dist > 0.0:
					_target_ledge_direction = 1
				else:
					# No ledge found - move toward player to explore
					_target_ledge_direction = to_player_dir if to_player_dir != 0 else -1
				
				if debug_logs:
					pass
		
		# COMMIT: Move in the chosen direction until we find a ledge or reach same level
		if _target_ledge_direction != 0:
			if debug_logs:
				pass
			return float(_target_ledge_direction) * move_speed
		if debug_logs:
			pass
		return 0.0
	
	# Same vertical level - reset ledge target and do normal horizontal chase
	_target_ledge_direction = 0
	_ledge_search_cooldown = 0.0  # Reset cooldown when reaching same level
	
	if adx > max_dist:
		return float(to_player_dir) * move_speed
	
	# In range, stop
	return 0.0

func _patrol_desired_velocity() -> float:
	var left: float = _home_x - patrol_distance
	var right: float = _home_x + patrol_distance

	if global_position.x < left:
		_patrol_dir = 1
	elif global_position.x > right:
		_patrol_dir = -1

	return float(_patrol_dir) * move_speed * 0.6

func _move_horizontal(desired_vx: float, delta: float) -> void:
	if absf(desired_vx) > 0.01:
		velocity.x = move_toward(velocity.x, desired_vx, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

func _apply_sprite_facing(dir: int) -> void:
	if view_3d == null:
		return
	# 3D view handles facing via rotation, not flip_h
	# Positive dir = right, negative dir = left
	if sprite_faces_right:
		view_3d.set_facing(dir)
	else:
		view_3d.set_facing(-dir)

func _update_facing() -> void:
	if _intent_dir != 0:
		_facing_dir = _intent_dir
		_apply_sprite_facing(_facing_dir)
		return

	var t: Node2D = _target
	if t == null:
		t = _face_target

	if t != null and is_instance_valid(t):
		var dx: float = t.global_position.x - global_position.x
		if dx > 1.0:
			_facing_dir = 1
		elif dx < -1.0:
			_facing_dir = -1

	_apply_sprite_facing(_facing_dir)

func _try_attack() -> void:
	if _attack_cd > 0.0:
		return
	if strikezone_scene == null:
		return
	if _target == null or not is_instance_valid(_target):
		return
	
	# Check vertical distance - only melee if player is at similar height
	var vertical_dist: float = absf(_target.global_position.y - global_position.y)
	if vertical_dist > melee_vertical_range:
		return  # Skip melee, will chase to get in range (or use ranged if available)

	_play_anim(anim_attack, true)

	_attack_id += 1
	var my_id: int = _attack_id

	var dir: int = 1
	if _target.global_position.x < global_position.x:
		dir = -1

	var anim_len: float = _get_anim_length(anim_attack)
	var min_cycle: float = maxf(attack_cooldown, anim_len)
	if attack_min_cycle_time > 0.0:
		min_cycle = maxf(min_cycle, attack_min_cycle_time)
	_attack_cd = min_cycle

	var hit_delay: float = clampf(attack_hit_time, 0.0, maxf(anim_len, 0.01))
	var spawn_pos: Vector2 = global_position + Vector2(melee_spawn_forward_px * float(dir), 0.0)
	
	# Spawn attack slash VFX
	if enable_attack_vfx and ATTACK_VFX_SCENE != null:
		_spawn_attack_vfx(spawn_pos, dir)

	# ✅ TIMING DEBUG: Mark attack animation start
	var _attack_start_time: float = Time.get_ticks_msec() / 1000.0
	if debug_logs:
		pass

	get_tree().create_timer(hit_delay).timeout.connect(func() -> void:
		if _death_started:
			return
		if my_id != _attack_id:
			return
		if strikezone_scene == null:
			return

		var node: Node = strikezone_scene.instantiate()
		var hb: Node2D = node as Node2D
		if hb == null:
			node.queue_free()
			return

		hb.set("face_dir", dir)
		hb.set("active_time", attack_active_time)
		hb.set("damage", attack_damage)
		hb.set("target_group", &"player")
		hb.set("debug_logs", debug_logs)  # Pass debug flag to hitbox

		var parent: Node = get_tree().current_scene
		if parent == null:
			hb.queue_free()
			return

		parent.add_child.call_deferred(hb)
		hb.set_global_position.call_deferred(spawn_pos)

		# ✅ TIMING DEBUG: Mark hitbox spawn
		var _hitbox_spawn_time: float = Time.get_ticks_msec() / 1000.0
		if debug_logs:
			pass
	)

func _try_contact_damage() -> void:
	if _contact_cd > 0.0:
		return

	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var b: Object = col.get_collider()
		var n: Node = b as Node
		if n != null and n.is_in_group("player"):
			_contact_cd = contact_damage_cooldown
			if n.has_method("take_damage"):
				n.call("take_damage", contact_damage)
			return

func _on_hurtbox_area_entered(a: Area2D) -> void:
	var dmg: int = 0
	if a.has_meta("damage"):
		dmg = int(a.get_meta("damage"))
	elif a.has_method("get_damage"):
		dmg = int(a.call("get_damage"))

	if dmg > 0:
		take_damage(dmg)

func take_damage(amount: int) -> void:
	if health != null and health.has_method("take_damage"):
		health.call("take_damage", amount, self)
		return
	queue_free()

func _has_ground_ahead(dir: int) -> bool:
	var space := get_world_2d().direct_space_state

	var from := global_position + Vector2(float(dir) * ground_probe_forward, ground_probe_origin_y)
	var to := from + Vector2(0.0, ground_probe_distance)

	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask

	var hit := space.intersect_ray(params)
	return not hit.is_empty()

## Find nearest ledge (open edge) in given direction
## Returns distance to ledge, or -1 if no ledge found within max_search_dist
func _find_ledge_distance(search_dir: int, max_search_dist: float = 500.0) -> float:
	var check_step: float = 50.0  # Check every 50px
	var current_dist: float = ground_probe_forward
	var space := get_world_2d().direct_space_state
	
	while current_dist < max_search_dist:
		var check_x: float = global_position.x + float(search_dir) * current_dist
		
		# Check if there's ground at current position (still on platform)
		var from_here := Vector2(check_x, global_position.y + ground_probe_origin_y)
		var to_here := from_here + Vector2(0.0, ground_probe_distance)
		var params_here := PhysicsRayQueryParameters2D.create(from_here, to_here)
		params_here.exclude = [self]
		params_here.collision_mask = world_collision_mask
		var has_ground_here: bool = not space.intersect_ray(params_here).is_empty()
		
		# Check if there's ground ahead from this position (is there a ledge?)
		var from_ahead := Vector2(check_x + float(search_dir) * ground_probe_forward, global_position.y + ground_probe_origin_y)
		var to_ahead := from_ahead + Vector2(0.0, ground_probe_distance)
		var params_ahead := PhysicsRayQueryParameters2D.create(from_ahead, to_ahead)
		params_ahead.exclude = [self]
		params_ahead.collision_mask = world_collision_mask
		var has_ground_ahead: bool = not space.intersect_ray(params_ahead).is_empty()
		
		# Found a ledge: ground here but not ahead
		if has_ground_here and not has_ground_ahead:
			return current_dist
		
		# Ran out of platform entirely
		if not has_ground_here:
			return -1.0
		
		current_dist += check_step
	
	return -1.0  # No ledge found within range

## Check if there's a ramp/slope in the given direction that leads toward target_y
## Returns true if a walkable slope exists that would reduce vertical distance to target
func _has_ramp_toward_target(dir: int, target_y: float, check_distance: float = 200.0) -> bool:
	var space := get_world_2d().direct_space_state
	var my_y: float = global_position.y
	
	# Check ground height at current position
	var from_start := Vector2(global_position.x, my_y + ground_probe_origin_y)
	var to_start := from_start + Vector2(0.0, ground_probe_distance)
	var params_start := PhysicsRayQueryParameters2D.create(from_start, to_start)
	params_start.exclude = [self]
	params_start.collision_mask = world_collision_mask
	var hit_start := space.intersect_ray(params_start)
	
	if hit_start.is_empty():
		return false
	
	var start_ground_y: float = hit_start.get("position", Vector2.ZERO).y
	
	# Check ground height ahead in the given direction
	var check_ahead_x: float = global_position.x + float(dir) * check_distance
	var from_ahead := Vector2(check_ahead_x, my_y + ground_probe_origin_y)
	var to_ahead := from_ahead + Vector2(0.0, ground_probe_distance + 200.0)  # Extra range for slopes
	var params_ahead := PhysicsRayQueryParameters2D.create(from_ahead, to_ahead)
	params_ahead.exclude = [self]
	params_ahead.collision_mask = world_collision_mask
	var hit_ahead := space.intersect_ray(params_ahead)
	
	if hit_ahead.is_empty():
		return false  # No ground ahead (probably a ledge)
	
	var ahead_ground_y: float = hit_ahead.get("position", Vector2.ZERO).y
	var slope_delta_y: float = ahead_ground_y - start_ground_y
	
	# Check if slope direction matches the direction we need to go vertically
	var need_to_go_down: bool = target_y > my_y
	var need_to_go_up: bool = target_y < my_y
	
	var slope_goes_down: bool = slope_delta_y > 20.0  # Slope descends ahead
	var slope_goes_up: bool = slope_delta_y < -20.0   # Slope ascends ahead
	
	# Ramp is useful if it goes in the direction we need
	var ramp_useful: bool = (need_to_go_down and slope_goes_down) or (need_to_go_up and slope_goes_up)
	
	if debug_logs and ramp_useful:
		pass
	
	return ramp_useful

## Check if there's a wall blocking the path in the given direction
## Used to prevent jumping into walls
func _has_wall_in_direction(dir: int, check_distance: float = 100.0) -> bool:
	var space := get_world_2d().direct_space_state
	
	# Raycast horizontally to detect walls (from center of body, not feet)
	var from := global_position + Vector2(0.0, -20.0)  # Check from body center, not feet
	var to := from + Vector2(float(dir) * check_distance, 0.0)
	
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		if debug_logs:
			pass
		return false
	
	# Check if the hit is a wall (vertical surface)
	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	var is_wall: bool = absf(normal.y) < 0.3  # Stricter check - more clearly vertical
	var _hit_distance: float = from.distance_to(hit.get("position", from))
	
	if debug_logs:
		pass
	
	return is_wall

## Check if there's a platform above that we can jump to reach
## Returns true if a jumpable platform exists above us
func _try_jump_to_target() -> void:
	# Strict ledge guard: Never jump off ledges (World3 horizontal mode)
	if strict_ledge_guard:
		return
	
	if _target == null or not is_instance_valid(_target):
		return
	if _jump_cd > 0.0:
		return
	if not is_on_floor():
		return
	
	# Check vertical difference
	var target_y: float = _target.global_position.y
	var my_y: float = global_position.y
	var vertical_diff: float = target_y - my_y
	
	# Only jump if meaningful vertical difference
	if absf(vertical_diff) < 50.0:
		# Reset ledge target when reaching same level
		_target_ledge_direction = 0
		return
	
	# Only attempt jumping to reach lower platforms (no upward jumping)
	# If player is above, just use normal pathfinding (ramps, etc.)
	
	# Check if there's a ledge in the direction we're moving toward
	if _target_ledge_direction == 0:
		return
	
	var has_ground: bool = _has_ground_ahead(_target_ledge_direction)
	
	# CASE 1: Jump at a ledge when target is above or below (DOWN jump)
	if not has_ground:
		# Before jumping, check if there's a wall blocking the jump path
		if _direction_flip_cooldown <= 0.0 and _has_wall_in_direction(_target_ledge_direction, 100.0):
			# Wall detected - flip and commit to opposite direction
			_target_ledge_direction = -_target_ledge_direction
			_direction_flip_cooldown = 2.0  # Commit to new direction for 2 seconds
			if debug_logs:
				pass
			return
		
		# Clear to jump down
		if debug_logs:
			pass
		velocity.y = jump_strength
		_is_jumping = true
		_jump_cd = jump_cooldown
		_play_anim(anim_jump_start, false)
		_anim_locked = true
		return

func _on_died() -> void:
	_start_death()

func _spawn_attack_vfx(spawn_position: Vector2, direction: int) -> void:
	"""Spawns blue slash VFX at attack position"""
	if ATTACK_VFX_SCENE == null:
		return
	
	var vfx: Node2D = ATTACK_VFX_SCENE.instantiate()
	if vfx == null:
		return
	
	# Add to scene root
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		scene_root.add_child(vfx)
		vfx.global_position = spawn_position
		
		# Set VFX facing direction
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", direction)
