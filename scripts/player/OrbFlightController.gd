# res://scripts/OrbFlightController.gd
extends Node2D
class_name OrbFlightController

signal flight_started
signal flight_completed
signal flight_cancelled

@export var player_group: StringName = &"player"

# Where to spawn the orb (defaults to player position at start)
@export var orb_scene: PackedScene
@export var rock_scene: PackedScene

# Flight tuning
@export var flight_speed_y: float = 520.0 # upward speed (pixels/sec)
@export var orb_move_speed_x: float = 600.0 # left/right dodge speed
@export var lane_half_width: float = 360.0 # clamp orb X around start X
@export var rock_spawn_interval: float = 0.5
@export var rock_spawn_half_width: float = 420.0
@export var rock_spawn_y_offset: float = -3500.0  # ✅ Spawn rocks far above (more negative = higher up)
@export var rock_fall_speed: float = 900.0
@export var rock_damage: int = 10
@export var match_rock_spawn_to_lane: bool = true

# ✅ Player lane targeting (makes dodging more challenging)
@export_range(0.0, 1.0, 0.05) var player_lane_target_chance: float = 0.60  # 60% chance to spawn near player
@export var player_lane_spread: float = 80.0  # How wide the "player lane" is (±pixels from player X)
@export var outside_lane_distance: float = 200.0  # Min distance from player when spawning "outside" the lane

# ✅ Performance: cleanup rocks that fall too far past the orb
@export var rock_cleanup_distance: float = 1200.0
@export var rock_cleanup_interval: float = 0.5  # Less frequent cleanup
@export var max_active_rocks: int = 8  # ✅ Reduced to 8 for better performance

# ✅ Object pooling for performance (no constant instantiate/free)
@export var rock_pool_size: int = 12  # Pool slightly larger than max active

# Completion target
@export var target_spawn_path: NodePath = NodePath() # Marker2D on Floor 3
@export var completion_distance_y: float = 1600.0 # if target_spawn_path not set, travel this far

# Safety
@export var end_lockout_seconds: float = 0.15

# -----------------------------
# ✅ Camera handoff
# -----------------------------
@export var player_camera_path: NodePath = ^"Camera2D"
@export var orb_camera_path: NodePath = ^"Camera2D"
@export var snap_camera_on_switch: bool = true
@export var orb_camera_offset_y: float = -450.0  # ✅ Offset camera down to show orb lower in view (negative = camera looks up, orb appears lower)

# -----------------------------
# ✅ Finish / Autopilot
# -----------------------------
# When orb reaches "finish Y", we stop input + rocks and let autopilot fly to target.
@export var finish_y_padding: float = 0.0

# Autopilot tuning (smooth glide to target)
@export var autopilot_speed: float = 1800.0  # Increased from 720 for faster, smoother transition
@export var autopilot_arrive_radius: float = 10.0

# ✅ Cinematic arc entrance (Thor-style)
@export var autopilot_arc_height: float = 800.0  # How high above target to arc
@export var autopilot_use_arc: bool = true  # Enable cinematic arc entrance

# Prevent getting stuck on platforms during autopilot
@export var disable_orb_collisions_during_autopilot: bool = true

var _player: Node2D = null
var _health: PlayerHealth = null

var _orb: CharacterBody2D = null
var _start_pos: Vector2 = Vector2.ZERO
var _target_y: float = 0.0
var _elapsed: float = 0.0

var _spawn_timer: float = 0.0
var _cleanup_timer: float = 0.0
var _active_rocks: Array[Node] = []  # ✅ Track active rocks
var _rock_pool: Array[OrbFallingRock] = []  # ✅ Pool of reusable rocks
var _running: bool = false
var _finishing: bool = false

# ✅ finishing state
enum FinishState { NONE, AUTOPILOT }
var _finish_state: int = FinishState.NONE
var _finish_target_pos: Vector2 = Vector2.ZERO
var _stop_rocks: bool = false

# ✅ Arc autopilot state
var _arc_start_pos: Vector2 = Vector2.ZERO
var _arc_peak_pos: Vector2 = Vector2.ZERO
var _arc_progress: float = 0.0  # 0.0 to 1.0

# camera
var _player_camera: Camera2D = null
var _orb_camera: Camera2D = null
var _player_camera_was_enabled: bool = true

# collision cache for orb (so we can restore)
var _orb_collision_cached: bool = false
var _orb_collision_cache: Array = [] # each entry: [CollisionObject2D, layer:int, mask:int]

# collision cache for player (to prevent hazard damage during flight)
var _player_collision_layer: int = 0
var _player_collision_mask: int = 0
var _player_collision_cached: bool = false

# ✅ Performance monitoring
@export_group("Debug")
@export var debug_fps_monitoring: bool = false  # ✅ Disabled for performance
@export var fps_warn_threshold: float = 55.0  # Warn if FPS drops below this
var _frame_times: Array[float] = []
var _max_frame_samples: int = 60
var _last_fps_warning: float = 0.0
var _fps_warning_cooldown: float = 2.0


func start_flight(player: Node2D) -> void:
	if _running:
		return
	if player == null or not is_instance_valid(player):
		return

	_player = player
	_health = _player.get_node_or_null("Health") as PlayerHealth

	_player_camera = _player.get_node_or_null(player_camera_path) as Camera2D
	if _player_camera != null:
		_player_camera_was_enabled = _player_camera.enabled

	_start_pos = _player.global_position
	_target_y = _compute_target_y()

	_spawn_orb()
	if _orb == null or not is_instance_valid(_orb):
		_player = null
		_health = null
		return

	_switch_to_orb_camera()

	_lock_player(true)
	_set_player_visible(false)
	_disable_player_collisions()

	_running = true
	_finishing = false
	_finish_state = FinishState.NONE
	_stop_rocks = false

	_elapsed = 0.0
	_spawn_timer = 0.0
	_cleanup_timer = rock_cleanup_interval
	_active_rocks.clear()
	
	# ✅ Initialize rock pool if needed
	_initialize_rock_pool()

	set_physics_process(true)
	flight_started.emit()


func cancel_flight() -> void:
	if not _running:
		return

	_restore_orb_collision_if_needed()
	_restore_player_camera()
	_restore_player_collisions() # ✅ Re-enable hazard collision
	_cleanup_orb_and_rocks()
	_lock_player(false)
	_set_player_visible(true)

	_running = false
	_finishing = false
	_finish_state = FinishState.NONE
	_stop_rocks = true

	flight_cancelled.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if not _running:
		return
	# ⚡ OPTIMIZATION: Removed is_instance_valid() from hot path (trust pool system)
	if _orb == null:
		cancel_flight()
		return
	
	# ✅ Check if player died during flight (health reached 0)
	# ⚡ OPTIMIZATION: Removed is_instance_valid() check (health is set once at start)
	if _health != null and _health.hp <= 0:
		_handle_death_during_flight()
		return
	
	# ✅ FPS monitoring
	if debug_fps_monitoring:
		_monitor_performance(delta)

	_elapsed += delta

	# -----------------------------
	# ✅ Finish autopilot tick
	# -----------------------------
	if _finishing and _finish_state == FinishState.AUTOPILOT:
		_tick_autopilot(delta)
		return
	
	# ✅ If finishing but not autopilot (death state), continue panning up
	if _finishing:
		# Continue moving orb up even though it's invisible (for camera pan)
		if _orb != null and is_instance_valid(_orb):
			var vel := _orb.velocity
			vel.y = -flight_speed_y
			vel.x = 0.0
			_orb.velocity = vel
			_orb.move_and_slide()
		return

	# -----------------------------
	# Normal player-controlled flight
	# -----------------------------
	# Completion check (enter finishing BEFORE doing more movement/spawns)
	# ✅ FIX: Use ADDITION so we trigger BEFORE reaching target (at higher Y, less negative)
	if not _finishing and _orb.global_position.y <= (_target_y + finish_y_padding):
		_begin_finish_autopilot()
		return

	# --- Orb motion: auto-up + input left/right ---
	# ✅ SAFETY: Explicitly block input if somehow still in normal flight during finishing
	var input_x: float = 0.0
	if not _finishing:
		input_x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_x += Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_x = clampf(input_x, -1.0, 1.0)

	var v := _orb.velocity
	v.x = input_x * orb_move_speed_x
	v.y = -flight_speed_y
	_orb.velocity = v
	_orb.move_and_slide()

	# Clamp orb X within lane centered around start X
	var gp := _orb.global_position
	gp.x = clampf(gp.x, _start_pos.x - lane_half_width, _start_pos.x + lane_half_width)
	_orb.global_position = gp

	# Spawn rocks
	if not _stop_rocks:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = maxf(rock_spawn_interval, 0.05)
			_spawn_rock()
	
	# ✅ Performance: cleanup rocks periodically, not every frame
	_cleanup_timer -= delta
	if _cleanup_timer <= 0.0:
		_cleanup_timer = maxf(rock_cleanup_interval, 0.1)
		_cleanup_distant_rocks()


# -----------------------------
# ✅ Finishing: Autopilot to spawn
# -----------------------------
func _begin_finish_autopilot() -> void:
	if _finishing:
		return

	_finishing = true
	_finish_state = FinishState.AUTOPILOT

	# stop hazards immediately
	_stop_rocks = true

	# optional lockout (tiny beat)
	if end_lockout_seconds > 0.0:
		# don't await here; we want to start autopilot logic now
		pass

	# choose autopilot destination
	var spawn_node := get_node_or_null(target_spawn_path) as Node2D
	_finish_target_pos = spawn_node.global_position if spawn_node != null else Vector2(_start_pos.x, _target_y)

	# ✅ Set up cinematic arc waypoints (Thor bifrost entrance)
	_arc_start_pos = _orb.global_position
	_arc_peak_pos = Vector2(
		_finish_target_pos.x,  # Horizontally aligned with target
		_finish_target_pos.y - autopilot_arc_height  # High above target
	)
	_arc_progress = 0.0

	# stop current motion right away
	_orb.velocity = Vector2.ZERO
	_orb.move_and_slide() # clear any residual motion

	# prevent platform snagging during the cinematic glide
	if disable_orb_collisions_during_autopilot:
		_cache_and_disable_orb_collisions()
		# Also disable the CharacterBody2D's own collision layers
		if _orb is CharacterBody2D:
			_orb.set_collision_layer(0)
			_orb.set_collision_mask(0)

	# kill any existing rocks right away
	_cleanup_rocks_only()


func _tick_autopilot(delta: float) -> void:
	# ⚡ OPTIMIZATION: Removed is_instance_valid() from hot path
	if _orb == null:
		cancel_flight()
		return

	# optional initial lockout delay
	if end_lockout_seconds > 0.0:
		end_lockout_seconds = 0.0
		# Do one frame later, but still stay in autopilot.
		return

	if autopilot_use_arc:
		_tick_autopilot_arc(delta)
	else:
		_tick_autopilot_straight(delta)


func _tick_autopilot_straight(delta: float) -> void:
	# Original straight-line autopilot
	var to_target: Vector2 = _finish_target_pos - _orb.global_position
	var dist: float = to_target.length()

	if dist <= maxf(autopilot_arrive_radius, 1.0):
		_complete_flight_at_target()
		return

	var dir: Vector2 = to_target / maxf(dist, 0.0001)
	var step: float = autopilot_speed * delta
	if step >= dist:
		_orb.global_position = _finish_target_pos
	else:
		_orb.global_position += dir * step


func _tick_autopilot_arc(delta: float) -> void:
	# ✅ Cinematic arc entrance (Thor bifrost style)
	# Calculate total arc distance for speed normalization
	var dist_to_peak: float = _arc_start_pos.distance_to(_arc_peak_pos)
	var dist_from_peak: float = _arc_peak_pos.distance_to(_finish_target_pos)
	var total_arc_dist: float = dist_to_peak + dist_from_peak
	
	if total_arc_dist < 1.0:
		# Degenerate case, just go straight
		_orb.global_position = _finish_target_pos
		_complete_flight_at_target()
		return
	
	# Progress along arc (0.0 = start, 0.5 = peak, 1.0 = target)
	var progress_step: float = (autopilot_speed * delta) / total_arc_dist
	_arc_progress += progress_step
	_arc_progress = clampf(_arc_progress, 0.0, 1.0)
	
	if _arc_progress >= 1.0:
		_orb.global_position = _finish_target_pos
		_complete_flight_at_target()
		return
	
	# Quadratic bezier curve through 3 points: start -> peak -> target
	var t: float = _arc_progress
	var pos: Vector2 = _bezier_quadratic(_arc_start_pos, _arc_peak_pos, _finish_target_pos, t)
	_orb.global_position = pos


# Quadratic Bezier: B(t) = (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
func _bezier_quadratic(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var t_inv: float = 1.0 - t
	return t_inv * t_inv * p0 + 2.0 * t_inv * t * p1 + t * t * p2


func _complete_flight_at_target() -> void:
	# ✅ Pause for 1 second at destination before spawning player
	await get_tree().create_timer(1.0).timeout
	
	# Place player where the orb arrived (not a teleport to arbitrary point — it followed the orb)
	if _player != null and is_instance_valid(_player):
		_player.global_position = _finish_target_pos

	_restore_orb_collision_if_needed()
	_restore_player_camera()
	_restore_player_collisions() # ✅ Re-enable hazard collision
	_cleanup_orb_and_rocks()
	_set_player_visible(true)
	_lock_player(false)

	_running = false
	_finishing = false
	_finish_state = FinishState.NONE

	flight_completed.emit()
	queue_free()


# -----------------------------
# Helpers
# -----------------------------
func _compute_target_y() -> float:
	var spawn_node := get_node_or_null(target_spawn_path) as Node2D
	if spawn_node != null:
		return spawn_node.global_position.y
	return _start_pos.y - maxf(completion_distance_y, 64.0)


func _spawn_orb() -> void:
	if orb_scene == null:
		push_warning("[OrbFlight] orb_scene is null.")
		return

	var n := orb_scene.instantiate()
	var orb := n as CharacterBody2D
	if orb == null:
		push_warning("[OrbFlight] orb_scene root must be CharacterBody2D.")
		n.queue_free()
		return

	get_tree().current_scene.add_child(orb)
	orb.global_position = _start_pos
	_orb = orb

	_orb_camera = _orb.get_node_or_null(orb_camera_path) as Camera2D
	if _orb_camera == null:
		push_warning("[OrbFlight] Orb camera not found. Add Camera2D under orb root and set orb_camera_path.")


# ✅ Initialize rock pool (creates rocks once, reuses them)
func _initialize_rock_pool() -> void:
	if rock_scene == null:
		return
	
	# Only create pool if it doesn't exist
	if _rock_pool.size() > 0:
		return
	
	for i in range(rock_pool_size):
		var n := rock_scene.instantiate()
		var rock := n as OrbFallingRock
		if rock == null:
			n.queue_free()
			continue
		
		get_tree().current_scene.add_child(rock)
		rock.deactivate()  # Start inactive
		_rock_pool.append(rock)
	
	pass

# ✅ Get an inactive rock from pool
func _get_pooled_rock() -> OrbFallingRock:
	for rock in _rock_pool:
		if rock != null and is_instance_valid(rock) and not rock.is_active():
			return rock
	return null

func _spawn_rock() -> void:
	if rock_scene == null or _orb == null:
		return
	
	# ✅ Limit max active rocks
	if _active_rocks.size() >= max_active_rocks:
		return
	
	# ✅ Get rock from pool instead of instantiating
	var rock: OrbFallingRock = _get_pooled_rock()
	if rock == null:
		return  # No available rocks in pool
	
	# ✅ Calculate spawn position with player lane targeting
	var rx: float = _calculate_rock_spawn_x()
	var ry: float = _orb.global_position.y + rock_spawn_y_offset
	rock.global_position = Vector2(rx, ry)
	
	# ✅ Debug: Show rock spawn location relative to orb (disabled for performance)
	# var orb_y: float = _orb.global_position.y
	# var distance_above: float = orb_y - ry
	# print("[OrbFlight] Rock spawn debug:")
	# print("  Orb Y: ", snappedf(orb_y, 0.1))
	# print("  Rock Y: ", snappedf(ry, 0.1))
	# print("  Distance above orb: ", snappedf(distance_above, 0.1), " (configured: ", rock_spawn_y_offset, ")")
	# print("  Expected distance: ", snappedf(-rock_spawn_y_offset, 0.1))
	
	# ✅ Configure and activate rock
	# ⚡ OPTIMIZATION: Pass cached health to avoid node lookups on collision
	rock.configure(_player, rock_fall_speed, rock_damage, _orb, _health)
	
	# ✅ Track active rock
	_active_rocks.append(rock)

# ⚡ OPTIMIZATION: Simplified rock spawn calculation (1 random call instead of 4)
func _calculate_rock_spawn_x() -> float:
	if _orb == null:
		# Fallback: random spawn if no orb
		var spawn_width: float = lane_half_width if match_rock_spawn_to_lane else rock_spawn_half_width
		return _start_pos.x + randf_range(-spawn_width, spawn_width)
	
	var orb_x: float = _orb.global_position.x
	var rand: float = randf()  # Single random number for everything
	
	if rand < player_lane_target_chance:
		# 60% chance: Spawn near the orb's current X position (player lane)
		# Use normalized rand value to pick position within lane
		var norm: float = rand / player_lane_target_chance  # 0.0 to 1.0
		return orb_x - player_lane_spread + (norm * player_lane_spread * 2.0)
	else:
		# 40% chance: Spawn OUTSIDE player lane
		var spawn_width: float = lane_half_width if match_rock_spawn_to_lane else rock_spawn_half_width
		var norm: float = (rand - player_lane_target_chance) / (1.0 - player_lane_target_chance)  # 0.0 to 1.0
		
		# Use norm to decide left (0.0-0.5) or right (0.5-1.0)
		if norm < 0.5:
			# Left side
			var min_x: float = _start_pos.x - spawn_width
			var max_x: float = orb_x - player_lane_spread - outside_lane_distance
			if max_x > min_x:
				return min_x + (norm * 2.0) * (max_x - min_x)
			return min_x
		else:
			# Right side
			var min_x: float = orb_x + player_lane_spread + outside_lane_distance
			var max_x: float = _start_pos.x + spawn_width
			if max_x > min_x:
				return min_x + ((norm - 0.5) * 2.0) * (max_x - min_x)
			return max_x


func _cleanup_orb_and_rocks() -> void:
	if _orb != null and is_instance_valid(_orb):
		_orb.queue_free()
	_orb = null
	_orb_camera = null
	_cleanup_rocks_only()

# ✅ Cleanup pool when controller is destroyed
func _exit_tree() -> void:
	# Deactivate all active rocks
	_cleanup_rocks_only()
	
	# Free all pooled rocks
	for rock in _rock_pool:
		if rock != null and is_instance_valid(rock):
			rock.queue_free()
	_rock_pool.clear()


func _cleanup_rocks_only() -> void:
	# ✅ Deactivate all active rocks (return to pool)
	for rock in _active_rocks:
		if rock != null and is_instance_valid(rock):
			var r := rock as OrbFallingRock
			if r != null:
				r.deactivate()
	_active_rocks.clear()


func _cleanup_distant_rocks() -> void:
	# ⚡ OPTIMIZATION: Simplified cleanup - trust pool system (no validity/type checks)
	if _orb == null:
		return
	
	var cleanup_y: float = _orb.global_position.y + rock_cleanup_distance
	
	# Iterate backwards so we can remove while iterating
	var i: int = _active_rocks.size() - 1
	while i >= 0:
		var rock: OrbFallingRock = _active_rocks[i]
		
		# Check if rock is no longer active (hit something or timed out) or fell too far
		if not rock.is_active() or rock.global_position.y > cleanup_y:
			rock.deactivate()
			_active_rocks.remove_at(i)
		
		i -= 1


func _handle_death_during_flight() -> void:
	# ✅ Handle player death during orb flight
	pass
	
	# Stop spawning new rocks
	_stop_rocks = true
	
	# Cleanup existing rocks immediately
	_cleanup_rocks_only()
	
	# Make orb invisible (simulate explosion/disappear)
	if _orb != null and is_instance_valid(_orb):
		_orb.visible = false
	
	# ✅ Keep camera on orb, continue panning up
	# The camera will stay with the orb position and keep moving up
	# until the death screen eventually shows
	
	# DON'T restore player camera yet - let it keep panning
	# DON'T make player visible yet - wait for death screen
	# DON'T restore collisions yet
	
	# Update player position to orb location (for when death screen shows)
	if _player != null and is_instance_valid(_player) and _orb != null and is_instance_valid(_orb):
		_player.global_position = _orb.global_position
	
	# Mark as finishing to stop normal flight logic
	_finishing = true
	_finish_state = FinishState.NONE
	
	# Continue panning up with invisible orb for cinematic death
	# The death screen will eventually take over
	# After a delay, cleanup and restore
	await get_tree().create_timer(2.0).timeout
	
	# Now cleanup everything
	_restore_orb_collision_if_needed()
	_restore_player_camera()
	_restore_player_collisions()
	
	if _orb != null and is_instance_valid(_orb):
		_orb.queue_free()
	_orb = null
	_orb_camera = null
	
	_running = false
	_finishing = false
	
	flight_cancelled.emit()
	queue_free()

func _lock_player(locked: bool) -> void:
	if _player == null:
		return
	if _player.has_method("set_input_locked"):
		_player.call("set_input_locked", locked)
		return
	if "input_locked" in _player:
		_player.set("input_locked", locked)


func _set_player_visible(v: bool) -> void:
	if _player == null:
		return
	_player.visible = v


func _disable_player_collisions() -> void:
	# Disable player's collision layers to prevent hazard damage during flight
	if _player == null or not is_instance_valid(_player):
		return
	if not (_player is CharacterBody2D or _player is CollisionObject2D):
		return
	
	_player_collision_layer = _player.collision_layer
	_player_collision_mask = _player.collision_mask
	_player_collision_cached = true
	
	_player.set_collision_layer(0)
	_player.set_collision_mask(0)
	pass


func _restore_player_collisions() -> void:
	if not _player_collision_cached:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if not (_player is CharacterBody2D or _player is CollisionObject2D):
		return
	
	_player.set_collision_layer(_player_collision_layer)
	_player.set_collision_mask(_player_collision_mask)
	_player_collision_cached = false
	pass


# -----------------------------
# Camera helpers
# -----------------------------
func _switch_to_orb_camera() -> void:
	if _player_camera != null and is_instance_valid(_player_camera):
		_player_camera.enabled = false
		if snap_camera_on_switch:
			_player_camera.reset_smoothing()

	if _orb_camera != null and is_instance_valid(_orb_camera):
		# ✅ Apply camera offset to show orb lower in view
		_orb_camera.offset = Vector2(0, orb_camera_offset_y)
		_orb_camera.enabled = true
		if snap_camera_on_switch:
			_orb_camera.reset_smoothing()


func _restore_player_camera() -> void:
	if _orb_camera != null and is_instance_valid(_orb_camera):
		# ✅ Reset camera offset when disabling
		_orb_camera.offset = Vector2.ZERO
		_orb_camera.enabled = false
		if snap_camera_on_switch:
			_orb_camera.reset_smoothing()

	if _player_camera != null and is_instance_valid(_player_camera):
		_player_camera.enabled = _player_camera_was_enabled
		if snap_camera_on_switch:
			_player_camera.reset_smoothing()


# -----------------------------
# ✅ Collision cache/disable (prevents sticking on platforms)
# -----------------------------
func _cache_and_disable_orb_collisions() -> void:
	if _orb == null or not is_instance_valid(_orb):
		return
	if _orb_collision_cached:
		return

	_orb_collision_cache.clear()
	_cache_collision_objects_recursive(_orb)

	for entry in _orb_collision_cache:
		var co: CollisionObject2D = entry[0]
		if co != null and is_instance_valid(co):
			co.collision_layer = 0
			co.collision_mask = 0

	_orb_collision_cached = true


func _restore_orb_collision_if_needed() -> void:
	if not _orb_collision_cached:
		return

	for entry in _orb_collision_cache:
		var co: CollisionObject2D = entry[0]
		var layer: int = entry[1]
		var mask: int = entry[2]
		if co != null and is_instance_valid(co):
			co.collision_layer = layer
			co.collision_mask = mask

	# Restore CharacterBody2D collision if needed (though orb is deleted anyway)
	if _orb != null and is_instance_valid(_orb) and _orb is CharacterBody2D:
		if _orb_collision_cache.size() > 0:
			var first_entry = _orb_collision_cache[0]
			if first_entry[0] == _orb:
				_orb.set_collision_layer(first_entry[1])
				_orb.set_collision_mask(first_entry[2])

	_orb_collision_cache.clear()
	_orb_collision_cached = false


func _cache_collision_objects_recursive(n: Node) -> void:
	var co := n as CollisionObject2D
	if co != null:
		_orb_collision_cache.append([co, co.collision_layer, co.collision_mask])

	for c: Node in n.get_children():
		_cache_collision_objects_recursive(c)


func _monitor_performance(delta: float) -> void:
	# Track frame times
	_frame_times.append(delta)
	if _frame_times.size() > _max_frame_samples:
		_frame_times.pop_front()
	
	# Calculate FPS from delta
	var current_fps: float = 1.0 / delta if delta > 0.0 else 60.0
	
	# Check if we should warn about FPS drop
	var time_now: float = Time.get_ticks_msec() / 1000.0
	if current_fps < fps_warn_threshold and (time_now - _last_fps_warning) > _fps_warning_cooldown:
		_last_fps_warning = time_now
		
		# Calculate average over last N frames
		var avg_delta: float = 0.0
		for ft in _frame_times:
			avg_delta += ft
		avg_delta /= float(_frame_times.size())
		var _avg_fps: float = 1.0 / avg_delta if avg_delta > 0.0 else 60.0
		
		# Check for invalid rocks in array
		var invalid_rocks: int = 0
		for rock in _active_rocks:
			if rock == null or not is_instance_valid(rock):
				invalid_rocks += 1
		if invalid_rocks > 0:
			pass
		
		pass
