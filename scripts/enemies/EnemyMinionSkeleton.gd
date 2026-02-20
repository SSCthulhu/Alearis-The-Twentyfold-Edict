extends "res://scripts/enemies/EnemyKnightAdd.gd"
class_name EnemyMinionSkeleton

# Minion-specific properties
@export var spawn_animation: StringName = &"Player/Skeletons_Spawn_Ground"
var _spawning: bool = true

func _ready() -> void:
	# Override animations for unarmed minion
	anim_attack = &"Player/Melee_Unarmed_Attack_Punch_A"
	anim_dead = &"Player/Skeletons_Death"
	anim_hit = &"Player/Hit_B"
	anim_idle = &"Player/Melee_Unarmed_Idle"
	anim_react = &"Player/Skeletons_Taunt"
	anim_walk = &"Player/Skeletons_Walking"
	anim_jump_start = &"Player/Jump_Start"
	anim_jump_idle = &"Player/Jump_Idle"
	anim_jump_land = &"Player/Jump_Land"
	
	# Minion properties - balanced for smaller, faster enemy
	max_hp = 20  # Weaker (vs knight's 60)
	move_speed = 180.0  # Faster (vs knight's 140)
	attack_damage = 8  # Weaker (vs knight's 12)
	attack_cooldown = 1.5  # Faster attacks (vs knight's 2.5)
	attack_hit_time = 0.3  # Quick punch timing (vs knight's 0.4)
	contact_damage = 5  # Weaker (vs knight's 10)
	
	# Smaller hitbox range (balanced for faster attacks)
	melee_forward_bias_px = 35.0  # Shorter reach (vs knight's 55)
	melee_width_px = 30.0  # Narrower (vs knight's 50)
	melee_spawn_forward_px = 0.0  # Same as knight
	
	# Ground probes use default knight values (no override needed)
	
	# Play spawn animation first
	if _has_anim(spawn_animation):
		_play_anim(spawn_animation, false)
		view_3d.stage_animation_finished.connect(_on_spawn_finished, CONNECT_ONE_SHOT)
	else:
		_spawning = false
		super._ready()

func _on_spawn_finished(anim_name: StringName) -> void:
	if anim_name == spawn_animation:
		_spawning = false
		# Move to normal z_index after spawn animation
		z_index = 5
		super._ready()

# Override physics process to prevent movement during spawn
func _physics_process(delta: float) -> void:
	if _spawning:
		# Apply gravity only during spawn
		if not is_on_floor():
			velocity.y += gravity * delta
			velocity.y = minf(velocity.y, max_fall_speed)
		move_and_slide()
		return
	
	# Normal behavior after spawn
	super._physics_process(delta)
