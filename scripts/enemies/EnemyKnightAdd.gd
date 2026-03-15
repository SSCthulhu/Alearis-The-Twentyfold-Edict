extends CharacterBody2D
class_name EnemyKnightAdd
const VfxRenderUtil = preload("res://scripts/vfx/VfxRenderUtil.gd")

@export var move_speed: float = 140.0
@export var accel: float = 1800.0
@export var friction: float = 2200.0
@export var movement_speed_multiplier: float = 1.25
@export var locomotion_anim_speed_multiplier: float = 1.20

@export var gravity: float = 1250.0
@export var max_fall_speed: float = 900.0

@export_group("Ground Adhesion")
@export var enable_slope_ground_adhesion: bool = true
@export var slope_floor_snap_length: float = 26.0
@export var slope_floor_max_angle_deg: float = 55.0
@export var slope_snap_requires_downward_motion: bool = false

# Jump
@export var can_jump: bool = true
@export var jump_strength: float = -1037.5
@export var jump_check_distance: float = 150.0
@export var jump_cooldown: float = 2.0
@export var enable_vertical_traversal: bool = true
@export var allow_upward_jump_traversal: bool = true
@export var jump_up_probe_height_bonus: float = 72.0
@export var jump_up_horizontal_boost: float = 0.55
@export var upward_jump_strength: float = -1037.5
@export var jump_over_obstacles: bool = true
@export var suppress_jump_when_ramp_available: bool = true
@export var ramp_jump_suppress_max_height: float = 260.0
@export var ramp_jump_suppress_max_dx: float = 420.0
@export var ramp_jump_commit_max_dx: float = 300.0
@export var enable_small_ledge_step_up: bool = true
@export var small_ledge_step_up_min_height: float = 10.0
@export var small_ledge_step_up_max_height: float = 42.0
@export var small_ledge_step_up_probe_forward: float = 72.0
@export var small_ledge_step_up_target_dx_max: float = 240.0
@export var ascend_stuck_jump_delay: float = 0.18
@export var ascend_stuck_wall_probe_distance: float = 46.0
@export var allow_retreat_step_up_jump: bool = false
@export var require_confirmed_higher_target_floor_for_jump_up: bool = true
@export var vertical_intent_y_threshold: float = 56.0
@export var retreat_vertical_intent_y_threshold: float = 84.0
@export var vertical_retry_fail_window: float = 0.22

# Debug
@export_group("Debug")
@export var debug_chase: bool = false

@export var debug_logs: bool = false
@export var debug_floor3_falling: bool = false  # Special debug for Floor 3 falling issues
@export var debug_nav_decisions: bool = false
@export var debug_nav_print_interval: float = 0.15
@export var debug_nav_arbiter: bool = false
@export var debug_nav_positions: bool = false

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
@export var aggro_by_same_floor_presence: bool = true
@export var same_floor_aggro_y_tolerance: float = 220.0

@export var standoff_deadzone: float = 4.0
@export var nav_center_hysteresis_x: float = 18.0
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
@export var stop_when_in_attack_range: bool = true
@export var melee_never_move_away_from_target: bool = true

# Melee telegraph readability (no-hit support)
@export var enable_melee_telegraph: bool = true
@export var telegraph_fill_color: Color = Color(0.95, 0.15, 0.15, 0.30)
@export var telegraph_width_px: float = 170.0
@export var telegraph_height_px: float = 64.0
@export var telegraph_forward_bias_px: float = 70.0
@export var telegraph_y_offset_px: float = -32.0
@export var telegraph_fade_in_time: float = 0.08
@export var telegraph_fade_out_time: float = 0.06
@export var enable_melee_windup_flash: bool = true
@export var melee_windup_flash_color: Color = Color(1.0, 0.45, 0.45, 1.0)
@export var melee_windup_flash_time: float = 0.10

# Attack VFX
@export var enable_attack_vfx: bool = true  # Toggle to enable/disable attack VFX
@export var attack_vfx_hit_offset_px: float = 20.0  # Offset from hit target along attack direction
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
@export var hold_when_no_vertical_path: bool = false

# -----------------------------
# Performance culling
# -----------------------------
@export var enable_distant_ai_culling: bool = true
@export var distant_ai_cull_distance_x: float = 2400.0
@export var distant_ai_cull_distance_y: float = 1600.0
@export var distant_ai_cull_tick_interval: float = 0.12

# -----------------------------
# Ledge safety
# -----------------------------
@export var prevent_falling_off_ledges: bool = true
@export var strict_ledge_guard: bool = false  # World3 mode: Always prevent ledge falls (ignore vertical chase)
@export var ground_probe_forward: float = 18.0
@export var ground_probe_distance: float = 80.0
@export var ground_probe_origin_y: float = 28.0
@export var world_collision_mask: int = 9  # Layers 1 (world) + 8 (enemy-only walls)
@export var safe_drop_max_distance: float = 1200.0
@export var safe_drop_target_y_tolerance: float = 420.0
@export var max_walk_step_down_height: float = 220.0
@export var allow_drop_from_unknown_surface: bool = false
@export var no_drop_floor_grace_time: float = 0.20
@export var no_drop_surface_name_tokens: PackedStringArray = PackedStringArray(["nodropplatform", "no_drop_platform"])
@export var never_dropthrough_surface_name_tokens: PackedStringArray = PackedStringArray(["ice", "floor", "cloud"])
@export var drop_surface_name_tokens: PackedStringArray = PackedStringArray(["dropthrough", "oneway", "one_way", "platform", "platforms", "bridge", "ledge"])
@export var forbidden_drop_surface_name_tokens: PackedStringArray = PackedStringArray(["lava", "magma", "acid", "death", "deathzone", "kill", "killzone", "void", "hazard", "damage"])
@export var enable_drop_through_platforms: bool = true
@export var drop_through_world_collision_layer_bit: int = 1
@export var drop_through_duration: float = 0.14
@export var drop_through_downward_boost: float = 280.0
@export var drop_through_vertical_min_distance: float = 90.0
@export var drop_through_horizontal_max_distance: float = 520.0
@export var drop_through_cooldown: float = 0.65
@export var drop_through_target_y_tolerance: float = 220.0
@export var drop_through_max_safe_landing_delta: float = 320.0
@export var drop_through_min_disable_time: float = 0.05
@export var drop_through_max_disable_fall_distance: float = 72.0
@export var drop_through_restore_after_leaving_platform: bool = true
@export var retreat_descend_hold_time: float = 0.90
@export var retreat_edge_recover_delay: float = 0.35
@export var retreat_edge_recover_lock_time: float = 0.70
@export var ranged_edge_escape_lock_time: float = 0.85
@export var ranged_edge_escape_release_distance: float = 96.0
@export var ranged_edge_escape_post_cross_hold_time: float = 0.35
@export var retreat_allow_edge_escape_if_not_forbidden: bool = true
@export var retreat_direction_commit_time: float = 0.32
@export var ascend_direction_commit_time: float = 0.40
@export var vertical_traverse_direction_commit_time: float = 0.22
@export var ascend_traverse_direction_commit_time: float = 0.65
@export var ascend_force_toward_target_dx: float = 260.0
@export var ascend_traverse_reverse_lock_time: float = 0.90
@export var retreat_prefer_dropthrough_on_same_level: bool = true
@export var retreat_dropthrough_same_level_max_dy: float = 72.0
@export var retreat_ramp_probe_distance: float = 320.0
@export var retreat_nav_lock_time: float = 0.45
@export var descend_confirm_hold_time: float = 0.18
@export var retreat_vertical_block_time: float = 0.55

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

enum NavState {
	HOLD,
	CHASE,
	RETREAT,
	ASCEND,
	DESCEND
}

enum VerticalAction {
	NONE,
	JUMP_UP,
	DROP_THROUGH,
	EDGE_DROP
}

enum SurfaceKind {
	UNKNOWN,
	WALKABLE_FLOOR,
	DROPTHROUGH_PLATFORM,
	FORBIDDEN
}

# Vertical pathfinding
var _target_ledge_direction: int = 0  # -1 left, 0 none, 1 right
var _ledge_search_cooldown: float = 0.0  # Re-evaluate ledge every X seconds
var _direction_flip_cooldown: float = 0.0  # Prevent rapid direction flipping
var _distant_ai_cull_timer: float = 0.0
var _is_ai_distant_culled: bool = false
var _drop_through_timer: float = 0.0
var _drop_through_cd: float = 0.0
var _drop_restore_collision_mask: int = 0
var _drop_through_elapsed: float = 0.0
var _drop_through_start_y: float = 0.0
var _preferred_jump_dir: int = 0
var _nav_state: NavState = NavState.HOLD
var _debug_nav_timer: float = 0.0
var _debug_nav_last_line: String = ""
var _vertical_fail_timer: float = 0.0
var _vertical_fail_reason: String = ""
var _retreat_dir_memory: int = 0
var _retreat_dir_memory_timer: float = 0.0
var _retreat_descend_hold_timer: float = 0.0
var _retreat_edge_blocked_timer: float = 0.0
var _retreat_recover_timer: float = 0.0
var _retreat_recover_dir: int = 0
var _retreat_commit_dir: int = 0
var _retreat_commit_timer: float = 0.0
var _ranged_escape_lock_timer: float = 0.0
var _ranged_escape_lock_dir: int = 0
var _ranged_escape_cross_pending: bool = false
var _ranged_escape_start_dx_sign: float = 0.0
var _ranged_escape_post_cross_timer: float = 0.0
var _no_drop_floor_grace_timer: float = 0.0
var _ascend_commit_dir: int = 0
var _ascend_commit_timer: float = 0.0
var _vertical_traverse_commit_dir: int = 0
var _vertical_traverse_commit_timer: float = 0.0
var _ascend_traverse_locked_dir: int = 0
var _ascend_traverse_reverse_lock_timer: float = 0.0
var _retreat_nav_lock_timer: float = 0.0
var _descend_confirm_timer: float = 0.0
var _retreat_vertical_block_timer: float = 0.0
var _ascend_stuck_timer: float = 0.0
var _ascend_no_progress_timer: float = 0.0
var _ascend_last_dx_to_target: float = -1.0

var _base_contact_damage: int = 0
var _base_attack_damage: int = 0
var _base_max_hp: int = 0

var _anim_locked: bool = false
var _death_started: bool = false

var _attack_id: int = 0
var _melee_telegraph: Polygon2D = null
var _telegraph_tween: Tween = null
var _flash_tween: Tween = null
var _view_default_modulate: Color = Color(1, 1, 1, 1)


func _apply_scaling_once() -> void:
	if run_scaler != null:
		run_scaler.apply_once()


func _ready() -> void:
	# Set collision mask to check layers 1 (world) + 8 (enemy-only walls)
	collision_mask = 9
	_drop_restore_collision_mask = collision_mask
	
	_base_contact_damage = contact_damage
	_base_attack_damage = attack_damage
	_base_max_hp = max_hp
	move_speed *= maxf(movement_speed_multiplier, 0.1)
	accel *= maxf(movement_speed_multiplier, 0.1)
	friction *= maxf(movement_speed_multiplier, 0.1)
	floor_max_angle = deg_to_rad(slope_floor_max_angle_deg)

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
		if view_3d.has_method("set_default_speed_multiplier"):
			view_3d.call("set_default_speed_multiplier", locomotion_anim_speed_multiplier)
		_play_anim(anim_idle, false)
		view_3d.set_facing(_facing_dir)
		_view_default_modulate = view_3d.modulate

	# ✅ Signals (death only here; DamageNumberEmitter handles damaged signals)
	if health != null:
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)
	
	# ⚡ OPTIMIZATION: Cache player reference to avoid tree walks every frame
	_player_cached = get_tree().get_first_node_in_group("player")
	_setup_melee_telegraph()

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
	_drop_through_cd = maxf(0.0, _drop_through_cd - delta)
	_debug_nav_timer = maxf(0.0, _debug_nav_timer - delta)
	_vertical_fail_timer = maxf(0.0, _vertical_fail_timer - delta)
	_no_drop_floor_grace_timer = maxf(0.0, _no_drop_floor_grace_timer - delta)
	_retreat_dir_memory_timer = maxf(0.0, _retreat_dir_memory_timer - delta)
	_retreat_descend_hold_timer = maxf(0.0, _retreat_descend_hold_timer - delta)
	_retreat_recover_timer = maxf(0.0, _retreat_recover_timer - delta)
	_retreat_commit_timer = maxf(0.0, _retreat_commit_timer - delta)
	_ranged_escape_lock_timer = maxf(0.0, _ranged_escape_lock_timer - delta)
	_ranged_escape_post_cross_timer = maxf(0.0, _ranged_escape_post_cross_timer - delta)
	_ascend_commit_timer = maxf(0.0, _ascend_commit_timer - delta)
	_vertical_traverse_commit_timer = maxf(0.0, _vertical_traverse_commit_timer - delta)
	_ascend_traverse_reverse_lock_timer = maxf(0.0, _ascend_traverse_reverse_lock_timer - delta)
	_retreat_nav_lock_timer = maxf(0.0, _retreat_nav_lock_timer - delta)
	_retreat_vertical_block_timer = maxf(0.0, _retreat_vertical_block_timer - delta)
	if _retreat_dir_memory_timer <= 0.0:
		_retreat_dir_memory = 0
	if _retreat_recover_timer <= 0.0:
		_retreat_recover_dir = 0
	_update_drop_through_state(delta)
	if _is_no_drop_platform_surface():
		_no_drop_floor_grace_timer = maxf(_no_drop_floor_grace_timer, no_drop_floor_grace_time)

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

	# Skip expensive AI/targeting logic when far from player.
	if _should_cull_distant_ai(delta):
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		_target = null
		_face_target = null
		_update_facing()
		_update_locomotion_anim()
		_try_contact_damage()
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
	_update_slope_ground_adhesion()
	_update_target()
	
	# Track floor state for jump landing
	var on_floor_now: bool = is_on_floor()
	if not _was_on_floor and on_floor_now and _is_jumping:
		# Just landed from a jump
		_is_jumping = false
		_anim_locked = false
		_play_anim(anim_jump_land, false)
	elif _is_jumping:
		# Failsafe: floor contact/probe can flicker near platform edges.
		# If we have nearby ground support and low vertical speed, clear jump state.
		var floor_hit: Dictionary = _floor_hit_under(self)
		var has_probe_support: bool = not floor_hit.is_empty()
		var near_ground_support: bool = false
		if has_probe_support:
			var probe_y: float = (floor_hit["position"] as Vector2).y - ground_probe_origin_y
			near_ground_support = absf(probe_y - global_position.y) <= 18.0
		if on_floor_now or (near_ground_support and absf(velocity.y) <= 48.0):
			_is_jumping = false
			_anim_locked = false
	_was_on_floor = on_floor_now
	
	var desired_vx: float = 0.0
	var in_attack_range: bool = false
	var forced_intent_dir: int = 0
	var retreat_edge_blocked: bool = false
	var movement_owner: String = "none"

	if _target != null:
		var dx: float = _target.global_position.x - global_position.x
		var adx: float = absf(dx)
		var dy: float = _target.global_position.y - global_position.y
		var ady: float = absf(dy)
		var enforce_melee_toward_target: bool = melee_never_move_away_from_target and stop_when_in_attack_range and anim_attack != &""
		var melee_reach: float = melee_forward_bias_px + (melee_width_px * 0.5) + melee_spawn_forward_px
		
		# In range only if BOTH horizontally close AND vertically close
		in_attack_range = (adx <= (melee_reach + standoff_deadzone)) and (ady <= melee_vertical_range)

		desired_vx = _chase_desired_velocity()
		movement_owner = "chase_velocity"
		_update_nav_state(desired_vx)
		if _nav_state == NavState.RETREAT and absf(desired_vx) > 0.01:
			var retreat_dx: float = _target.global_position.x - global_position.x
			var desired_retreat_dir: int = _stable_retreat_dir(retreat_dx, 0.22, 96.0)
			if _retreat_commit_timer <= 0.0 or _retreat_commit_dir == 0:
				_retreat_commit_dir = desired_retreat_dir
				_retreat_commit_timer = maxf(retreat_direction_commit_time, 0.05)
			# Keep retreat movement direction committed for a short window to prevent
			# rapid left/right arbitration when probes flicker on ramps/edges.
			desired_vx = float(_retreat_commit_dir) * absf(desired_vx)
			movement_owner = "retreat_commit"
			# Re-evaluate nav state after retreat commit so downstream vertical/action
			# logic sees the final movement direction, not stale pre-commit intent.
			_update_nav_state(desired_vx)
		elif _nav_state == NavState.ASCEND and absf(desired_vx) > 0.01:
			var desired_ascend_dir: int = 1 if desired_vx > 0.0 else -1
			if _ascend_commit_timer <= 0.0 or _ascend_commit_dir == 0:
				_ascend_commit_dir = desired_ascend_dir
				_ascend_commit_timer = maxf(ascend_direction_commit_time, 0.05)
			desired_vx = float(_ascend_commit_dir) * absf(desired_vx)
			_preferred_jump_dir = _ascend_commit_dir
			movement_owner = "ascend_commit"
		else:
			if _nav_state != NavState.ASCEND:
				_ascend_commit_dir = 0
				_ascend_commit_timer = 0.0
		var retreat_like_motion: bool = _is_moving_away_from_target(desired_vx)
		if retreat_like_motion and (_nav_state == NavState.RETREAT or _retreat_nav_lock_timer > 0.0):
			_retreat_vertical_block_timer = maxf(_retreat_vertical_block_timer, retreat_vertical_block_time)
		
		# Single nav pipeline:
		# 1) vertical intent (if strongly separated), 2) horizontal intent, 3) action commit.
		var to_target_dir: int = 1 if dx >= 0.0 else -1
		var base_traverse_dir: int = to_target_dir
		if absf(desired_vx) > 0.01:
			base_traverse_dir = 1 if desired_vx > 0.0 else -1
		var ramp_assist: bool = (
			enable_vertical_traversal
			and _nav_state != NavState.RETREAT
			and ady > maxf(vertical_intent_y_threshold * 0.45, 24.0)
			and _has_walkable_slope_in_direction(base_traverse_dir, 220.0, _target.global_position.y, true)
		)
		var retreat_descend_requested: bool = _nav_state == NavState.RETREAT and dy > retreat_vertical_intent_y_threshold
		var retreat_descend_confirmed: bool = false
		if retreat_descend_requested:
			var retreat_descend_min_delta: float = maxf(retreat_vertical_intent_y_threshold, maxf(vertical_intent_y_threshold + 16.0, 72.0))
			retreat_descend_confirmed = _has_confirmed_target_floor_below(retreat_descend_min_delta)
		var allow_vertical_intent: bool = enable_vertical_traversal and (ady > vertical_intent_y_threshold or ramp_assist)
		var retreat_vertical_hard_lock: bool = _retreat_vertical_block_timer > 0.0 and retreat_like_motion
		if retreat_vertical_hard_lock:
			allow_vertical_intent = false
		if _nav_state == NavState.RETREAT:
			# Hard rule: retreat stays horizontal (walk ramps naturally) and never
			# hands control to vertical traverse arbitration.
			allow_vertical_intent = false
		if allow_vertical_intent:
			if absf(dx) > 10.0:
				var desired_traverse_dir: int = _pick_vertical_traverse_dir(_target.global_position.y, base_traverse_dir)
				var next_vertical_state: NavState = NavState.DESCEND if dy > 0.0 else NavState.ASCEND
				# For ASCEND, bias toward the player's horizontal side when far away.
				# This prevents left/right ping-pong when both ramp probes look viable.
				if next_vertical_state == NavState.ASCEND:
					var toward_target_dir: int = 1 if dx >= 0.0 else -1
					if absf(dx) >= maxf(ascend_force_toward_target_dx, 80.0):
						var toward_has_slope: bool = _has_walkable_slope_in_direction(toward_target_dir, 320.0, _target.global_position.y, true)
						var away_has_slope: bool = _has_walkable_slope_in_direction(-toward_target_dir, 320.0, _target.global_position.y, true)
						if toward_has_slope or not away_has_slope:
							desired_traverse_dir = toward_target_dir
					if enforce_melee_toward_target:
						desired_traverse_dir = toward_target_dir
				if next_vertical_state == NavState.ASCEND and _ascend_traverse_reverse_lock_timer > 0.0 and _ascend_traverse_locked_dir != 0:
					if desired_traverse_dir != _ascend_traverse_locked_dir:
						desired_traverse_dir = _ascend_traverse_locked_dir
				var traverse_dir: int = desired_traverse_dir
				if _vertical_traverse_commit_timer <= 0.0 or _vertical_traverse_commit_dir == 0:
					_vertical_traverse_commit_dir = desired_traverse_dir
					if next_vertical_state == NavState.ASCEND:
						_vertical_traverse_commit_timer = maxf(ascend_traverse_direction_commit_time, 0.05)
						if _ascend_traverse_locked_dir == 0:
							_ascend_traverse_locked_dir = desired_traverse_dir
						elif _ascend_traverse_locked_dir != desired_traverse_dir:
							# Prevent immediate left/right recommit churn while ascending.
							_vertical_traverse_commit_dir = _ascend_traverse_locked_dir
						_ascend_traverse_reverse_lock_timer = maxf(_ascend_traverse_reverse_lock_timer, ascend_traverse_reverse_lock_time)
					else:
						_vertical_traverse_commit_timer = maxf(vertical_traverse_direction_commit_time, 0.05)
				else:
					traverse_dir = _vertical_traverse_commit_dir
				var descend_route_confirmed: bool = true
				if next_vertical_state == NavState.DESCEND:
					descend_route_confirmed = _can_commit_descend_from_vertical_intent(traverse_dir, _target.global_position.y)
				var block_retreat_descend: bool = _nav_state == NavState.RETREAT and next_vertical_state == NavState.DESCEND and not retreat_descend_confirmed
				var block_unconfirmed_descend: bool = next_vertical_state == NavState.DESCEND and not descend_route_confirmed
				if block_retreat_descend or block_unconfirmed_descend:
					movement_owner = "retreat_descend_guard"
					if debug_nav_decisions and debug_nav_arbiter:
						var guard_reason: String = "retreat_descend_blocked" if block_retreat_descend else "descend_route_unconfirmed"
						_debug_nav("arbiter guard=%s dy=%.1f dir=%d floor=%s target_floor=%s" % [
							guard_reason,
							dy,
							traverse_dir,
							_debug_floor_name_under(self),
							_debug_floor_name_under(_target)
						])
				else:
					desired_vx = float(traverse_dir) * move_speed
					_nav_state = next_vertical_state
					movement_owner = "vertical_traverse_commit"
					_preferred_jump_dir = traverse_dir
			else:
				_preferred_jump_dir = _pick_vertical_traverse_dir(_target.global_position.y, base_traverse_dir)
		else:
			_vertical_traverse_commit_dir = 0
			_vertical_traverse_commit_timer = 0.0
			if _nav_state != NavState.ASCEND:
				_ascend_traverse_locked_dir = 0
				_ascend_traverse_reverse_lock_timer = 0.0
			if retreat_vertical_hard_lock:
				movement_owner = "retreat_vertical_lock"
				if debug_nav_decisions and debug_nav_arbiter:
					_debug_nav("arbiter guard=retreat_vertical_lock t=%.2f dy=%.1f floor=%s target_floor=%s" % [
						_retreat_vertical_block_timer,
						dy,
						_debug_floor_name_under(self),
						_debug_floor_name_under(_target)
					])
			if _nav_state == NavState.RETREAT and retreat_descend_requested and not retreat_descend_confirmed:
				movement_owner = "retreat_descend_guard"
				if debug_nav_decisions and debug_nav_arbiter:
					_debug_nav("arbiter guard=retreat_descend_wait dy=%.1f floor=%s target_floor=%s" % [
						dy,
						_debug_floor_name_under(self),
						_debug_floor_name_under(_target)
					])
			if absf(desired_vx) > 0.01:
				_preferred_jump_dir = 1 if desired_vx > 0.0 else -1
			else:
				_preferred_jump_dir = 1 if dx >= 0.0 else -1
		_target_ledge_direction = _preferred_jump_dir

		# Melee enemies hold for attack window; ranged units can disable this.
		if in_attack_range and stop_when_in_attack_range:
			velocity.x = 0.0
		# Hard melee rule: never move horizontally away from player.
		var has_floor_probe_support_now: bool = not _floor_hit_under(self).is_empty()
		if enforce_melee_toward_target and is_on_floor() and has_floor_probe_support_now:
			var toward_target_dir_h: int = 1 if dx >= 0.0 else -1
			if absf(desired_vx) > 0.01 and signf(desired_vx) != float(toward_target_dir_h):
				desired_vx = absf(desired_vx) * float(toward_target_dir_h)
				forced_intent_dir = toward_target_dir_h
				if _nav_state == NavState.RETREAT:
					_nav_state = NavState.CHASE
				movement_owner = "melee_toward_lock"
		# Ranged edge-escape lock: once cross-through is chosen, keep direction stable
		# briefly to prevent retreat<->cross-through spin loops on no-drop platforms.
		if (not stop_when_in_attack_range) and _ranged_escape_lock_dir != 0:
			var keep_escape_lock: bool = false
			if _target != null and is_instance_valid(_target):
				var lock_dx: float = _target.global_position.x - global_position.x
				var lock_dx_sign: float = signf(lock_dx)
				if _ranged_escape_cross_pending:
					keep_escape_lock = true
					# Crossing is complete once we move from one side of the player to the other.
					if _ranged_escape_start_dx_sign != 0.0 and lock_dx_sign != 0.0 and lock_dx_sign != _ranged_escape_start_dx_sign:
						_ranged_escape_cross_pending = false
						_ranged_escape_post_cross_timer = maxf(ranged_edge_escape_post_cross_hold_time, 0.05)
				if absf(lock_dx) <= maxf(ranged_edge_escape_release_distance, 24.0):
					keep_escape_lock = true
					_ranged_escape_lock_timer = maxf(_ranged_escape_lock_timer, 0.10)
				if _ranged_escape_post_cross_timer > 0.0:
					keep_escape_lock = true
			if keep_escape_lock or _ranged_escape_lock_timer > 0.0:
				desired_vx = float(_ranged_escape_lock_dir) * move_speed
				velocity.x = desired_vx
				forced_intent_dir = _ranged_escape_lock_dir
				movement_owner = "ranged_escape_lock"
			else:
				_ranged_escape_lock_dir = 0
				_ranged_escape_cross_pending = false
				_ranged_escape_start_dx_sign = 0.0
				_ranged_escape_post_cross_timer = 0.0
	else:
		desired_vx = _patrol_desired_velocity() if patrol_enabled else 0.0
		movement_owner = "patrol"
		_nav_state = NavState.HOLD
		_retreat_commit_dir = 0
		_retreat_commit_timer = 0.0
		_ranged_escape_lock_dir = 0
		_ranged_escape_lock_timer = 0.0
		_ranged_escape_cross_pending = false
		_ranged_escape_start_dx_sign = 0.0
		_ranged_escape_post_cross_timer = 0.0

	# Ledge prevention:
	# - strict mode: always prevent falls
	# - non-strict: allow vertical states to use explicit drop logic instead of hard guard
	var ledge_guard_floor_ok: bool = is_on_floor() or _no_drop_floor_grace_timer > 0.0
	if prevent_falling_off_ledges and absf(desired_vx) > 0.01 and ledge_guard_floor_ok and not _is_jumping:
		var force_no_drop_guard: bool = _no_drop_floor_grace_timer > 0.0
		var apply_guard: bool = force_no_drop_guard or strict_ledge_guard or (_nav_state != NavState.ASCEND and _nav_state != NavState.DESCEND)
		if apply_guard:
			var guard_dir: int = 1 if desired_vx > 0.0 else -1
			var on_no_drop_platform: bool = _is_no_drop_platform_surface()
			var has_ground: bool = _has_ground_ahead(guard_dir)
			# On no-drop platforms (typically above death zones), require explicit ground
			# ahead and do not allow slope-probe fallback to "greenlight" edge walk-off.
			if not has_ground and not on_no_drop_platform and _has_walkable_slope_in_direction(guard_dir, 140.0):
				has_ground = true
			# Retreat simplification: allow moving off edges unless we detect a forbidden
			# landing surface (lava/death/kill/void/hazard) below.
			if not has_ground and _nav_state == NavState.RETREAT and retreat_allow_edge_escape_if_not_forbidden:
				if not _is_no_drop_platform_surface() and not _is_forbidden_drop_ahead(guard_dir):
					has_ground = true
			
			if not has_ground:
				# If retreating and that side is blocked, prefer a valid reverse route over standstill.
				if _nav_state == NavState.RETREAT:
					# 45-degree ramps can look like a blocked edge on short probes.
					# Before declaring retreat blocked, search farther for a valid slope path.
					if _has_walkable_slope_in_direction(guard_dir, maxf(retreat_ramp_probe_distance, 220.0)):
						has_ground = true
						movement_owner = "retreat_ramp_path"
						retreat_edge_blocked = false
						forced_intent_dir = guard_dir
					else:
						# Do not reverse direction on retreat edges (causes left/right jitter loops).
						# Retreat descent logic will handle platform drop-through/edge-drop.
						desired_vx = 0.0
						_preferred_jump_dir = guard_dir
						forced_intent_dir = guard_dir
						retreat_edge_blocked = true
						movement_owner = "retreat_edge_block"
			if not has_ground:
				# Stop at ledge
				if patrol_enabled:
					_patrol_dir = -guard_dir
				desired_vx = 0.0
				velocity.x = 0.0
				movement_owner = "ledge_guard_stop"
				if _nav_state == NavState.RETREAT:
					forced_intent_dir = guard_dir
					retreat_edge_blocked = true
				
				if debug_logs and strict_ledge_guard:
					pass

	if _nav_state == NavState.RETREAT:
		if retreat_edge_blocked:
			_retreat_edge_blocked_timer += delta
		else:
			_retreat_edge_blocked_timer = maxf(_retreat_edge_blocked_timer - delta * 1.5, 0.0)

		# Ranged retreat policy: if blocked at an edge and cannot descend safely,
		# immediately cross through pressure instead of stalling/spinning in place.
		if retreat_edge_blocked and (not stop_when_in_attack_range) and _target != null and is_instance_valid(_target):
			var cross_dir_now: int = 1 if _target.global_position.x >= global_position.x else -1
			desired_vx = float(cross_dir_now) * move_speed
			velocity.x = desired_vx
			_retreat_commit_dir = cross_dir_now
			_retreat_commit_timer = maxf(retreat_direction_commit_time, 0.05)
			_ranged_escape_lock_dir = cross_dir_now
			_ranged_escape_lock_timer = maxf(ranged_edge_escape_lock_time, 0.05)
			_ranged_escape_cross_pending = true
			var cross_dx_now: float = _target.global_position.x - global_position.x
			_ranged_escape_start_dx_sign = signf(cross_dx_now)
			forced_intent_dir = cross_dir_now
			retreat_edge_blocked = false
			_retreat_edge_blocked_timer = 0.0
			movement_owner = "retreat_edge_cross_through"

		# If retreat is stalled, immediately cross through the target side to
		# re-establish distance instead of oscillating at edges/ramps.
		if absf(desired_vx) <= 0.01 and _target != null and is_instance_valid(_target):
			var retreat_dir: int = _stable_retreat_dir(_target.global_position.x - global_position.x, 0.24, 96.0)
			if _has_walkable_slope_in_direction(retreat_dir, maxf(retreat_ramp_probe_distance, 220.0)):
				desired_vx = float(retreat_dir) * move_speed
				_retreat_commit_dir = retreat_dir
				_retreat_commit_timer = maxf(retreat_direction_commit_time, 0.05)
				forced_intent_dir = retreat_dir
				retreat_edge_blocked = false
				_retreat_edge_blocked_timer = 0.0
				movement_owner = "retreat_ramp_retry"
			else:
				var cross_dir: int = 1 if _target.global_position.x >= global_position.x else -1
				desired_vx = float(cross_dir) * move_speed
				# Ranged enemies should not "wind up" when crossing through pressure.
				# Snap to full speed so escape feels immediate.
				if not stop_when_in_attack_range:
					velocity.x = desired_vx
					_ranged_escape_lock_dir = cross_dir
					_ranged_escape_lock_timer = maxf(ranged_edge_escape_lock_time, 0.05)
					_ranged_escape_cross_pending = true
					var cross_dx: float = _target.global_position.x - global_position.x
					_ranged_escape_start_dx_sign = signf(cross_dx)
				_retreat_commit_dir = cross_dir
				_retreat_commit_timer = maxf(retreat_direction_commit_time, 0.05)
				forced_intent_dir = cross_dir
				retreat_edge_blocked = false
				_retreat_edge_blocked_timer = 0.0
				movement_owner = "retreat_cross_through"

		# Corner recovery: if retreat remains blocked, commit a short reverse move
		# so the enemy can re-open pathing instead of stalling forever.
		if _retreat_recover_timer > 0.0 and _retreat_recover_dir != 0:
			desired_vx = float(_retreat_recover_dir) * move_speed
			forced_intent_dir = _retreat_recover_dir
			movement_owner = "retreat_recover_lock"
		elif retreat_edge_blocked and _retreat_edge_blocked_timer >= maxf(retreat_edge_recover_delay, 0.05):
			_retreat_recover_dir = -_preferred_jump_dir if _preferred_jump_dir != 0 else 1
			_retreat_recover_timer = maxf(retreat_edge_recover_lock_time, 0.15)
			_retreat_edge_blocked_timer = 0.0
			desired_vx = float(_retreat_recover_dir) * move_speed
			_retreat_commit_dir = _retreat_recover_dir
			_retreat_commit_timer = maxf(retreat_direction_commit_time, 0.05)
			forced_intent_dir = _retreat_recover_dir
			movement_owner = "retreat_recover_start"
	else:
		_retreat_edge_blocked_timer = 0.0
		_retreat_commit_dir = 0
		_retreat_commit_timer = 0.0

	if _nav_state == NavState.ASCEND and is_on_floor() and absf(desired_vx) > 0.01:
		var current_dx_to_target: float = 0.0
		if _target != null and is_instance_valid(_target):
			current_dx_to_target = absf(_target.global_position.x - global_position.x)
		var dx_progressed: bool = false
		if _ascend_last_dx_to_target < 0.0:
			dx_progressed = true
		else:
			dx_progressed = current_dx_to_target <= (_ascend_last_dx_to_target - 2.0)
		var has_horizontal_motion: bool = absf(velocity.x) >= maxf(move_speed * 0.28, 32.0)
		if dx_progressed or has_horizontal_motion:
			_ascend_no_progress_timer = 0.0
			_ascend_stuck_timer = maxf(_ascend_stuck_timer - delta * 2.5, 0.0)
		else:
			_ascend_no_progress_timer += delta
			if _ascend_no_progress_timer >= 0.10:
				_ascend_stuck_timer += delta
		_ascend_last_dx_to_target = current_dx_to_target
	else:
		_ascend_no_progress_timer = 0.0
		_ascend_last_dx_to_target = -1.0
		_ascend_stuck_timer = maxf(_ascend_stuck_timer - delta * 2.5, 0.0)

	var next_intent_dir: int = 0
	if desired_vx > 0.0:
		next_intent_dir = 1
	elif desired_vx < 0.0:
		next_intent_dir = -1
	elif forced_intent_dir != 0:
		next_intent_dir = forced_intent_dir
	var to_target_dx: float = 0.0
	if _target != null and is_instance_valid(_target):
		to_target_dx = _target.global_position.x - global_position.x
	var close_flip_window: bool = absf(to_target_dx) <= 72.0
	var retreat_committed_motion: bool = _nav_state == NavState.RETREAT and absf(desired_vx) > 0.01
	var ranged_committed_motion: bool = (not stop_when_in_attack_range) and absf(desired_vx) > 0.01
	if retreat_committed_motion:
		# During committed retreat movement, intent must follow actual movement direction.
		# Keeping stale intent here causes turn-in-place loops on ramps.
		next_intent_dir = 1 if desired_vx > 0.0 else -1
	elif ranged_committed_motion:
		# Ranged kiting should always face movement direction while repositioning.
		# This prevents moonwalk visuals when escape direction flips near edges/player overlap.
		next_intent_dir = 1 if desired_vx > 0.0 else -1
	else:
		if next_intent_dir != 0 and _intent_dir != 0 and next_intent_dir != _intent_dir:
			if _direction_flip_cooldown > 0.0 or close_flip_window:
				next_intent_dir = _intent_dir
			else:
				_direction_flip_cooldown = 0.18
	_intent_dir = next_intent_dir
	if _intent_dir != 0:
		_preferred_jump_dir = _intent_dir
	if _nav_state == NavState.RETREAT and _target != null and is_instance_valid(_target):
		_preferred_jump_dir = _stable_retreat_dir(_target.global_position.x - global_position.x, 0.28, 120.0)

	# Vertical traversal decisions use current intent/movement context.
	if can_jump and _target != null:
		_try_jump_to_target()

	if _intent_dir != 0:
		if (velocity.x > 0.0 and _intent_dir < 0) or (velocity.x < 0.0 and _intent_dir > 0):
			velocity.x = 0.0

	if debug_nav_decisions and debug_nav_arbiter and _target != null and is_instance_valid(_target):
		var arbiter_line: String = "arbiter owner=%s desired=%.1f intent=%d nav=%s dy=%.1f dx=%.1f floor=%s target_floor=%s" % [
			movement_owner,
			desired_vx,
			_intent_dir,
			_nav_state_name(_nav_state),
			_target.global_position.y - global_position.y,
			absf(_target.global_position.x - global_position.x),
			_debug_floor_name_under(self),
			_debug_floor_name_under(_target)
		]
		_debug_nav(arbiter_line)

	_move_horizontal(desired_vx, delta)
	move_and_slide()

	_update_facing()
	_update_locomotion_anim()

	if _target != null and in_attack_range:
		_try_attack()

	_try_contact_damage()

func _should_cull_distant_ai(delta: float) -> bool:
	if not enable_distant_ai_culling:
		_is_ai_distant_culled = false
		return false
	_distant_ai_cull_timer = maxf(_distant_ai_cull_timer - delta, 0.0)
	if _distant_ai_cull_timer > 0.0:
		return _is_ai_distant_culled
	_distant_ai_cull_timer = maxf(distant_ai_cull_tick_interval, 0.05)

	var player: Node2D = _get_player()
	if player == null or not is_instance_valid(player):
		_is_ai_distant_culled = false
		return false

	var dx: float = absf(player.global_position.x - global_position.x)
	var dy: float = absf(player.global_position.y - global_position.y)
	_is_ai_distant_culled = dx >= maxf(distant_ai_cull_distance_x, 0.0) or dy >= maxf(distant_ai_cull_distance_y, 0.0)
	return _is_ai_distant_culled

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
		_hide_melee_telegraph()
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

	_hide_melee_telegraph()
	_stop_melee_windup_flash()
	if _melee_telegraph != null and is_instance_valid(_melee_telegraph):
		_melee_telegraph.queue_free()
		_melee_telegraph = null

	_play_anim(anim_dead, true)

	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)

func _exit_tree() -> void:
	if _melee_telegraph != null and is_instance_valid(_melee_telegraph):
		_melee_telegraph.queue_free()
	_melee_telegraph = null

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
	var same_floor_for_aggro: bool = aggro_by_same_floor_presence and _is_same_floor_for_aggro(player)
	var should_aggro_now: bool = d <= aggro_range or same_floor_for_aggro

	# Always face player if close enough
	if should_aggro_now:
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
	if should_aggro_now:
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
	# Probe a few nearby vertical lines and only accept floor-like normals.
	# This avoids classifying side walls as "floor" near ramp seams/edges.
	var x_offsets: PackedFloat32Array = PackedFloat32Array([0.0, -10.0, 10.0])
	for x_off: float in x_offsets:
		var from: Vector2 = node.global_position + Vector2(x_off, 6.0)
		var to: Vector2 = from + Vector2(0.0, platform_probe_distance)
		var params := PhysicsRayQueryParameters2D.create(from, to)
		params.exclude = [node]
		params.collision_mask = platform_probe_mask
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			continue
		var normal: Vector2 = hit.get("normal", Vector2.ZERO)
		if normal.dot(Vector2.UP) < 0.35:
			continue
		var collider_obj: Variant = hit.get("collider", null)
		if collider_obj is Node:
			var node_name: String = String((collider_obj as Node).name).to_lower()
			# Keep wall boundary colliders from being treated as floor probes.
			if node_name.contains("wall"):
				continue
		return hit
	return {}

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
		# Too close - back away at full run speed (no slowdown near player).
		return -signf(dx) * move_speed
	elif dist > max_dist:
		# Too far - close in at full run speed.
		return signf(dx) * move_speed
	elif dist < preferred_dist:
		# Slightly close - still retreat at full run speed for snappier kiting.
		return -signf(dx) * move_speed
	else:
		# In ideal range - hold position
		return 0.0

func _stable_retreat_dir(dx: float, hold_seconds: float = 0.22, deadzone: float = 70.0) -> int:
	var abs_dx: float = absf(dx)
	var desired: int = 0
	if abs_dx <= 1.0:
		desired = -_facing_dir if _facing_dir != 0 else -1
	else:
		desired = -1 if dx > 0.0 else 1

	# Keep retreat direction sticky near close-range overlap on ramps,
	# and damp sudden sign flips that cause left/right jitter loops.
	if _retreat_dir_memory != 0:
		var sign_changed: bool = desired != _retreat_dir_memory
		if abs_dx <= deadzone:
			desired = _retreat_dir_memory
		elif sign_changed:
			if _direction_flip_cooldown > 0.0:
				desired = _retreat_dir_memory
			else:
				_direction_flip_cooldown = maxf(_direction_flip_cooldown, hold_seconds)

	if desired == 0:
		desired = -1
	_retreat_dir_memory = desired
	_retreat_dir_memory_timer = maxf(hold_seconds, 0.05)
	return desired

func _update_nav_state(desired_vx: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_nav_state = NavState.HOLD
		_descend_confirm_timer = 0.0
		_retreat_nav_lock_timer = 0.0
		return
	var previous_nav_state: NavState = _nav_state
	var dx: float = _target.global_position.x - global_position.x
	var dy: float = _target.global_position.y - global_position.y
	var vertical_state_threshold: float = maxf(vertical_intent_y_threshold + 16.0, 72.0)
	var descend_confirmed: bool = _has_confirmed_target_floor_below(maxf(retreat_vertical_intent_y_threshold, vertical_state_threshold))
	var retreat_like_motion: bool = _is_moving_away_from_target(desired_vx)
	if retreat_like_motion:
		_nav_state = NavState.RETREAT
		_retreat_nav_lock_timer = maxf(_retreat_nav_lock_timer, retreat_nav_lock_time)
		return
	if not enable_vertical_traversal:
		_descend_confirm_timer = 0.0
		if absf(desired_vx) <= 0.01:
			_nav_state = NavState.HOLD
			_retreat_nav_lock_timer = 0.0
			return
		var to_target_sign_flat: float = signf(dx)
		if absf(dx) <= maxf(nav_center_hysteresis_x, 1.0):
			if _nav_state == NavState.RETREAT or _nav_state == NavState.CHASE:
				if _nav_state == NavState.RETREAT:
					_retreat_nav_lock_timer = maxf(_retreat_nav_lock_timer, retreat_nav_lock_time)
				else:
					_retreat_nav_lock_timer = 0.0
				return
			to_target_sign_flat = 0.0
		if to_target_sign_flat == 0.0:
			_nav_state = NavState.CHASE if desired_vx > 0.0 else NavState.RETREAT
		else:
			var move_sign_flat: float = signf(desired_vx)
			_nav_state = NavState.CHASE if move_sign_flat == to_target_sign_flat else NavState.RETREAT
		if _nav_state == NavState.RETREAT:
			_retreat_nav_lock_timer = maxf(_retreat_nav_lock_timer, retreat_nav_lock_time)
		else:
			_retreat_nav_lock_timer = 0.0
		return
	if _retreat_nav_lock_timer > 0.0 and previous_nav_state == NavState.RETREAT:
		var lock_descend_dir: int = 0
		if absf(desired_vx) > 0.01:
			lock_descend_dir = 1 if desired_vx > 0.0 else -1
		elif absf(dx) > 0.01:
			lock_descend_dir = 1 if dx > 0.0 else -1
		else:
			lock_descend_dir = _facing_dir if _facing_dir != 0 else 1
		var can_break_retreat_lock_for_descend: bool = dy > vertical_state_threshold and _can_commit_descend_from_vertical_intent(lock_descend_dir, _target.global_position.y)
		if not can_break_retreat_lock_for_descend:
			_nav_state = NavState.RETREAT
			return
	# Keep retreat horizontal unless target is meaningfully below.
	# This prevents RETREAT<->ASCEND churn around ramp offsets (dy ~ 40-70).
	if _nav_state == NavState.RETREAT:
		if dy > maxf(retreat_vertical_intent_y_threshold, vertical_state_threshold) and descend_confirmed:
			_nav_state = NavState.DESCEND
			return
	else:
		if dy > vertical_state_threshold and descend_confirmed:
			_nav_state = NavState.DESCEND
			return
		if dy < -vertical_state_threshold:
			_nav_state = NavState.DESCEND if dy > 0.0 else NavState.ASCEND
			return
	if absf(desired_vx) <= 0.01:
		_nav_state = NavState.HOLD
		return

	var to_target_sign: float = signf(dx)
	if absf(dx) <= maxf(nav_center_hysteresis_x, 1.0):
		# Near centerline, preserve previous chase/retreat intent to avoid rapid flips.
		if _nav_state == NavState.RETREAT or _nav_state == NavState.CHASE:
			return
		to_target_sign = 0.0

	if to_target_sign == 0.0:
		# If horizontally aligned, preserve intent from movement direction only.
		_nav_state = NavState.CHASE if desired_vx > 0.0 else NavState.RETREAT
	else:
		var move_sign: float = signf(desired_vx)
		# Moving toward target = chase, away from target = retreat.
		_nav_state = NavState.CHASE if move_sign == to_target_sign else NavState.RETREAT

	# Arbitration guard:
	# When target appears lower but no lower floor is confirmed, treat away-movement
	# as retreat so we do not churn between CHASE/RETREAT around ramp Y offsets.
	if dy > vertical_state_threshold and not descend_confirmed:
		var move_sign_guard: float = signf(desired_vx)
		var to_target_sign_guard: float = signf(dx)
		if move_sign_guard != 0.0 and to_target_sign_guard != 0.0 and move_sign_guard != to_target_sign_guard:
			_nav_state = NavState.RETREAT
	if _nav_state == NavState.RETREAT:
		_retreat_nav_lock_timer = maxf(_retreat_nav_lock_timer, retreat_nav_lock_time)
	else:
		_retreat_nav_lock_timer = 0.0

func _has_confirmed_target_floor_below(min_delta: float) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var my_floor_hit: Dictionary = _floor_hit_under(self)
	var target_floor_hit: Dictionary = _floor_hit_under(_target)
	if my_floor_hit.is_empty() or target_floor_hit.is_empty():
		return false
	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y
	var target_floor_y: float = (target_floor_hit["position"] as Vector2).y
	return (target_floor_y - my_floor_y) >= min_delta

func _nav_state_name(state: NavState) -> String:
	match state:
		NavState.HOLD:
			return "HOLD"
		NavState.CHASE:
			return "CHASE"
		NavState.RETREAT:
			return "RETREAT"
		NavState.ASCEND:
			return "ASCEND"
		NavState.DESCEND:
			return "DESCEND"
	return "UNKNOWN"

func _vertical_action_name(action: VerticalAction) -> String:
	match action:
		VerticalAction.NONE:
			return "NONE"
		VerticalAction.JUMP_UP:
			return "JUMP_UP"
		VerticalAction.DROP_THROUGH:
			return "DROP_THROUGH"
		VerticalAction.EDGE_DROP:
			return "EDGE_DROP"
	return "UNKNOWN"

func _debug_nav(line: String) -> void:
	if not debug_nav_decisions:
		return
	var final_line: String = line
	if debug_nav_positions and _target != null and is_instance_valid(_target):
		final_line += " ex=%.1f ey=%.1f px=%.1f py=%.1f" % [
			global_position.x,
			global_position.y,
			_target.global_position.x,
			_target.global_position.y
		]
	if _debug_nav_timer > 0.0 and final_line == _debug_nav_last_line:
		return
	_debug_nav_timer = maxf(debug_nav_print_interval, 0.01)
	_debug_nav_last_line = final_line
	print("[EnemyNav:%s] %s" % [name, final_line])

func _debug_floor_name_under(node: Node2D) -> String:
	var hit: Dictionary = _floor_hit_under(node)
	if hit.is_empty():
		return "none"
	var collider_obj: Variant = hit.get("collider", null)
	if collider_obj is Node:
		return String((collider_obj as Node).name)
	return "unknown"

func _pick_vertical_traverse_dir(target_y: float, fallback_dir: int) -> int:
	var left_ramp: bool = _has_ramp_toward_target(-1, target_y, 320.0)
	var right_ramp: bool = _has_ramp_toward_target(1, target_y, 320.0)
	if not left_ramp:
		left_ramp = _has_walkable_slope_in_direction(-1, 240.0, target_y, true)
	if not right_ramp:
		right_ramp = _has_walkable_slope_in_direction(1, 240.0, target_y, true)
	if left_ramp and not right_ramp:
		return -1
	if right_ramp and not left_ramp:
		return 1
	if left_ramp and right_ramp:
		return fallback_dir if fallback_dir != 0 else 1
	# No ramp detected in either direction: pick the nearer reachable ledge so we keep progressing
	# instead of stalling against a blocked side.
	var left_ledge: float = _find_ledge_distance(-1, 520.0)
	var right_ledge: float = _find_ledge_distance(1, 520.0)
	if left_ledge > 0.0 and right_ledge <= 0.0:
		return -1
	if right_ledge > 0.0 and left_ledge <= 0.0:
		return 1
	if left_ledge > 0.0 and right_ledge > 0.0:
		return -1 if left_ledge < right_ledge else 1
	return fallback_dir if fallback_dir != 0 else 1

func _update_slope_ground_adhesion() -> void:
	if not enable_slope_ground_adhesion:
		floor_snap_length = 0.0
		return

	floor_max_angle = deg_to_rad(slope_floor_max_angle_deg)
	var disable_snap: bool = _is_jumping or _drop_through_timer > 0.0
	if disable_snap:
		floor_snap_length = 0.0
		return
	if slope_snap_requires_downward_motion and velocity.y < 0.0:
		floor_snap_length = 0.0
		return

	floor_snap_length = maxf(slope_floor_snap_length, 0.0)
	if floor_snap_length <= 0.0:
		return
	# Apply proactively so floor contact does not flicker on ramp seams.
	if not slope_snap_requires_downward_motion or velocity.y >= -1.0:
		apply_floor_snap()

func _has_walkable_slope_in_direction(
	dir: int,
	check_distance: float = 220.0,
	target_y: float = 0.0,
	match_target_vertical: bool = false
) -> bool:
	var space := get_world_2d().direct_space_state
	var start_from := global_position + Vector2(0.0, ground_probe_origin_y)
	var start_to := start_from + Vector2(0.0, maxf(ground_probe_distance, 80.0))
	var start_params := PhysicsRayQueryParameters2D.create(start_from, start_to)
	start_params.exclude = [self]
	start_params.collision_mask = world_collision_mask
	var start_hit: Dictionary = space.intersect_ray(start_params)
	if start_hit.is_empty():
		return false

	var ahead_x: float = global_position.x + float(dir) * maxf(check_distance, 20.0)
	var ahead_top: float = global_position.y - maxf(jump_up_probe_height_bonus + 36.0, 96.0)
	var ahead_from := Vector2(ahead_x, ahead_top)
	var ahead_to := Vector2(ahead_x, global_position.y + ground_probe_origin_y + maxf(ground_probe_distance + 220.0, 160.0))
	var ahead_params := PhysicsRayQueryParameters2D.create(ahead_from, ahead_to)
	ahead_params.exclude = [self]
	ahead_params.collision_mask = world_collision_mask
	var ahead_hit: Dictionary = space.intersect_ray(ahead_params)
	if ahead_hit.is_empty():
		return false

	var start_y: float = (start_hit.get("position", start_from) as Vector2).y
	var ahead_y: float = (ahead_hit.get("position", ahead_from) as Vector2).y
	var delta_y: float = ahead_y - start_y
	if absf(delta_y) < 6.0:
		return false
	if absf(delta_y) > maxf(max_walk_step_down_height + 260.0, 280.0):
		return false

	if match_target_vertical:
		var need_up: bool = target_y < global_position.y
		var need_down: bool = target_y > global_position.y
		if need_up and delta_y > -4.0:
			return false
		if need_down and delta_y < 4.0:
			return false
	return true

func _matches_surface_name_tokens(name_value: String, tokens: PackedStringArray) -> bool:
	var name_lower: String = name_value.to_lower()
	for token: String in tokens:
		if token.is_empty():
			continue
		if name_lower.contains(token.to_lower()):
			return true
	return false

func _is_no_drop_surface(collider_obj: Variant) -> bool:
	if not (collider_obj is Node):
		return false
	var node_name: String = String((collider_obj as Node).name)
	return _matches_surface_name_tokens(node_name, no_drop_surface_name_tokens)

func _is_no_drop_platform_surface() -> bool:
	if not is_on_floor():
		return false
	var floor_hit: Dictionary = _floor_hit_under(self)
	var collider_obj: Variant = floor_hit.get("collider", null) if not floor_hit.is_empty() else _get_floor_collider_from_slide()
	return _is_no_drop_surface(collider_obj)

func _is_forbidden_drop_surface(collider_obj: Variant) -> bool:
	return _surface_kind_for_collider(collider_obj) == SurfaceKind.FORBIDDEN

func _surface_kind_for_collider(collider_obj: Variant) -> SurfaceKind:
	if not (collider_obj is Node):
		return SurfaceKind.UNKNOWN
	var node_name: String = String((collider_obj as Node).name)
	if _matches_surface_name_tokens(node_name, forbidden_drop_surface_name_tokens):
		return SurfaceKind.FORBIDDEN
	if _matches_surface_name_tokens(node_name, no_drop_surface_name_tokens):
		return SurfaceKind.WALKABLE_FLOOR
	if _matches_surface_name_tokens(node_name, never_dropthrough_surface_name_tokens):
		return SurfaceKind.WALKABLE_FLOOR
	if _matches_surface_name_tokens(node_name, drop_surface_name_tokens):
		return SurfaceKind.DROPTHROUGH_PLATFORM
	return SurfaceKind.WALKABLE_FLOOR

func _chase_desired_velocity() -> float:
	if _target == null:
		return 0.0

	var dx: float = _target.global_position.x - global_position.x
	var adx: float = absf(dx)
	var to_player_dir: int = 1 if dx >= 0.0 else -1
	if chase_only_when_same_platform and not _is_same_platform(_target):
		var small_step_bridge: bool = _is_small_floor_step_to_target(maxf(small_ledge_step_up_max_height, same_platform_floor_y_tolerance + 8.0))
		if not small_step_bridge:
			return 0.0

	var melee_reach: float = melee_forward_bias_px + (melee_width_px * 0.5) + melee_spawn_forward_px
	var max_dist: float = melee_reach + standoff_deadzone

	# Horizontal-only core chase. Vertical commit happens in _try_jump_to_target.
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
		if dx > 16.0:
			_facing_dir = 1
		elif dx < -16.0:
			_facing_dir = -1

	_apply_sprite_facing(_facing_dir)

func _face_toward_position(target_pos: Vector2) -> void:
	var dx: float = target_pos.x - global_position.x
	if dx > 16.0:
		_facing_dir = 1
	elif dx < -16.0:
		_facing_dir = -1
	_apply_sprite_facing(_facing_dir)

func _has_clear_line_to_target(target_pos: Vector2, y_offset: float = -40.0) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(0.0, y_offset)
	var to := target_pos + Vector2(0.0, y_offset)
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(params)
	return hit.is_empty()

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
	_show_melee_telegraph(dir, hit_delay)
	_play_melee_windup_flash(hit_delay)

	# ✅ TIMING DEBUG: Mark attack animation start
	var _attack_start_time: float = Time.get_ticks_msec() / 1000.0
	if debug_logs:
		pass

	get_tree().create_timer(hit_delay).timeout.connect(func() -> void:
		_hide_melee_telegraph()
		_stop_melee_windup_flash()
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
		if hb.has_signal("damage_confirmed") and not hb.damage_confirmed.is_connected(_on_attack_damage_confirmed):
			hb.damage_confirmed.connect(_on_attack_damage_confirmed)

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
	var probes: Array[float] = [
		float(dir) * ground_probe_forward,
		float(dir) * (ground_probe_forward + 10.0),
		float(dir) * maxf(ground_probe_forward - 10.0, 6.0)
	]
	var probe_top_offset: float = maxf(jump_up_probe_height_bonus * 0.5, 42.0)
	for probe_x: float in probes:
		var from := global_position + Vector2(probe_x, -probe_top_offset)
		var to := from + Vector2(0.0, maxf(ground_probe_distance, max_walk_step_down_height + 24.0))
		var params := PhysicsRayQueryParameters2D.create(from, to)
		params.exclude = [self]
		params.collision_mask = world_collision_mask
		var hit: Dictionary = space.intersect_ray(params)
		if not hit.is_empty():
			var hit_pos: Vector2 = hit.get("position", from)
			var step_down: float = hit_pos.y - from.y
			if step_down <= max_walk_step_down_height:
				return true
	return false

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
	var ahead_probe_top: float = my_y - maxf(jump_up_probe_height_bonus + 36.0, 96.0)
	var from_ahead := Vector2(check_ahead_x, ahead_probe_top)
	var to_ahead := Vector2(check_ahead_x, my_y + ground_probe_origin_y + ground_probe_distance + 240.0)  # Extra range for slopes
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

func _can_drop_from_current_surface() -> bool:
	var floor_hit: Dictionary = _floor_hit_under(self)
	var collider_obj: Variant = floor_hit.get("collider", null) if not floor_hit.is_empty() else _get_floor_collider_from_slide()
	if collider_obj == null:
		# Fallback near ledge tips where probe can miss despite floor contact.
		return is_on_floor() and allow_drop_from_unknown_surface
	if _is_no_drop_surface(collider_obj):
		return false
	if not (collider_obj is Node):
		return allow_drop_from_unknown_surface
	if _surface_kind_for_collider(collider_obj) == SurfaceKind.DROPTHROUGH_PLATFORM:
		return true
	return allow_drop_from_unknown_surface

func _is_dropthrough_platform_surface() -> bool:
	if not is_on_floor():
		return false
	var floor_hit: Dictionary = _floor_hit_under(self)
	var collider_obj: Variant = floor_hit.get("collider", null) if not floor_hit.is_empty() else _get_floor_collider_from_slide()
	if collider_obj == null:
		return false
	return _surface_kind_for_collider(collider_obj) == SurfaceKind.DROPTHROUGH_PLATFORM

func _get_floor_collider_from_slide() -> Variant:
	if not is_on_floor():
		return null
	var best_dot: float = 0.5
	var best_collider: Variant = null
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision2D = get_slide_collision(i)
		if col == null:
			continue
		var up_dot: float = col.get_normal().dot(Vector2.UP)
		if up_dot >= best_dot:
			best_dot = up_dot
			best_collider = col.get_collider()
	return best_collider

func _can_drop_through_toward_target(target_y: float) -> bool:
	if _is_no_drop_platform_surface():
		return false
	var floor_hit: Dictionary = _floor_hit_under(self)
	if floor_hit.is_empty() and not is_on_floor():
		return false
	var my_floor_y: float = (floor_hit["position"] as Vector2).y if not floor_hit.is_empty() else (global_position.y + ground_probe_origin_y)
	var my_floor_collider: Variant = floor_hit.get("collider", null) if not floor_hit.is_empty() else null
	var space := get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(0.0, 10.0)
	var to: Vector2 = from + Vector2(0.0, maxf(safe_drop_max_distance, 120.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	if my_floor_collider is CollisionObject2D:
		params.exclude.append(my_floor_collider)
	params.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		return false
	var landing_collider: Variant = hit.get("collider", null)
	if _is_forbidden_drop_surface(landing_collider):
		return false
	var landing_y: float = (hit["position"] as Vector2).y
	if landing_y <= my_floor_y + 6.0:
		return false
	var landing_delta: float = landing_y - my_floor_y
	if landing_delta > maxf(drop_through_max_safe_landing_delta, 24.0):
		return false
	var landing_body_y: float = landing_y - ground_probe_origin_y

	# Descend/retreat behavior should be permissive:
	# if we found a valid lower landing and target is below us, allow commit.
	var is_descending_intent: bool = (_nav_state == NavState.DESCEND or _nav_state == NavState.RETREAT) and target_y > (global_position.y + 24.0)
	if is_descending_intent:
		if _target != null and is_instance_valid(_target):
			var target_floor_hit_desc: Dictionary = _floor_hit_under(_target)
			if not target_floor_hit_desc.is_empty():
				var target_floor_y_desc: float = (target_floor_hit_desc["position"] as Vector2).y
				if target_floor_y_desc > my_floor_y + (drop_through_vertical_min_distance * 0.5):
					return true
		return true

	var y_tolerance: float = drop_through_target_y_tolerance if hold_when_no_vertical_path else (drop_through_target_y_tolerance * 2.5)
	if _nav_state == NavState.DESCEND or _nav_state == NavState.RETREAT:
		y_tolerance *= 1.75
	if absf(target_y - landing_body_y) > y_tolerance:
		return false
	if _target != null and is_instance_valid(_target):
		var target_floor_hit: Dictionary = _floor_hit_under(_target)
		if not target_floor_hit.is_empty():
			var target_floor_y: float = (target_floor_hit["position"] as Vector2).y
			var floor_tolerance: float = y_tolerance * 1.25 if (_nav_state == NavState.DESCEND or _nav_state == NavState.RETREAT) else y_tolerance
			if absf(landing_y - target_floor_y) > floor_tolerance:
				return false
	return true

func _can_force_dropthrough_descend() -> bool:
	if not enable_drop_through_platforms:
		return false
	if _drop_through_cd > 0.0:
		return false
	if not is_on_floor():
		return false
	if not _is_dropthrough_platform_surface():
		return false
	if _is_no_drop_platform_surface():
		return false
	if _target == null or not is_instance_valid(_target):
		return false

	var my_floor_hit: Dictionary = _floor_hit_under(self)
	var target_floor_hit: Dictionary = _floor_hit_under(_target)
	if my_floor_hit.is_empty() or target_floor_hit.is_empty():
		return false

	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y
	var target_floor_y: float = (target_floor_hit["position"] as Vector2).y
	if target_floor_y <= my_floor_y + (drop_through_vertical_min_distance * 0.5):
		return false

	# Safety: ensure the first valid landing under us is not a forbidden surface.
	var my_floor_collider: Variant = my_floor_hit.get("collider", null)
	var from: Vector2 = Vector2(global_position.x, my_floor_y + 8.0)
	var to: Vector2 = from + Vector2(0.0, maxf(safe_drop_max_distance, 120.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	if my_floor_collider is CollisionObject2D:
		params.exclude.append(my_floor_collider)
	params.collision_mask = world_collision_mask
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return false
	if _is_forbidden_drop_surface(hit.get("collider", null)):
		return false
	return true

func _can_force_dropthrough_retreat() -> bool:
	if not enable_drop_through_platforms:
		return false
	if _drop_through_cd > 0.0:
		return false
	if not is_on_floor():
		return false
	if not _is_dropthrough_platform_surface():
		return false
	if _is_no_drop_platform_surface():
		return false
	if not _is_target_significantly_below(24.0):
		return false
	# Retreat should prefer descending through platforms when available.
	# Require a safe landing below so we never drop into forbidden/death zones.
	var floor_hit: Dictionary = _floor_hit_under(self)
	if floor_hit.is_empty():
		return false
	var my_floor_collider: Variant = floor_hit.get("collider", null)
	var my_floor_y: float = (floor_hit["position"] as Vector2).y
	var from: Vector2 = Vector2(global_position.x, my_floor_y + 8.0)
	var to: Vector2 = from + Vector2(0.0, maxf(safe_drop_max_distance, 120.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	if my_floor_collider is CollisionObject2D:
		params.exclude.append(my_floor_collider)
	params.collision_mask = world_collision_mask
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return false
	if _is_forbidden_drop_surface(hit.get("collider", null)):
		return false
	return true

func _can_force_dropthrough_retreat_same_level() -> bool:
	if not retreat_prefer_dropthrough_on_same_level:
		return false
	if not enable_drop_through_platforms:
		return false
	if _drop_through_cd > 0.0:
		return false
	if not is_on_floor():
		return false
	if not _is_dropthrough_platform_surface():
		return false
	if _is_no_drop_platform_surface():
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	var dy: float = _target.global_position.y - global_position.y
	if absf(dy) > maxf(retreat_dropthrough_same_level_max_dy, 8.0):
		return false
	# Apply the same forbidden-surface safety gate used by descend/retreat force-drop.
	var floor_hit: Dictionary = _floor_hit_under(self)
	if floor_hit.is_empty():
		return false
	var my_floor_collider: Variant = floor_hit.get("collider", null)
	var my_floor_y: float = (floor_hit["position"] as Vector2).y
	var from: Vector2 = Vector2(global_position.x, my_floor_y + 8.0)
	var to: Vector2 = from + Vector2(0.0, maxf(safe_drop_max_distance, 120.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	if my_floor_collider is CollisionObject2D:
		params.exclude.append(my_floor_collider)
	params.collision_mask = world_collision_mask
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return false
	if _is_forbidden_drop_surface(hit.get("collider", null)):
		return false
	return true

func _update_drop_through_state(delta: float) -> void:
	if _drop_through_timer <= 0.0:
		return
	_drop_through_elapsed += delta
	_drop_through_timer = maxf(_drop_through_timer - delta, 0.0)
	var can_restore_early: bool = _drop_through_elapsed >= maxf(drop_through_min_disable_time, 0.01)
	if can_restore_early:
		# Re-enable world collision as soon as we are no longer standing on a
		# drop-through platform so we cannot tunnel through additional floors.
		if drop_through_restore_after_leaving_platform and not _is_dropthrough_platform_surface():
			collision_mask = _drop_restore_collision_mask
			_drop_through_timer = 0.0
			return
		# Absolute safety clamp: never keep world collision disabled beyond a
		# short vertical travel budget from drop start.
		var max_fall_dist: float = maxf(drop_through_max_disable_fall_distance, 24.0)
		if absf(global_position.y - _drop_through_start_y) >= max_fall_dist:
			collision_mask = _drop_restore_collision_mask
			_drop_through_timer = 0.0
			return
	if _drop_through_timer <= 0.0:
		collision_mask = _drop_restore_collision_mask

func _start_drop_through() -> void:
	if _drop_through_timer > 0.0:
		return
	if _is_no_drop_platform_surface():
		return
	var floor_hit: Dictionary = _floor_hit_under(self)
	var current_floor_collider: Variant = floor_hit.get("collider", null) if not floor_hit.is_empty() else _get_floor_collider_from_slide()
	if _surface_kind_for_collider(current_floor_collider) != SurfaceKind.DROPTHROUGH_PLATFORM:
		# Hard safety: never disable world collision on solid floors (ice/floor/cloud/etc).
		return
	var bit: int = clampi(drop_through_world_collision_layer_bit, 1, 32)
	_drop_restore_collision_mask = collision_mask
	collision_mask = collision_mask & ~(1 << (bit - 1))
	_drop_through_timer = maxf(drop_through_duration, 0.05)
	_drop_through_elapsed = 0.0
	_drop_through_start_y = global_position.y
	_drop_through_cd = maxf(drop_through_cooldown, 0.0)
	velocity.y = maxf(velocity.y, drop_through_downward_boost)
	_is_jumping = true
	_debug_nav("action=DROP_THROUGH dir=%d nav=%s" % [_preferred_jump_dir, _nav_state_name(_nav_state)])

func _can_jump_up_over_obstacle(dir: int) -> bool:
	var gravity_abs: float = maxf(absf(gravity), 1.0)
	var jump_v: float = upward_jump_strength if upward_jump_strength < -1.0 else jump_strength
	var max_jump_height: float = (jump_v * jump_v) / (2.0 * gravity_abs) + maxf(jump_up_probe_height_bonus, 0.0)
	var top_y: float = global_position.y - max_jump_height
	var space := get_world_2d().direct_space_state
	var sample_x: float = global_position.x + float(dir) * maxf(jump_check_distance, 110.0)
	var from := Vector2(sample_x, top_y)
	var to := Vector2(sample_x, global_position.y + ground_probe_origin_y)
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(params)
	return not hit.is_empty()

func _can_step_up_small_ledge(dir: int, dx_to_target: float, vertical_diff: float) -> bool:
	if not enable_small_ledge_step_up:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	if not is_on_floor():
		return false
	if _jump_cd > 0.0:
		return false
	if dx_to_target > maxf(small_ledge_step_up_target_dx_max, 32.0):
		return false
	# Small ledge climb is only for slight upward movement, not full vertical traversal.
	if vertical_diff >= -small_ledge_step_up_min_height:
		return false
	if vertical_diff < -maxf(small_ledge_step_up_max_height * 1.8, 56.0):
		return false

	var my_floor_hit: Dictionary = _floor_hit_under(self)
	var target_floor_hit: Dictionary = _floor_hit_under(_target)
	if my_floor_hit.is_empty() or target_floor_hit.is_empty():
		return false
	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y
	var target_floor_y: float = (target_floor_hit["position"] as Vector2).y
	var floor_step_up: float = my_floor_y - target_floor_y
	if floor_step_up < small_ledge_step_up_min_height or floor_step_up > maxf(small_ledge_step_up_max_height, small_ledge_step_up_min_height):
		return false

	# Prefer ramp walking when a valid upward slope exists.
	if _has_walkable_slope_in_direction(dir, maxf(small_ledge_step_up_probe_forward * 1.6, 120.0), _target.global_position.y, true):
		return false

	var space := get_world_2d().direct_space_state
	var probe_x: float = global_position.x + float(dir) * maxf(small_ledge_step_up_probe_forward, 24.0)
	var from := Vector2(probe_x, global_position.y - maxf(jump_up_probe_height_bonus * 0.5, 42.0))
	var to := Vector2(probe_x, global_position.y + ground_probe_origin_y + maxf(ground_probe_distance + 80.0, 120.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var ahead_hit: Dictionary = space.intersect_ray(params)
	if ahead_hit.is_empty():
		return false
	var ahead_floor_y: float = (ahead_hit.get("position", from) as Vector2).y
	var ahead_step_up: float = my_floor_y - ahead_floor_y
	if ahead_step_up < small_ledge_step_up_min_height or ahead_step_up > maxf(small_ledge_step_up_max_height, small_ledge_step_up_min_height):
		return false
	if _is_forbidden_drop_surface(ahead_hit.get("collider", null)):
		return false
	return true

func _can_step_up_local_ledge(dir: int) -> bool:
	if not enable_small_ledge_step_up:
		return false
	if not is_on_floor():
		return false
	if _jump_cd > 0.0:
		return false
	# If a clear upward ramp exists, prefer walking it over jumping.
	if _has_walkable_slope_in_direction(dir, maxf(small_ledge_step_up_probe_forward * 1.8, 140.0)):
		return false

	var my_floor_hit: Dictionary = _floor_hit_under(self)
	if my_floor_hit.is_empty():
		return false
	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y

	var space := get_world_2d().direct_space_state
	var probe_x: float = global_position.x + float(dir) * maxf(small_ledge_step_up_probe_forward, 24.0)
	var from := Vector2(probe_x, global_position.y - maxf(jump_up_probe_height_bonus * 0.65, 52.0))
	var to := Vector2(probe_x, global_position.y + ground_probe_origin_y + maxf(ground_probe_distance + 80.0, 120.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var ahead_hit: Dictionary = space.intersect_ray(params)
	if ahead_hit.is_empty():
		return false
	var ahead_floor_y: float = (ahead_hit.get("position", from) as Vector2).y
	var step_up: float = my_floor_y - ahead_floor_y
	if step_up < small_ledge_step_up_min_height or step_up > maxf(small_ledge_step_up_max_height, small_ledge_step_up_min_height):
		return false
	if _is_forbidden_drop_surface(ahead_hit.get("collider", null)):
		return false
	return true

func _can_step_up_local_ledge_retreat(dir: int) -> bool:
	# Retreat variant: intentionally more permissive than ASCEND logic so ranged
	# kiting can hop short lips while moving away, even when slope probes are noisy.
	if not enable_small_ledge_step_up:
		return false
	if not is_on_floor():
		return false
	if _jump_cd > 0.0:
		return false

	var my_floor_hit: Dictionary = _floor_hit_under(self)
	if my_floor_hit.is_empty():
		return false
	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y

	var space := get_world_2d().direct_space_state
	var probe_x: float = global_position.x + float(dir) * maxf(small_ledge_step_up_probe_forward, 24.0)
	var from := Vector2(probe_x, global_position.y - maxf(jump_up_probe_height_bonus * 0.55, 46.0))
	var to := Vector2(probe_x, global_position.y + ground_probe_origin_y + maxf(ground_probe_distance + 80.0, 120.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var ahead_hit: Dictionary = space.intersect_ray(params)
	if ahead_hit.is_empty():
		return false
	var ahead_floor_y: float = (ahead_hit.get("position", from) as Vector2).y
	var step_up: float = my_floor_y - ahead_floor_y
	if step_up < small_ledge_step_up_min_height:
		return false
	if step_up > maxf(small_ledge_step_up_max_height + 12.0, small_ledge_step_up_min_height):
		return false
	if _is_forbidden_drop_surface(ahead_hit.get("collider", null)):
		return false
	return true

func _is_safe_drop_toward_target(dir: int, target_y: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(float(dir) * ground_probe_forward, ground_probe_origin_y)
	var to := from + Vector2(0.0, maxf(safe_drop_max_distance, 80.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		return false
	var landing_collider: Variant = hit.get("collider", null)
	if _is_forbidden_drop_surface(landing_collider):
		return false
	var hit_pos: Vector2 = hit.get("position", from)
	var drop_distance: float = hit_pos.y - from.y
	if drop_distance < 6.0:
		return false
	if drop_distance > safe_drop_max_distance:
		return false
	if drop_distance > maxf(drop_through_max_safe_landing_delta, 24.0):
		return false
	var landing_body_y: float = hit_pos.y - ground_probe_origin_y
	var y_tolerance: float = safe_drop_target_y_tolerance
	if not hold_when_no_vertical_path:
		y_tolerance *= 2.5
	if absf(target_y - landing_body_y) > y_tolerance:
		return false
	return true

func _is_safe_escape_drop(dir: int) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(float(dir) * ground_probe_forward, ground_probe_origin_y)
	var to := from + Vector2(0.0, maxf(safe_drop_max_distance, 80.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		return false
	var landing_collider: Variant = hit.get("collider", null)
	if _is_forbidden_drop_surface(landing_collider):
		return false
	var hit_pos: Vector2 = hit.get("position", from)
	var drop_distance: float = hit_pos.y - from.y
	if drop_distance < 8.0:
		return false
	if drop_distance > safe_drop_max_distance:
		return false
	if drop_distance > maxf(drop_through_max_safe_landing_delta, 24.0):
		return false
	return true

func _is_forbidden_drop_ahead(dir: int) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(float(dir) * ground_probe_forward, ground_probe_origin_y)
	var to := from + Vector2(0.0, maxf(safe_drop_max_distance, 80.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = world_collision_mask
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		# No floor detected in probe range -> treat as non-forbidden for retreat escape.
		return false
	return _is_forbidden_drop_surface(hit.get("collider", null))

func _is_target_significantly_below(min_delta: float = 48.0) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var my_floor_hit: Dictionary = _floor_hit_under(self)
	var target_floor_hit: Dictionary = _floor_hit_under(_target)
	if my_floor_hit.is_empty() or target_floor_hit.is_empty():
		return (_target.global_position.y - global_position.y) >= min_delta
	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y
	var target_floor_y: float = (target_floor_hit["position"] as Vector2).y
	return (target_floor_y - my_floor_y) >= min_delta

func _has_confirmed_target_floor_above(min_delta: float) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var my_floor_hit: Dictionary = _floor_hit_under(self)
	var target_floor_hit: Dictionary = _floor_hit_under(_target)
	if my_floor_hit.is_empty() or target_floor_hit.is_empty():
		return false
	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y
	var target_floor_y: float = (target_floor_hit["position"] as Vector2).y
	return (my_floor_y - target_floor_y) >= min_delta

func _is_small_floor_step_to_target(max_height: float) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var my_floor_hit: Dictionary = _floor_hit_under(self)
	var target_floor_hit: Dictionary = _floor_hit_under(_target)
	if my_floor_hit.is_empty() or target_floor_hit.is_empty():
		return false
	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y
	var target_floor_y: float = (target_floor_hit["position"] as Vector2).y
	var floor_delta: float = absf(target_floor_y - my_floor_y)
	return floor_delta >= maxf(small_ledge_step_up_min_height, 6.0) and floor_delta <= maxf(max_height, small_ledge_step_up_min_height)

func _is_moving_away_from_target(desired_vx: float) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if absf(desired_vx) <= 0.01:
		return false
	var dx: float = _target.global_position.x - global_position.x
	var to_target_sign: float = signf(dx)
	if to_target_sign == 0.0:
		return false
	return signf(desired_vx) != to_target_sign

func _can_commit_descend_from_vertical_intent(dir: int, target_y: float) -> bool:
	var descend_confirm_threshold: float = maxf(vertical_intent_y_threshold + 16.0, 72.0)
	var route_confirmed_now: bool = false
	if _has_confirmed_target_floor_below(descend_confirm_threshold):
		route_confirmed_now = true

	# Allow descend when current surface supports a deliberate, safe drop route.
	# This keeps platform/ramp traversal intentional and avoids false descend flips.
	if dir == 0:
		dir = 1 if _facing_dir >= 0 else -1
	var vertical_diff: float = target_y - global_position.y
	if not route_confirmed_now and vertical_diff > maxf(drop_through_vertical_min_distance * 0.5, 40.0):
		if enable_drop_through_platforms and _drop_through_cd <= 0.0 and _is_dropthrough_platform_surface():
			if _can_drop_through_toward_target(target_y):
				route_confirmed_now = true
		elif _can_drop_from_current_surface() and _is_safe_escape_drop(dir):
			route_confirmed_now = true
	var dt: float = maxf(get_physics_process_delta_time(), 0.0)
	if route_confirmed_now:
		_descend_confirm_timer = minf(_descend_confirm_timer + dt, maxf(descend_confirm_hold_time, 0.02) + 0.25)
	else:
		_descend_confirm_timer = 0.0
	return _descend_confirm_timer >= maxf(descend_confirm_hold_time, 0.02)

func _can_jump_up_to_target(dir: int) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if _has_wall_in_direction(dir, 72.0):
		return false
	var gravity_abs: float = maxf(absf(gravity), 1.0)
	var jump_v: float = upward_jump_strength if upward_jump_strength < -1.0 else jump_strength
	var max_jump_height: float = (jump_v * jump_v) / (2.0 * gravity_abs)
	max_jump_height += maxf(jump_up_probe_height_bonus, 0.0)
	var top_y: float = global_position.y - max_jump_height
	var search_dist: float = maxf(jump_check_distance, 180.0)
	var step_dist: float = 60.0
	var space := get_world_2d().direct_space_state
	while step_dist <= search_dist:
		var sample_x: float = global_position.x + float(dir) * step_dist
		var from := Vector2(sample_x, top_y)
		var to := Vector2(sample_x, global_position.y + ground_probe_origin_y)
		var params := PhysicsRayQueryParameters2D.create(from, to)
		params.exclude = [self]
		params.collision_mask = world_collision_mask
		var hit: Dictionary = space.intersect_ray(params)
		if not hit.is_empty():
			var hit_pos: Vector2 = hit.get("position", from)
			var jump_height_needed: float = global_position.y - hit_pos.y
			if jump_height_needed > 30.0 and jump_height_needed <= max_jump_height:
				return true
		step_dist += 40.0
	return false

## Check if there's a platform above that we can jump to reach
## Returns true if a jumpable platform exists above us
func _try_jump_to_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _jump_cd > 0.0:
		return
	if not is_on_floor():
		return
	if _vertical_fail_timer > 0.0 and (_nav_state == NavState.ASCEND or _nav_state == NavState.DESCEND):
		return

	var target_y: float = _target.global_position.y
	var vertical_diff: float = target_y - global_position.y
	var dx_to_target: float = absf(_target.global_position.x - global_position.x)
	var preferred_dir: int = _preferred_jump_dir
	if _nav_state == NavState.ASCEND and _vertical_traverse_commit_timer > 0.0 and _vertical_traverse_commit_dir != 0:
		preferred_dir = _vertical_traverse_commit_dir
	if _nav_state == NavState.ASCEND and _ascend_commit_timer > 0.0 and _ascend_commit_dir != 0:
		preferred_dir = _ascend_commit_dir
	if preferred_dir == 0:
		preferred_dir = 1 if _target.global_position.x >= global_position.x else -1

	# Retreat default: if on a drop-through platform and safe, descend immediately.
	if _nav_state == NavState.RETREAT and (_can_force_dropthrough_retreat() or _can_force_dropthrough_retreat_same_level()):
		_start_drop_through()
		_retreat_descend_hold_timer = maxf(retreat_descend_hold_time, 0.2)
		_vertical_fail_timer = 0.0
		_vertical_fail_reason = ""
		_debug_nav("nav=%s action=%s reason=%s dy=%.1f dx=%.1f dir=%d floor=%s target_floor=%s" % [
			_nav_state_name(_nav_state),
			_vertical_action_name(VerticalAction.DROP_THROUGH),
			"force_retreat_dropthrough",
			vertical_diff,
			dx_to_target,
			preferred_dir,
			_debug_floor_name_under(self),
			_debug_floor_name_under(_target)
		])
		return

	# Priority: when explicitly descending from a drop-through platform, commit to
	# drop-through instead of walking to an edge first.
	# Do not force from HOLD/CHASE to avoid accidental spawn/load drops.
	if _nav_state == NavState.DESCEND and _can_force_dropthrough_descend():
			_start_drop_through()
			_vertical_fail_timer = 0.0
			_vertical_fail_reason = ""
			_debug_nav("nav=%s action=%s reason=%s dy=%.1f dx=%.1f dir=%d floor=%s target_floor=%s" % [
				_nav_state_name(_nav_state),
				_vertical_action_name(VerticalAction.DROP_THROUGH),
				"force_dropthrough",
				vertical_diff,
				dx_to_target,
				preferred_dir,
				_debug_floor_name_under(self),
				_debug_floor_name_under(_target)
			])
			return

	var decision: Dictionary = _choose_vertical_action(vertical_diff, dx_to_target, preferred_dir, target_y)
	var chosen_action: VerticalAction = int(decision.get("action", VerticalAction.NONE)) as VerticalAction
	var reason_code: String = String(decision.get("reason", "none"))
	_debug_nav("nav=%s action=%s reason=%s dy=%.1f dx=%.1f dir=%d floor=%s target_floor=%s" % [
		_nav_state_name(_nav_state),
		_vertical_action_name(chosen_action),
		reason_code,
		vertical_diff,
		dx_to_target,
		preferred_dir,
		_debug_floor_name_under(self),
		_debug_floor_name_under(_target)
	])

	match chosen_action:
		VerticalAction.JUMP_UP:
			velocity.y = upward_jump_strength if upward_jump_strength < -1.0 else jump_strength
			velocity.x = float(preferred_dir) * move_speed * jump_up_horizontal_boost
			_is_jumping = true
			_jump_cd = jump_cooldown
			_play_anim(anim_jump_start, false)
			_vertical_fail_timer = 0.0
			_vertical_fail_reason = ""
			return
		VerticalAction.DROP_THROUGH:
			_start_drop_through()
			if _nav_state == NavState.RETREAT:
				_retreat_descend_hold_timer = maxf(retreat_descend_hold_time, 0.2)
			_vertical_fail_timer = 0.0
			_vertical_fail_reason = ""
			return
		VerticalAction.EDGE_DROP:
			# If we're on a drop-through platform, prefer true drop-through over edge walk-off.
			if enable_drop_through_platforms and _is_dropthrough_platform_surface() and _drop_through_cd <= 0.0:
				_start_drop_through()
				_vertical_fail_timer = 0.0
				_vertical_fail_reason = ""
				return
			velocity.y = maxf(velocity.y, 220.0)
			_is_jumping = true
			_jump_cd = jump_cooldown
			if _nav_state == NavState.RETREAT:
				_retreat_descend_hold_timer = maxf(retreat_descend_hold_time, 0.2)
			_play_anim(anim_jump_start, false)
			_vertical_fail_timer = 0.0
			_vertical_fail_reason = ""
			return
		_:
			_vertical_fail_reason = reason_code
			_vertical_fail_timer = maxf(vertical_retry_fail_window, 0.05)
			return

func _choose_vertical_action(vertical_diff: float, dx_to_target: float, preferred_dir: int, target_y: float) -> Dictionary:
	var result: Dictionary = {
		"action": VerticalAction.NONE,
		"reason": "no_action"
	}
	if _nav_state == NavState.ASCEND and _vertical_traverse_commit_timer > 0.0 and _vertical_traverse_commit_dir != 0:
		preferred_dir = _vertical_traverse_commit_dir
	if _nav_state == NavState.ASCEND and _ascend_commit_timer > 0.0 and _ascend_commit_dir != 0:
		preferred_dir = _ascend_commit_dir
	if preferred_dir == 0:
		result["reason"] = "no_dir"
		return result
	if _nav_state == NavState.RETREAT and _target != null and is_instance_valid(_target):
		# Ensure retreat vertical decisions don't use stale chase-facing direction.
		preferred_dir = _stable_retreat_dir(_target.global_position.x - global_position.x, 0.22, 96.0)
		var retreat_target_below_for_step: bool = _is_target_significantly_below(24.0)
		var retreat_step_up_candidate: bool = (
			allow_retreat_step_up_jump
			and not retreat_target_below_for_step
			and (_can_step_up_local_ledge(preferred_dir) or _can_step_up_local_ledge_retreat(preferred_dir))
		)
		if not _is_target_significantly_below(24.0) and not retreat_step_up_candidate:
			result["reason"] = "retreat_flat"
			return result

	var score_jump_up: float = -9999.0
	var score_drop_through: float = -9999.0
	var score_edge_drop: float = -9999.0
	var reason_code: String = "no_action"
	if _nav_state == NavState.RETREAT and allow_retreat_step_up_jump:
		var retreat_target_below: bool = _is_target_significantly_below(24.0)
		if not retreat_target_below and (_can_step_up_local_ledge(preferred_dir) or _can_step_up_local_ledge_retreat(preferred_dir)):
			score_jump_up = maxf(score_jump_up, 175.0)
			reason_code = "retreat_step_up"
	var target_floor_has_support: bool = false
	var target_floor_above_confirmed: bool = false
	if _target != null and is_instance_valid(_target):
		target_floor_has_support = not _floor_hit_under(_target).is_empty()
		target_floor_above_confirmed = _has_confirmed_target_floor_above(maxf(small_ledge_step_up_min_height, 12.0))
	var allow_jump_up: bool = true
	if require_confirmed_higher_target_floor_for_jump_up:
		# Prevent "reactionary" upward jumps when target is airborne or floor probes are ambiguous.
		allow_jump_up = target_floor_has_support and target_floor_above_confirmed
	if jump_over_obstacles and allow_upward_jump_traversal and _nav_state == NavState.ASCEND:
		if allow_jump_up and _ascend_stuck_timer >= maxf(ascend_stuck_jump_delay, 0.05):
			score_jump_up = maxf(score_jump_up, 180.0)
			reason_code = "ascend_stuck_jump"
	var ramp_available_up: bool = _has_ramp_toward_target(preferred_dir, target_y, 240.0)
	if jump_over_obstacles and allow_upward_jump_traversal and _nav_state != NavState.RETREAT:
		if allow_jump_up and _can_step_up_local_ledge(preferred_dir):
			score_jump_up = maxf(score_jump_up, 170.0)
			reason_code = "local_step_up"
	var suppress_jump_for_ramp: bool = (
		suppress_jump_when_ramp_available
		and ramp_available_up
		and vertical_diff < 0.0
		and absf(vertical_diff) <= ramp_jump_suppress_max_height
		and dx_to_target <= ramp_jump_suppress_max_dx
	)

	if _nav_state != NavState.RETREAT and allow_upward_jump_traversal and vertical_diff < -72.0:
		if _retreat_descend_hold_timer > 0.0:
			reason_code = "descend_hold"
		elif suppress_jump_for_ramp:
			reason_code = "ramp_walk"
		elif dx_to_target > maxf(ramp_jump_commit_max_dx, jump_check_distance * 1.5):
			# Too far to commit jump yet; keep walking toward the real ramp/ledge.
			reason_code = "jump_approach"
		elif allow_jump_up and _can_jump_up_to_target(preferred_dir):
			score_jump_up = 120.0 - absf(vertical_diff) * 0.03
		else:
			reason_code = "jump_floor" if not allow_jump_up else "jump_range"

	var obstacle_wall: bool = _has_wall_in_direction(preferred_dir, 54.0)
	if jump_over_obstacles and allow_upward_jump_traversal and _nav_state != NavState.RETREAT:
		if allow_jump_up and _can_step_up_small_ledge(preferred_dir, dx_to_target, vertical_diff):
			score_jump_up = maxf(score_jump_up, 165.0)
			reason_code = "small_step_up"
	if allow_jump_up and jump_over_obstacles and (not suppress_jump_for_ramp) and absf(vertical_diff) <= 24.0 and dx_to_target > 120.0 and obstacle_wall and _can_jump_up_over_obstacle(preferred_dir):
		score_jump_up = maxf(score_jump_up, 90.0)
	if allow_jump_up and jump_over_obstacles and vertical_diff < -20.0 and vertical_diff > -120.0 and dx_to_target <= 220.0:
		if _has_wall_in_direction(preferred_dir, 42.0) and _can_jump_up_over_obstacle(preferred_dir):
			score_jump_up = maxf(score_jump_up, 140.0)
			reason_code = "step_up"

	var can_drop_cd: bool = _drop_through_cd <= 0.0
	var drop_min_dy: float = maxf(drop_through_vertical_min_distance, 56.0)
	var target_below_for_drop: bool = _is_target_significantly_below(40.0)
	# Priority rule: on one-way/drop-through platforms, descend through them when
	# target is below and landing is safe, even if edge probes still report ground.
	if enable_drop_through_platforms and can_drop_cd and _is_dropthrough_platform_surface() and _is_target_significantly_below(24.0):
		if _can_drop_through_toward_target(target_y):
			score_drop_through = maxf(score_drop_through, 160.0)
			reason_code = "platform_descend_priority"
	if enable_drop_through_platforms and can_drop_cd and vertical_diff > drop_min_dy and target_below_for_drop and dx_to_target <= drop_through_horizontal_max_distance:
		if not _is_dropthrough_platform_surface():
			reason_code = "drop_surface"
		elif not _can_drop_through_toward_target(target_y):
			reason_code = "drop_target"
		else:
			score_drop_through = 125.0
	elif enable_drop_through_platforms and not can_drop_cd:
		reason_code = "drop_cd"

	if vertical_diff > 50.0:
		if _has_ground_ahead(preferred_dir):
			if reason_code == "no_action":
				reason_code = "edge_ground"
		elif not _can_drop_from_current_surface():
			reason_code = "edge_surface"
		elif not _is_safe_drop_toward_target(preferred_dir, target_y):
			reason_code = "edge_target"
		else:
			score_edge_drop = 100.0

	# Retreat edge-escape: if retreat path is blocked at an edge, prefer descending safely
	# instead of pacing/oscillating on that edge.
	if _nav_state == NavState.RETREAT:
		var retreat_target_below: bool = _is_target_significantly_below(24.0)
		var can_force_platform_descend: bool = (
			enable_drop_through_platforms
			and can_drop_cd
			and _is_dropthrough_platform_surface()
			and retreat_target_below
		)
		# If retreating on a drop-through platform and descent is valid, prioritize this path
		# even when edge probes report ground ahead.
		if can_force_platform_descend:
			score_drop_through = maxf(score_drop_through, 150.0)
			reason_code = "retreat_dropthrough"
		elif not _has_ground_ahead(preferred_dir) and retreat_target_below and _is_safe_escape_drop(preferred_dir):
			score_edge_drop = maxf(score_edge_drop, 130.0)
			reason_code = "retreat_edgedrop"

	if score_jump_up >= score_drop_through and score_jump_up >= score_edge_drop and score_jump_up > 0.0:
		result["action"] = VerticalAction.JUMP_UP
		result["reason"] = "jump_up"
		return result
	if score_drop_through >= score_edge_drop and score_drop_through > 0.0:
		result["action"] = VerticalAction.DROP_THROUGH
		result["reason"] = "drop_through"
		return result
	if score_edge_drop > 0.0:
		result["action"] = VerticalAction.EDGE_DROP
		result["reason"] = "edge_drop"
		return result

	result["reason"] = reason_code
	return result

func _on_died() -> void:
	_start_death()

func _is_same_floor_for_aggro(player: Node2D) -> bool:
	if player == null:
		return false
	var my_hit: Dictionary = _floor_hit_under(self)
	var pl_hit: Dictionary = _floor_hit_under(player)
	if my_hit.is_empty() or pl_hit.is_empty():
		return false
	var my_y: float = (my_hit["position"] as Vector2).y
	var pl_y: float = (pl_hit["position"] as Vector2).y
	return absf(my_y - pl_y) <= same_floor_aggro_y_tolerance

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
		VfxRenderUtil.promote(vfx, 230)
		vfx.global_position = spawn_position
		
		# Set VFX facing direction
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", direction)

func _on_attack_damage_confirmed(_target_node: Node, hit_position: Vector2, facing: int) -> void:
	"""Spawn slash VFX only when a melee hit actually deals HP damage."""
	if not enable_attack_vfx:
		return
	if ATTACK_VFX_SCENE == null:
		return
	var dir: int = -1 if facing < 0 else 1
	var spawn_position: Vector2 = hit_position + Vector2(attack_vfx_hit_offset_px * float(dir), 0.0)
	_spawn_attack_vfx(spawn_position, dir)

func _setup_melee_telegraph() -> void:
	if _melee_telegraph != null and is_instance_valid(_melee_telegraph):
		return
	_melee_telegraph = Polygon2D.new()
	_melee_telegraph.name = "MeleeTelegraph"
	_melee_telegraph.visible = false
	_melee_telegraph.z_as_relative = false
	_melee_telegraph.z_index = 235
	_melee_telegraph.color = telegraph_fill_color
	var half_w: float = maxf(telegraph_width_px * 0.5, 8.0)
	var half_h: float = maxf(telegraph_height_px * 0.5, 8.0)
	_melee_telegraph.polygon = PackedVector2Array([
		Vector2(-half_w, -half_h),
		Vector2(half_w, -half_h),
		Vector2(half_w, half_h),
		Vector2(-half_w, half_h)
	])
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		scene_root.add_child(_melee_telegraph)

func _show_melee_telegraph(dir: int, hit_delay: float) -> void:
	if not enable_melee_telegraph:
		return
	if _melee_telegraph == null or not is_instance_valid(_melee_telegraph):
		_setup_melee_telegraph()
		if _melee_telegraph == null or not is_instance_valid(_melee_telegraph):
			return
	var side: int = -1 if dir < 0 else 1
	_melee_telegraph.global_position = global_position + Vector2(telegraph_forward_bias_px * float(side), telegraph_y_offset_px)
	_melee_telegraph.visible = true
	_melee_telegraph.modulate.a = 0.0
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	var fade_in: float = minf(maxf(telegraph_fade_in_time, 0.01), maxf(hit_delay - 0.01, 0.01))
	_telegraph_tween = create_tween()
	_telegraph_tween.tween_property(_melee_telegraph, "modulate:a", telegraph_fill_color.a, fade_in)

func _hide_melee_telegraph() -> void:
	if _melee_telegraph == null or not is_instance_valid(_melee_telegraph):
		return
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	_telegraph_tween = create_tween()
	_telegraph_tween.tween_property(_melee_telegraph, "modulate:a", 0.0, maxf(telegraph_fade_out_time, 0.01))
	_telegraph_tween.tween_callback(func() -> void:
		if _melee_telegraph != null and is_instance_valid(_melee_telegraph):
			_melee_telegraph.visible = false
	)

func _play_melee_windup_flash(hit_delay: float) -> void:
	if not enable_melee_windup_flash:
		return
	if view_3d == null:
		return
	_stop_melee_windup_flash()
	var flash_time: float = minf(maxf(melee_windup_flash_time, 0.01), maxf(hit_delay * 0.6, 0.01))
	_flash_tween = create_tween()
	_flash_tween.tween_property(view_3d, "modulate", melee_windup_flash_color, flash_time * 0.5)
	_flash_tween.tween_property(view_3d, "modulate", _view_default_modulate, flash_time * 0.5)

func _stop_melee_windup_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if view_3d != null and is_instance_valid(view_3d):
		view_3d.modulate = _view_default_modulate
