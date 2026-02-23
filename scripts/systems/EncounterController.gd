extends Node
class_name EncounterController

signal phase_changed(new_phase: int)
signal dps_time_changed(time_left: float)

enum Phase { ASCENT, DPS }

signal encounter_completed

@export var victory_ui_path: NodePath = ^"../UI/VictoryUI"
var _ended: bool = false
var _victory_ui: Node = null

@export var boss_path: NodePath = ^"../Boss"
@export var dps_duration: float = 15.0

@export var charge_scene: PackedScene
@export var respawn_charge_on_ascent: bool = true

@export var world_scene_paths: Array[String] = [
	"res://scenes/World1.tscn",
	"res://scenes/World2.tscn",
	"res://scenes/World3.tscn"
]

@export var charge_stations_root_path: NodePath = ^"../Arena/ChargeStations"
@export var randomize_active_station_each_ascent: bool = true
@export var hide_inactive_stations: bool = true

@export var charge_spawns_root_path: NodePath = ^"../Arena/ChargeSpawn"
@export var randomize_charge_spawn: bool = true

@export var ascension_sockets_root_path: NodePath = ^"../Arena/AscensionSocket"
@export var randomize_active_socket: bool = true
@export var hide_inactive_sockets: bool = true

# -----------------------------
# Add-unlock mechanic
# -----------------------------
@export var add_scene: PackedScene
@export var adds_per_cycle: int = 3
@export var glowing_add_color: Color = Color(1.0, 1.0, 0.0, 1.0)  # Yellow glow
@export var glowing_add_light_energy: float = 1.2

# -----------------------------
# Elite (Golem) pre-boss mechanic
# -----------------------------
@export var golem_scene: PackedScene  # Skeleton Golem scene for elite floor 5 spawns

@export var start_on_ready: bool = true
var encounter_active: bool = false

var _boss_mode: bool = false

var phase: int = Phase.ASCENT
var _boss: Node = null

var _dps_timer: float = 0.0
var _dps_extended_this_window: bool = false # ✅ E2 gate: only extend once per DPS

var _active_charge: AscensionCharge = null
var _spawn_queued: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _spawns: Array[Node2D] = []
var _active_spawn: Node2D = null

var _sockets: Array[AscensionSocket] = []
var _active_socket: AscensionSocket = null

var _stations: Array[ChargeStation] = []
var _active_station: ChargeStation = null

# Cycle state
var _cycle_adds: Array[Node] = []
var _unlocked_station_index: int = -1
var _station_unlocked: bool = false

# ✅ Elite (Golem) pre-boss state
var _golem_phase_active: bool = false
var _golems: Array[Node] = []
var _golems_to_defeat: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)
	set_process(false)

	add_to_group("encounter")
	_rng.randomize()

	# Victory UI hookup
	_victory_ui = get_node_or_null(victory_ui_path)
	if _victory_ui == null:
		push_warning("[Encounter] VictoryUI not found at path: %s" % String(victory_ui_path))
	else:
		# Proceed signal
		if _victory_ui.has_signal("proceed_pressed"):
			if not _victory_ui.proceed_pressed.is_connected(_on_victory_proceed):
				_victory_ui.proceed_pressed.connect(_on_victory_proceed)
		else:
			push_warning("[Encounter] VictoryUI missing signal proceed_pressed")

		# Input lock signal
		if _victory_ui.has_signal("input_lock_changed"):
			if not _victory_ui.input_lock_changed.is_connected(_on_victory_input_lock_changed):
				_victory_ui.input_lock_changed.connect(_on_victory_input_lock_changed)
		else:
			push_warning("[Encounter] VictoryUI missing signal input_lock_changed")

	# Important: clean disconnect on exit so we never receive late signals during teardown
	if not tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.connect(_on_tree_exiting)

	_boss = get_node_or_null(boss_path)
	if _boss == null:
		# Only warn in main world scenes (sub-arenas and FinalWorld don't have bosses)
		var scene_name: String = ""
		if get_tree().current_scene:
			scene_name = String(get_tree().current_scene.name)
		if not ("SubArena" in scene_name or "FinalWorld" in scene_name):
			push_warning("[Encounter] Boss not found. Set boss_path on EncounterController.")
	else:
		if _boss.has_signal("died"):
			if not _boss.died.is_connected(_on_boss_died):
				_boss.died.connect(_on_boss_died)
		else:
			push_warning("[Encounter] Boss has no 'died' signal.")

	if charge_scene == null:
		push_warning("[Encounter] charge_scene not assigned. Assign AscensionCharge.tscn in Inspector.")
	if add_scene == null:
		push_warning("[Encounter] add_scene not assigned. Assign an add enemy scene (e.g., EnemyKnightAdd.tscn).")

	_load_charge_stations()
	_load_spawns_from_root()
	_load_sockets_from_root_and_connect()
	_adopt_existing_charge()
	
	# Hide encounter elements until encounter starts
	_hide_encounter_elements()

	if start_on_ready:
		call_deferred("_begin_encounter")


func _on_tree_exiting() -> void:
	# During scene changes, avoid any lingering callbacks from VictoryUI
	if _victory_ui != null and is_instance_valid(_victory_ui):
		if _victory_ui.has_signal("proceed_pressed") and _victory_ui.proceed_pressed.is_connected(_on_victory_proceed):
			_victory_ui.proceed_pressed.disconnect(_on_victory_proceed)
		if _victory_ui.has_signal("input_lock_changed") and _victory_ui.input_lock_changed.is_connected(_on_victory_input_lock_changed):
			_victory_ui.input_lock_changed.disconnect(_on_victory_input_lock_changed)


func _on_victory_input_lock_changed(locked: bool) -> void:
	# ✅ Critical crash fix: this signal can fire while we're being freed or after scene change begins.
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return

	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return

	if player.has_method("set_input_locked"):
		player.call("set_input_locked", locked)
		return

	# Fallbacks
	if "input_locked" in player:
		player.set("input_locked", locked)
		return
	if "controls_enabled" in player:
		player.set("controls_enabled", not locked)
		return


# -----------------------------
# ✅ NEW: single activation gate so boss encounter can't "start" while inactive
# -----------------------------
func _activate_encounter() -> void:
	# If we ended earlier (or physics was disabled), re-arm safely.
	_ended = false
	encounter_active = true
	set_physics_process(true)
	set_process(false)


func _begin_encounter() -> void:
	_activate_encounter()
	_boss_mode = false
	
	# ✅ Check if elite modifier requires Golem pre-boss phase (same as begin_boss_encounter)
	var elites_to_spawn: int = 0
	if RunStateSingleton != null and "elites_to_spawn_bonus" in RunStateSingleton:
		elites_to_spawn = int(RunStateSingleton.elites_to_spawn_bonus)
		#print("[Encounter] _begin_encounter: Checking for elites: elites_to_spawn_bonus = %d" % elites_to_spawn)
	
	if golem_scene == null:
		pass
		#print("[Encounter] _begin_encounter: WARNING: golem_scene is NULL!")
	
	if elites_to_spawn > 0 and golem_scene != null:
		# Start Golem phase instead of normal encounter
		#print("[Encounter] _begin_encounter: ✅ Elite modifier active: spawning %d Golem(s) before boss" % elites_to_spawn)
		_boss_mode = true  # Treat Golem phase as boss mode
		_start_golem_phase(elites_to_spawn)
	else:
		# Normal encounter
		#print("[Encounter] _begin_encounter: Starting normal encounter (no elites)")
		_set_phase(Phase.ASCENT)


func begin_boss_encounter() -> void:
	# ✅ CRITICAL FIX: Clean up any existing adds from _begin_encounter() before starting boss
	pass
	_cleanup_cycle_adds()  # Remove any adds that spawned earlier
	
	# ✅ CRITICAL: this must actually activate processing, or ASCENT cycle won't run.
	_activate_encounter()
	
	# Show encounter elements now that boss encounter is starting
	_show_encounter_elements()

	_boss_mode = true
	pass
	pass

	# ✅ Check if elite modifier requires Golem pre-boss phase
	var elites_to_spawn: int = 0
	if RunStateSingleton != null and "elites_to_spawn_bonus" in RunStateSingleton:
		elites_to_spawn = int(RunStateSingleton.elites_to_spawn_bonus)
		pass
	else:
		pass
	
	if golem_scene == null:
		pass
	
	if elites_to_spawn > 0 and golem_scene != null:
		# Start Golem phase instead of normal encounter
		pass
		_start_golem_phase(elites_to_spawn)
	else:
		# Normal boss encounter
		pass
		_set_phase(Phase.ASCENT)


func _physics_process(delta: float) -> void:
	if not encounter_active:
		return

	if phase == Phase.DPS:
		_dps_timer -= delta
		if _dps_timer < 0.0:
			_dps_timer = 0.0

		dps_time_changed.emit(_dps_timer)

		if _dps_timer <= 0.0:
			_set_phase(Phase.ASCENT)


# -----------------------------
# DPS lifecycle
# -----------------------------
func start_dps() -> void:
	_dps_timer = dps_duration
	_dps_extended_this_window = false # ✅ reset gate each new DPS window
	_set_phase(Phase.DPS)
	dps_time_changed.emit(_dps_timer)
	pass


func get_dps_time_left() -> float:
	return maxf(_dps_timer, 0.0)


# ✅ E2 API: extend current DPS timer (only once per DPS window)
func extend_dps_window(extra_seconds: float, reason: String = "") -> bool:
	if phase != Phase.DPS:
		return false
	if extra_seconds <= 0.0:
		return false
	if _dps_extended_this_window:
		return false

	var _before: float = maxf(_dps_timer, 0.0)
	_dps_timer = maxf(_dps_timer + extra_seconds, 0.0)
	_dps_extended_this_window = true

	dps_time_changed.emit(_dps_timer)

	var _why: String = "" if reason == "" else (" (" + reason + ")")
	pass

	return true


func _on_charge_socketed(consumed_charge: AscensionCharge) -> void:
	if phase == Phase.DPS:
		return

	notify_charge_consumed(consumed_charge)
	start_dps()

	# ✅ Notify relic system AFTER DPS starts so timer exists and phase == DPS
	_notify_player_orb_socketed()


func _notify_player_orb_socketed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player == null:
		return

	var rep := player.get_node_or_null("RelicEffectsPlayer")
	if rep != null and rep.has_method("on_orb_socketed"):
		rep.call("on_orb_socketed", self)


func notify_charge_consumed(consumed_charge: AscensionCharge) -> void:
	if consumed_charge == null:
		return
	if _active_charge == consumed_charge:
		_active_charge = null

	call_deferred("_disable_all_stations")


func notify_charge_picked_up(_charge: AscensionCharge) -> void:
	pass

func notify_charge_dropped(_charge: AscensionCharge) -> void:
	pass

func notify_charge_lost(lost_charge: AscensionCharge) -> void:
	if lost_charge == null:
		return
	if _active_charge == lost_charge:
		_active_charge = null


# -----------------------------
# Phase control
# -----------------------------
func _set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(phase)

	match phase:
		Phase.ASCENT:
			#print("[Encounter] Phase: ASCENT")
			_apply_boss_rules(false, true)

			# ✅ Leaving DPS -> allow extension next time
			_dps_extended_this_window = false

			_pick_active_spawn()
			_pick_active_socket()

			_begin_ascent_cycle()

			if respawn_charge_on_ascent:
				_queue_spawn_charge()

		Phase.DPS:
			#print("[Encounter] Phase: DPS")
			_apply_boss_rules(true, false)

			_cleanup_cycle_adds()

			_set_only_socket_enabled(_active_socket)
			call_deferred("_disable_all_stations")


func _apply_boss_rules(vulnerable: bool, attacks_enabled: bool) -> void:
	if _boss == null:
		return
	if _boss.has_method("set_vulnerable"):
		_boss.set_vulnerable(vulnerable)
	if _boss.has_method("set_attacks_enabled"):
		# Only enable attacks if we're in boss mode (boss encounter has started)
		var should_enable_attacks: bool = attacks_enabled and _boss_mode
		_boss.set_attacks_enabled(should_enable_attacks)


# -----------------------------
# Ascent cycle (adds unlock station)
# -----------------------------
func _begin_ascent_cycle() -> void:
	# ✅ Skip normal cycle if Golem phase is active
	if _golem_phase_active:
		pass
		return
	
	_station_unlocked = false
	_unlocked_station_index = -1

	_disable_all_stations()
	if hide_inactive_stations:
		_set_all_stations_visible(false)

	_spawn_cycle_adds()


func _spawn_cycle_adds() -> void:
	_cleanup_cycle_adds()

	if add_scene == null:
		push_warning("[Encounter] add_scene is NULL; cannot spawn cycle adds.")
		return
	if _stations.is_empty():
		push_warning("[Encounter] No stations loaded; cannot spawn cycle adds.")
		return

	# Always spawn 3 adds but only use 2 stations (randomly picked)
	var spawn_count: int = adds_per_cycle  # Should be 3
	var station_count: int = _stations.size()  # Should be 2 after removing ChargeStation_C
	
	if spawn_count <= 0 or station_count <= 0:
		return

	# Randomly pick which of the 3 adds will unlock a station (0, 1, or 2)
	var glowing_idx: int = _rng.randi_range(0, spawn_count - 1)
	
	# Map the glowing add to one of the available stations (0 or 1)
	var station_idx: int = _rng.randi_range(0, station_count - 1)
	_unlocked_station_index = station_idx

	for i: int in range(spawn_count):
		# Pick station position for this add
		# For the first 2 adds, use station positions; for the 3rd, use a nearby position
		var spawn_pos: Vector2
		if i < station_count:
			var st: ChargeStation = _stations[i] as ChargeStation
			if st == null or not is_instance_valid(st):
				continue
			spawn_pos = st.global_position + Vector2(0.0, -8.0)
		else:
			# 3rd add: spawn near a random station with offset
			var st: ChargeStation = _stations[_rng.randi_range(0, station_count - 1)] as ChargeStation
			if st == null or not is_instance_valid(st):
				continue
			spawn_pos = st.global_position + Vector2(_rng.randf_range(-200.0, 200.0), -8.0)

		var add_node: Node = add_scene.instantiate()
		var add2d: Node2D = add_node as Node2D
		if add2d == null:
			push_warning("[Encounter] add_scene root must be Node2D/CharacterBody2D.")
			add_node.queue_free()
			continue

		get_tree().current_scene.add_child(add2d)
		add2d.global_position = spawn_pos

		# ✅ CRITICAL: ensure Shock Charm can find these adds
		add2d.add_to_group(&"floor5_enemies")

		_cycle_adds.append(add2d)

		var is_glowing: bool = (i == glowing_idx)
		_apply_add_glow(add2d, is_glowing)
		
		# Connect death handler - only the glowing add will trigger station unlock
		if is_glowing:
			_connect_add_death(add2d, station_idx)
		else:
			_connect_add_death(add2d, -1)  # Non-glowing adds don't unlock stations


func _apply_add_glow(add2d: Node2D, enabled: bool) -> void:
	var spr: Sprite2D = add2d.get_node_or_null("Sprite2D") as Sprite2D
	if spr != null:
		spr.self_modulate = glowing_add_color if enabled else Color(1, 1, 1, 1)

	var light: PointLight2D = add2d.get_node_or_null("PointLight2D") as PointLight2D
	if light != null:
		light.visible = enabled
		if enabled:
			light.energy = glowing_add_light_energy


func _connect_add_death(add2d: Node2D, idx: int) -> void:
	var h: Node = add2d.get_node_or_null("Health")
	if h != null and h.has_signal("died"):
		h.died.connect(func() -> void:
			_on_cycle_add_died(idx)
		)
		return

	if add2d.has_signal("died"):
		add2d.died.connect(func() -> void:
			_on_cycle_add_died(idx)
		)
		return

	push_warning("[Encounter] Add has no Health.died or died signal; cannot unlock station on death.")


func _on_cycle_add_died(idx: int) -> void:
	# Ignore non-glowing adds (idx == -1)
	if idx < 0:
		return
	
	if _station_unlocked:
		return
	
	if idx != _unlocked_station_index:
		return

	_station_unlocked = true
	pass
	_unlock_station(idx)


func _unlock_station(idx: int) -> void:
	if idx < 0 or idx >= _stations.size():
		return

	_disable_all_stations()
	if hide_inactive_stations:
		_set_all_stations_visible(false)

	_active_station = _stations[idx]
	if _active_station != null and is_instance_valid(_active_station):
		if hide_inactive_stations:
			_active_station.visible = true
		_active_station.set_active(true)


func _cleanup_cycle_adds() -> void:
	for n in _cycle_adds:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_cycle_adds.clear()


func _set_all_stations_visible(v: bool) -> void:
	for s in _stations:
		if s != null and is_instance_valid(s):
			s.visible = v


func _hide_encounter_elements() -> void:
	# Hide all charge stations
	_set_all_stations_visible(false)
	
	# Hide all ascension sockets
	for s in _sockets:
		if s != null and is_instance_valid(s):
			s.visible = false
			if s.has_method("set_enabled"):
				s.set_enabled(false)
	
	# Hide charge orb if it exists
	if _active_charge != null and is_instance_valid(_active_charge):
		_active_charge.visible = false


func _show_encounter_elements() -> void:
	# Show charge orb if it exists
	if _active_charge != null and is_instance_valid(_active_charge):
		_active_charge.visible = true
	
	# Pick active socket if not already picked
	if _active_socket == null:
		_pick_active_socket()
	
	var _active_name: String = "null"
	if _active_socket != null:
		_active_name = _active_socket.name
	pass
	
	# Sockets remain hidden until charge is fully forged
	# They're shown by _on_charge_fully_charged() when the charge is ready
	# This prevents sockets from appearing before the player has forged the charge
	
	# Stations remain hidden until unlocked by killing the glowing add
	# They're managed by _unlock_station() which respects hide_inactive_stations


# -------------------- Charge spawning --------------------
func _charge_exists() -> bool:
	return _active_charge != null \
		and is_instance_valid(_active_charge) \
		and not _active_charge.is_queued_for_deletion() \
		and _active_charge.is_inside_tree()

func _queue_spawn_charge() -> void:
	if _spawn_queued:
		return

	if not _charge_exists():
		_adopt_existing_charge()
	if _charge_exists():
		return
	if charge_scene == null:
		return

	_spawn_queued = true
	call_deferred("_spawn_charge_if_needed")

func _spawn_charge_if_needed() -> void:
	_spawn_queued = false

	if not _charge_exists():
		_adopt_existing_charge()
	if _charge_exists():
		return
	if charge_scene == null:
		return
	if _active_spawn == null:
		push_warning("[Encounter] No active spawn found.")
		return

	var node: Node = charge_scene.instantiate()
	var charge: AscensionCharge = node as AscensionCharge
	if charge == null:
		push_warning("[Encounter] charge_scene root must be AscensionCharge.")
		node.queue_free()
		return

	get_tree().current_scene.add_child(charge)
	charge.global_position = _active_spawn.global_position
	_active_charge = charge

	_hook_charge(_active_charge)

func _adopt_existing_charge() -> void:
	var found: Array[AscensionCharge] = []
	_find_charges(get_tree().current_scene, found)
	if found.is_empty():
		return

	_active_charge = found[0]
	_hook_charge(_active_charge)

	if found.size() > 1:
		for i in range(1, found.size()):
			var c: AscensionCharge = found[i]
			if c != null and is_instance_valid(c):
				c.queue_free()

func _hook_charge(charge: AscensionCharge) -> void:
	if charge == null or not is_instance_valid(charge):
		return

	if charge.has_method("set_encounter"):
		charge.set_encounter(self)

	if not charge.picked_up.is_connected(_on_charge_picked_up_sig):
		charge.picked_up.connect(_on_charge_picked_up_sig)
	
	# Connect to fully_charged signal to show sockets when charge is ready
	if charge.has_signal("fully_charged") and not charge.fully_charged.is_connected(_on_charge_fully_charged):
		charge.fully_charged.connect(_on_charge_fully_charged)
	if not charge.dropped.is_connected(_on_charge_dropped_sig):
		charge.dropped.connect(_on_charge_dropped_sig)
	if not charge.consumed.is_connected(_on_charge_consumed_sig):
		charge.consumed.connect(_on_charge_consumed_sig)

func _on_charge_picked_up_sig(_carrier: Node2D) -> void:
	if _active_charge != null:
		notify_charge_picked_up(_active_charge)

func _on_charge_dropped_sig() -> void:
	if _active_charge != null:
		notify_charge_dropped(_active_charge)

func _on_charge_consumed_sig() -> void:
	if _active_charge != null:
		notify_charge_consumed(_active_charge)

func _on_charge_fully_charged() -> void:
	# Show sockets when charge is fully forged
	_set_only_socket_enabled(_active_socket)

func _find_charges(n: Node, out: Array[AscensionCharge]) -> void:
	var c: AscensionCharge = n as AscensionCharge
	if c != null and not c.is_queued_for_deletion():
		out.append(c)
	for child: Node in n.get_children():
		_find_charges(child, out)

# -------------------- Spawns --------------------
func _load_spawns_from_root() -> void:
	_spawns.clear()
	_active_spawn = null
	var root: Node = get_node_or_null(charge_spawns_root_path)
	if root == null:
		# Only warn in main world scenes (sub-arenas and FinalWorld don't have charge spawns)
		var scene_name: String = ""
		if get_tree().current_scene:
			scene_name = String(get_tree().current_scene.name)
		if not ("SubArena" in scene_name or "FinalWorld" in scene_name):
			push_warning("[Encounter] ChargeSpawn root not found.")
		return
	for child: Node in root.get_children():
		var n := child as Node2D
		if n != null:
			_spawns.append(n)

func _pick_active_spawn() -> void:
	if _spawns.is_empty():
		_active_spawn = null
		return
	_active_spawn = _spawns[0] if not randomize_charge_spawn else _spawns[_rng.randi_range(0, _spawns.size() - 1)]

# -------------------- Sockets --------------------
func _load_sockets_from_root_and_connect() -> void:
	_sockets.clear()
	_active_socket = null
	var root: Node = get_node_or_null(ascension_sockets_root_path)
	if root == null:
		push_warning("[Encounter] AscensionSocket root not found.")
		return
	_find_sockets_recursive(root, _sockets)
	for s in _sockets:
		if s != null and is_instance_valid(s):
			if not s.charge_socketed.is_connected(_on_charge_socketed):
				s.charge_socketed.connect(_on_charge_socketed)

func _find_sockets_recursive(n: Node, out: Array[AscensionSocket]) -> void:
	var s := n as AscensionSocket
	if s != null:
		out.append(s)
	for child: Node in n.get_children():
		_find_sockets_recursive(child, out)

func _pick_active_socket() -> void:
	if _sockets.is_empty():
		_active_socket = null
		return
	_active_socket = _sockets[0] if not randomize_active_socket else _sockets[_rng.randi_range(0, _sockets.size() - 1)]
	_set_only_socket_enabled(_active_socket)

func _set_only_socket_enabled(active: AscensionSocket) -> void:
	for s in _sockets:
		if s == null or not is_instance_valid(s):
			continue
		var on := (s == active)
		if s.has_method("set_enabled"):
			s.set_enabled(on)
			# Also manage parent socket visibility when hiding inactive sockets
			if hide_inactive_sockets:
				s.visible = on
		else:
			s.monitoring = on
			s.monitorable = on
			if hide_inactive_sockets:
				s.visible = on

# -------------------- Stations --------------------
func _load_charge_stations() -> void:
	_stations.clear()
	_active_station = null
	var root: Node = get_node_or_null(charge_stations_root_path)
	if root == null:
		# Only warn in main world scenes (sub-arenas and FinalWorld don't have charge stations)
		var scene_name: String = ""
		if get_tree().current_scene:
			scene_name = String(get_tree().current_scene.name)
		if not ("SubArena" in scene_name or "FinalWorld" in scene_name):
			push_warning("[Encounter] ChargeStations root not found.")
		return
	for child: Node in root.get_children():
		var s := child as ChargeStation
		if s != null:
			_stations.append(s)
	_disable_all_stations()

func _disable_all_stations() -> void:
	for s in _stations:
		if s != null and is_instance_valid(s):
			s.set_active(false)
	_active_station = null


func _on_boss_died() -> void:
	_end_encounter_and_show_victory()

func _end_encounter_and_show_victory() -> void:
	if _ended:
		return
	_ended = true
	encounter_active = false

	set_physics_process(false)
	set_process(false)

	_cleanup_cycle_adds()
	_disable_all_stations()

	if _boss != null:
		if _boss.has_method("set_attacks_enabled"):
			_boss.set_attacks_enabled(false)
		if _boss.has_method("set_vulnerable"):
			_boss.set_vulnerable(false)
		if _boss.has_method("set_combat_paused"):
			_boss.set_combat_paused(true)

	if _victory_ui == null or not is_instance_valid(_victory_ui):
		_victory_ui = get_node_or_null(victory_ui_path)

	if _victory_ui == null:
		push_warning("[Encounter] VictoryUI not found at path: %s" % String(victory_ui_path))
	else:
		if _victory_ui.has_method("open_victory"):
			_victory_ui.call("open_victory")
		else:
			_victory_ui.visible = true

	encounter_completed.emit()


func _on_world_complete() -> void:
	# Optional helper if you call this elsewhere; safe version (no double-open)
	if _victory_ui == null or not is_instance_valid(_victory_ui):
		_victory_ui = get_node_or_null(victory_ui_path)

	if _victory_ui == null:
		push_warning("[Encounter] VictoryUI not found at path: %s" % String(victory_ui_path))
		return

	if RunStateSingleton != null and _victory_ui.has_method("set_run_summary_snapshot"):
		_victory_ui.call("set_run_summary_snapshot",
			RunStateSingleton.world_index,
			RunStateSingleton.floor_index,
			RunStateSingleton.dice_min,
			RunStateSingleton.dice_max,
			RunStateSingleton.get_active_modifier_ids()
		)

	if _victory_ui.has_method("open_victory"):
		_victory_ui.call("open_victory")
	else:
		_victory_ui.visible = true


func _on_victory_proceed() -> void:
	# ✅ DO NOT advance_world here. VictoryUI already advances world when a relic is selected.
	# This handler should ONLY pick the next scene based on the NEW RunStateSingleton.world_index.

	var tree := get_tree()
	if tree == null:
		return

	var idx: int = 0
	if RunStateSingleton != null:
		idx = clampi(RunStateSingleton.world_index - 1, 0, world_scene_paths.size() - 1)

	var next_path: String = world_scene_paths[idx]

	if not ResourceLoader.exists(next_path):
		push_warning("[Encounter] Next world scene missing: %s. Falling back to World1." % next_path)
		next_path = world_scene_paths[0]

	tree.paused = false
	call_deferred("_change_scene_safe", next_path)


func _change_scene_safe(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(path)

# -----------------------------
# ✅ Elite (Golem) pre-boss phase
# -----------------------------
func _start_golem_phase(elite_count: int) -> void:
	_golem_phase_active = true
	_golems_to_defeat = elite_count
	_golems.clear()
	
	# Keep boss completely inactive during Golem phase
	_apply_boss_rules(false, false)  # Not vulnerable, no attacks
	
	pass
	
	# ✅ Set phase to ASCENT FIRST (before spawning), so _golem_phase_active flag prevents normal adds
	phase = Phase.ASCENT
	
	# Spawn Golems (deferred to avoid physics query issues)
	call_deferred("_spawn_golems", elite_count)

func _spawn_golems(count: int) -> void:
	if golem_scene == null:
		push_warning("[Encounter] golem_scene is NULL; cannot spawn Golems.")
		_complete_golem_phase()  # Fail-safe: start normal encounter
		return
	
	if _stations.is_empty():
		push_warning("[Encounter] No stations loaded; cannot spawn Golems.")
		_complete_golem_phase()  # Fail-safe: start normal encounter
		return
	
	var spawn_count: int = mini(count, _stations.size())
	
	for i in range(spawn_count):
		var st: ChargeStation = _stations[i] as ChargeStation
		if st == null or not is_instance_valid(st):
			continue
		
		var golem_node: Node = golem_scene.instantiate()
		var golem_2d: Node2D = golem_node as Node2D
		if golem_2d == null:
			push_warning("[Encounter] golem_scene root must be Node2D/CharacterBody2D.")
			golem_node.queue_free()
			continue
		
		get_tree().current_scene.add_child(golem_2d)
		golem_2d.global_position = st.global_position + Vector2(0.0, -8.0)
		
		# ✅ CRITICAL: Add to floor5_enemies group so abilities work
		golem_2d.add_to_group(&"floor5_enemies")
		golem_2d.add_to_group(&"elites")  # Mark as elite for future use
		
		_golems.append(golem_2d)
		
		# Connect death signal
		_connect_golem_death(golem_2d, i)
		
		pass

func _connect_golem_death(golem_2d: Node2D, idx: int) -> void:
	var h: Node = golem_2d.get_node_or_null("Health")
	if h != null and h.has_signal("died"):
		h.died.connect(func() -> void:
			_on_golem_died(idx)
		)
		return
	
	if golem_2d.has_signal("died"):
		golem_2d.died.connect(func() -> void:
			_on_golem_died(idx)
		)
		return
	
	push_warning("[Encounter] Golem has no Health.died or died signal; cannot track death.")

func _on_golem_died(_idx: int) -> void:
	if not _golem_phase_active:
		return
	
	_golems_to_defeat -= 1
	pass
	
	if _golems_to_defeat <= 0:
		pass
		_complete_golem_phase()

func _complete_golem_phase() -> void:
	_golem_phase_active = false
	_golems.clear()
	_golems_to_defeat = 0
	
	# ✅ Consume elite modifier after Golems are defeated
	if RunStateSingleton != null and "elites_to_spawn_bonus" in RunStateSingleton:
		RunStateSingleton.elites_to_spawn_bonus = 0
		pass
	
	# Start normal boss encounter (adds will spawn, boss becomes active)
	# ✅ Use call_deferred to avoid physics query errors
	pass
	call_deferred("_set_phase", Phase.ASCENT)  # This will now spawn normal adds since _golem_phase_active = false
