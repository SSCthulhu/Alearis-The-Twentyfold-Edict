extends "res://scripts/enemies/EnemyKnightAdd.gd"
class_name EnemySkeletonGolem

# Skeleton Golem - Large elite enemy with dual attacks and ranged immunity

# Attack settings
@export var basic_attack_damage: int = 10
@export var slam_damage: int = 25
@export var slam_radius: float = 750.0  # Large AoE radius (tripled from 250)
@export var slam_cast_time: float = 3.0
@export var slam_cooldown: float = 10.0  # Ensure slam happens every ~10 seconds
@export var basic_attack_cooldown: float = 2.0

# Ranged immunity
@export var melee_damage_range: float = 100.0  # Player must be within 100px to damage golem

# ✅ Debug control
@export var debug_golem: bool = false  # Set to false to disable Golem debug logs

# State tracking
var _executing_slam: bool = false  # NEW: Locked during slam animation
var _slam_cd: float = 0.0
var _basic_attack_cd: float = 0.0
var _can_choose_slam: bool = true  # Flag to prioritize slam

# Animation names
var anim_basic_attack: StringName = &"Player/Melee_1H_Slash"
var anim_slam: StringName = &"Player/Melee_2H_Slam"

@onready var cast_bar: ProgressBar = $CastBar
@onready var _casting_helper: EnemyCastingHelper = EnemyCastingHelper.new()

func _ready() -> void:
	# Override animations for large_rig
	anim_attack = &""  # Disable default attack - we'll handle manually
	anim_dead = &"Player/Death_AS"
	anim_hit = &"Player/Hit_A"
	anim_idle = &"Player/Melee_2H_Idle"
	anim_react = &""  # No react animation for golem
	anim_walk = &"Player/Walking_A"
	anim_jump_start = &""  # No jumping
	anim_jump_idle = &""
	anim_jump_land = &""
	
	# Golem stats
	max_hp = 200
	move_speed = 100.0  # Slower than player but faster than other enemies
	
	# Initialize casting helper
	add_child(_casting_helper)
	_casting_helper.initialize_cast_bar(cast_bar)
	
	super._ready()

func _physics_process(delta: float) -> void:
	if _death_started:
		return
	
	# Update cooldowns
	if _slam_cd > 0.0:
		_slam_cd -= delta
	if _basic_attack_cd > 0.0:
		_basic_attack_cd -= delta
	
	# Handle slam casting or executing
	if _casting_helper.is_casting or _executing_slam:
		if _casting_helper.is_casting:
			_update_slam_cast(delta)
		# Stay still while casting/slamming
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

func _update_slam_cast(delta: float) -> void:
	if _casting_helper.update_cast(delta):
		# Immediately transition to executing state
		_casting_helper.finish_cast()
		_executing_slam = true
		# Call async execution
		_execute_slam_async()

func _execute_slam_async() -> void:
	# NOW play the slam animation (cast is complete)
	if debug_golem: print("[Golem] Cast complete! Playing slam animation...")
	_play_anim(anim_slam, true)
	
	# Get full animation length
	var slam_anim_length: float = _get_anim_length(anim_slam)
	if debug_golem: print("[Golem] Slam animation length: ", slam_anim_length, "s")
	
	# Wait for slam animation impact (user reported 0.793-1.0s, using 0.9s)
	if debug_golem: print("[Golem] Waiting 0.9s for slam impact...")
	await get_tree().create_timer(0.9).timeout
	
	# Deal AoE damage at impact moment
	if debug_golem: print("[Golem] IMPACT NOW!")
	_deal_slam_damage()
	
	# Wait for rest of animation to complete
	var remaining_time: float = slam_anim_length - 0.9
	if remaining_time > 0.0:
		if debug_golem: print("[Golem] Waiting ", remaining_time, "s for animation to finish...")
		await get_tree().create_timer(remaining_time).timeout
	
	# Reset cooldowns and unlock
	if debug_golem: print("[Golem] Slam animation complete, unlocking")
	_slam_cd = slam_cooldown
	_can_choose_slam = false
	_executing_slam = false  # Unlock movement

func _deal_slam_damage() -> void:
	# Find the player
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		if debug_golem: print("[Golem] Slam: No player found!")
		return
	
	# Check if player is in range
	var dist: float = global_position.distance_to(player.global_position)
	if debug_golem: print("[Golem] Slam executed! Distance to player: ", dist, "px, slam_radius: ", slam_radius, "px")
	
	if dist > slam_radius:
		if debug_golem: print("[Golem] Slam MISSED - player too far!")
		return
	
	# Deal damage to player's Health node (same as EnemyMeleeHitbox approach)
	if player.has_node("Health"):
		var player_health: Node = player.get_node("Health")
		if player_health != null and player_health.has_method("take_damage"):
			# PlayerHealth signature: take_damage(amount, source, ignore_invuln)
			var argc: int = player_health.get_method_argument_count("take_damage")
			if argc >= 3:
				player_health.call("take_damage", slam_damage, self, false)
			elif argc >= 2:
				player_health.call("take_damage", slam_damage, self)
			else:
				player_health.call("take_damage", slam_damage)
			if debug_golem: print("[Golem] Slam HIT player for ", slam_damage, " damage!")
		else:
			if debug_golem: print("[Golem] Player Health node doesn't have take_damage method!")
	else:
		if debug_golem: print("[Golem] Player doesn't have Health child node!")

# Override attack behavior to handle dual attacks
func _try_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	
	# Check if in attack range (must match base class calculation!)
	var dx: float = _target.global_position.x - global_position.x
	var dy: float = _target.global_position.y - global_position.y
	var melee_reach: float = melee_forward_bias_px + (melee_width_px * 0.5) + melee_spawn_forward_px
	var in_range: bool = (
		absf(dx) <= (melee_reach + standoff_deadzone + 10.0) and  # +10 buffer to prevent edge cases
		absf(dy) <= melee_vertical_range
	)
	
	if not in_range:
		return
	
	# Don't start new attacks if already executing slam
	if _executing_slam:
		return
	
	# Prioritize slam if off cooldown
	if _slam_cd <= 0.0 and _can_choose_slam:
		_start_slam_cast()
	elif _basic_attack_cd <= 0.0:
		_perform_basic_attack()

func _start_slam_cast() -> void:
	# Don't start if already casting or executing
	if _casting_helper.is_casting or _executing_slam:
		return
		
	_casting_helper.start_cast(slam_cast_time)
	
	# Don't play slam animation yet - wait for cast to finish!
	if debug_golem: print("[Golem] Starting slam CAST - bar filling for 3s...")

func _perform_basic_attack() -> void:
	_play_anim(anim_basic_attack, true)
	_basic_attack_cd = basic_attack_cooldown
	
	# Allow slam to be chosen again after basic attack
	_can_choose_slam = true
	
	# Spawn hitbox after delay
	if attack_hit_time > 0.0:
		await get_tree().create_timer(attack_hit_time).timeout
	
	if _death_started or _target == null or not is_instance_valid(_target):
		return
	
	_spawn_melee_hitbox(basic_attack_damage)

func _spawn_melee_hitbox(damage: int) -> void:
	if strikezone_scene == null:
		return
	
	var hitbox: Node = strikezone_scene.instantiate()
	if hitbox == null:
		return
	
	# Set facing direction BEFORE adding to tree (before _ready() runs)
	if hitbox.has_method("set"):
		hitbox.set("face_dir", _facing_dir)
	
	var parent: Node = get_tree().current_scene
	if parent == null:
		hitbox.queue_free()
		return
	
	parent.add_child(hitbox)
	
	# Position hitbox at golem center - EnemyMeleeHitbox will apply offset in _ready()
	hitbox.global_position = global_position + Vector2(0.0, -40.0)
	
	# Scale hitbox for large enemy
	if hitbox is Node2D:
		hitbox.scale = Vector2(2.5, 2.5)
	
	# Set damage
	if hitbox.has_method("set_damage"):
		hitbox.call("set_damage", damage)
	elif hitbox is Area2D:
		hitbox.set_meta("damage", damage)
	
	if debug_golem: print("[Golem] Spawned hitbox at: ", hitbox.global_position, " facing: ", _facing_dir, " damage: ", damage)

# Override animation finished
func _on_anim_finished(anim_name: StringName) -> void:
	super._on_anim_finished(anim_name)
	
	# Unlock animation lock for golem animations
	if anim_name == anim_basic_attack or anim_name == anim_slam:
		_anim_locked = false

# Disable jumping
func _try_jump_to_target() -> void:
	return  # Golem never jumps

func _should_attempt_jump() -> bool:
	return false  # Golem never jumps
