extends "res://scripts/enemies/EnemyKnightAdd.gd"
class_name EnemySkeletonMage

# Skeleton Mage - pure caster enemy with rapid ranged attacks and distance keeping

# Ranged attack
@export var projectile_scene: PackedScene
@export var ranged_cast_time: float = 1.5  # Faster than Necromancer (was 2.0)
@export var ranged_cooldown: float = 3.5  # Much faster than Necromancer (was 6.0)
@export var ranged_damage: int = 12  # Slightly less than Necromancer (was 15)
@export var ranged_range: float = 700.0  # Long caster range (increased from 450)

# Distance keeping
@export var preferred_distance: float = 350.0  # Increased from 280
@export var min_distance: float = 250.0  # Increased from 200
@export var max_distance: float = 500.0  # Increased from 400

# State tracking
var _shooting: bool = false  # Playing shoot animation after cast
var _ranged_cd: float = 0.0

# Magic animation names (same as Necromancer)
var anim_cast: StringName = &"Player/Ranged_Magic_Spellcasting"
var anim_shoot: StringName = &"Player/Ranged_Magic_Shoot"

@onready var cast_bar: ProgressBar = $CastBar
@onready var _casting_helper: EnemyCastingHelper = EnemyCastingHelper.new()

func _ready() -> void:
	# Override animations - no melee
	anim_attack = &""  # Mages don't use melee
	anim_dead = &"Player/Skeletons_Death"
	anim_hit = &"Player/Hit_B"
	anim_idle = &"Player/Skeletons_Idle"
	anim_react = &"Player/Skeletons_Taunt"
	anim_walk = &"Player/Skeletons_Walking"
	anim_jump_start = &"Player/Jump_Start"
	anim_jump_idle = &"Player/Jump_Idle"
	anim_jump_land = &"Player/Jump_Land"
	
	# Initialize casting helper
	add_child(_casting_helper)
	_casting_helper.initialize_cast_bar(cast_bar)
	
	super._ready()

func _physics_process(delta: float) -> void:
	if _death_started:
		return
	
	# Update cooldowns
	if _ranged_cd > 0.0:
		_ranged_cd -= delta
	
	# Handle casting or shooting
	if _casting_helper.is_casting or _shooting:
		if _casting_helper.is_casting:
			_update_casting(delta)
		# Don't call super - stay still while casting/shooting
		# Still apply gravity
		if not is_on_floor():
			velocity.y += gravity * delta
			velocity.y = minf(velocity.y, max_fall_speed)
		velocity.x = 0.0
		move_and_slide()
		_update_facing()
		_update_locomotion_anim()
		return
	
	# Normal behavior
	super._physics_process(delta)
	
	# Check for ranged opportunities
	if not _casting_helper.is_casting and _target != null and is_instance_valid(_target):
		_try_ranged_attack()

func _try_ranged_attack() -> void:
	if _ranged_cd > 0.0:
		return
	if not _can_ranged_attack():
		return
	
	_start_ranged_cast()

func _can_ranged_attack() -> bool:
	if projectile_scene == null:
		return false
	if _target == null:
		return false
	var dist: float = global_position.distance_to(_target.global_position)
	return dist <= ranged_range

func _start_ranged_cast() -> void:
	# Use actual animation length or fallback to export value
	var anim_len := _get_anim_length(anim_cast)
	var duration: float = anim_len if anim_len > 0.0 else ranged_cast_time
	
	_casting_helper.start_cast(duration)
	_play_anim(anim_cast, true)

func _update_casting(delta: float) -> void:
	if _casting_helper.update_cast(delta):
		_finish_cast()

func _finish_cast() -> void:
	_casting_helper.finish_cast()
	_shooting = true  # Lock in shooting animation
	
	# Execute the spell effect
	_fire_projectile()
	_ranged_cd = ranged_cooldown
	
	# Play shoot animation (will unlock when animation finishes)
	_play_anim(anim_shoot, true)

func _fire_projectile() -> void:
	if projectile_scene == null or _target == null:
		return
	
	var projectile: Node = projectile_scene.instantiate()
	if projectile == null:
		return
	
	var spawn_pos: Vector2 = global_position + Vector2(0.0, -40.0)
	
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
	if _casting_helper.is_casting:
		return 0.0
	
	# Use base class distance keeping helper
	return _distance_keeping_velocity(_target.global_position, min_distance, preferred_distance, max_distance)

# Override animation finished to unlock shooting state and anim lock
func _on_anim_finished(anim_name: StringName) -> void:
	super._on_anim_finished(anim_name)
	
	# Unlock animation lock for all magic animations
	if anim_name == anim_cast or anim_name == anim_shoot:
		_anim_locked = false
	
	# Unlock shooting state when shoot animation finishes
	if anim_name == anim_shoot:
		_shooting = false

# Disable melee attacks
func _try_attack() -> void:
	# Mages don't use melee attacks
	pass
