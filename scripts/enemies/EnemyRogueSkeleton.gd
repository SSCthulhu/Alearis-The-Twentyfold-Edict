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

# Distance keeping - sniper behavior (maintain long distance)
@export var preferred_distance: float = 600.0  # Doubled from 300
@export var min_distance: float = 400.0  # Doubled from 200
@export var max_distance: float = 800.0  # Doubled from 400

# State tracking
var _aiming: bool = false
var _shooting: bool = false
var _reloading: bool = false
var _attack_timer: float = 0.0
var _attack_state_duration: float = 0.0
var _ranged_cd: float = 0.0

# Animation names
var anim_aim: StringName = &"Player/Ranged_2H_Aiming"
var anim_shoot: StringName = &"Player/Ranged_2H_Shoot"
var anim_reload: StringName = &"Player/Ranged_2H_Reload"

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
	
	super._ready()

func _physics_process(delta: float) -> void:
	if _death_started:
		return
	
	# Update ranged attack cooldown
	if _ranged_cd > 0.0:
		_ranged_cd -= delta
	
	# Handle attack states (aiming, shooting, reloading)
	if _aiming or _shooting or _reloading:
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
	
	# Check line of sight (simple version - not blocked by walls)
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(0.0, -40.0)
	var to := _target.global_position + Vector2(0.0, -40.0)
	
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var hit := space.intersect_ray(params)
	
	# If hit something, check if it's the target or a wall
	if not hit.is_empty():
		var collider = hit.get("collider")
		# If we hit something other than the target, line of sight is blocked
		if collider != _target:
			return false
	
	return true

func _start_aim() -> void:
	_aiming = true
	_attack_timer = 0.0
	# Use actual animation length or fallback to export value
	var anim_len := _get_anim_length(anim_aim)
	_attack_state_duration = anim_len if anim_len > 0.0 else aim_time
	_play_anim(anim_aim, true)

func _start_shoot() -> void:
	_aiming = false
	_shooting = true
	_attack_timer = 0.0
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
		projectile.call("initialize", direction, ranged_damage)

# Override chase behavior for distance keeping
func _chase_desired_velocity() -> float:
	if _target == null:
		return 0.0
	if _aiming or _shooting or _reloading:
		return 0.0
	
	# Use base class distance keeping helper
	return _distance_keeping_velocity(_target.global_position, min_distance, preferred_distance, max_distance)

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
