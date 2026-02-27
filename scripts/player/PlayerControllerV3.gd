extends CharacterBody2D
class_name PlayerControllerV3

## Silksong-style integrated controller
## ALL movement, combat, and character abilities in one place

# -----------------------------
# Signals
# -----------------------------
signal state_changed(from_state: STATE, to_state: STATE)
signal roll_started(character_name: String, facing_direction: int)  # Emitted when player rolls/dodges
signal landed(was_double_jump: bool, facing_direction: int)  # Emitted when player lands on the ground
signal defensive_activated(character_name: String, facing_direction: int)  # Emitted when defensive ability is used
signal heavy_attack_started(character_name: String, facing_direction: int)  # Emitted when heavy attack begins
signal light_attack_started(character_name: String, combo_step: int, facing_direction: int)  # Emitted when light attack begins
signal ultimate_attack_hit(character_name: String, enemy_position: Vector2, facing_direction: int)  # Emitted when ultimate hits an enemy
signal knight_ultimate_started(facing_direction: int)  # Emitted when Knight starts ultimate wave attack
signal knight_ultimate_hit(enemy: Node, enemy_position: Vector2)  # Emitted when Knight ultimate hits an enemy
signal dash_started(facing_direction: int, is_airborne: bool)  # Emitted when dash starts (-1=left, 1=right, airborne=in air)
signal jump_started(is_double_jump: bool, facing_direction: int)  # Emitted when player jumps

# -----------------------------
# State Machine
# -----------------------------
enum STATE {
	IDLE,
	WALK,
	SPRINT,
	JUMP,
	DOUBLE_JUMP,
	FALL,
	DASH,
	TURNING,
	ROLL,
	LIGHT_ATTACK,  # Combo system integrated here
	HEAVY_ATTACK,
	ULTIMATE,
	DEFEND,  # Character-specific defensive ability
	HIT,
	DEATH
}

var active_state: STATE = STATE.FALL
var previous_state: STATE = STATE.FALL

# -----------------------------
# Movement Constants
# -----------------------------
const WALK_VELOCITY: float = 320.0  # Increased from 200.0 (closer to sprint)
const SPRINT_VELOCITY: float = 500.0  # Increased from 400.0
const SPRINT_ACCELERATION: float = 2200.0  # Increased for faster sprint buildup

const JUMP_VELOCITY: float = -1037.5  # Increased by 100 (was -937.5)
const JUMP_DECELERATION: float = 1500.0
const DOUBLE_JUMP_VELOCITY: float = -687.5  # Increased by 25% again (was -550.0)

# Air movement (same for all characters - matches Rogue's current air speed)
const AIR_VELOCITY: float = 384.0  # 320.0 * 1.2 (Rogue's air speed)

const FALL_GRAVITY: float = 1500.0
const FALL_VELOCITY: float = 500.0

const DASH_LENGTH: float = 100.0
const DASH_VELOCITY: float = 600.0

@export_group("Ground Adhesion")
@export var enable_slope_ground_adhesion: bool = true
@export var slope_floor_snap_length: float = 22.0
@export var slope_floor_max_angle_deg: float = 50.0
@export var slope_snap_requires_downward_motion: bool = true

# -----------------------------
# Character Data
# -----------------------------
@export var character_data: CharacterData = null

# -----------------------------
# Node References
# -----------------------------
@export var body_3d_view_path: NodePath = ^"Visual/Body3DView"
@export var combat_path: NodePath = ^"Combat"
@export var health_path: NodePath = ^"Health"

var _body_3d_view = null
var _combat = null
var _health = null

# -----------------------------
# Input Lock (Victory UI, Cutscenes, etc.)
# -----------------------------
var _input_locked: bool = false  # When true, disable all player input and freeze animations
var _cutscene_motion_locked: bool = false  # When true, disable control but still allow natural falling

# -----------------------------
# Movement State
# -----------------------------
var _facing_direction: int = 1
var _can_double_jump: bool = false
var _can_dash: bool = false
var _saved_position: Vector2 = Vector2.ZERO
var _is_sprinting: bool = false
var _dash_jump_buffer: bool = false
var _used_double_jump: bool = false  # Track if double jump was used for landing animation
var _drop_last_tap_time: float = -999.0
var _drop_through_timer: float = 0.0
var _drop_through_fall_lock_timer: float = 0.0
var _drop_restore_collision_mask: int = 0
var _floor_on_dropthrough_platform: bool = false
var _last_floor_collider_name: StringName = &""

# Timers
var _coyote_timer: Timer = null
var _dash_cooldown: Timer = null

# -----------------------------
# Combat State (Integrated)
# -----------------------------
var _combo_step: int = 0  # 0 = none, 1, 2, 3
var _combo_window_timer: float = 0.0
var _combo_attack_timer: float = 0.0
var _combo_attack_duration: float = 0.0  # Full animation duration for current attack
var _combo_can_continue: bool = false  # Flag when animation is far enough to accept next input

@export_group("Light Combo Feel")
@export_range(0.30, 0.95, 0.01) var rogue_combo_chain_unlock_threshold: float = 0.70
@export_range(0.30, 0.95, 0.01) var knight_combo_chain_unlock_threshold: float = 0.55

# Attack movement
var _attack_move_active: bool = false
var _attack_move_timer: float = 0.0
var _attack_move_duration: float = 0.0
var _attack_move_speed: float = 0.0

# -----------------------------
# Roll/Dodge System
# -----------------------------
@export_group("Roll & Dodge")
@export var roll_max_charges: int = 2
@export var roll_recharge_time: float = 10.0
@export var roll_duration: float = 0.55
@export var roll_chain_lockout: float = 0.15
@export var roll_iframes: bool = true
@export var roll_iframe_buffer: float = 0.05
@export var perfect_dodge_window: float = 0.14
@export var perfect_dodge_lockout: float = 0.35

var _roll_charges: int = 2
var _roll_recharge_timers: Array[float] = []
var _roll_active: bool = false
var _roll_timer: float = 0.0
var _roll_chain_timer: float = 0.0
var _perfect_dodge_timer: float = 0.0
var _roll_direction: int = 1
var _roll_speed: float = 0.0

# -----------------------------
# Input Actions
# -----------------------------
@export_group("Input Actions")
@export var input_move_left: StringName = &"move_left"
@export var input_move_right: StringName = &"move_right"
@export var input_move_down: StringName = &"move_down"
@export var input_jump: StringName = &"jump"
@export var input_dash: StringName = &"dash"
@export var input_roll: StringName = &"Dodge"
@export var input_light_attack: StringName = &"attack_light"
@export var input_heavy_attack: StringName = &"attack_heavy"
@export var input_ultimate: StringName = &"ultimate"
@export var input_defend: StringName = &"defend"

@export_group("Drop Through Platforms")
@export var drop_through_double_tap_window: float = 0.22
@export var drop_through_duration: float = 0.12
@export var drop_through_downward_boost: float = 360.0
@export var drop_through_downward_boost_air: float = 460.0
@export var drop_through_world_collision_layer_bit: int = 1
@export var auto_drop_when_airborne_holding_down: bool = true
@export var drop_through_airborne_probe_feet_offset: float = 36.0
@export var drop_through_airborne_probe_distance: float = 96.0
@export var drop_through_roll_cue_lock_time: float = 0.14
@export var drop_through_allowed_floor_names: PackedStringArray = PackedStringArray(["Platforms"])

# Testing/Debug inputs
@export_group("Debug/Testing Inputs")
@export var enable_god_mode_input: bool = false  # Disabled for demo release
@export var enable_bigd_input: bool = false  # Disabled for demo release
@export var input_god_mode: StringName = &"god_mode_toggle"
@export var input_bigd: StringName = &"BIGD"

# -----------------------------
# Setup
# -----------------------------
func _ready() -> void:
	_setup_nodes()
	_setup_timers()
	_load_character_data()
	_initialize_roll_charges()
	_drop_restore_collision_mask = collision_mask
	floor_max_angle = deg_to_rad(slope_floor_max_angle_deg)
	switch_state(STATE.FALL)


func _setup_nodes() -> void:
	_body_3d_view = get_node_or_null(body_3d_view_path)
	_combat = get_node_or_null(combat_path)
	_health = get_node_or_null(health_path)
	
	# Initialize interaction prompt
	var interaction_prompt := get_node_or_null("InteractionPrompt")
	if interaction_prompt != null and interaction_prompt.has_method("set_player"):
		interaction_prompt.set_player(self)
	
	# Connect to health signals for hit/death animations
	if _health != null:
		if _health.has_signal("died") and not _health.died.is_connected(_on_health_died):
			_health.died.connect(_on_health_died)
		if _health.has_signal("damage_applied") and not _health.damage_applied.is_connected(_on_health_damage_applied):
			_health.damage_applied.connect(_on_health_damage_applied)
	
	if _body_3d_view == null:
		push_error("[PlayerV3] Body3DView not found at: %s" % body_3d_view_path)


func _setup_timers() -> void:
	# Coyote timer (use physics process for better sync)
	_coyote_timer = Timer.new()
	_coyote_timer.name = "CoyoteTimer"
	_coyote_timer.wait_time = 0.15  # Increased from 0.10 for more generous timing
	_coyote_timer.one_shot = true
	_coyote_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS  # IMPORTANT: sync with physics
	add_child(_coyote_timer)
	
	# Dash cooldown
	_dash_cooldown = Timer.new()
	_dash_cooldown.name = "DashCooldown"
	_dash_cooldown.wait_time = 0.1
	_dash_cooldown.one_shot = true
	_dash_cooldown.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(_dash_cooldown)


func _load_character_data() -> void:
	"""Auto-load character data from CharacterDatabase"""
	if character_data != null:
		pass
		return
	
	if not has_node("/root/CharacterDatabase"):
		push_warning("[PlayerV3] CharacterDatabase not found - defaulting to Rogue")
		_load_default_character()
		return
	
	var char_db = get_node("/root/CharacterDatabase")
	var selected_char: String = char_db.get("selected_character")
	
	if selected_char == "":
		push_warning("[PlayerV3] No character selected - defaulting to Rogue")
		_load_default_character()
		return
	
	var char_data: CharacterData = char_db.call("get_character_data", selected_char)
	if char_data == null or not char_data.is_valid():
		push_warning("[PlayerV3] Invalid character data - defaulting to Rogue")
		_load_default_character()
		return
	
	character_data = char_data
	pass


func _load_default_character() -> void:
	const ROGUE_DATA := preload("res://resources/characters/rogue_data.tres")
	character_data = ROGUE_DATA
	pass


func _initialize_roll_charges() -> void:
	_roll_charges = roll_max_charges
	_roll_recharge_timers.clear()
	for i in range(roll_max_charges):
		_roll_recharge_timers.append(0.0)


# -----------------------------
# Physics Process
# -----------------------------
func _physics_process(delta: float) -> void:
	_update_drop_through_timer(delta)

	# CRITICAL: If input is locked (victory UI, cutscenes, etc.), freeze player completely
	if _input_locked:
		velocity = Vector2.ZERO  # Stop all movement
		move_and_slide()
		return  # Skip all input processing and state updates

	# Cutscene motion lock: no control/actions, but allow falling to ground naturally.
	if _cutscene_motion_locked:
		velocity.x = 0.0
		if not is_on_floor():
			if active_state != STATE.FALL:
				switch_state(STATE.FALL)
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
		else:
			if velocity.y > 0.0:
				velocity.y = 0.0
			if active_state != STATE.IDLE:
				switch_state(STATE.IDLE)
		move_and_slide()
		return

	_update_roll_charges(delta)
	_update_timers(delta)
	_update_combo_timers(delta)
	_update_slope_ground_adhesion()
	_check_grounded_dropthrough_request()
	_check_airborne_pre_dropthrough()
	
	# Check for debug/test inputs
	_handle_debug_inputs()
	
	process_state(delta)
	
	# Don't apply physics during ultimate
	var was_on_floor_before_move: bool = is_on_floor()
	if active_state != STATE.ULTIMATE:
		move_and_slide()
	_update_floor_surface_cache()
	_check_airborne_auto_dropthrough(was_on_floor_before_move)

func _update_slope_ground_adhesion() -> void:
	if not enable_slope_ground_adhesion:
		return

	floor_max_angle = deg_to_rad(slope_floor_max_angle_deg)

	var jump_pressed: bool = Input.is_action_just_pressed(input_jump)
	var disable_snap: bool = (
		_drop_through_timer > 0.0
		or jump_pressed
		or active_state == STATE.JUMP
		or active_state == STATE.DOUBLE_JUMP
	)
	floor_snap_length = 0.0 if disable_snap else maxf(slope_floor_snap_length, 0.0)
	if disable_snap:
		return

	if slope_snap_requires_downward_motion and velocity.y < 0.0:
		return

	# Keeps body glued to valid slopes when descending, while still allowing true ledge drop-offs.
	if not is_on_floor():
		apply_floor_snap()

func _update_drop_through_timer(delta: float) -> void:
	if _drop_through_fall_lock_timer > 0.0:
		_drop_through_fall_lock_timer = maxf(_drop_through_fall_lock_timer - delta, 0.0)
	if _drop_through_timer <= 0.0:
		return
	_drop_through_timer = maxf(_drop_through_timer - delta, 0.0)
	if _drop_through_timer <= 0.0:
		collision_mask = _drop_restore_collision_mask

func _check_grounded_dropthrough_request() -> void:
	if _drop_through_timer > 0.0:
		return
	if not is_on_floor():
		return
	if not _floor_on_dropthrough_platform:
		return
	if not Input.is_action_just_pressed(input_move_down):
		return
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	if now_sec - _drop_last_tap_time <= drop_through_double_tap_window:
		_start_drop_through(true)
		_drop_last_tap_time = -999.0
	else:
		_drop_last_tap_time = now_sec

func _check_airborne_pre_dropthrough() -> void:
	if _drop_through_timer > 0.0:
		return
	if not auto_drop_when_airborne_holding_down:
		return
	if is_on_floor():
		return
	if not Input.is_action_pressed(input_move_down):
		return
	if not _is_dropthrough_platform_below():
		return
	# Pre-emptively disable one-way platform collision before landing frame.
	_start_drop_through(false, true)

func _check_airborne_auto_dropthrough(was_on_floor_before_move: bool) -> void:
	if _drop_through_timer > 0.0:
		return
	if not auto_drop_when_airborne_holding_down:
		return
	# If falling while holding down and we touch a one-way platform this frame, drop through immediately.
	if was_on_floor_before_move:
		return
	if not is_on_floor():
		return
	if not Input.is_action_pressed(input_move_down):
		return
	if not _floor_on_dropthrough_platform:
		return
	_start_drop_through(false, true)

func _start_drop_through(play_roll_anim: bool = false, airborne_mode: bool = false) -> void:
	if _drop_through_timer > 0.0:
		return
	var bit: int = clampi(drop_through_world_collision_layer_bit, 1, 32)
	_drop_restore_collision_mask = collision_mask
	collision_mask = collision_mask & ~(1 << (bit - 1))
	_drop_through_timer = maxf(drop_through_duration, 0.01)
	velocity.y = maxf(velocity.y, drop_through_downward_boost_air if airborne_mode else drop_through_downward_boost)
	if active_state != STATE.FALL:
		switch_state(STATE.FALL)
	if play_roll_anim and not airborne_mode:
		_drop_through_fall_lock_timer = maxf(drop_through_roll_cue_lock_time, 0.01)
		# Play roll cue after state change so FALL animation setup doesn't immediately override it.
		_play_animation("dodge", 2.0)

func _is_dropthrough_platform_below() -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(0.0, drop_through_airborne_probe_feet_offset)
	var to: Vector2 = from + Vector2(0.0, maxf(drop_through_airborne_probe_distance, 8.0))
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider_obj: Variant = hit.get("collider", null)
	if collider_obj is Node:
		return _is_dropthrough_platform_node(collider_obj as Node)
	return false

func _update_floor_surface_cache() -> void:
	_floor_on_dropthrough_platform = false
	_last_floor_collider_name = &""
	if not is_on_floor():
		return
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision2D = get_slide_collision(i)
		if col == null:
			continue
		if col.get_normal().dot(Vector2.UP) < 0.5:
			continue
		var collider_obj: Object = col.get_collider()
		if collider_obj is Node:
			var n: Node = collider_obj as Node
			_last_floor_collider_name = StringName(n.name)
			if _is_dropthrough_platform_node(n):
				_floor_on_dropthrough_platform = true
				return

func _is_dropthrough_floor_name_allowed(surface_name: String) -> bool:
	for allowed: String in drop_through_allowed_floor_names:
		if allowed == surface_name:
			return true
	var lower: String = surface_name.to_lower()
	return lower.contains("platform") or lower.contains("cloud") or lower.contains("ledge")

func _is_dropthrough_platform_node(node: Node) -> bool:
	if node == null:
		return false

	# Check collider ancestry so nested shapes/bodies under platform groups still qualify.
	var cursor: Node = node
	while cursor != null:
		if _is_dropthrough_floor_name_allowed(String(cursor.name)):
			return true
		cursor = cursor.get_parent()
	return false


func _update_timers(delta: float) -> void:
	if _roll_chain_timer > 0.0:
		_roll_chain_timer -= delta
	if _perfect_dodge_timer > 0.0:
		_perfect_dodge_timer -= delta


func _update_roll_charges(delta: float) -> void:
	for i in range(_roll_recharge_timers.size()):
		if _roll_recharge_timers[i] > 0.0:
			_roll_recharge_timers[i] -= delta
			if _roll_recharge_timers[i] <= 0.0:
				_roll_charges = mini(_roll_charges + 1, roll_max_charges)


func _update_combo_timers(delta: float) -> void:
	if _combo_window_timer > 0.0:
		_combo_window_timer -= delta
	if _combo_attack_timer > 0.0:
		_combo_attack_timer -= delta


func _handle_debug_inputs() -> void:
	"""Handle testing/debug input actions"""
	# God mode toggle (only if enabled in inspector)
	if enable_god_mode_input and Input.is_action_just_pressed(input_god_mode):
		_toggle_god_mode()
	
	# BIGD super damage attack (only if enabled in inspector)
	if enable_bigd_input and Input.is_action_just_pressed(input_bigd):
		_trigger_bigd_attack()


func _toggle_god_mode() -> void:
	"""Toggle invincibility for testing"""
	if _health == null:
		push_warning("[PlayerV3] Health node not found; cannot toggle god mode.")
		return
	
	_health.god_mode = not _health.god_mode
	pass


func _trigger_bigd_attack() -> void:
	"""Trigger super damage attack for testing"""
	if _combat == null:
		push_warning("[PlayerV3] Combat node not found; cannot use BIGD attack.")
		return
	
	if _combat.has_method("_start_attack"):
		_combat.call("_start_attack", &"BIGD")
		pass


# -----------------------------
# State Machine Core
# -----------------------------
func switch_state(to_state: STATE) -> void:
	var prev = active_state
	previous_state = active_state
	active_state = to_state
	
	state_changed.emit(prev, to_state)
	_on_state_enter(to_state)


func _on_state_enter(state: STATE) -> void:
	match state:
		STATE.IDLE:
			_reset_animation_state()  # Reset animation speed before playing idle
			_play_animation_loop("idle")
			_can_double_jump = true
			_can_dash = true
		
		STATE.WALK:
			_reset_animation_state()  # Reset animation speed before playing walk
			_play_animation_loop("run")  # Maps to QAnim/Jog_Fwd
			_can_double_jump = true
			_can_dash = true
		
		STATE.SPRINT:
			_play_animation_loop("sprint")  # Maps to QAnim/Sprint
			_is_sprinting = true
			_can_double_jump = true
			_can_dash = true
		
		STATE.JUMP:
			if previous_state != STATE.TURNING:
				_play_animation("jump_start")
			velocity.y = JUMP_VELOCITY  # NO speed multiplier - all characters jump same height
			_coyote_timer.stop()
			_used_double_jump = false  # Reset on initial jump
			var _char_name: String = "Unknown"
			if character_data != null:
				_char_name = character_data.character_name
			pass
			
			# Emit signal for VFX
			jump_started.emit(false, _facing_direction)
		
		STATE.DOUBLE_JUMP:
			_play_animation("double_jump_start")  # Play ninja jump start animation
			velocity.y = DOUBLE_JUMP_VELOCITY  # NO speed multiplier - all characters jump same height
			_can_double_jump = false
			_is_sprinting = false
			_used_double_jump = true  # Mark that double jump was used
			var _char_name: String = "Unknown"
			if character_data != null:
				_char_name = character_data.character_name
			pass
			
			# Emit signal for VFX
			jump_started.emit(true, _facing_direction)
		
		STATE.FALL:
			# Check if this is a coyote buffer fall (walked off edge) or real fall (jumped)
			var is_coyote_fall: bool = (previous_state == STATE.IDLE or 
			                             previous_state == STATE.WALK or 
			                             previous_state == STATE.SPRINT or 
			                             previous_state == STATE.TURNING)
			
			if is_coyote_fall:
				# Coyote buffer fall - DON'T change animation (prevents slope stutter)
				pass
				_coyote_timer.start()
				_can_double_jump = true
				_can_dash = true
				_used_double_jump = false
			else:
				# Real fall from jump - play appropriate animation
				if previous_state == STATE.JUMP:
					_play_animation_loop("jump")  # Regular jump idle
				elif previous_state == STATE.DOUBLE_JUMP:
					_play_animation_loop("double_jump_idle")  # Ninja jump idle
				elif previous_state != STATE.DOUBLE_JUMP and not _used_double_jump:
					_play_animation_loop("fall")  # Fallback
		
		STATE.DASH:
			if _dash_cooldown.time_left > 0:
				active_state = previous_state
				return
			
			_play_animation_loop("sprint")  # Use sprint animation for dash
			velocity.y = 0
			_set_facing_direction(signf(Input.get_axis(input_move_left, input_move_right)))
			velocity.x = _facing_direction * DASH_VELOCITY * _get_speed_multiplier()
			_saved_position = position
			_can_dash = previous_state == STATE.IDLE or previous_state == STATE.WALK or previous_state == STATE.SPRINT
			_dash_jump_buffer = false
			_dash_cooldown.start()
			
			# Emit signal for VFX
			var airborne: bool = not is_on_floor()
			pass
			dash_started.emit(_facing_direction, airborne)
		
		STATE.TURNING:
			_set_facing_direction(-_facing_direction)
			_is_sprinting = true
		
		STATE.ROLL:
			_start_roll()
		
		STATE.LIGHT_ATTACK:
			_start_light_attack()
		
		STATE.HEAVY_ATTACK:
			_start_heavy_attack()
		
		STATE.ULTIMATE:
			_start_ultimate()
		
		STATE.DEFEND:
			_start_defend()
		
		STATE.HIT:
			# No longer used - kept for compatibility
			pass
		
		STATE.DEATH:
			_play_animation("death")
			velocity.x = 0
			velocity.y = 0
			set_physics_process(false)


func process_state(delta: float) -> void:
	match active_state:
		STATE.IDLE:
			_handle_ground_movement()
			
			# Use coyote timer as floor buffer to prevent slope stuttering
			if not is_on_floor() and _coyote_timer.time_left <= 0.0:
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed(input_defend) and _can_use_defend():
				switch_state(STATE.DEFEND)
			elif Input.is_action_just_pressed(input_jump):
				switch_state(STATE.JUMP)
			elif Input.is_action_just_pressed(input_dash):
				switch_state(STATE.DASH)
			elif Input.is_action_pressed(input_dash) and _dash_cooldown.time_left > 0:
				switch_state(STATE.SPRINT)
			elif Input.get_axis(input_move_left, input_move_right) != 0:
				switch_state(STATE.WALK)
			elif Input.is_action_just_pressed(input_roll) and _can_roll():
				switch_state(STATE.ROLL)
			elif Input.is_action_just_pressed(input_light_attack):
				switch_state(STATE.LIGHT_ATTACK)
			elif Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
				switch_state(STATE.HEAVY_ATTACK)
			elif Input.is_action_just_pressed(input_ultimate) and _can_use_ultimate():
				switch_state(STATE.ULTIMATE)
		
		STATE.WALK:
			_handle_ground_movement()
			
			# Use coyote timer as floor buffer to prevent slope stuttering
			if not is_on_floor() and _coyote_timer.time_left <= 0.0:
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed(input_defend) and _can_use_defend():
				switch_state(STATE.DEFEND)
			elif Input.is_action_just_pressed(input_jump):
				switch_state(STATE.JUMP)
			elif Input.is_action_just_pressed(input_dash):
				switch_state(STATE.DASH)
			elif Input.is_action_pressed(input_dash) and _dash_cooldown.time_left > 0:
				switch_state(STATE.SPRINT)
			elif Input.get_axis(input_move_left, input_move_right) == 0:
				switch_state(STATE.IDLE)
			elif Input.is_action_just_pressed(input_roll) and _can_roll():
				switch_state(STATE.ROLL)
			elif Input.is_action_just_pressed(input_light_attack):
				switch_state(STATE.LIGHT_ATTACK)
			elif Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
				switch_state(STATE.HEAVY_ATTACK)
			elif Input.is_action_just_pressed(input_ultimate) and _can_use_ultimate():
				switch_state(STATE.ULTIMATE)
		
		STATE.SPRINT:
			_handle_sprint(delta)
			
			# Use coyote timer as floor buffer to prevent slope stuttering
			if not is_on_floor() and _coyote_timer.time_left <= 0.0:
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed(input_defend) and _can_use_defend():
				switch_state(STATE.DEFEND)
			elif not Input.is_action_pressed(input_dash):
				switch_state(STATE.WALK if Input.get_axis(input_move_left, input_move_right) != 0 else STATE.IDLE)
			elif Input.is_action_just_pressed(input_jump):
				switch_state(STATE.JUMP)
			elif _is_input_against_facing():
				switch_state(STATE.TURNING)
			elif Input.is_action_just_pressed(input_roll) and _can_roll():
				switch_state(STATE.ROLL)
			elif Input.is_action_just_pressed(input_light_attack):
				switch_state(STATE.LIGHT_ATTACK)
			elif Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
				switch_state(STATE.HEAVY_ATTACK)
		
		STATE.JUMP, STATE.DOUBLE_JUMP:
			velocity.y = move_toward(velocity.y, 0, JUMP_DECELERATION * delta)
			
			# Air movement - same for all characters (no speed multiplier)
			_handle_air_movement()
			
			if Input.is_action_just_released(input_jump) or velocity.y >= 0:
				velocity.y = 0
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed(input_defend) and _can_use_defend():
				switch_state(STATE.DEFEND)
			elif Input.is_action_just_pressed(input_jump) and _can_double_jump:
				switch_state(STATE.DOUBLE_JUMP)
			elif Input.is_action_just_pressed(input_dash) and _can_dash:
				switch_state(STATE.DASH)
			elif Input.is_action_just_pressed(input_roll) and _can_roll():
				switch_state(STATE.ROLL)
			elif Input.is_action_just_pressed(input_light_attack):
				switch_state(STATE.LIGHT_ATTACK)
			elif Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
				switch_state(STATE.HEAVY_ATTACK)
		
		STATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			
			# Air movement - same for all characters (no speed multiplier)
			_handle_air_movement()
			
			if Input.is_action_just_pressed(input_defend) and _can_use_defend():
				switch_state(STATE.DEFEND)
			elif is_on_floor() and _drop_through_fall_lock_timer <= 0.0:
				# Only play landing animation/VFX if we entered FALL from a jump (not walking off edge)
				# Check previous state: if we came from IDLE/WALK/SPRINT, it's a slope/coyote situation
				var came_from_ground_state: bool = (previous_state == STATE.IDLE or 
				                                      previous_state == STATE.WALK or 
				                                      previous_state == STATE.SPRINT or 
				                                      previous_state == STATE.TURNING)
				
				# Also check if we actually fell (coyote timer expired = real fall)
				var coyote_expired: bool = _coyote_timer.is_stopped() or _coyote_timer.time_left <= 0.0
				
				# Only play landing if we came from JUMP/DOUBLE_JUMP or coyote time expired (real fall)
				var was_real_fall: bool = (previous_state == STATE.JUMP or 
				                           previous_state == STATE.DOUBLE_JUMP or 
				                           coyote_expired)
				
				if was_real_fall and not came_from_ground_state:
					# Play appropriate landing animation
					var was_double_jump: bool = _used_double_jump
					if _used_double_jump:
						_play_animation("double_jump_land")  # Ninja jump land
					else:
						_play_animation("jump_land")  # Regular jump land
					
					# Emit landed signal for VFX
					landed.emit(was_double_jump, _facing_direction)
					
					_used_double_jump = false  # Reset after landing
				else:
					# Was slope/coyote buffer, don't play landing
					pass
				
				switch_state(STATE.IDLE if Input.get_axis(input_move_left, input_move_right) == 0 else STATE.WALK)
			elif Input.is_action_just_pressed(input_jump):
				var coyote_time_remaining = _coyote_timer.time_left
				if coyote_time_remaining > 0:
					switch_state(STATE.JUMP)
				elif _can_double_jump:
					switch_state(STATE.DOUBLE_JUMP)
			elif Input.is_action_just_pressed(input_dash) and _can_dash:
				switch_state(STATE.DASH)
			elif Input.is_action_just_pressed(input_roll) and _can_roll():
				switch_state(STATE.ROLL)
			elif Input.is_action_just_pressed(input_light_attack):
				switch_state(STATE.LIGHT_ATTACK)
			elif Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
				switch_state(STATE.HEAVY_ATTACK)
		
		STATE.DASH:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			
			if Input.is_action_pressed(input_dash):
				_is_sprinting = true
			else:
				_is_sprinting = false
			
			if is_on_floor():
				_coyote_timer.start()
			
			if Input.is_action_just_pressed(input_jump):
				_dash_jump_buffer = true
			
			var distance: float = absf(position.x - _saved_position.x)
			if distance >= DASH_LENGTH or signf(get_last_motion().x) != _facing_direction:
				if _dash_jump_buffer and _coyote_timer.time_left > 0:
					switch_state(STATE.JUMP)
				elif is_on_floor():
					if Input.is_action_pressed(input_dash):
						switch_state(STATE.SPRINT)
					elif Input.get_axis(input_move_left, input_move_right) != 0:
						switch_state(STATE.WALK)
					else:
						switch_state(STATE.IDLE)
				else:
					switch_state(STATE.FALL)
			elif Input.is_action_just_pressed(input_roll) and _can_roll():
				switch_state(STATE.ROLL)
			elif Input.is_action_just_pressed(input_light_attack):
				switch_state(STATE.LIGHT_ATTACK)
			elif Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
				switch_state(STATE.HEAVY_ATTACK)
		
		STATE.TURNING:
			if signf(velocity.x) == _facing_direction and _is_input_against_facing():
				_set_facing_direction(-_facing_direction)
			
			_handle_sprint(delta)
			
			# Use coyote timer as floor buffer to prevent slope stuttering
			if not is_on_floor() and _coyote_timer.time_left <= 0.0:
				switch_state(STATE.FALL)
			elif not _is_sprinting or velocity.x * _facing_direction >= SPRINT_VELOCITY * _get_speed_multiplier():
				switch_state(STATE.WALK if Input.get_axis(input_move_left, input_move_right) != 0 else STATE.IDLE)
			elif Input.is_action_just_pressed(input_jump):
				_is_sprinting = false
				switch_state(STATE.JUMP)
			elif Input.is_action_just_pressed(input_roll) and _can_roll():
				switch_state(STATE.ROLL)
			elif Input.is_action_just_pressed(input_light_attack):
				switch_state(STATE.LIGHT_ATTACK)
			elif Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
				switch_state(STATE.HEAVY_ATTACK)
		
		STATE.ROLL:
			_process_roll(delta)
		
		STATE.LIGHT_ATTACK:
			_process_light_attack(delta)
		
		STATE.HEAVY_ATTACK:
			_process_heavy_attack(delta)
		
		STATE.ULTIMATE:
			_process_ultimate(delta)
		
		STATE.DEFEND:
			_process_defend(delta)
		
		STATE.HIT:
			# No longer used - kept for compatibility
			pass
		
		STATE.DEATH:
			pass  # Dead - no exit


# -----------------------------
# Movement Handlers
# -----------------------------
func _handle_ground_movement(input_direction: float = 0.0, horizontal_velocity: float = WALK_VELOCITY, step: float = WALK_VELOCITY) -> void:
	if input_direction == 0.0:
		input_direction = signf(Input.get_axis(input_move_left, input_move_right))
	
	_set_facing_direction(input_direction)
	
	var target_velocity: float = input_direction * horizontal_velocity * _get_speed_multiplier()
	velocity.x = move_toward(velocity.x, target_velocity, step)


func _handle_sprint(delta: float) -> void:
	_handle_ground_movement(_facing_direction, SPRINT_VELOCITY, SPRINT_ACCELERATION * delta)


func _handle_air_movement() -> void:
	"""Air movement during jumps/falls - same speed for all characters"""
	var input_direction: float = signf(Input.get_axis(input_move_left, input_move_right))
	
	_set_facing_direction(input_direction)
	
	# NO speed multiplier - all characters have same air control
	var target_velocity: float = input_direction * AIR_VELOCITY
	velocity.x = move_toward(velocity.x, target_velocity, AIR_VELOCITY)
	_is_sprinting = Input.is_action_pressed(input_dash)


func _set_facing_direction(direction: float) -> void:
	if direction != 0:
		_facing_direction = 1 if direction > 0 else -1
		
		if _body_3d_view != null and _body_3d_view.has_method("set_facing"):
			_body_3d_view.call("set_facing", _facing_direction)


func _is_input_toward_facing() -> bool:
	return signf(Input.get_axis(input_move_left, input_move_right)) == _facing_direction


func _is_input_against_facing() -> bool:
	return signf(Input.get_axis(input_move_left, input_move_right)) == -_facing_direction


func _get_speed_multiplier() -> float:
	if character_data != null:
		return character_data.move_speed_multiplier
	return 1.0


# -----------------------------
# Animation System
# -----------------------------
func _reset_animation_state() -> void:
	"""Reset animation player speed to character's default before playing new animation"""
	if _body_3d_view == null:
		return
	
	var anim_player = _body_3d_view.get("_anim_player")
	if anim_player == null:
		return
	
	# Reset animation player speed to character's default
	# This is needed because some animations (ultimate, defensive) change the speed_scale
	var default_speed: float = 2.0  # Knight's default from knight.tscn
	if character_data != null and character_data.character_name == "Rogue":
		default_speed = 1.0  # Rogue's default
	
	if anim_player.speed_scale != default_speed:
		anim_player.speed_scale = default_speed
		pass


func _play_animation_loop(anim_name: StringName) -> void:
	if _body_3d_view == null:
		return
	
	# Let Player3DView handle duplicate checks
	if _body_3d_view.has_method("play_loop"):
		_body_3d_view.call("play_loop", anim_name, false)


func _play_animation(anim_name: StringName, speed: float = 1.0) -> void:
	if _body_3d_view == null:
		return
	
	if _body_3d_view.has_method("play_one_shot"):
		_body_3d_view.call("play_one_shot", anim_name, true, speed)
	else:
		pass


func _get_animation_length(anim_name: StringName) -> float:
	if _body_3d_view == null:
		return 0.0
	
	if _body_3d_view.has_method("get_anim_length"):
		return _body_3d_view.call("get_anim_length", anim_name)
	
	return 0.0


# =============================================================================
# ROLL/DODGE SYSTEM
# =============================================================================

func _can_roll() -> bool:
	return _roll_charges > 0 and _roll_chain_timer <= 0.0


func _can_use_heavy_attack() -> bool:
	"""Check if heavy attack is off cooldown"""
	if _combat == null:
		return true  # No combat system, allow attack
	
	if not _combat.has_method("is_ability_ready"):
		return true  # No cooldown system, allow attack
	
	var is_ready: bool = _combat.call("is_ability_ready", &"heavy")
	
	if not is_ready:
		# Debug: Log cooldown remaining
		if _combat.has_method("get_ability_cooldown_remaining"):
			var _cooldown_left: float = _combat.call("get_ability_cooldown_remaining", &"heavy")
			pass
	
	return is_ready


func _can_use_ultimate() -> bool:
	"""Check if ultimate is off cooldown"""
	if _combat == null:
		return false
	if not _combat.has_method("is_ability_ready"):
		return false
	return _combat.call("is_ability_ready", &"ultimate")


func _start_roll() -> void:
	if not _can_roll():
		return
	
	# Consume charge
	_roll_charges -= 1
	_start_recharge_timer()
	
	# Set roll state
	_roll_active = true
	_roll_timer = roll_duration
	_roll_chain_timer = roll_chain_lockout
	_perfect_dodge_timer = perfect_dodge_window
	
	# Grant invulnerability to PlayerHealth for i-frames and perfect dodge
	if _health != null and roll_iframes:
		# Grant invuln for full roll duration with "roll" source (PerfectDodgeDetector tracks perfect dodge window)
		_health.grant_invuln(roll_duration, "roll")
		pass
	
	# Get roll config from character data
	var roll_direction: String = "forward"
	var roll_distance: float = 400.0
	var roll_dur: float = roll_duration
	
	if character_data != null and not character_data.roll_movement.is_empty():
		roll_direction = character_data.roll_movement.get("direction", "forward")
		roll_distance = character_data.roll_movement.get("distance", 400.0)
		roll_dur = character_data.roll_movement.get("duration", roll_duration)
	
	# Calculate roll velocity with ease-out
	var dir_mult: int = 1 if roll_direction == "forward" else -1
	_roll_direction = _facing_direction * dir_mult
	_roll_speed = roll_distance / roll_dur
	velocity.x = _roll_direction * _roll_speed
	velocity.y = 0
	
	# Slower animation for better visual
	var anim_speed: float = 1.0
	var anim_length: float = _get_animation_length(&"dodge")
	if anim_length > 0.0 and roll_dur > 0.0:
		# Make animation slower (140% of duration means ~0.71x speed)
		anim_speed = anim_length / (roll_dur * 1.4)
	else:
		anim_speed = 0.7  # Fallback - even slower
	
	# Play animation
	_play_animation("dodge", anim_speed)
	
	# Emit signal for VFX
	var _char_name: String = "Unknown"
	if character_data != null:
		_char_name = character_data.character_name
	pass
	roll_started.emit(_char_name, _facing_direction)
	
	pass


func _process_roll(delta: float) -> void:
	# Apply roll velocity with ease-out curve
	if _roll_timer > 0.0:
		var t: float = 1.0 - (_roll_timer / roll_duration)
		var ease_value: float = 1.0 - pow(1.0 - t, 2.0)  # Ease-out quad
		velocity.x = _roll_direction * _roll_speed * (1.0 - ease_value * 0.3)  # Slow down by 30% at end
		
		_roll_timer -= delta
		
		if _roll_timer <= 0.0:
			_roll_active = false
			
			# Transition back to movement
			if is_on_floor():
				switch_state(STATE.IDLE if Input.get_axis(input_move_left, input_move_right) == 0 else STATE.WALK)
			else:
				switch_state(STATE.FALL)
	
	# Can cancel with attacks
	if Input.is_action_just_pressed(input_light_attack):
		_roll_active = false
		switch_state(STATE.LIGHT_ATTACK)
	elif Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
		_roll_active = false
		switch_state(STATE.HEAVY_ATTACK)


func _start_recharge_timer() -> void:
	for i in range(_roll_recharge_timers.size()):
		if _roll_recharge_timers[i] <= 0.0:
			_roll_recharge_timers[i] = roll_recharge_time
			break


func is_in_iframe() -> bool:
	if not roll_iframes:
		return false
	if not _roll_active:
		return false
	
	var elapsed: float = roll_duration - _roll_timer
	return elapsed >= roll_iframe_buffer


func is_in_perfect_dodge_window() -> bool:
	return _perfect_dodge_timer > 0.0


# =============================================================================
# LIGHT ATTACK COMBO SYSTEM (Integrated)
# =============================================================================

func _start_light_attack() -> void:
	# Advance combo step
	_combo_step += 1
	if _combo_step > 3:
		_combo_step = 1  # Reset to 1
	
	# Reset timers and flags
	_combo_window_timer = 0.4  # Small buffer window after animation (reduced from 1.2s)
	_combo_attack_timer = 0.0
	_combo_attack_duration = 0.0
	_combo_can_continue = false  # Can't continue until animation is mostly done
	
	# Get combo config - character-specific
	var combo_damage: int = 2
	var combo_anim: StringName = &"light_attack"
	var combo_speed: float = 1.6
	
	if character_data != null:
		match character_data.character_name:
			"Rogue":
				# Rogue-specific combo values - fast and agile
				match _combo_step:
					1:
						combo_damage = 2
						combo_anim = &"QAnim/Sword_Regular_A"
						combo_speed = 1.6
					2:
						combo_damage = 2
						combo_anim = &"QAnim/Sword_Regular_B"
						combo_speed = 1.6
					3:
						combo_damage = 5
						combo_anim = &"QAnim/Sword_Regular_C"
						combo_speed = 1.8  # Fast finisher for continuous attacks
			
			"Knight":
				# Knight-specific combo values - slower and heavier but still fluid
				match _combo_step:
					1:
						combo_damage = 3  # More damage than Rogue
						combo_anim = &"QAnim/Sword_Regular_A"
						combo_speed = 1.4  # Slower than Rogue's 1.6, but not too slow
					2:
						combo_damage = 3
						combo_anim = &"QAnim/Sword_Regular_B"
						combo_speed = 1.4
					3:
						combo_damage = 7  # Higher finisher damage
						combo_anim = &"QAnim/Sword_Regular_C"
						combo_speed = 1.2  # Heavier finisher, still faster than before
	
	# Trigger damage via Combat node
	if _combat != null and _combat.has_method("start_rogue_combo_hit"):
		_combat.call("start_rogue_combo_hit", _combo_step, combo_damage)
	
	# Play animation directly (bypass mapping since we're using full names)
	if _body_3d_view != null:
		var anim_player = _body_3d_view.get("_anim_player")
		if anim_player != null and anim_player.has_animation(combo_anim):
			var anim_length: float = 0.0
			if anim_player.has_animation(combo_anim):
				var anim = anim_player.get_animation(combo_anim)
				anim_length = anim.length
			
			if anim_length <= 0.0:
				anim_length = 0.5
			
			# Calculate actual animation duration at this speed
			var actual_duration: float = anim_length / combo_speed
			_combo_attack_timer = actual_duration
			_combo_attack_duration = actual_duration  # Store full duration
			
			anim_player.speed_scale = combo_speed
			anim_player.play(combo_anim)
			pass
			
		# Emit signal for VFX
		var _char_name: String = "Unknown"
		if character_data != null:
			_char_name = character_data.character_name
		pass
		light_attack_started.emit(_char_name, _combo_step, _facing_direction)


func _process_light_attack(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
	
	# Minimal ground movement
	velocity.x = move_toward(velocity.x, 0.0, 2600.0 * delta)
	
	# Update attack timer
	if _combo_attack_timer > 0.0:
		_combo_attack_timer -= delta
		
		# Check if animation is complete enough - unlock combo continuation
		if not _combo_can_continue and _combo_attack_duration > 0.0:
			var progress: float = 1.0 - (_combo_attack_timer / _combo_attack_duration)
			# Require a minimum completion percentage before chaining next combo hit.
			var unlock_threshold: float = knight_combo_chain_unlock_threshold
			if character_data != null and character_data.character_name == "Rogue":
				unlock_threshold = rogue_combo_chain_unlock_threshold
			unlock_threshold = clampf(unlock_threshold, 0.05, 0.99)
			
			if progress >= unlock_threshold:
				_combo_can_continue = true
				pass
	
	# Check for combo continuation - ONLY if animation is far enough along
	if Input.is_action_just_pressed(input_light_attack):
		if _combo_can_continue and _combo_window_timer > 0.0:
			# Animation has passed the per-character unlock threshold and is within buffer window.
			_start_light_attack()
			return
	
	# Check for cancels
	if Input.is_action_just_pressed(input_roll) and _can_roll():
		_combo_step = 0
		_combo_window_timer = 0.0
		_combo_attack_timer = 0.0
		_combo_attack_duration = 0.0
		_combo_can_continue = false
		switch_state(STATE.ROLL)
		return
	
	if Input.is_action_just_pressed(input_dash):
		_combo_step = 0
		_combo_window_timer = 0.0
		_combo_attack_timer = 0.0
		_combo_attack_duration = 0.0
		_combo_can_continue = false
		switch_state(STATE.DASH)
		return
	
	# Can interrupt combo window with heavy attack (only if off cooldown)
	if Input.is_action_just_pressed(input_heavy_attack) and _can_use_heavy_attack():
		_combo_step = 0
		_combo_window_timer = 0.0
		_combo_attack_timer = 0.0
		_combo_attack_duration = 0.0
		_combo_can_continue = false
		switch_state(STATE.HEAVY_ATTACK)
		return
	
	# Check if current attack animation finished
	if _combo_attack_timer <= 0.0:
		# Animation finished - unlock combo continuation if not already
		if not _combo_can_continue:
			_combo_can_continue = true
		
		# Check if combo window still active (small buffer after animation)
		if _combo_window_timer > 0.0:
			_combo_window_timer -= delta
			
			# Still in window - stay in attack state waiting for next input
			# Player can move slightly during window
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
			
			# Also check for movement input to cancel combo window early
			var input_dir = Input.get_axis(input_move_left, input_move_right)
			if input_dir != 0.0 and is_on_floor():
				# Player wants to move, end combo
				pass
				_combo_step = 0
				_combo_window_timer = 0.0
				_combo_attack_timer = 0.0
				_combo_attack_duration = 0.0
				_combo_can_continue = false
				switch_state(STATE.WALK)
				return
			
			return
		
		# Combo window expired, end combo
		pass
		_combo_step = 0
		_combo_window_timer = 0.0
		_combo_attack_timer = 0.0
		_combo_attack_duration = 0.0
		_combo_can_continue = false
		
		if is_on_floor():
			var input_dir = Input.get_axis(input_move_left, input_move_right)
			switch_state(STATE.WALK if input_dir != 0 else STATE.IDLE)
		else:
			switch_state(STATE.FALL)


# =============================================================================
# HEAVY ATTACK SYSTEM (Integrated)
# =============================================================================

func _start_heavy_attack() -> void:
	# CRITICAL: Safety check - block if on cooldown
	if not _can_use_heavy_attack():
		pass
		# Return to appropriate state
		if is_on_floor():
			var input_dir = Input.get_axis(input_move_left, input_move_right)
			switch_state(STATE.WALK if input_dir != 0 else STATE.IDLE)
		else:
			switch_state(STATE.FALL)
		return
	
	# Emit signal for VFX
	var _char_name: String = character_data.character_name if character_data != null else "Unknown"
	pass
	heavy_attack_started.emit(_char_name, _facing_direction)
	
	# Get heavy attack config
	var attack_distance: float = 0.0
	var attack_duration: float = 0.0
	
	if character_data != null and not character_data.attack_movement.is_empty():
		if character_data.attack_movement.has("heavy"):
			var cfg: Dictionary = character_data.attack_movement["heavy"]
			attack_distance = cfg.get("distance", 0.0)
			attack_duration = cfg.get("duration", 0.5)
	
	# Start attack movement if configured (distance > 0)
	if attack_distance > 0.0 and attack_duration > 0.0:
		_attack_move_active = true
		_attack_move_timer = 0.0
		_attack_move_duration = attack_duration
		_attack_move_speed = attack_distance / attack_duration
		pass
	else:
		# No movement (Knight AOE attack)
		_attack_move_active = false
		_attack_move_duration = attack_duration if attack_duration > 0.0 else 0.8
		_attack_move_timer = 0.0
		pass
	
	# Trigger damage via PlayerCombat
	if _combat != null:
		if _combat.has_method("_start_attack"):
			_combat.call("_start_attack", &"heavy")
			pass
		else:
			pass
	
	# Play animation
	var anim_name: StringName = &"heavy_attack"
	var anim_speed: float = 1.0
	
	# Get animation length for timing
	var anim_length: float = _get_animation_length(anim_name)
	if anim_length > 0.0 and _attack_move_duration > 0.0:
		anim_speed = anim_length / _attack_move_duration
		pass
	
	_play_animation(anim_name, anim_speed)


func _process_heavy_attack(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
	
	# Always update timer
	_attack_move_timer += delta
	
	# Handle attack movement (if character has dash attacks like Rogue)
	if _attack_move_active:
		if _attack_move_timer >= _attack_move_duration:
			_attack_move_active = false
			
			# Attack finished
			if is_on_floor():
				var input_dir = Input.get_axis(input_move_left, input_move_right)
				switch_state(STATE.WALK if input_dir != 0 else STATE.IDLE)
			else:
				switch_state(STATE.FALL)
		else:
			# Ease-out movement
			var t: float = clampf(_attack_move_timer / _attack_move_duration, 0.0, 1.0)
			var ease_out: float = 1.0 - pow(t, 2.0)
			velocity.x = float(_facing_direction) * _attack_move_speed * ease_out
	else:
		# No movement (Knight AOE attack) - just wait for animation
		velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
		
		if _attack_move_timer >= _attack_move_duration:
			# Attack animation finished
			if is_on_floor():
				var input_dir = Input.get_axis(input_move_left, input_move_right)
				switch_state(STATE.WALK if input_dir != 0 else STATE.IDLE)
			else:
				switch_state(STATE.FALL)
	
	# Can cancel with dodge/roll
	if Input.is_action_just_pressed(input_roll) and _can_roll():
		_attack_move_active = false
		switch_state(STATE.ROLL)
		return
	
	if Input.is_action_just_pressed(input_dash):
		_attack_move_active = false
		switch_state(STATE.DASH)
		return


# =============================================================================
# ULTIMATE SYSTEM (Integrated - Rogue Multi-Strike)
# =============================================================================

var _ultimate_active: bool = false
var _ultimate_targets: Array[Node] = []
var _ultimate_current_index: int = 0
var _ultimate_pause_timer: float = 0.0
var _ultimate_origin_pos: Vector2 = Vector2.ZERO

# Defensive ability state
var _defend_animation_timer: float = 0.0

func _start_ultimate() -> void:
	# Safety gate: block if ultimate is still on cooldown.
	if not _can_use_ultimate():
		if is_on_floor():
			var input_dir: float = Input.get_axis(input_move_left, input_move_right)
			switch_state(STATE.WALK if input_dir != 0.0 else STATE.IDLE)
		else:
			switch_state(STATE.FALL)
		return
	
	# Trigger ultimate cooldown in PlayerCombat
	if _combat != null:
		_combat._start_attack(&"ultimate")
	
	# Trigger ultimate cooldown in PlayerCombat
	if _combat != null:
		_combat._start_attack(&"ultimate")
	
	# Get enemies using FloorProgressionController (same as RogueController)
	var enemies: Array[Node] = _get_enemies_on_current_floor()
	
	if enemies.is_empty():
		pass
		switch_state(STATE.IDLE)
		return
	
	# Shuffle and start
	enemies.shuffle()
	_ultimate_active = true
	_ultimate_targets = enemies
	_ultimate_current_index = 0
	_ultimate_origin_pos = global_position
	
	# Grant invulnerability
	if _health != null:
		_health.set("_invuln_timer", 999.0)
	
	pass
	
	# Attack first enemy immediately
	_ultimate_attack_next_enemy()


func _get_enemies_on_current_floor() -> Array[Node]:
	"""Get all alive enemies on the current floor (copied from RogueController)"""
	var result: Array[Node] = []
	
	# Try to find FloorProgressionController
	var floor_controller: Node = get_tree().get_first_node_in_group("floors")
	if floor_controller == null:
		pass
		# Fallback: get all enemies
		var all_enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in all_enemies:
			var hp_node = enemy.get_node_or_null("Health")
			if hp_node != null and hp_node.get("hp") > 0:
				result.append(enemy)
		
		# Check boss
		var bosses = get_tree().get_nodes_in_group("boss")
		for boss in bosses:
			var hp_node = boss.get_node_or_null("BossHealth")
			if hp_node != null and hp_node.get("hp") > 0:
				result.append(boss)
		return result
	
	# Get current floor number
	if not floor_controller.has_method("get_current_floor_number"):
		push_warning("[PlayerV3] FloorProgressionController missing get_current_floor_number()")
		return result
	
	var current_floor: int = floor_controller.call("get_current_floor_number")
	pass
	
	# Get floor enemy group name
	var group_name: StringName = &""
	var groups: Array = floor_controller.get("floor_enemy_groups")
	var idx: int = current_floor - 1  # Convert to 0-based index
	
	if groups != null and not groups.is_empty() and idx >= 0 and idx < groups.size():
		group_name = groups[idx]
		pass
	else:
		# Fallback for boss floors
		if current_floor == 5:
			group_name = &"floor5_enemies"
		else:
			push_warning("[PlayerV3] Floor %d out of bounds" % current_floor)
			return result
	
	# Get enemies from the group
	var enemies: Array[Node] = get_tree().get_nodes_in_group(group_name)
	pass
	
	# Filter to alive enemies
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		
		var hp_node = enemy.get_node_or_null("Health")
		if hp_node == null:
			hp_node = enemy.get_node_or_null("BossHealth")
		
		if hp_node != null:
			var hp = hp_node.get("hp")
			if hp > 0:
				result.append(enemy)
	
	pass
	return result


func _process_ultimate(delta: float) -> void:
	# Freeze in place - CRITICAL: Set to zero every frame
	velocity = Vector2.ZERO
	
	# Verify we're actually in ultimate state
	if active_state != STATE.ULTIMATE:
		pass
		_end_ultimate()
		return
	
	# Check if Knight (wave attack) or Rogue (sequential teleport)
	var is_knight: bool = character_data != null and character_data.character_name == "Knight"
	
	# Update pause timer
	if _ultimate_pause_timer > 0.0:
		_ultimate_pause_timer -= delta
		if _ultimate_pause_timer <= 0.0:
			if is_knight:
				# Knight wave is done, end ultimate
				_end_ultimate()
			elif _ultimate_current_index < _ultimate_targets.size():
				# Rogue: attack next enemy
				_ultimate_attack_next_enemy()
			else:
				# Rogue: all targets hit, end ultimate
				_end_ultimate()


func _ultimate_attack_next_enemy() -> void:
	# Check character type for different ultimate behaviors
	var is_knight: bool = character_data != null and character_data.character_name == "Knight"
	
	if is_knight:
		# Knight: Wave attack - stay in place, hit all enemies in front at once
		_ultimate_knight_wave_attack()
	else:
		# Rogue: Teleport to each enemy sequentially
		_ultimate_rogue_teleport_attack()


func _ultimate_knight_wave_attack() -> void:
	"""Knight ultimate: Stationary wave attack hitting all enemies in front"""
	pass
	
	# Emit signal for VFX
	pass
	knight_ultimate_started.emit(_facing_direction)
	
	# Play wave animation once
	var _animation_duration: float = 0.5
	if _body_3d_view != null:
		var anim_player = _body_3d_view.get("_anim_player")
		var ult_anim: StringName = &"MAnim/SwordandShieldCast"
		var ult_speed: float = 1.5
		
		if anim_player != null and anim_player.has_animation(ult_anim):
			var anim = anim_player.get_animation(ult_anim)
			_animation_duration = anim.length / ult_speed
			
			anim_player.speed_scale = ult_speed
			anim_player.play(ult_anim)
			pass
	
	# Unlock player at 1.2s (when wave fires), but continue damage async
	_ultimate_pause_timer = 1.2
	
	# Capture snapshot of targets before async operation (prevents race condition)
	var captured_targets: Array[Node] = _ultimate_targets.duplicate()
	var captured_facing: int = _facing_direction
	var captured_position: Vector2 = global_position
	
	# Apply damage asynchronously after delay (VFX plays independently)
	_apply_knight_ultimate_damage_delayed(captured_facing, captured_position, captured_targets)


func _apply_knight_ultimate_damage_delayed(captured_facing: int, player_pos: Vector2, targets: Array[Node]) -> void:
	"""Apply Knight ultimate damage after delay"""
	# Wait for wave to travel before applying damage
	pass
	await get_tree().create_timer(1.4).timeout
	pass
	
	# Damage ALL enemies in front of player (using captured snapshot)
	var _enemies_hit: int = 0
	for enemy in targets:
		if enemy == null or not is_instance_valid(enemy):
			continue
		
		# Check if enemy is in front of player
		var enemy_pos: Vector2 = enemy.global_position
		if enemy.has_node("BossVisual"):
			var visual_node = enemy.get_node("BossVisual")
			if visual_node != null:
				enemy_pos = visual_node.global_position
		
		# Only hit enemies in front of player's facing direction (use captured values)
		var to_enemy: float = enemy_pos.x - player_pos.x
		if signf(to_enemy) == captured_facing or absf(to_enemy) < 50.0:
			# Enemy is in front or very close
			var hp_node = enemy.get_node_or_null("Health")
			if hp_node == null:
				hp_node = enemy.get_node_or_null("BossHealth")
			
			if hp_node != null and hp_node.has_method("take_damage"):
				var hp_value = hp_node.get("hp")
				if hp_value != null and hp_value > 0:
					hp_node.call("take_damage", 20, self, &"ultimate", false)
					_enemies_hit += 1
					pass
					
				# Emit signal for VFX at enemy position
				pass
				knight_ultimate_hit.emit(enemy, enemy_pos)
	
	pass


func _ultimate_rogue_teleport_attack() -> void:
	"""Rogue ultimate: Teleport to each enemy sequentially"""
	if _ultimate_current_index >= _ultimate_targets.size():
		# All enemies attacked, end ultimate
		_end_ultimate()
		return
	
	var enemy: Node = _ultimate_targets[_ultimate_current_index]
	
	# Validate enemy
	if enemy == null or not is_instance_valid(enemy):
		pass
		_ultimate_current_index += 1
		_ultimate_pause_timer = 0.15  # Short delay before next
		return
	
	var hp_node = enemy.get_node_or_null("Health")
	if hp_node == null:
		hp_node = enemy.get_node_or_null("BossHealth")
	
	if hp_node == null:
		pass
		_ultimate_current_index += 1
		_ultimate_pause_timer = 0.15
		return
	
	var hp_value = hp_node.get("hp")
	if hp_value == null or hp_value <= 0:
		pass
		_ultimate_current_index += 1
		_ultimate_pause_timer = 0.15
		return
	
	# Get enemy position (use visual node for boss)
	var enemy_pos: Vector2 = enemy.global_position
	if enemy.has_node("BossVisual"):
		var visual_node = enemy.get_node("BossVisual")
		if visual_node != null:
			enemy_pos = visual_node.global_position
			pass
	
	# Get enemy facing direction
	var enemy_facing: int = 1
	if enemy.get("_facing_dir") != null:
		enemy_facing = int(enemy.get("_facing_dir"))
	
	# Teleport behind enemy (opposite of their facing)
	var behind_offset: float = -enemy_facing * 100.0
	var target_pos = Vector2(enemy_pos.x + behind_offset, enemy_pos.y)
	
	pass
	pass
	pass
	
	# Teleport to enemy's position (both X and Y)
	global_position = target_pos
	
	pass
	
	# Face same direction as enemy
	_set_facing_direction(float(enemy_facing))
	
	# Play Rogue ultimate animation
	var animation_duration: float = 0.5
	if _body_3d_view != null:
		var anim_player = _body_3d_view.get("_anim_player")
		var ult_anim: StringName = &"QAnim/Sword_Dash_NoRM"
		var ult_speed: float = 3.0
		
		if anim_player != null and anim_player.has_animation(ult_anim):
			var anim = anim_player.get_animation(ult_anim)
			animation_duration = anim.length / ult_speed
			
			anim_player.speed_scale = ult_speed
			anim_player.play(ult_anim)
			pass
	
	# Deal damage
	if hp_node.has_method("take_damage"):
		hp_node.call("take_damage", 20, self, &"ultimate", false)
		pass
		
	# Emit signal for VFX (spawn at enemy position)
	var _char_name: String = "Unknown"
	if character_data != null:
		_char_name = character_data.character_name
	pass
	ultimate_attack_hit.emit(_char_name, enemy_pos, _facing_direction)
	
	# Move to next enemy
	_ultimate_current_index += 1
	_ultimate_pause_timer = animation_duration + 0.15  # Wait for animation + short pause


func _end_ultimate() -> void:
	pass
	pass
	
	# Only Rogue teleports back to origin
	var is_knight: bool = character_data != null and character_data.character_name == "Knight"
	if not is_knight:
		pass
		# Teleport back to origin (full position - both X and Y)
		global_position = _ultimate_origin_pos
		pass
	else:
		pass
	
	# Clear state
	_ultimate_active = false
	_ultimate_targets.clear()
	_ultimate_current_index = 0
	_ultimate_pause_timer = 0.0
	
	# Remove invulnerability
	if _health != null:
		_health.set("_invuln_timer", 0.0)
	
	# CRITICAL: Stop the ultimate animation to prevent bone transforms from persisting
	if _body_3d_view != null:
		var anim_player = _body_3d_view.get("_anim_player")
		if anim_player != null and anim_player.is_playing():
			var current_anim: String = anim_player.current_animation
			# Check if it's an ultimate animation
			if "Cast" in current_anim or "SwordandShield" in current_anim:
				pass
				anim_player.stop()
				# Reset speed_scale to character's default
				var default_speed: float = 2.0 if is_knight else 1.0
				anim_player.speed_scale = default_speed
	
	# Return to appropriate state
	if is_on_floor():
		var input_dir = Input.get_axis(input_move_left, input_move_right)
		switch_state(STATE.WALK if input_dir != 0 else STATE.IDLE)
	else:
		switch_state(STATE.FALL)
	
	pass


# =============================================================================
# PUBLIC API
# =============================================================================

func set_input_locked(locked: bool) -> void:
	"""Lock/unlock player input (called by VictoryUI, cutscenes, etc.)"""
	_input_locked = locked
	
	if locked:
		# Stop all movement and animations when locking
		velocity = Vector2.ZERO
		
		# Stop any currently playing animation to prevent "ghost" inputs
		if _body_3d_view != null:
			var anim_player = _body_3d_view.get("_anim_player")
			if anim_player != null and anim_player.is_playing():
				pass
				anim_player.stop()
		
		pass
	else:
		# When unlocking, transition to appropriate idle state
		if is_inside_tree() and is_on_floor():
			switch_state(STATE.IDLE)
		
		pass


func set_cutscene_motion_lock(locked: bool) -> void:
	"""Disable player control while still allowing gravity/fall behavior."""
	_cutscene_motion_locked = locked

	if locked:
		# Stop any currently playing animation immediately to avoid run/walk carry-over.
		if _body_3d_view != null:
			var anim_player = _body_3d_view.get("_anim_player")
			if anim_player != null and anim_player.is_playing():
				anim_player.stop()

		# Clear horizontal movement immediately; keep vertical so air states can fall naturally.
		velocity.x = 0.0

		# Force state immediately so visuals snap to idle/fall instead of running in place.
		switch_state(STATE.IDLE if is_on_floor() else STATE.FALL)
	else:
		if is_on_floor():
			switch_state(STATE.IDLE)
		else:
			switch_state(STATE.FALL)


func get_current_state() -> STATE:
	return active_state


func get_facing_direction() -> int:
	return _facing_direction


# Expose "facing" property for AttackHitbox to read
var facing: int:
	get:
		return _facing_direction
	set(value):
		_facing_direction = value


func get_roll_charges() -> int:
	return _roll_charges


func get_roll_max_charges() -> int:
	return maxi(1, roll_max_charges)


func get_roll_next_charge_time_left() -> float:
	"""Returns time left until next charge is ready"""
	if _roll_charges >= get_roll_max_charges():
		return 0.0
	
	# Find the recharge timer that's active (lowest value > 0)
	var min_time: float = 999999.0
	for timer_val in _roll_recharge_timers:
		if timer_val > 0.0 and timer_val < min_time:
			min_time = timer_val
	
	if min_time < 999999.0:
		return min_time
	
	return 0.0


func get_roll_recharge_time() -> float:
	"""Returns total recharge time for a dodge charge"""
	return maxf(roll_recharge_time, 0.01)


# =============================================================================
# DEFENSIVE ABILITY SYSTEM (Character-Specific)
# =============================================================================

func _can_use_defend() -> bool:
	"""Check if defensive ability is off cooldown"""
	if _combat == null:
		return false
	if not _combat.has_method("is_ability_ready"):
		return false
	return _combat.call("is_ability_ready", &"defend")


func _start_defend() -> void:
	"""Activate character-specific defensive ability"""
	pass
	
	# Trigger defensive buff via PlayerCombat
	# PlayerCombat._try_defend() will:
	# 1. Check cooldown
	# 2. Apply character-specific buff (Knight = damage reduction, Rogue = dodge chance)
	# 3. Set cooldown
	if _combat != null:
		if _combat.has_method("_try_defend"):
			_combat.call("_try_defend")
		else:
			push_warning("[PlayerV3] Combat node has no _try_defend method")
	
	# Emit signal for VFX
	var _char_name: String = character_data.character_name if character_data != null else "Unknown"
	pass
	defensive_activated.emit(_char_name, _facing_direction)
	
	# Play character-specific animation
	_play_defensive_animation()


func _play_defensive_animation() -> void:
	"""Play MAnim/SwordandShieldPowerup animation"""
	if _body_3d_view == null:
		return
	
	var anim_player = _body_3d_view.get("_anim_player")
	if anim_player == null:
		return
	
	var defend_anim: StringName = &"MAnim/SwordandShieldPowerup"
	
	if anim_player.has_animation(defend_anim):
		var anim = anim_player.get_animation(defend_anim)
		var anim_length: float = anim.length if anim != null else 1.0
		
		# Play at normal speed
		_defend_animation_timer = anim_length
		anim_player.speed_scale = 1.0
		anim_player.play(defend_anim)
		
		var _char_name: String = character_data.character_name if character_data != null else "Unknown"
		pass
	else:
		push_warning("[PlayerV3] Defensive animation not found: %s" % defend_anim)
		_defend_animation_timer = 0.5  # Fallback duration


func _process_defend(delta: float) -> void:
	"""Process defensive ability animation state"""
	# Apply gravity
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
	
	# Stop horizontal movement
	velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
	
	# Update animation timer
	if _defend_animation_timer > 0.0:
		_defend_animation_timer -= delta
		
		if _defend_animation_timer <= 0.0:
			# Animation finished, return to appropriate state
			if is_on_floor():
				var input_dir = Input.get_axis(input_move_left, input_move_right)
				switch_state(STATE.WALK if input_dir != 0 else STATE.IDLE)
			else:
				switch_state(STATE.FALL)


func play_defensive_animation() -> void:
	"""Public API for PlayerCombat to trigger animation (called via _try_defend)"""
	# This is called by PlayerCombat when the "defend" input is pressed in _process
	# But we're handling it in the state machine now, so this can be a no-op
	# or we can use it as a callback
	pass


func handle_hit() -> void:
	"""
	Legacy function - no longer used.
	Invulnerability is now granted directly via _health.grant_invuln() in _start_roll().
	PerfectDodgeDetector handles perfect dodge detection automatically.
	"""
	# This function is kept for backwards compatibility but does nothing
	# The real i-frame and perfect dodge logic is handled by:
	# 1. _start_roll() granting invuln to PlayerHealth
	# 2. PerfectDodgeDetector monitoring invuln timing
	# 3. PlayerHealth blocking damage when invulnerable
	pass


func handle_death() -> void:
	"""Called by Health node when dying"""
	switch_state(STATE.DEATH)


func _on_health_damage_applied(_damage: int, _source: Node) -> void:
	"""Signal handler: called when player takes damage"""
	# Check for perfect dodge (but don't interrupt gameplay)
	handle_hit()
	
	# Don't play hit animation if in the middle of attacking (especially Rogue combos)
	# This prevents disrupting fast combo chains
	if active_state == STATE.LIGHT_ATTACK or active_state == STATE.HEAVY_ATTACK or active_state == STATE.ULTIMATE:
		pass
		return
	
	# Just play hit animation without interrupting gameplay
	# No state change, no stun - purely visual feedback
	if _body_3d_view != null:
		# Get the actual hit animation name
		if character_data != null:
			var hit_anim = character_data.get_animation(&"hit")
			if hit_anim != &"":
				var anim_player = _body_3d_view.get("_anim_player")
				if anim_player != null and anim_player.has_animation(hit_anim):
					# Play hit animation at fast speed so it doesn't interfere too long
					anim_player.speed_scale = 2.0
					anim_player.play(hit_anim)
					pass


func _on_health_died() -> void:
	"""Signal handler: called when player dies"""
	handle_death()
