# res://scripts/FloorProgressionController.gd
extends Node
class_name FloorProgressionController

signal active_floor_changed(floor_number: int)
signal floor_unlocked(floor_index: int)
signal floor_status_changed(floor_number: int, enemies_left: int, floor_complete: bool)
signal chest_opened(floor_number: int)

@export var player_path: NodePath = ^"../Player"
@export var encounter_controller_path: NodePath = ^"../EncounterController"
@export var rising_hazard_path: NodePath = ^"../RisingHazard"
@export var steam_elevator_path: NodePath = ^"../Arena/Geometry/SteamElevator"

@export var gate_paths: Array[NodePath] = [
	^"../Arena/Ceilings/CeilingGate_F1",
	^"../Arena/Ceilings/CeilingGate_F2",
	^"../Arena/Ceilings/CeilingGate_F3",
	^"../Arena/Ceilings/CeilingGate_F4",
]

@export var floor_enemy_groups: Array[StringName] = [
	&"floor1_enemies",
	&"floor2_enemies",
	&"floor3_enemies",
	&"floor4_enemies",
]

@export_group("Floor Detection")
@export_enum("Vertical (Y-axis)", "Horizontal (X-axis)") var floor_progression_mode: int = 0  # 0 = vertical (World2), 1 = horizontal (World3)
@export var derive_floor_ceiling_y_from_gates: bool = true
@export var gate_ceiling_y_offset: float = 0.0 # tweak if your gate sprite isn't exactly the ceiling line
@export var gate_wall_x_offset: float = 0.0 # For horizontal mode: offset from gate X position

var _derived_floor_ceiling_y: PackedFloat32Array = PackedFloat32Array()
var _derived_floor_wall_x: PackedFloat32Array = PackedFloat32Array()

@export var floor_ceiling_y: PackedFloat32Array = PackedFloat32Array([200.0, -900.0, -1925.0, -2800.0])
@export var floor_wall_x: PackedFloat32Array = PackedFloat32Array([3000.0, 6000.0, 9000.0, 12000.0])  # For horizontal mode (World3)
@export var boss_start_y: float = -2900.0
@export var boss_start_x: float = 15000.0  # For horizontal mode (World3)
@export var max_floor_number: int = 5

# -----------------------------
# Reward chest + Dice UI
# -----------------------------
@export var chest_scene: PackedScene
@export var dice_choice_ui_path: NodePath = ^"../UI/DiceModifierChoice"

@export var chest_spawn_paths: Array[NodePath] = [
	^"../Arena/ChestSpawns/ChestSpawn_F1",
	^"../Arena/ChestSpawns/ChestSpawn_F2",
	^"../Arena/ChestSpawns/ChestSpawn_F3",
	^"../Arena/ChestSpawns/ChestSpawn_F4",
]
@export var chest_spawn_fallback_path: NodePath = ^"../Arena/ChestSpawns/ChestSpawn_Default"

# -----------------------------
# World2 Doorways (optional)
# -----------------------------
@export_group("World2 Doorways")
@export var enable_world2_doors: bool = false

# These are AnimatedSprite2D nodes in your World2 tree:
# Arena2/Doorways/Floor1Door
# Arena2/Doorways/Floor2Door
@export var floor1_door_path: NodePath = NodePath()
@export var floor2_door_path: NodePath = NodePath()

# Input action used to interact with doors
@export var input_interact: StringName = &"interact"

# How close player must be to interact (no Area2D required)
@export_range(8.0, 256.0, 1.0) var door_interact_radius: float = 48.0

# Door animation names (AnimatedSprite2D animations)
@export var door_anim_closed: StringName = &"closed"
@export var door_anim_opening: StringName = &"opening"
@export var door_anim_open: StringName = &"open"

# Where on the door we measure distance (relative to the door node)
@export var door1_interact_offset: Vector2 = Vector2(0.0, 24.0) # move point DOWN
@export var door2_interact_offset: Vector2 = Vector2(0.0, 24.0)

# After Floor2Door opening completes, wait this long before spawning player
@export_range(0.0, 3.0, 0.05) var floor2_spawn_delay: float = 1.0

# Where to spawn relative to Floor2Door when arriving
@export var floor2_spawn_offset: Vector2 = Vector2(0.0, 10.0)

# If true, hide doors until unlocked (optional)
@export var door1_hide_until_unlocked: bool = false

# -----------------------------
# World3 Simple Teleport (optional)
# -----------------------------
@export_group("World3 Simple Teleport")
@export var enable_world3_teleport: bool = false

# Sprite to interact with (e.g., Sadad1 entrance)
@export var teleport_entrance_path: NodePath = NodePath()

# Where to teleport player (e.g., PlayerSpawn marker)
@export var teleport_destination_path: NodePath = NodePath()

# Interaction distance
@export_range(8.0, 256.0, 1.0) var teleport_interact_radius: float = 96.0

# Where on the entrance sprite we measure distance (relative to sprite)
@export var teleport_entrance_offset: Vector2 = Vector2(0.0, 0.0)

# Optional: only allow teleport after certain floor is unlocked
@export var teleport_requires_floor_unlocked: int = 0  # 0 = always available, 1-4 = requires that floor cleared

# Fade effect settings
@export var teleport_fade_rect_path: NodePath = NodePath("../UI/ScreenRoot/HUDRoot/TeleportFade")
@export var teleport_fade_out_time: float = 0.4
@export var teleport_camera_settle_time: float = 0.6  # Wait for camera to finish moving before fade-in
@export var teleport_fade_in_time: float = 0.5

# -----------------------------
# World2 Orb Flight (LightBeamStation -> OrbFlightController)
# -----------------------------
@export_group("World2 Orb Flight")
@export var enable_orb_flight: bool = true

# LightBeamStation node in World2
@export var light_beam_station_path: NodePath = ^"../Arena2/LightBeamStation"

# Marker2D on Floor 3 where player appears when flight completes
@export var orb_target_spawn_path: NodePath = ^"../Arena2/Spawns/Floor3/PlayerSpawn"

# PackedScenes
@export var orb_scene: PackedScene        # OrbLight.tscn
@export var rock_scene: PackedScene       # OrbFallingRock.tscn

# Optional tuning passthrough (defaults match OrbFlightController)
@export var orb_flight_speed_y: float = 520.0
@export var orb_lane_half_width: float = 360.0
@export var orb_move_speed_x: float = 600.0
@export var orb_rock_spawn_interval: float = 0.45
@export var orb_rock_spawn_half_width: float = 420.0
@export var orb_rock_spawn_y_offset: float = -1000.0  # ✅ Spawn rocks above orb (adjust this value, not OrbFlightController!)
@export var orb_rock_fall_speed: float = 900.0
@export var orb_rock_damage: int = 10
@export var orb_match_rock_spawn_to_lane: bool = true # match rock spawn width to lane width
@export var orb_rock_cleanup_distance: float = 1200.0 # cleanup rocks this far below orb
@export var orb_rock_cleanup_interval: float = 0.5 # how often to check for cleanup (performance)
@export var orb_max_active_rocks: int = 20 # prevent rock spam (performance)
@export var orb_end_lockout_seconds: float = 0.15
@export var orb_finish_y_padding: float = 0.0 # trigger autopilot this many pixels BEFORE reaching target
@export var orb_autopilot_speed: float = 1800.0 # speed during autopilot glide to spawn
@export var orb_autopilot_arc_height: float = 800.0 # height of dramatic arc entrance
@export var orb_autopilot_use_arc: bool = true # enable cinematic arc entrance

var _light_beam_station: LightBeamStation = null
var _orb_flight: OrbFlightController = null
var _orb_flight_completed_once: bool = false

# -----------------------------
# Platform unlocks (after floor cleared + modifier chosen)
# -----------------------------
@export_group("Platform Unlocks")
@export var hide_platforms_on_ready: bool = true

@export_group("Unlock after Floor 1 + Dice Choice")
@export var unlock_floor_1_platforms: Array[NodePath] = [] # Platform8, Platform9

@export_group("Unlock after Floor 2 + Dice Choice")
@export var unlock_floor_2_platforms: Array[NodePath] = [] # Platform14

@export_group("Unlock after Floor 3 + Dice Choice")
@export var unlock_floor_3_platforms: Array[NodePath] = [] # Platform23

@export_group("Unlock after Floor 4 + Dice Choice")
@export var unlock_floor_4_platforms: Array[NodePath] = [] # Platform20, Platform24

# -----------------------------
# Platform unlock visuals
# -----------------------------
@export var platform_fade_in_time: float = 0.25
@export var platform_fade_in_stagger: float = 0.06
@export var platform_fade_in_ease_out: bool = true
@export var platform_enable_collision_immediately: bool = true

# -----------------------------
# Legacy arrays (kept for compatibility)
# -----------------------------
@export var unlock_after_floor_1: Array[NodePath] = [
	^"../Arena/Platform8",
	^"../Arena/Platform9",
]
@export var unlock_after_floor_2: Array[NodePath] = [
	^"../Arena/Platform14",
]
@export var unlock_after_floor_3: Array[NodePath] = [
	^"../Arena/Platform23",
]
@export var unlock_after_floor_4: Array[NodePath] = [
	^"../Arena/Platform20",
	^"../Arena/Platform24",
]

# Cache original collision layers/masks so we can restore
var _platform_collision_cache: Dictionary = {} # CollisionObject2D -> {"layer": int, "mask": int}

@onready var _player: Node2D = get_node_or_null(player_path) as Node2D
@onready var _encounter: Node = get_node_or_null(encounter_controller_path)
@onready var _hazard: Node = get_node_or_null(rising_hazard_path)

@export var floor_band_padding: float = 40.0

var _current_floor_number: int = 1
var _last_enemies_left: int = -1
var _last_floor_complete: bool = false

var _last_synced_run_floor: int = -1
var _last_synced_run_world: int = -1

var _gates: Array[Node] = []
var _unlocked: PackedByteArray = PackedByteArray()
var _boss_started: bool = false

var _pending_gate_open: PackedByteArray = PackedByteArray()
var _pending_floor_to_open: int = -1

var _chest_spawned: PackedByteArray = PackedByteArray()

# ✅ Track which floors have spawned enemies (to prevent checking unspawned floors)
var _floor_spawned: PackedByteArray = PackedByteArray([1, 0, 0, 0])  # Floor 1 spawns on ready

var _last_floor_number: int = -1

# -----------------------------
# World2 door runtime
# -----------------------------
var _door1: AnimatedSprite2D = null
var _door2: AnimatedSprite2D = null

var _door1_unlocked: bool = false
var _door_transition_active: bool = false

# -----------------------------
# World3 teleport runtime
# -----------------------------
var _teleport_entrance: Node2D = null
var _teleport_entrance_area: Area2D = null  # Optional InteractArea child
var _teleport_destination: Node2D = null
var _teleport_fade_rect: ColorRect = null
var _teleport_active: bool = false
var _player_in_teleport_zone: bool = false

# -----------------------------
# World3 SteamElevator runtime
# -----------------------------
var _steam_elevator: Node2D = null
var _elevator_teleport_completed: bool = false

func _ready() -> void:
	add_to_group(&"floors")

	_gates.clear()
	for p: NodePath in gate_paths:
		_gates.append(get_node_or_null(p))

	_unlocked.resize(_gates.size())
	_pending_gate_open.resize(_gates.size())
	_chest_spawned.resize(_gates.size())

	for i in range(_gates.size()):
		_unlocked[i] = 0
		_pending_gate_open[i] = 0
		_chest_spawned[i] = 0
		_set_gate_open(i, false)

	_build_floor_ceiling_y_from_gates()

	if hide_platforms_on_ready:
		_prepare_and_hide_unlock_platforms()

	var dice_ui: Node = get_node_or_null(dice_choice_ui_path)
	if dice_ui != null and dice_ui.has_signal("modifier_chosen"):
		if not dice_ui.modifier_chosen.is_connected(_on_modifier_chosen):
			dice_ui.modifier_chosen.connect(_on_modifier_chosen)
			#print("[Floors] Connected to DiceModifierChoice.modifier_chosen")
	else:
		push_warning("[Floors] DiceModifierChoice not found or missing modifier_chosen signal. Path: %s" % [String(dice_choice_ui_path)])

	# World2 door init (optional)
	_setup_world2_doors()

	# World2 orb flight init (optional)
	_setup_orb_flight()

	# World3 teleport init (optional)
	_setup_world3_teleport()
	
	# World3 SteamElevator connection (for boss activation)
	_setup_steam_elevator()

	#print("[Floors] Ready. Groups=", floor_enemy_groups, " Gates=", gate_paths)

func _setup_orb_flight() -> void:
	_light_beam_station = null
	_orb_flight = null
	_orb_flight_completed_once = false

	if not enable_orb_flight:
		return

	_light_beam_station = get_node_or_null(light_beam_station_path) as LightBeamStation
	if _light_beam_station == null:
		push_warning("[Floors] OrbFlight enabled but LightBeamStation path invalid: %s" % String(light_beam_station_path))
		return

	# Start hidden - only show after Floor 2 modifier is chosen
	_light_beam_station.visible = false
	if _light_beam_station.has_method("set_enabled"):
		_light_beam_station.set_enabled(false)

	if not _light_beam_station.activated.is_connected(_on_light_beam_station_activated):
		_light_beam_station.activated.connect(_on_light_beam_station_activated)

func _on_light_beam_station_activated(_station: LightBeamStation, activator: Node2D) -> void:
	if not enable_orb_flight:
		return
	if _orb_flight != null and is_instance_valid(_orb_flight):
		return # already running
	if _orb_flight_completed_once:
		return # one-time sequence

	# Gate: only allow after Floor 2 cleared (index 1) AND player is actually on floor 2
	if _current_floor_number != 2:
		return
	if _unlocked.size() >= 2 and _unlocked[1] == 0:
		return

	if activator == null or not is_instance_valid(activator):
		return
	if activator != _player:
		# safety: we only support the main player
		return

	if orb_scene == null:
		push_warning("[Floors] OrbFlight: orb_scene is not assigned (OrbLight.tscn).")
		return
	if rock_scene == null:
		push_warning("[Floors] OrbFlight: rock_scene is not assigned (OrbFallingRock.tscn).")
		return

	# Create controller and configure
	var c := OrbFlightController.new()
	c.orb_scene = orb_scene
	c.rock_scene = rock_scene

	c.flight_speed_y = orb_flight_speed_y
	c.orb_move_speed_x = orb_move_speed_x
	c.lane_half_width = orb_lane_half_width
	c.rock_spawn_interval = orb_rock_spawn_interval
	c.rock_spawn_half_width = orb_rock_spawn_half_width
	c.rock_spawn_y_offset = orb_rock_spawn_y_offset
	c.rock_fall_speed = orb_rock_fall_speed
	c.rock_damage = orb_rock_damage
	c.match_rock_spawn_to_lane = orb_match_rock_spawn_to_lane
	c.rock_cleanup_distance = orb_rock_cleanup_distance
	c.rock_cleanup_interval = orb_rock_cleanup_interval
	c.max_active_rocks = orb_max_active_rocks
	c.end_lockout_seconds = orb_end_lockout_seconds
	c.finish_y_padding = orb_finish_y_padding
	c.autopilot_speed = orb_autopilot_speed
	c.autopilot_arc_height = orb_autopilot_arc_height
	c.autopilot_use_arc = orb_autopilot_use_arc

	# IMPORTANT: target_spawn_path is resolved relative to the controller node.
	# We add controller to current_scene root, so a relative path like "Arena2/Spawns/Floor3/PlayerSpawn" works.
	c.target_spawn_path = orb_target_spawn_path

	# Add to scene and start
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		c.queue_free()
		return

	tree.current_scene.add_child(c)
	_orb_flight = c

	if not c.flight_completed.is_connected(_on_orb_flight_completed):
		c.flight_completed.connect(_on_orb_flight_completed)
	if not c.flight_cancelled.is_connected(_on_orb_flight_cancelled):
		c.flight_cancelled.connect(_on_orb_flight_cancelled)

	# Prevent repeat presses during startup
	if _light_beam_station != null and is_instance_valid(_light_beam_station):
		_light_beam_station.set_enabled(false)

	c.start_flight(_player)

func _on_orb_flight_completed() -> void:
	_orb_flight_completed_once = true

	# Keep station disabled after completion (one-shot experience)
	_orb_flight = null

func _on_orb_flight_cancelled() -> void:
	# If cancelled, allow retry.
	_orb_flight = null
	if _light_beam_station != null and is_instance_valid(_light_beam_station):
		_light_beam_station.set_enabled(true)

func _setup_world2_doors() -> void:
	_door1 = null
	_door2 = null
	_door1_unlocked = false
	_door_transition_active = false

	if not enable_world2_doors:
		return

	if floor1_door_path != NodePath():
		_door1 = get_node_or_null(floor1_door_path) as AnimatedSprite2D
	if floor2_door_path != NodePath():
		_door2 = get_node_or_null(floor2_door_path) as AnimatedSprite2D

	if _door1 == null:
		push_warning("[Floors] World2 doors enabled but Floor1Door path invalid.")
	if _door2 == null:
		push_warning("[Floors] World2 doors enabled but Floor2Door path invalid.")

	# Force correct default visuals (prevents "starts open")
	_force_door_state(_door1, door_anim_closed)
	_force_door_state(_door2, door_anim_closed)

	# Optional: hide door1 until unlocked
	if _door1 != null and door1_hide_until_unlocked:
		_door1.visible = false

func _force_door_state(door: AnimatedSprite2D, anim_name: StringName) -> void:
	if door == null:
		return
	var a := String(anim_name)
	if a == "":
		return
	door.stop()
	door.animation = a
	door.frame = 0
	# Ensure opening doesn't loop (safe even if already configured)
	if door.sprite_frames != null and door.sprite_frames.has_animation(String(door_anim_opening)):
		door.sprite_frames.set_animation_loop(String(door_anim_opening), false)

func _play_door_anim(door: AnimatedSprite2D, anim_name: StringName) -> void:
	if door == null:
		return
	var a := String(anim_name)
	if a == "":
		return
	door.play(a)

func _sync_runstate_floor() -> void:
	if RunStateSingleton == null:
		return
	if not ("floor_index" in RunStateSingleton):
		return
	if not ("world_index" in RunStateSingleton):
		return

	var rs_world: int = int(RunStateSingleton.world_index)
	var rs_floor: int = int(RunStateSingleton.floor_index)

	if rs_world != _last_synced_run_world:
		_last_synced_run_world = rs_world
		_last_synced_run_floor = -1

	if _current_floor_number != rs_floor and _current_floor_number != _last_synced_run_floor:
		RunStateSingleton.floor_index = _current_floor_number
		_last_synced_run_floor = _current_floor_number

func get_current_floor_number() -> int:
	return _current_floor_number

func get_enemies_left_current_floor() -> int:
	if floor_enemy_groups.is_empty():
		return 0
	var idx: int = _current_floor_number - 1
	if idx < 0 or idx >= floor_enemy_groups.size():
		return 0
	return get_tree().get_nodes_in_group(floor_enemy_groups[idx]).size()

func is_current_floor_complete() -> bool:
	if floor_enemy_groups.is_empty():
		return true
	var idx: int = _current_floor_number - 1
	if idx < 0 or idx >= floor_enemy_groups.size():
		return true
	return _unlocked[idx] == 1

func is_floor_complete(floor_index: int) -> bool:
	if floor_enemy_groups.is_empty():
		return true
	if floor_index < 0 or floor_index >= _unlocked.size():
		return false
	return _unlocked[floor_index] == 1

func _get_floor_thresholds() -> PackedFloat32Array:
	if derive_floor_ceiling_y_from_gates and _derived_floor_ceiling_y.size() > 0:
		return _derived_floor_ceiling_y
	return floor_ceiling_y

func _get_floor_thresholds_x() -> PackedFloat32Array:
	if derive_floor_ceiling_y_from_gates and _derived_floor_wall_x.size() > 0:
		return _derived_floor_wall_x
	return floor_wall_x

func _update_current_floor_from_player() -> void:
	if _player == null:
		return

	var floor_num: int = 1
	
	if floor_progression_mode == 1:  # Horizontal (X-axis) mode for World3
		var x: float = _player.global_position.x
		var thresholds: PackedFloat32Array = _get_floor_thresholds_x()
		
		for i in range(thresholds.size()):
			if x >= float(thresholds[i]) - floor_band_padding:
				floor_num = i + 2
	else:  # Vertical (Y-axis) mode for World2
		var y: float = _player.global_position.y
		var thresholds: PackedFloat32Array = _get_floor_thresholds()
		
		for i in range(thresholds.size()):
			if y <= float(thresholds[i]) - floor_band_padding:
				floor_num = i + 2

	var inferred_max: int = _get_floor_thresholds().size() + 1
	var max_f: int = max_floor_number if max_floor_number > 0 else inferred_max
	_current_floor_number = clampi(floor_num, 1, max_f)

	if _current_floor_number != _last_floor_number:
		_last_floor_number = _current_floor_number
		active_floor_changed.emit(_current_floor_number)

func _emit_floor_status_if_changed() -> void:
	var enemies_left: int = get_enemies_left_current_floor()
	var complete: bool = is_current_floor_complete()
	if enemies_left == _last_enemies_left and complete == _last_floor_complete:
		return
	_last_enemies_left = enemies_left
	_last_floor_complete = complete
	floor_status_changed.emit(_current_floor_number, enemies_left, complete)

func _process(_delta: float) -> void:
	var count: int = mini(_gates.size(), floor_enemy_groups.size())
	for i in range(count):
		if _unlocked[i] == 1:
			continue
		# ✅ CRITICAL FIX: Only check floors that have actually spawned enemies
		if i >= _floor_spawned.size() or _floor_spawned[i] == 0:
			continue
		if _is_floor_cleared_by_group(floor_enemy_groups[i]):
			_on_floor_cleared(i)

	# ✅ CRITICAL: Don't start boss until Floor 4 is cleared AND modifier is chosen
	# Floor 4 is index 3, so check if _unlocked[3] == 1
	var floor4_unlocked: bool = (_unlocked.size() > 3 and _unlocked[3] == 1)
	
	# Check boss start based on progression mode
	# World3 (horizontal mode): Boss starts via SteamElevator teleport_completed signal (after 1 second delay)
	# World2 (vertical mode): Boss starts when player crosses Y threshold
	if floor_progression_mode == 0:
		# Vertical mode (World2): Position-based trigger
		var boss_triggered: bool = _player.global_position.y <= boss_start_y
		
		if not _boss_started and _player != null and boss_triggered and floor4_unlocked:
			_boss_started = true
			pass
			if _encounter == null:
				pass
			elif not _encounter.has_method("begin_boss_encounter"):
				pass
			else:
				pass
				_encounter.call("begin_boss_encounter")
				pass
	# Horizontal mode (World3): Boss starts from _on_steam_elevator_teleport_completed()
	# No position check needed here

	_update_current_floor_from_player()
	_sync_runstate_floor()
	_emit_floor_status_if_changed()

	# World2 door interaction (only when enabled)
	_update_world2_door_interaction()

	# World3 teleport interaction (only when enabled)
	_update_world3_teleport_interaction()

func _update_world2_door_interaction() -> void:
	if not enable_world2_doors:
		return
	if _door_transition_active:
		return
	if _player == null:
		return
	if not _door1_unlocked:
		return
	if _door1 == null:
		return

	# Only interact from Floor 1 -> Floor 2
	if _current_floor_number != 1:
		return

	if not Input.is_action_just_pressed(input_interact):
		return

	var door_point: Vector2 = _door1.global_position + door1_interact_offset
	var d: float = _player.global_position.distance_to(door_point)
	if d > door_interact_radius:
		return

	# Trigger transition
	_start_floor1_to_floor2_transition()

func _start_floor1_to_floor2_transition() -> void:
	if _door_transition_active:
		return
	_door_transition_active = true

	pass

	# Lock input
	_set_player_input_locked(true)

	# Play Door1 opening (then open)
	_force_door_state(_door1, door_anim_closed)
	_play_door_anim(_door1, door_anim_opening)

	# Use async flow via deferred call so we don't block frame
	call_deferred("_door_transition_sequence")

func _door_transition_sequence() -> void:
	# Door1 opening finish
	if _door1 != null:
		await _door1.animation_finished
		_force_door_state(_door1, door_anim_open)

	# Hide player during transition
	_set_player_visible(false)

	# Floor2 door should play opening, then open, then wait, then spawn player
	if _door2 != null:
		_force_door_state(_door2, door_anim_closed)
		_play_door_anim(_door2, door_anim_opening)
		await _door2.animation_finished
		_force_door_state(_door2, door_anim_open)

	# Wait before spawning
	if floor2_spawn_delay > 0.0:
		await get_tree().create_timer(floor2_spawn_delay).timeout

	# Teleport/spawn player at Floor2Door + offset
	if _player != null and _door2 != null:
		_player.global_position = _door2.global_position + floor2_spawn_offset

	# CRITICAL: Force floor number to 2 after spawning at Floor2Door
	# This ensures ultimates work immediately without waiting for _update_current_floor_from_player()
	_current_floor_number = 2
	_last_floor_number = 2
	active_floor_changed.emit(2)

	_set_player_visible(true)
	_set_player_input_locked(false)

	_door_transition_active = false

func _set_player_visible(v: bool) -> void:
	if _player == null:
		return
	_player.visible = v

func _set_player_input_locked(locked: bool) -> void:
	if _player == null:
		return
	if _player.has_method("set_input_locked"):
		_player.call("set_input_locked", locked)
		return
	if "input_locked" in _player:
		_player.set("input_locked", locked)

func _is_floor_cleared_by_group(group_name: StringName) -> bool:
	return get_tree().get_nodes_in_group(group_name).is_empty()

func _set_boss_combat_paused(p: bool) -> void:
	var boss: Node = get_tree().get_first_node_in_group(&"boss")
	if boss != null and boss.has_method("set_combat_paused"):
		boss.call("set_combat_paused", p)

func _on_floor_cleared(index: int) -> void:
	_unlocked[index] = 1

	_set_boss_combat_paused(true)

	if _hazard != null and _hazard.has_method("set_paused_by_system"):
		_hazard.call("set_paused_by_system", true)

	if _hazard != null and _hazard.has_method("rise_to_ceiling_y"):
		var target_y: float = _get_floor_ceiling_y(index)
		_hazard.call("rise_to_ceiling_y", target_y, true)

	_pending_gate_open[index] = 1
	_pending_floor_to_open = index

	_spawn_reward_chest_for_floor(index)

	#print("[Floors] Floor cleared. Gate/door will open AFTER modifier. Floor=", index + 1)

func _on_modifier_chosen() -> void:
	_set_boss_combat_paused(false)

	var idx: int = _pending_floor_to_open
	if idx < 0 or idx >= _pending_gate_open.size() or _pending_gate_open[idx] == 0:
		for i in range(_pending_gate_open.size()):
			if _pending_gate_open[i] == 1:
				idx = i
				break

	if idx >= 0 and idx < _pending_gate_open.size() and _pending_gate_open[idx] == 1:
		_pending_gate_open[idx] = 0
		_pending_floor_to_open = -1

		# World1 & World2 use ceiling gates normally
		# World3 (horizontal mode): Open all gates EXCEPT Floor 3 (idx 2) - player uses cave teleport for Floor 3
		var should_open_gate: bool = true
		if floor_progression_mode == 1 and idx == 2:  # Horizontal mode + Floor 3
			should_open_gate = false
			pass
		
		if should_open_gate:
			_set_gate_open(idx, true)

		_apply_platform_unlock_for_floor(idx)
		floor_unlocked.emit(idx + 1)

		#print("[Floors] Modifier chosen → opened ceiling for Floor ", idx + 1)
		
		# ✅ NEW: Spawn next floor's enemies AFTER modifier is chosen
		# BUT: Skip Floor 5 (boss floor) - that's handled by EncounterController
		var next_floor: int = idx + 1
		if next_floor < 4:  # Only spawn floors 1-4 (indices 0-3)
			var spawner: Node = get_node_or_null("../FloorEnemySpawner")
			if spawner != null and spawner.has_method("spawn_next_floor"):
				spawner.call("spawn_next_floor", idx)
				# Mark next floor as spawned so we can check it for completion
				if next_floor < _floor_spawned.size():
					_floor_spawned[next_floor] = 1
				#print("[Floors] Called spawner.spawn_next_floor(%d), marked floor %d as spawned" % [idx, next_floor + 1])
			else:
				pass
		else:
			pass
		_unlock_platforms_for_floor(idx + 1)

		# ✅ World2: after Floor 1 modifier chosen, unlock Door1 interaction
		if enable_world2_doors and (idx == 0):
			_door1_unlocked = true
			if _door1 != null:
				if door1_hide_until_unlocked:
					_door1.visible = true
				_force_door_state(_door1, door_anim_closed)
				# Enable the InteractArea for the interaction prompt
				var interact_area: Area2D = _door1.get_node_or_null("InteractArea")
				if interact_area != null:
					interact_area.monitoring = true
					interact_area.monitorable = true
			pass

		# ✅ World2: after Floor 2 modifier chosen, enable LightBeamStation
		if enable_orb_flight and (idx == 1):
			if _light_beam_station != null and is_instance_valid(_light_beam_station):
				_light_beam_station.visible = true
				if _light_beam_station.has_method("set_enabled"):
					_light_beam_station.set_enabled(true)
				pass
		
		# ✅ World3: after Floor 3 modifier chosen, enable cave teleport InteractArea
		if enable_world3_teleport and (idx == 2):
			if _teleport_entrance_area != null and is_instance_valid(_teleport_entrance_area):
				_teleport_entrance_area.monitoring = true
				_teleport_entrance_area.monitorable = true
				pass

func _get_floor_ceiling_y(index: int) -> float:
	var thresholds: PackedFloat32Array = _get_floor_thresholds()
	if index >= 0 and index < thresholds.size():
		return float(thresholds[index])
	return 0.0

func _set_gate_open(index: int, open: bool) -> void:
	if index < 0 or index >= _gates.size():
		return
	var g: Node = _gates[index]
	if g == null:
		return
	if g.has_method("set_open"):
		g.call("set_open", open)
	else:
		if g is CollisionObject2D:
			var co := g as CollisionObject2D
			if open:
				co.set_deferred("collision_layer", 0)
				co.set_deferred("collision_mask", 0)

# -----------------------------
# Platform helpers
# -----------------------------
func _fade_in_platform_sprite(platform: Node, delay_s: float) -> void:
	if platform == null or not is_instance_valid(platform):
		return

	var spr: Sprite2D = platform.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		var ci: CanvasItem = platform as CanvasItem
		if ci == null:
			return
		ci.visible = true
		var m: Color = ci.modulate
		m.a = 0.0
		ci.modulate = m
		var tw0: Tween = create_tween()
		if platform_fade_in_ease_out:
			tw0.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw0.tween_interval(maxf(delay_s, 0.0))
		tw0.tween_property(ci, "modulate:a", 1.0, maxf(platform_fade_in_time, 0.01))
		return

	spr.visible = true
	var c: Color = spr.modulate
	c.a = 0.0
	spr.modulate = c

	var tw: Tween = create_tween()
	if platform_fade_in_ease_out:
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(delay_s, 0.0))
	tw.tween_property(spr, "modulate:a", 1.0, maxf(platform_fade_in_time, 0.01))

func _set_platform_collision_enabled(platform: Node, enabled: bool) -> void:
	if platform == null or not is_instance_valid(platform):
		return

	if platform is CollisionObject2D:
		var co := platform as CollisionObject2D
		if enabled:
			var cached: Variant = _platform_collision_cache.get(co, null)
			if cached != null:
				co.collision_layer = int(cached["layer"])
				co.collision_mask = int(cached["mask"])
		else:
			co.collision_layer = 0
			co.collision_mask = 0

	for child: Node in platform.get_children():
		if child is CollisionObject2D:
			var co2 := child as CollisionObject2D
			if enabled:
				var cached2: Variant = _platform_collision_cache.get(co2, null)
				if cached2 != null:
					co2.collision_layer = int(cached2["layer"])
					co2.collision_mask = int(cached2["mask"])
			else:
				co2.collision_layer = 0
				co2.collision_mask = 0

	for child2: Node in platform.get_children():
		var cs: CollisionShape2D = child2 as CollisionShape2D
		if cs != null:
			cs.set_deferred("disabled", not enabled)

func _set_platform_visual_enabled(platform: Node, enabled: bool) -> void:
	if platform == null or not is_instance_valid(platform):
		return
	if platform is CanvasItem:
		(platform as CanvasItem).visible = enabled
	for child: Node in platform.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = enabled

func _reveal_platforms_with_fade(paths: Array[NodePath]) -> void:
	var delay: float = 0.0
	for p: NodePath in paths:
		if p == NodePath():
			continue
		var n: Node = get_node_or_null(p)
		if n == null:
			push_warning("[Floors] Platform path not found: %s" % String(p))
			continue

		_set_platform_visual_enabled(n, true)

		if platform_enable_collision_immediately:
			_set_platform_collision_enabled(n, true)
		else:
			_set_platform_collision_enabled(n, false)

		_fade_in_platform_sprite(n, delay)

		if not platform_enable_collision_immediately:
			var t: float = maxf(delay, 0.0) + maxf(platform_fade_in_time, 0.01)
			get_tree().create_timer(t).timeout.connect(func() -> void:
				if n != null and is_instance_valid(n):
					_set_platform_collision_enabled(n, true)
			)

		delay += platform_fade_in_stagger

func _prepare_and_hide_unlock_platforms() -> void:
	_platform_collision_cache.clear()

	_cache_platforms(unlock_floor_1_platforms)
	_cache_platforms(unlock_floor_2_platforms)
	_cache_platforms(unlock_floor_3_platforms)
	_cache_platforms(unlock_floor_4_platforms)

	_cache_platforms(unlock_after_floor_1)
	_cache_platforms(unlock_after_floor_2)
	_cache_platforms(unlock_after_floor_3)
	_cache_platforms(unlock_after_floor_4)

	_set_platforms_visible(unlock_floor_1_platforms, false)
	_set_platforms_visible(unlock_floor_2_platforms, false)
	_set_platforms_visible(unlock_floor_3_platforms, false)
	_set_platforms_visible(unlock_floor_4_platforms, false)

	_set_platforms_visible(unlock_after_floor_1, false)
	_set_platforms_visible(unlock_after_floor_2, false)
	_set_platforms_visible(unlock_after_floor_3, false)
	_set_platforms_visible(unlock_after_floor_4, false)

func _unlock_platforms_for_floor(floor_number: int) -> void:
	match floor_number:
		1:
			if not unlock_floor_1_platforms.is_empty():
				_reveal_platforms_with_fade(unlock_floor_1_platforms)
			else:
				_reveal_platforms_with_fade(unlock_after_floor_1)
		2:
			if not unlock_floor_2_platforms.is_empty():
				_reveal_platforms_with_fade(unlock_floor_2_platforms)
			else:
				_reveal_platforms_with_fade(unlock_after_floor_2)
		3:
			if not unlock_floor_3_platforms.is_empty():
				_reveal_platforms_with_fade(unlock_floor_3_platforms)
			else:
				_reveal_platforms_with_fade(unlock_after_floor_3)
		4:
			if not unlock_floor_4_platforms.is_empty():
				_reveal_platforms_with_fade(unlock_floor_4_platforms)
			else:
				_reveal_platforms_with_fade(unlock_after_floor_4)
		_:
			pass

func _cache_platforms(paths: Array[NodePath]) -> void:
	for p: NodePath in paths:
		if p == NodePath():
			continue
		var n: Node = get_node_or_null(p)
		if n == null:
			push_warning("[Floors] Platform path not found: %s" % String(p))
			continue

		if n is CollisionObject2D:
			var co := n as CollisionObject2D
			if not _platform_collision_cache.has(co):
				_platform_collision_cache[co] = {"layer": co.collision_layer, "mask": co.collision_mask}

		for child: Node in n.get_children():
			if child is CollisionObject2D:
				var co2 := child as CollisionObject2D
				if not _platform_collision_cache.has(co2):
					_platform_collision_cache[co2] = {"layer": co2.collision_layer, "mask": co2.collision_mask}

func _set_platforms_visible(paths: Array[NodePath], v: bool) -> void:
	for p: NodePath in paths:
		if p == NodePath():
			continue

		var n: Node = get_node_or_null(p)
		if n == null:
			push_warning("[Floors] Platform path not found: %s (cannot toggle visibility)" % String(p))
			continue

		if n is CanvasItem:
			(n as CanvasItem).visible = v
		for child: Node in n.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = v

		if n is CollisionObject2D:
			var co := n as CollisionObject2D
			if v:
				var cached: Variant = _platform_collision_cache.get(co, null)
				if cached != null:
					co.collision_layer = int(cached["layer"])
					co.collision_mask = int(cached["mask"])
			else:
				co.collision_layer = 0
				co.collision_mask = 0

		for child2: Node in n.get_children():
			if child2 is CollisionObject2D:
				var co2 := child2 as CollisionObject2D
				if v:
					var cached2: Variant = _platform_collision_cache.get(co2, null)
					if cached2 != null:
						co2.collision_layer = int(cached2["layer"])
						co2.collision_mask = int(cached2["mask"])
				else:
					co2.collision_layer = 0
					co2.collision_mask = 0

func _apply_platform_unlock_for_floor(index_zero_based: int) -> void:
	match index_zero_based:
		0:
			_reveal_platforms_with_fade(unlock_after_floor_1)
		1:
			_reveal_platforms_with_fade(unlock_after_floor_2)
		2:
			_reveal_platforms_with_fade(unlock_after_floor_3)
		3:
			_reveal_platforms_with_fade(unlock_after_floor_4)
		_:
			pass

# -----------------------------
# Chest spawning
# -----------------------------
func _spawn_reward_chest_for_floor(floor_index_zero_based: int) -> void:
	if floor_index_zero_based < 0 or floor_index_zero_based >= _chest_spawned.size():
		return
	if _chest_spawned[floor_index_zero_based] == 1:
		return
	if chest_scene == null:
		push_warning("[Floors] chest_scene not assigned.")
		return

	var dice_ui: Node = get_node_or_null(dice_choice_ui_path)
	if dice_ui == null or not dice_ui.has_method("open_from_chest"):
		push_warning("[Floors] Dice UI missing or missing open_from_chest().")
		return

	var spawn_pos: Vector2 = _get_chest_spawn_position(floor_index_zero_based)

	var chest_node: Node = chest_scene.instantiate()
	var chest2d: Node2D = chest_node as Node2D
	if chest2d == null:
		push_warning("[Floors] chest_scene root must be Node2D/Area2D.")
		chest_node.queue_free()
		return

	get_tree().current_scene.add_child(chest2d)
	chest2d.global_position = spawn_pos

	if chest2d.has_signal("opened"):
		var floor_number: int = floor_index_zero_based + 1
		chest2d.connect("opened", Callable(self, "_on_reward_chest_opened").bind(floor_number, chest2d, dice_ui))
	else:
		push_warning("[Floors] Chest missing 'opened' signal.")
		chest2d.queue_free()
		return

	_chest_spawned[floor_index_zero_based] = 1
	#print("[Floors] Spawned reward chest for Floor ", floor_index_zero_based + 1)

func _on_reward_chest_opened(_chest: Node, floor_number: int, chest2d: Node, dice_ui: Node) -> void:
	# Emit signal for other systems (e.g., elevator platforms)
	chest_opened.emit(floor_number)
	
	if dice_ui != null and is_instance_valid(dice_ui):
		dice_ui.call("open_from_chest", floor_number, chest2d)

func _get_chest_spawn_position(floor_index_zero_based: int) -> Vector2:
	if floor_index_zero_based >= 0 and floor_index_zero_based < chest_spawn_paths.size():
		var sp: Node2D = get_node_or_null(chest_spawn_paths[floor_index_zero_based]) as Node2D
		if sp != null:
			return sp.global_position

	var fallback: Node2D = get_node_or_null(chest_spawn_fallback_path) as Node2D
	if fallback != null:
		return fallback.global_position

	if _player != null and is_instance_valid(_player):
		return _player.global_position + Vector2(0.0, 24.0)

	return Vector2.ZERO

func _build_floor_ceiling_y_from_gates() -> void:
	_derived_floor_ceiling_y = PackedFloat32Array()
	_derived_floor_wall_x = PackedFloat32Array()

	if not derive_floor_ceiling_y_from_gates:
		return

	if _gates.is_empty():
		push_warning("[Floors] derive_floor_ceiling_y_from_gates is ON but gate_paths is empty.")
		return

	# gate_paths are in order F1..F4 in your inspector, which matches your floors.
	# Each gate corresponds to the boundary ABOVE that floor (vertical) or to the RIGHT (horizontal).
	for i in range(_gates.size()):
		var g: Node = _gates[i]
		var n2d: Node2D = g as Node2D
		if n2d == null:
			push_warning("[Floors] Gate at index %d is not Node2D; cannot derive position." % i)
			continue
		
		if floor_progression_mode == 1:  # Horizontal mode (World3)
			_derived_floor_wall_x.append(n2d.global_position.x + gate_wall_x_offset)
		else:  # Vertical mode (World2)
			_derived_floor_ceiling_y.append(n2d.global_position.y + gate_ceiling_y_offset)

	# If any gates were skipped, fall back.
	if floor_progression_mode == 1 and _derived_floor_wall_x.is_empty():
		push_warning("[Floors] Failed to derive floor_wall_x from gates; using inspector floor_wall_x instead.")
	elif floor_progression_mode == 0 and _derived_floor_ceiling_y.is_empty():
		push_warning("[Floors] Failed to derive floor_ceiling_y from gates; using inspector floor_ceiling_y instead.")

# -----------------------------
# World3 Simple Teleport System
# -----------------------------
func _setup_world3_teleport() -> void:
	_teleport_entrance = null
	_teleport_entrance_area = null
	_teleport_destination = null
	_teleport_fade_rect = null
	_teleport_active = false
	_player_in_teleport_zone = false

	if not enable_world3_teleport:
		return

	if teleport_entrance_path != NodePath():
		_teleport_entrance = get_node_or_null(teleport_entrance_path) as Node2D
	if teleport_destination_path != NodePath():
		_teleport_destination = get_node_or_null(teleport_destination_path) as Node2D
	if teleport_fade_rect_path != NodePath():
		_teleport_fade_rect = get_node_or_null(teleport_fade_rect_path) as ColorRect

	if _teleport_entrance == null:
		push_warning("[Floors] World3 teleport enabled but entrance path invalid: %s" % String(teleport_entrance_path))
		return
	if _teleport_destination == null:
		push_warning("[Floors] World3 teleport enabled but destination path invalid: %s" % String(teleport_destination_path))
		return
	if _teleport_fade_rect == null:
		push_warning("[Floors] World3 teleport fade rect not found at: %s" % String(teleport_fade_rect_path))

	# Check for optional InteractArea child (for visual collision zone editing)
	if _teleport_entrance.has_node("InteractArea"):
		_teleport_entrance_area = _teleport_entrance.get_node("InteractArea") as Area2D
		if _teleport_entrance_area != null:
			# Start disabled - will be enabled after Floor 3 is cleared
			_teleport_entrance_area.monitoring = false
			_teleport_entrance_area.monitorable = false
			_teleport_entrance_area.body_entered.connect(_on_teleport_area_entered)
			_teleport_entrance_area.body_exited.connect(_on_teleport_area_exited)
			pass
		else:
			pass

func _setup_steam_elevator() -> void:
	"""Connect to SteamElevator's teleport_completed signal for boss activation"""
	_steam_elevator = null
	_elevator_teleport_completed = false
	
	if steam_elevator_path == NodePath():
		pass
		return
	
	_steam_elevator = get_node_or_null(steam_elevator_path) as Node2D
	if _steam_elevator == null:
		# Only warn in World3 (horizontal mode) where SteamElevator is expected
		if floor_progression_mode == 1:
			push_warning("[Floors] SteamElevator not found at: %s" % String(steam_elevator_path))
		return
	
	if not _steam_elevator.has_signal("teleport_completed"):
		push_warning("[Floors] SteamElevator found but missing teleport_completed signal")
		return
	
	_steam_elevator.teleport_completed.connect(_on_steam_elevator_teleport_completed)
	pass

func _on_teleport_area_entered(body: Node2D) -> void:
	if body == _player:
		_player_in_teleport_zone = true

func _on_teleport_area_exited(body: Node2D) -> void:
	if body == _player:
		_player_in_teleport_zone = false

func trigger_boss_encounter_after_portal() -> void:
	"""Called by Portal.gd after teleporting player to Floor 5 (World2)"""
	if _boss_started:
		pass
		return
	
	var floor4_unlocked: bool = (_unlocked.size() > 3 and _unlocked[3] == 1)
	if not floor4_unlocked:
		pass
		return
	
	_boss_started = true
	pass
	
	if _encounter == null:
		pass
	elif not _encounter.has_method("begin_boss_encounter"):
		pass
	else:
		_encounter.call("begin_boss_encounter")
		pass

func _on_steam_elevator_teleport_completed() -> void:
	"""Called when SteamElevator completes teleport+fade to Floor 5"""
	pass
	pass
	_elevator_teleport_completed = true
	
	# Wait 1 second then trigger boss encounter
	await get_tree().create_timer(1.0).timeout
	
	# Check if floor 4 is unlocked (should be, since player just arrived from elevator)
	var floor4_unlocked: bool = (_unlocked.size() > 3 and _unlocked[3] == 1)
	
	pass
	
	if not _boss_started and floor4_unlocked:
		_boss_started = true
		pass
		if _encounter == null:
			pass
			pass
		elif not _encounter.has_method("begin_boss_encounter"):
			pass
			pass
		else:
			pass
			_encounter.call("begin_boss_encounter")
			pass
	else:
		if _boss_started:
			pass
		if not floor4_unlocked:
			pass

func _update_world3_teleport_interaction() -> void:
	if not enable_world3_teleport:
		return
	if _teleport_active:
		return
	if _player == null:
		return
	if _teleport_entrance == null or _teleport_destination == null:
		return

	# Check if floor requirement is met
	if teleport_requires_floor_unlocked > 0:
		var floor_index: int = teleport_requires_floor_unlocked - 1
		if floor_index < _unlocked.size() and _unlocked[floor_index] == 0:
			return  # Floor not unlocked yet

	if not Input.is_action_just_pressed(input_interact):
		return

	# Check if player is in range (use Area2D if available, otherwise distance)
	var in_range: bool = false
	if _teleport_entrance_area != null:
		# Use Area2D collision detection (visual editing in editor!)
		in_range = _player_in_teleport_zone
	else:
		# Fallback to distance-based detection
		var entrance_point: Vector2 = _teleport_entrance.global_position + teleport_entrance_offset
		var d: float = _player.global_position.distance_to(entrance_point)
		in_range = d <= teleport_interact_radius

	if not in_range:
		return

	# Trigger teleport
	_start_world3_teleport()

func _start_world3_teleport() -> void:
	if _teleport_active:
		return
	_teleport_active = true

	pass

	# Lock input
	_set_player_input_locked(true)

	# Use deferred call for async flow
	call_deferred("_world3_teleport_sequence")

func _world3_teleport_sequence() -> void:
	# Step 1: Fade OUT (screen goes black)
	if _teleport_fade_rect != null:
		_teleport_fade_rect.visible = true
		var tween_out := create_tween()
		tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_out.tween_method(_set_teleport_fade_alpha, 0.0, 1.0, teleport_fade_out_time)
		await tween_out.finished
	else:
		# Fallback if no fade rect
		await get_tree().create_timer(0.3).timeout

	# Step 2: Move player and camera while screen is black
	_set_player_visible(false)
	
	if _player != null and _teleport_destination != null:
		_player.global_position = _teleport_destination.global_position
		pass
	
	# Wait for camera to finish moving to new position (screen is black, so player won't see the movement)
	await get_tree().create_timer(teleport_camera_settle_time).timeout
	
	_set_player_visible(true)

	# Step 3: Fade IN (screen returns to normal, camera should be settled now)
	if _teleport_fade_rect != null:
		var tween_in := create_tween()
		tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_in.tween_method(_set_teleport_fade_alpha, 1.0, 0.0, teleport_fade_in_time)
		await tween_in.finished
		_teleport_fade_rect.visible = false
	else:
		# Fallback if no fade rect
		await get_tree().create_timer(0.2).timeout

	# Unlock input
	_set_player_input_locked(false)

	_teleport_active = false
	pass

# Helper to set fade alpha
func _set_teleport_fade_alpha(alpha: float) -> void:
	if _teleport_fade_rect == null:
		return
	var c := _teleport_fade_rect.color
	c.a = alpha
	_teleport_fade_rect.color = c
