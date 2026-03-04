extends Node
class_name BossEncounterWorld2

# World 2 Boss Encounter with Phrase/Portal mechanic
# Phase 1: 3 random enemies spawn, boss immune + attacks
# Phase 2: Enemies dead → boss says phrase → 3 portals spawn (correct/wrong)
# Phase 3: Player sockets charge → boss vulnerable for 15s
# Repeat until boss dies

signal phase_changed(new_phase: int)
signal encounter_completed

const RELIC_ROLL_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/RelicDiceRollScreen.tscn")

enum Phase { IMMUNE_COMBAT, PORTAL_CHOICE, DPS }

@export var boss_path: NodePath = ^"../Boss"
@export var player_path: NodePath = ^"../Player"
@export var dps_duration: float = 15.0
@export var victory_ui_path: NodePath = ^"../UI/VictoryUI"

# World progression (after victory)
@export var world_scene_paths: Array[String] = [
	"res://scenes/world/World1.tscn",
	"res://scenes/world/World2.tscn",
	"res://scenes/world/World3.tscn"
]

# Enemy spawning
@export var enemy_scenes: Array[PackedScene] = []  # Add 4 enemy types
@export var enemies_per_cycle: int = 3
@export var enemy_spawns_root_path: NodePath = ^"../Arena/Spawns/Floor5"
@export var randomize_enemy_spawn_points: bool = true
@export var enemy_spawn_positions: Array[Vector2] = [
	Vector2(-300, -18500),
	Vector2(0, -18500),
	Vector2(300, -18500)
]

# Portal spawning
@export var portal_scene: PackedScene
@export var portal_positions: Array[Vector2] = [
	Vector2(-500, -18300),
	Vector2(0, -18300),
	Vector2(500, -18300)
]

# Sub-arenas (you'll build these)
@export var wrong_portal_arena_scene: String = "res://scenes/boss/BossSubArenaWrong.tscn"
@export var right_portal_arena_scene: String = "res://scenes/boss/BossSubArenaRight.tscn"
@export var boss_arena_return_position: Vector2 = Vector2(0, -18500)  # Where player spawns back

# AscensionSocket for DPS phase
@export var ascension_socket_path: NodePath = ^"../Arena/AscensionSocket"

# Phrase system
@export var phrase_display_path: NodePath = ^"../Boss/PhraseDisplay"

@export var debug_logs: bool = false

var phase: int = Phase.IMMUNE_COMBAT
var _boss: Node = null
var _player: Node2D = null
var _victory_ui: Node = null
var _socket: AscensionSocket = null
var _phrase_display: Node = null
var _relic_roll_screen: Node = null
var _pending_victory_reward_roll: int = -1

var _dps_timer: float = 0.0
var _active_enemies: Array[Node] = []
var _active_portals: Array[Node] = []
var _enemy_spawn_nodes: Array[Node2D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _current_phrase: String = ""
var _correct_portal_color: String = ""  # "void", "light", or "shadow"

var _ended: bool = false
var _encounter_active: bool = false

# Phrases and their portal colors
const PHRASES = {
	"void": "Seek the VOID",
	"light": "Embrace the LIGHT",
	"shadow": "Enter the SHADOW"
}

# Portal color → visual color mapping
const PORTAL_COLORS = {
	"void": Color(0.5, 0.0, 0.8, 0.8),      # Purple
	"light": Color(1.0, 0.85, 0.0, 0.8),    # Gold
	"shadow": Color(0.1, 0.1, 0.1, 0.9)     # Black
}

func _ready() -> void:
	_seed_rng_for_world2_boss()
	
	_boss = get_node_or_null(boss_path)
	if _boss == null:
		push_error("[BossEncounterWorld2] Boss not found at: ", boss_path)
		return
	
	_player = get_node_or_null(player_path)
	if _player == null:
		push_error("[BossEncounterWorld2] Player not found at: ", player_path)
		return
	
	_victory_ui = get_node_or_null(victory_ui_path)
	_socket = get_node_or_null(ascension_socket_path)
	_phrase_display = get_node_or_null(phrase_display_path)
	_load_enemy_spawn_nodes()
	
	pass
	
	# Connect boss death
	if _boss.has_signal("died"):
		_boss.died.connect(_on_boss_died)
	
	# Connect socket
	if _socket and _socket.has_signal("charge_socketed"):
		_socket.charge_socketed.connect(_on_charge_socketed)
	
	# Connect victory UI proceed signal (for world transition)
	if _victory_ui != null:
		if _victory_ui.has_signal("proceed_pressed"):
			if not _victory_ui.proceed_pressed.is_connected(_on_victory_proceed):
				_victory_ui.proceed_pressed.connect(_on_victory_proceed)
		else:
			push_warning("[BossEncounterWorld2] VictoryUI missing signal proceed_pressed")
		
		# Input lock signal
		if _victory_ui.has_signal("input_lock_changed"):
			if not _victory_ui.input_lock_changed.is_connected(_on_victory_input_lock_changed):
				_victory_ui.input_lock_changed.connect(_on_victory_input_lock_changed)
		else:
			push_warning("[BossEncounterWorld2] VictoryUI missing signal input_lock_changed")
	
	# Check if we're returning from sub-arena and need to restore state
	var portal_data = get_node_or_null("/root/PortalTransitionData")
	
	# CRITICAL: Set world_index to 2 when World2 loads (unless returning from sub-arena)
	if portal_data == null or not portal_data.is_returning:
		if RunStateSingleton != null:
			RunStateSingleton.world_index = 2
			print("[BossEncounterWorld2] Set world_index to 2 for World2")
	if portal_data != null and portal_data.is_returning:
		# CRITICAL: Wait for Boss._ready() to complete first (it sets HP=max_hp)
		# Otherwise our restoration gets overwritten
		await get_tree().process_frame
		_restore_encounter_state(portal_data)
	else:
		if debug_logs:
			pass

func _seed_rng_for_world2_boss() -> void:
	if RunStateSingleton != null and RunStateSingleton.has_method("make_rng_for_domain"):
		var seeded_rng: RandomNumberGenerator = RunStateSingleton.call("make_rng_for_domain", &"boss_encounter_world2", 0) as RandomNumberGenerator
		if seeded_rng != null:
			_rng.seed = seeded_rng.seed
			return
	_rng.randomize()

func _restore_encounter_state(portal_data: Node) -> void:
	# Restore encounter from sub-arena return
	_encounter_active = true
	phase = portal_data.boss_phase
	
	if debug_logs:
		pass
	
	# Restore boss health
	if _boss.has_method("set_hp"):
		_boss.call("set_hp", portal_data.boss_hp)
	elif "hp" in _boss:
		_boss.hp = portal_data.boss_hp
	
	# Set boss state based on phase
	if phase == Phase.PORTAL_CHOICE:
		if _boss.has_method("set_vulnerable"):
			_boss.set_vulnerable(false)
		if _boss.has_method("set_attacks_enabled"):
			_boss.set_attacks_enabled(false)
		
		# CRITICAL: Show the ascension socket so player can socket their charge
		if _socket != null and _socket.has_method("set_enabled"):
			_socket.set_enabled(true)
			if debug_logs:
				print("[BossEncounterWorld2] Socket enabled after return from sub-arena")
		
		if debug_logs:
			pass
	
	# Don't clear the portal data yet - ReturnHandler will do that

func begin_encounter() -> void:
	if _encounter_active:
		return
	
	_encounter_active = true
	
	if debug_logs:
		pass
	
	_set_phase(Phase.IMMUNE_COMBAT)

# Alias for FloorProgressionController compatibility
func begin_boss_encounter() -> void:
	begin_encounter()

func _set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(phase)
	
	match phase:
		Phase.IMMUNE_COMBAT:
			if debug_logs:
				pass
			_start_immune_combat_phase()
		
		Phase.PORTAL_CHOICE:
			if debug_logs:
				pass
			_start_portal_choice_phase()
		
		Phase.DPS:
			if debug_logs:
				pass
			_start_dps_phase()

func _start_immune_combat_phase() -> void:
	# Boss becomes immune and starts attacking
	if _boss.has_method("set_vulnerable"):
		_boss.set_vulnerable(false)
	if _boss.has_method("set_attacks_enabled"):
		_boss.set_attacks_enabled(true)
	
	# Spawn 3 random enemies
	_spawn_cycle_enemies()

func _spawn_cycle_enemies() -> void:
	_cleanup_enemies()
	
	if enemy_scenes.is_empty():
		push_error("[BossEncounterWorld2] No enemy scenes assigned!")
		return
	
	var spawn_positions: Array[Vector2] = _pick_enemy_spawn_positions(enemies_per_cycle)
	var spawn_count: int = spawn_positions.size()
	if spawn_count <= 0:
		push_warning("[BossEncounterWorld2] No valid enemy spawn positions found.")
		return
	
	for i in range(spawn_count):
		# Pick random enemy type
		var enemy_scene = enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)]
		var enemy_node = enemy_scene.instantiate()
		var enemy_2d = enemy_node as Node2D
		
		if enemy_2d == null:
			push_warning("[BossEncounterWorld2] Enemy scene root must be Node2D")
			enemy_node.queue_free()
			continue
		
		get_tree().current_scene.add_child(enemy_2d)
		enemy_2d.global_position = spawn_positions[i]
		enemy_2d.add_to_group(&"floor5_enemies")
		
		_active_enemies.append(enemy_2d)
		
		# Connect death signal
		_connect_enemy_death(enemy_2d)
		
		if debug_logs:
			pass

func _load_enemy_spawn_nodes() -> void:
	_enemy_spawn_nodes.clear()
	var root: Node = get_node_or_null(enemy_spawns_root_path)
	if root == null:
		if debug_logs:
			push_warning("[BossEncounterWorld2] Enemy spawn root not found at: %s" % String(enemy_spawns_root_path))
		return

	for child: Node in root.get_children():
		var p: Node2D = child as Node2D
		if p != null:
			_enemy_spawn_nodes.append(p)

	if debug_logs:
		pass

func _pick_enemy_spawn_positions(requested_count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count: int = maxi(requested_count, 0)
	if count <= 0:
		return result

	if not _enemy_spawn_nodes.is_empty():
		var pool: Array[Node2D] = _enemy_spawn_nodes.duplicate()
		if randomize_enemy_spawn_points:
			_shuffle_node2d_array(pool)
		var use_count: int = mini(count, pool.size())
		for i in range(use_count):
			var n: Node2D = pool[i]
			if n != null and is_instance_valid(n):
				result.append(n.global_position)
		if not result.is_empty():
			return result

	# Fallback to legacy inspector vector positions if marker nodes are unavailable.
	var fallback_count: int = mini(count, enemy_spawn_positions.size())
	for i in range(fallback_count):
		result.append(enemy_spawn_positions[i])
	return result

func _connect_enemy_death(enemy: Node2D) -> void:
	var health = enemy.get_node_or_null("Health")
	if health == null:
		push_error("[BossEncounterWorld2] Enemy ", enemy.name, " has no Health node!")
		return
	
	if not health.has_signal("died"):
		push_error("[BossEncounterWorld2] Enemy ", enemy.name, " Health has no 'died' signal!")
		return
	
	health.died.connect(func() -> void:
		_on_enemy_died(enemy)
	)
	
	if debug_logs:
		pass

func _on_enemy_died(_enemy: Node) -> void:
	if debug_logs:
		pass
	
	# Prevent multiple transitions if already in/moving to portal phase
	if phase != Phase.IMMUNE_COMBAT:
		return
	
	# Check if all enemies are dead
	var all_dead = true
	var _alive_count = 0
	var dead_count = 0
	var _invalid_count = 0
	
	for e in _active_enemies:
		if e == null or not is_instance_valid(e):
			_invalid_count += 1
			continue
			
		var h = e.get_node_or_null("Health")
		if h == null:
			if debug_logs:
				pass
			_invalid_count += 1
			continue
		
		# EnemyHealth has hp variable, not is_alive() method
		var enemy_hp: int = 0
		if "hp" in h:
			enemy_hp = h.hp
		
		if enemy_hp > 0:
			all_dead = false
			_alive_count += 1
		else:
			dead_count += 1
	
	if debug_logs:
		pass
	
	# CRITICAL: Show phrase after FIRST enemy dies (dead_count >= 1)
	if dead_count >= 1 and _phrase_display != null:
		# Only show once (check if not already shown)
		if _current_phrase == "":
			# Pick random phrase
			var phrase_keys = PHRASES.keys()
			_correct_portal_color = phrase_keys[_rng.randi_range(0, phrase_keys.size() - 1)]
			_current_phrase = PHRASES[_correct_portal_color]
			
			if debug_logs:
				pass
			
			if _phrase_display.has_method("show_phrase"):
				_phrase_display.show_phrase(_current_phrase)
	
	if all_dead:
		if debug_logs:
			pass
		
		# Stop boss attacks
		if _boss.has_method("set_attacks_enabled"):
			_boss.set_attacks_enabled(false)
		
		# Wait a moment then show portals
		await get_tree().create_timer(2.0).timeout
		
		# Double-check we're still in IMMUNE_COMBAT (prevent race condition)
		if phase == Phase.IMMUNE_COMBAT:
			_set_phase(Phase.PORTAL_CHOICE)

func _cleanup_enemies() -> void:
	for e in _active_enemies:
		if e != null and is_instance_valid(e):
			e.queue_free()
	_active_enemies.clear()

func _start_portal_choice_phase() -> void:
	# Phrase is already shown (generated when first enemy died in _on_enemy_died)
	# Just verify it exists
	if _current_phrase == "":
		push_warning("[BossEncounterWorld2] Entering portal phase but phrase not set! This shouldn't happen.")
		# Fallback: generate phrase now
		var phrase_keys = PHRASES.keys()
		_correct_portal_color = phrase_keys[_rng.randi_range(0, phrase_keys.size() - 1)]
		_current_phrase = PHRASES[_correct_portal_color]
		
		if _phrase_display and _phrase_display.has_method("show_phrase"):
			_phrase_display.show_phrase(_current_phrase)
	
	if debug_logs:
		pass
	
	# Spawn 3 portals in random order
	_spawn_portals()

func _spawn_portals() -> void:
	_cleanup_portals()
	
	if portal_scene == null:
		push_error("[BossEncounterWorld2] portal_scene not assigned!")
		return
	
	# Shuffle portal colors
	var colors: Array[String] = ["void", "light", "shadow"]
	_shuffle_string_array(colors)
	
	# Shuffle spawn positions
	var positions: Array[Vector2] = portal_positions.duplicate()
	_shuffle_vector2_array(positions)
	
	for i in range(3):
		var portal = portal_scene.instantiate()
		get_tree().current_scene.add_child(portal)
		portal.global_position = positions[i]
		portal.add_to_group("portal")  # For interaction prompt detection
		
		var portal_color = colors[i]
		var is_correct = (portal_color == _correct_portal_color)
		
		# Configure portal
		if portal.has_method("setup"):
			portal.setup(portal_color, is_correct, PORTAL_COLORS[portal_color])
		
		# Set target scenes
		if portal.has_method("set_target_scene"):
			var target_scene = right_portal_arena_scene if is_correct else wrong_portal_arena_scene
			portal.set_target_scene(target_scene)
		
		# Set return position
		if portal.has_method("set_return_position"):
			portal.set_return_position(boss_arena_return_position)
		
		_active_portals.append(portal)
		
		if debug_logs:
			pass

func _shuffle_node2d_array(arr: Array[Node2D]) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Node2D = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _shuffle_string_array(arr: Array[String]) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: String = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _shuffle_vector2_array(arr: Array[Vector2]) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Vector2 = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _cleanup_portals() -> void:
	for p in _active_portals:
		if p != null and is_instance_valid(p):
			p.queue_free()
	_active_portals.clear()
	
	# Hide phrase
	if _phrase_display and _phrase_display.has_method("hide_phrase"):
		_phrase_display.hide_phrase()

func _on_charge_socketed(_charge: AscensionCharge) -> void:
	if debug_logs:
		pass
	
	if phase != Phase.PORTAL_CHOICE:
		if debug_logs:
			pass
		return
	
	if debug_logs:
		pass
	
	# Clean up portals
	_cleanup_portals()
	
	_set_phase(Phase.DPS)

func _start_dps_phase() -> void:
	# Boss becomes vulnerable, stops attacking
	if _boss.has_method("set_vulnerable"):
		_boss.set_vulnerable(true)
	if _boss.has_method("set_attacks_enabled"):
		_boss.set_attacks_enabled(false)
	
	_dps_timer = dps_duration
	set_physics_process(true)
	
	if debug_logs:
		pass

func _physics_process(delta: float) -> void:
	if phase != Phase.DPS:
		return
	
	_dps_timer -= delta
	
	if _dps_timer <= 0.0:
		if debug_logs:
			pass
		
		set_physics_process(false)
		_set_phase(Phase.IMMUNE_COMBAT)

func _on_boss_died() -> void:
	if debug_logs:
		pass
	
	_end_encounter()

func _end_encounter() -> void:
	if _ended:
		return
	_ended = true
	_encounter_active = false
	
	set_physics_process(false)
	
	_cleanup_enemies()
	_cleanup_portals()
	
	if _boss:
		if _boss.has_method("set_attacks_enabled"):
			_boss.set_attacks_enabled(false)
		if _boss.has_method("set_vulnerable"):
			_boss.set_vulnerable(false)
	
	# Show victory UI
	if _victory_ui and _victory_ui.has_method("open_victory"):
		_start_relic_roll_then_victory()
	
	encounter_completed.emit()

func _ensure_relic_roll_screen() -> Node:
	if _relic_roll_screen != null and is_instance_valid(_relic_roll_screen):
		return _relic_roll_screen
	if RELIC_ROLL_SCREEN_SCENE == null:
		return null
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var node: Node = RELIC_ROLL_SCREEN_SCENE.instantiate()
	tree.current_scene.add_child(node)
	_relic_roll_screen = node
	return _relic_roll_screen

func _start_relic_roll_then_victory() -> void:
	if RunStateSingleton == null:
		_open_victory_with_pending_roll()
		return

	var dice_min: int = int(RunStateSingleton.dice_min)
	var dice_max: int = int(RunStateSingleton.dice_max)
	_pending_victory_reward_roll = int(RunStateSingleton.call("get_victory_reward_roll"))
	var target_band: int = int(RunStateSingleton.call("get_target_relic_band_from_roll", _pending_victory_reward_roll))

	var roll_screen: Node = _ensure_relic_roll_screen()
	if roll_screen == null:
		_open_victory_with_pending_roll()
		return

	_on_victory_input_lock_changed(true)

	if roll_screen.has_signal("roll_completed"):
		if not roll_screen.roll_completed.is_connected(_on_relic_roll_completed_for_victory):
			roll_screen.roll_completed.connect(_on_relic_roll_completed_for_victory)

	if roll_screen.has_method("prepare_roll"):
		roll_screen.call("prepare_roll", dice_min, dice_max)
	if roll_screen.has_method("start_relic_roll"):
		roll_screen.call("start_relic_roll", dice_min, dice_max, _pending_victory_reward_roll, target_band)
	else:
		_open_victory_with_pending_roll()

func _on_relic_roll_completed_for_victory(_result: int) -> void:
	if _relic_roll_screen != null and is_instance_valid(_relic_roll_screen):
		if _relic_roll_screen.has_method("fade_out_text_only"):
			await _relic_roll_screen.call("fade_out_text_only")
	_open_victory_with_pending_roll()
	if _relic_roll_screen != null and is_instance_valid(_relic_roll_screen) and _relic_roll_screen.has_method("hide_screen"):
		_relic_roll_screen.call("hide_screen")

func _open_victory_with_pending_roll() -> void:
	if _victory_ui == null or not is_instance_valid(_victory_ui):
		return
	if _victory_ui.has_method("open_victory"):
		_victory_ui.call("open_victory", _pending_victory_reward_roll)
	else:
		_victory_ui.visible = true

# -----------------------------
# Victory & World Transition
# -----------------------------
func _on_victory_proceed() -> void:
	# VictoryUI already called advance_world() when relic was selected
	# This handler picks the next scene based on RunStateSingleton.world_index
	
	var tree := get_tree()
	if tree == null:
		return
	
	var idx: int = 0
	if RunStateSingleton != null:
		var current_world = RunStateSingleton.world_index
		print("[BossEncounterWorld2] Victory proceed - current world_index: ", current_world)
		idx = clampi(RunStateSingleton.world_index - 1, 0, world_scene_paths.size() - 1)
		print("[BossEncounterWorld2] Array index calculated: ", idx)
		pass
	
	var next_path: String = world_scene_paths[idx]
	print("[BossEncounterWorld2] Next scene path: ", next_path)
	pass
	
	# If World3 doesn't exist, repeat World2
	if not ResourceLoader.exists(next_path):
		print("[BossEncounterWorld2] WARNING: ", next_path, " does not exist! Falling back to World2")
		if debug_logs:
			pass
		next_path = "res://scenes/world/World2.tscn"
	
	if debug_logs:
		pass
	
	tree.paused = false
	call_deferred("_change_scene_safe", next_path)

func _change_scene_safe(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(path)

func _on_victory_input_lock_changed(locked: bool) -> void:
	# Lock/unlock player input during victory screen
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	
	if _player != null and _player.has_method("set_input_locked"):
		_player.set_input_locked(locked)
