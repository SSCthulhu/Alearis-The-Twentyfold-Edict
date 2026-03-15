extends "res://scripts/enemies/EnemyKnightAdd.gd"
class_name EnemyRogueSkeleton

# Rogue Skeleton - crossbow wielding ranged enemy with distance keeping

# Ranged attack
@export var projectile_scene: PackedScene
@export var aim_time: float = 1.0  # Time to aim before shooting
@export var reload_time: float = 1.5  # Time to reload after shooting
@export var ranged_attack_cooldown: float = 4.0  # Total cooldown between ranged attacks
@export var ranged_damage: int = 20
@export var ranged_range: float = 900.0  # Sniper range - doubled from 450
@export var require_line_of_sight: bool = false

# Distance keeping - sniper behavior (maintain long distance)
@export var preferred_distance: float = 600.0  # Doubled from 300
@export var min_distance: float = 400.0  # Doubled from 200
@export var max_distance: float = 800.0  # Doubled from 400
@export var retreat_flip_deadzone: float = 64.0
@export var retreat_cast_buffer: float = 24.0

# State tracking
var _aiming: bool = false
var _shooting: bool = false
var _reloading: bool = false
var _attack_timer: float = 0.0
var _attack_state_duration: float = 0.0
var _ranged_cd: float = 0.0
var _retreat_mode: bool = false

# Animation names
var anim_aim: StringName = &"Player/Ranged_2H_Aiming"
var anim_shoot: StringName = &"Player/Ranged_2H_Shoot"
var anim_reload: StringName = &"Player/Ranged_2H_Reload"

@onready var cast_bar: ProgressBar = $CastBar
@onready var _casting_helper: EnemyCastingHelper = EnemyCastingHelper.new()

func _ready() -> void:
	# Override animations - remove melee, use ranged
	anim_attack = &""  # No melee attack
	anim_dead = &"Player/Skeletons_Death"
	anim_hit = &"Player/Hit_B"
	anim_idle = &"Player/Skeletons_Idle"
	anim_react = &"Player/Skeletons_Taunt"
	anim_walk = &"Player/Skeletons_Walking"
	anim_jump_start = &"Player/Jump_Start"
	anim_jump_idle = &"Player/Jump_Idle"
	anim_jump_land = &"Player/Jump_Land"

	# Mirror other ranged/casting enemies: orange telegraph while aiming.
	add_child(_casting_helper)
	_casting_helper.initialize_cast_bar(cast_bar)
	hold_when_no_vertical_path = false
	# Rogue kiting should stay deterministic: keep retreat/chase horizontal and let
	# slope movement handle ramps naturally. This avoids vertical-traverse arbitration
	# from fighting retreat direction on ramps.
	enable_vertical_traversal = false
	allow_upward_jump_traversal = true
	allow_retreat_step_up_jump = true
	retreat_ramp_probe_distance = 420.0
	enable_drop_through_platforms = true
	stop_when_in_attack_range = false
	melee_never_move_away_from_target = false
	require_confirmed_higher_target_floor_for_jump_up = true
	
	super._ready()

func _physics_process(delta: float) -> void:
	if _death_started:
		return
	
	# Update ranged attack cooldown
	if _ranged_cd > 0.0:
		_ranged_cd -= delta
	
	# Handle attack states:
	# - aiming/shooting lock movement
	# - reloading runs in background and does not freeze movement
	if _aiming or _shooting:
		_update_attack_state(delta)
		# Stay still while attacking
		if not is_on_floor():
			velocity.y += gravity * delta
			velocity.y = minf(velocity.y, max_fall_speed)
		velocity.x = 0.0
		_intent_dir = 0  # Clear intent so facing updates based on target position
		move_and_slide()
		_update_facing()
		_update_locomotion_anim()
		return
	elif _reloading:
		_update_attack_state(delta)
	
	# Normal behavior
	super._physics_process(delta)
	
	# Check for ranged attack opportunity
	if not _aiming and not _shooting and not _reloading and _target != null and is_instance_valid(_target):
		_try_ranged_attack()

func _try_ranged_attack() -> void:
	if _ranged_cd > 0.0:
		return
	if not _can_ranged_attack():
		return
	
	_start_aim()

func _can_ranged_attack() -> bool:
	if projectile_scene == null:
		return false
	if _target == null:
		return false
	var dist: float = global_position.distance_to(_target.global_position)
	if dist > ranged_range:
		return false
	if _retreat_mode:
		return false
	# Do not start a new aim cycle while still in close pressure range.
	if dist < (preferred_distance + maxf(retreat_cast_buffer, 0.0)):
		return false
	
	if require_line_of_sight:
		# Optional strict LOS mode; default is off for platform-heavy arenas.
		var space := get_world_2d().direct_space_state
		var from := global_position + Vector2(0.0, -40.0)
		var to := _target.global_position + Vector2(0.0, -40.0)
		var params := PhysicsRayQueryParameters2D.create(from, to)
		params.exclude = [self]
		params.collision_mask = world_collision_mask
		var hit := space.intersect_ray(params)
		if not hit.is_empty():
			var collider: Variant = hit.get("collider")
			if collider != _target:
				return false
	
	return true

func _start_aim() -> void:
	_aiming = true
	_attack_timer = 0.0
	if _target != null and is_instance_valid(_target):
		_face_toward_position(_target.global_position)
	# Use actual animation length or fallback to export value
	var anim_len := _get_anim_length(anim_aim)
	_attack_state_duration = anim_len if anim_len > 0.0 else aim_time
	_casting_helper.start_cast(_attack_state_duration)
	_play_anim(anim_aim, true)

func _start_shoot() -> void:
	_aiming = false
	_casting_helper.finish_cast()
	_shooting = true
	_attack_timer = 0.0
	if _target != null and is_instance_valid(_target):
		_face_toward_position(_target.global_position)
	# Always use actual animation length for shooting
	_attack_state_duration = _get_anim_length(anim_shoot)
	_play_anim(anim_shoot, true)
	
	# Fire projectile immediately when shoot animation starts
	_fire_projectile()

func _start_reload() -> void:
	_shooting = false
	_reloading = true
	_attack_timer = 0.0
	# Use actual animation length or fallback to export value
	var anim_len := _get_anim_length(anim_reload)
	_attack_state_duration = anim_len if anim_len > 0.0 else reload_time
	_play_anim(anim_reload, true)

func _update_attack_state(delta: float) -> void:
	_attack_timer += delta
	if _aiming and _casting_helper.is_casting:
		_casting_helper.update_cast(delta)
	
	if _attack_timer >= _attack_state_duration:
		if _aiming:
			_start_shoot()
		elif _shooting:
			_start_reload()
		elif _reloading:
			_finish_attack()

func _finish_attack() -> void:
	_aiming = false
	_shooting = false
	_reloading = false
	_casting_helper.finish_cast()
	_ranged_cd = ranged_attack_cooldown

func _fire_projectile() -> void:
	if projectile_scene == null or _target == null:
		return
	
	var projectile: Node = projectile_scene.instantiate()
	if projectile == null:
		return
	
	# Spawn from crossbow position (in front and slightly up)
	var spawn_offset: Vector2 = Vector2(float(_facing_dir) * 40.0, -50.0)
	var spawn_pos: Vector2 = global_position + spawn_offset
	
	var parent: Node = get_tree().current_scene
	if parent == null:
		projectile.queue_free()
		return
	
	parent.add_child(projectile)
	projectile.global_position = spawn_pos
	
	# Set projectile direction and damage
	if projectile.has_method("initialize"):
		var direction: Vector2 = (_target.global_position - spawn_pos).normalized()
		if absf(direction.x) > 0.001:
			_facing_dir = 1 if direction.x > 0.0 else -1
			_apply_sprite_facing(_facing_dir)
		projectile.call("initialize", direction, ranged_damage)

# Override chase behavior for distance keeping
func _chase_desired_velocity() -> float:
	if _target == null:
		return 0.0
	if _aiming or _shooting:
		return 0.0
	
	# Use base class distance keeping helper
	var desired_vx: float = _distance_keeping_velocity(_target.global_position, min_distance, preferred_distance, max_distance)
	var dx: float = _target.global_position.x - global_position.x
	var dist: float = absf(dx)
	# Keep retreat pressure active slightly outside preferred distance so ranged AI
	# does not HOLD/RETREAT churn while preparing shots.
	var pressure_dist: float = maxf(min_distance, preferred_distance + 32.0)
	var retreat_exit_dist: float = pressure_dist + maxf(retreat_flip_deadzone, 24.0)
	if _retreat_mode:
		if dist >= retreat_exit_dist:
			_retreat_mode = false
	else:
		if dist <= pressure_dist:
			_retreat_mode = true
	if _retreat_mode:
		var retreat_dir: float = float(_stable_retreat_dir(dx, 0.24, retreat_flip_deadzone))
		return retreat_dir * move_speed
	# Do not step toward the player just to recover LOS; ranged should stop/attack,
	# then continue retreating away.
	return desired_vx

# Override animation finished to unlock anim lock
func _on_anim_finished(anim_name: StringName) -> void:
	super._on_anim_finished(anim_name)
	
	# Unlock animation lock for all ranged attack animations
	if anim_name == anim_aim or anim_name == anim_shoot or anim_name == anim_reload:
		_anim_locked = false

# Disable melee attacks
func _try_attack() -> void:
	# Rogues don't use melee attacks
	pass
