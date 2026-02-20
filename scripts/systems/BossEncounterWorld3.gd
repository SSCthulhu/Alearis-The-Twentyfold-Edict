extends Node
class_name BossEncounterWorld3

# World 3 Boss Encounter with Forge mechanic
# Phase 1: Boss immune, charge spawns → player picks up
# Phase 2: Player stands on SteamElevator with charge → forges it (10s under fire)
# Phase 3: Player sockets forged charge → boss vulnerable for 15s DPS
# Repeat until boss dies

signal phase_changed(new_phase: int)
signal encounter_completed
signal forge_progress(seconds: float, required: float)

enum Phase { COLLECT_CHARGE, FORGE_CHARGE, SOCKET_CHARGE, DPS }

@export var boss_path: NodePath = ^"../Boss"
@export var player_path: NodePath = ^"../Player"
@export var dps_duration: float = 15.0
@export var victory_ui_path: NodePath = ^"../UI/VictoryUI"
@export var dice_roll_screen_path: NodePath = ^"../DiceRollScreen"
@export var fade_rect_path: NodePath = ^"../UI/ScreenRoot/HUDRoot/TeleportFade"

# Charge system
@export var charge_scene: PackedScene
@export var charge_spawn_path: NodePath = ^"../Arena/ChargeSpawn"
@export var ascension_socket_path: NodePath = ^"../AscensionSocket/AscensionSocketA"

# Forge system
@export var steam_elevator_path: NodePath = ^"../Arena/Geometry/SteamElevator"
@export var forge_duration: float = 10.0
@export var forge_attack_multiplier: float = 1.5  # Boss attacks faster during forge

# World progression
@export var world_scene_paths: Array[String] = [
	"res://scenes/world/World1.tscn",
	"res://scenes/world/World2.tscn",
	"res://scenes/world/World3.tscn"
]

@export var debug_logs: bool = false

var phase: int = Phase.COLLECT_CHARGE
var _boss: Node = null
var _player: Node2D = null
var _victory_ui: Node = null
var _dice_roll_screen: Node = null
var _fade_rect: ColorRect = null
var _socket: AscensionSocket = null
var _steam_elevator: Node2D = null
var _charge_spawn: Node2D = null

var _dps_timer: float = 0.0
var _forge_timer: float = 0.0
var _active_charge: AscensionCharge = null
var _ended: bool = false
var _encounter_active: bool = false
var _is_forging: bool = false
var _player_on_elevator: bool = false

func _ready() -> void:
	_boss = get_node_or_null(boss_path)
	if _boss == null:
		push_error("[BossEncounterWorld3] Boss not found at: ", boss_path)
		return
	
	_player = get_node_or_null(player_path)
	if _player == null:
		push_error("[BossEncounterWorld3] Player not found at: ", player_path)
		return
	
	_victory_ui = get_node_or_null(victory_ui_path)
	_dice_roll_screen = get_node_or_null(dice_roll_screen_path)
	_fade_rect = get_node_or_null(fade_rect_path)
	_socket = get_node_or_null(ascension_socket_path)
	_steam_elevator = get_node_or_null(steam_elevator_path)
	_charge_spawn = get_node_or_null(charge_spawn_path)
	
	if _steam_elevator == null:
		push_error("[BossEncounterWorld3] SteamElevator not found at: ", steam_elevator_path)
	
	if _dice_roll_screen == null:
		push_warning("[BossEncounterWorld3] DiceRollScreen not found at: ", dice_roll_screen_path)
	
	if _fade_rect == null:
		push_warning("[BossEncounterWorld3] Fade rect not found at: ", fade_rect_path)
	
	# Connect boss death
	if _boss.has_signal("died"):
		_boss.died.connect(_on_boss_died)
	
	# Connect socket
	if _socket and _socket.has_signal("charge_socketed"):
		_socket.charge_socketed.connect(_on_charge_socketed)
	
	# Connect steam elevator
	if _steam_elevator:
		if _steam_elevator.has_signal("player_entered"):
			_steam_elevator.player_entered.connect(_on_player_entered_elevator)
		if _steam_elevator.has_signal("player_exited"):
			_steam_elevator.player_exited.connect(_on_player_exited_elevator)
	
	# Connect victory UI
	if _victory_ui != null:
		if _victory_ui.has_signal("proceed_pressed"):
			if not _victory_ui.proceed_pressed.is_connected(_on_victory_proceed):
				_victory_ui.proceed_pressed.connect(_on_victory_proceed)
		
		if _victory_ui.has_signal("input_lock_changed"):
			if not _victory_ui.input_lock_changed.is_connected(_on_victory_input_lock_changed):
				_victory_ui.input_lock_changed.connect(_on_victory_input_lock_changed)
		
		if _victory_ui.has_signal("relic_chosen"):
			if not _victory_ui.relic_chosen.is_connected(_on_relic_chosen):
				_victory_ui.relic_chosen.connect(_on_relic_chosen)
		
		if debug_logs:
			pass
	
	# Connect dice roll screen
	if _dice_roll_screen != null:
		if _dice_roll_screen.has_signal("roll_completed"):
			if not _dice_roll_screen.roll_completed.is_connected(_on_dice_roll_completed):
				_dice_roll_screen.roll_completed.connect(_on_dice_roll_completed)
		
		if debug_logs:
			pass
	
	if debug_logs:
		pass

func begin_encounter() -> void:
	if _encounter_active:
		return
	
	_encounter_active = true
	
	if debug_logs:
		pass
	
	_set_phase(Phase.COLLECT_CHARGE)

# Alias for FloorProgressionController compatibility
func begin_boss_encounter() -> void:
	begin_encounter()

func _set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(phase)
	
	match phase:
		Phase.COLLECT_CHARGE:
			if debug_logs:
				pass
			_start_collect_charge_phase()
		
		Phase.FORGE_CHARGE:
			if debug_logs:
				pass
			_start_forge_charge_phase()
		
		Phase.SOCKET_CHARGE:
			if debug_logs:
				pass
			_start_socket_charge_phase()
		
		Phase.DPS:
			if debug_logs:
				pass
			_start_dps_phase()

func _start_collect_charge_phase() -> void:
	# Boss immune and attacking at normal speed
	if _boss.has_method("set_vulnerable"):
		_boss.set_vulnerable(false)
	if _boss.has_method("set_attacks_enabled"):
		_boss.set_attacks_enabled(true)
	if _boss.has_method("set_attack_speed_multiplier"):
		_boss.set_attack_speed_multiplier(1.0)
	
	# Socket disabled
	if _socket:
		_socket.set_enabled(false)
	
	# Only spawn charge if none exists or the previous one was consumed
	if _active_charge == null or not is_instance_valid(_active_charge) or _active_charge.is_consumed:
		_spawn_charge()
	else:
		if debug_logs:
			pass
	
	# Enable forge mode on elevator
	if _steam_elevator and _steam_elevator.has_method("set_forge_mode"):
		_steam_elevator.set_forge_mode(true)
	
	# Start animation if player is already on the platform
	if _player_on_elevator and _steam_elevator and _steam_elevator.has_method("start_forge_animation"):
		_steam_elevator.start_forge_animation()
	
	if debug_logs:
		pass

func _spawn_charge() -> void:
	if charge_scene == null:
		push_error("[BossEncounterWorld3] charge_scene not assigned!")
		return
	
	var spawn_pos: Vector2 = _charge_spawn.global_position if _charge_spawn else _player.global_position + Vector2(200, 0)
	
	_active_charge = charge_scene.instantiate() as AscensionCharge
	get_tree().root.add_child(_active_charge)
	_active_charge.global_position = spawn_pos
	
	if debug_logs:
		pass

func _start_forge_charge_phase() -> void:
	_is_forging = true
	_forge_timer = 0.0
	
	# Ensure boss keeps attacking (immune)
	if _boss.has_method("set_attacks_enabled"):
		_boss.set_attacks_enabled(true)
	if _boss.has_method("set_vulnerable"):
		_boss.set_vulnerable(false)
	
	# Boss attacks faster during forge
	if _boss.has_method("set_attack_speed_multiplier"):
		_boss.set_attack_speed_multiplier(forge_attack_multiplier)
	
	# Start forge animation immediately (player is on platform)
	if _steam_elevator and _steam_elevator.has_method("start_forge_animation"):
		_steam_elevator.start_forge_animation()
	
	if debug_logs:
		pass

func _start_socket_charge_phase() -> void:
	_is_forging = false
	
	# Boss returns to normal attack speed but KEEPS attacking
	if _boss.has_method("set_attack_speed_multiplier"):
		_boss.set_attack_speed_multiplier(1.0)
	
	# Ensure boss keeps attacking (should already be true, but explicitly set it)
	if _boss.has_method("set_attacks_enabled"):
		_boss.set_attacks_enabled(true)
	
	# Boss stays immune
	if _boss.has_method("set_vulnerable"):
		_boss.set_vulnerable(false)
	
	# Stop forge animation
	if _steam_elevator and _steam_elevator.has_method("stop_forge_animation"):
		_steam_elevator.stop_forge_animation()
	
	# Enable socket
	if _socket:
		_socket.set_enabled(true)
	
	if debug_logs:
		pass

func _start_dps_phase() -> void:
	_dps_timer = dps_duration
	
	# Boss vulnerable, stop attacks, normal speed
	if _boss.has_method("set_vulnerable"):
		_boss.set_vulnerable(true)
	if _boss.has_method("set_attacks_enabled"):
		_boss.set_attacks_enabled(false)
	if _boss.has_method("set_attack_speed_multiplier"):
		_boss.set_attack_speed_multiplier(1.0)
	
	# Disable socket
	if _socket:
		_socket.set_enabled(false)
	
	if debug_logs:
		pass

func _physics_process(delta: float) -> void:
	if not _encounter_active or _ended:
		return
	
	match phase:
		Phase.COLLECT_CHARGE:
			_update_collect_phase(delta)
		
		Phase.FORGE_CHARGE:
			_update_forge_phase(delta)
		
		Phase.DPS:
			_update_dps_phase(delta)

func _update_collect_phase(_delta: float) -> void:
	# Manage forge animation based on player position (visual feedback)
	if _player_on_elevator:
		# Player is on forge platform - play animation even if not forging yet
		if _steam_elevator and _steam_elevator.has_method("start_forge_animation"):
			_steam_elevator.start_forge_animation()  # Safe to call repeatedly - checks if already playing
	else:
		# Player not on platform - stop animation
		if _steam_elevator and _steam_elevator.has_method("stop_forge_animation"):
			_steam_elevator.stop_forge_animation()
	
	# Check if player picked up charge and is on elevator
	if _active_charge and _active_charge.is_carried and _player_on_elevator:
		_set_phase(Phase.FORGE_CHARGE)

func _update_forge_phase(delta: float) -> void:
	# Check if player still on elevator with charge
	if not _player_on_elevator or not _active_charge or not is_instance_valid(_active_charge) or not _active_charge.is_carried:
		# Player left elevator or dropped charge - stop animation and reset
		if _steam_elevator and _steam_elevator.has_method("stop_forge_animation"):
			_steam_elevator.stop_forge_animation()
		
		if debug_logs:
			pass
		_forge_timer = 0.0
		forge_progress.emit(0.0, forge_duration)
		# Don't clear _active_charge here - player might pick it back up
		_set_phase(Phase.COLLECT_CHARGE)
		return
	
	# Continue forging
	_forge_timer += delta
	forge_progress.emit(_forge_timer, forge_duration)
	
	# Update charge if it has a method
	if _active_charge.has_method("set_forge_progress"):
		_active_charge.set_forge_progress(_forge_timer / forge_duration)
	
	# Check if forge complete
	if _forge_timer >= forge_duration:
		# Mark charge as fully charged/forged
		if _active_charge.has_method("add_charge_seconds"):
			_active_charge.add_charge_seconds(forge_duration)
		_set_phase(Phase.SOCKET_CHARGE)

func _update_dps_phase(delta: float) -> void:
	_dps_timer -= delta
	
	if _dps_timer <= 0.0:
		# DPS window over, boss immune again
		if debug_logs:
			pass
		# Clear charge reference - it was consumed in the socket
		_active_charge = null
		_set_phase(Phase.COLLECT_CHARGE)

func _on_player_entered_elevator() -> void:
	_player_on_elevator = true
	
	# Start animation when player enters during collect or forge phase
	if phase == Phase.COLLECT_CHARGE or phase == Phase.FORGE_CHARGE:
		if _steam_elevator and _steam_elevator.has_method("start_forge_animation"):
			_steam_elevator.start_forge_animation()
	
	if debug_logs:
		pass

func _on_player_exited_elevator() -> void:
	_player_on_elevator = false
	
	# Stop animation when player leaves
	if _steam_elevator and _steam_elevator.has_method("stop_forge_animation"):
		_steam_elevator.stop_forge_animation()
	
	if debug_logs:
		pass

func _on_charge_socketed(_charge: AscensionCharge) -> void:
	if phase != Phase.SOCKET_CHARGE:
		return
	
	if debug_logs:
		pass
	
	# Clear reference - socket will consume the charge
	_active_charge = null
	_set_phase(Phase.DPS)

func _on_boss_died() -> void:
	if _ended:
		return
	
	_ended = true
	_encounter_active = false
	
	if debug_logs:
		pass
	
	encounter_completed.emit()
	
	if _victory_ui != null:
		if _victory_ui.has_method("open_victory"):
			_victory_ui.open_victory()
			if debug_logs:
				pass
		else:
			push_warning("[BossEncounterWorld3] VictoryUI found but missing open_victory() method")
	else:
		push_warning("[BossEncounterWorld3] VictoryUI not found at: ", victory_ui_path)

func _on_victory_proceed() -> void:
	if not is_inside_tree():
		return
	
	if debug_logs:
		pass
	
	# Start the dice roll sequence
	call_deferred("_start_dice_roll_sequence")

func _start_dice_roll_sequence() -> void:
	"""Fade to black → Dice roll → Show result → Fade out → Load next scene"""
	
	if debug_logs:
		pass
	
	# Step 1: Fade to black (1 second)
	if _fade_rect != null:
		_fade_rect.visible = true
		_fade_rect.color = Color(0, 0, 0, 0)
		var tween_out := create_tween()
		tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_out.tween_property(_fade_rect, "color:a", 1.0, 1.0)
		await tween_out.finished
		if debug_logs:
			pass
	else:
		await get_tree().create_timer(1.0).timeout
	
	# Step 2: While screen is BLACK, show dice roll screen (but don't start roll yet)
	if _dice_roll_screen != null:
		# Get dice range from RunStateSingleton
		var dice_min: int = 1
		var dice_max: int = 20
		
		if RunStateSingleton != null:
			dice_min = int(RunStateSingleton.dice_min)
			dice_max = int(RunStateSingleton.dice_max)
		
		# Make dice screen visible and show the range
		_dice_roll_screen.visible = true
		if _dice_roll_screen.has_method("prepare_roll"):
			_dice_roll_screen.prepare_roll(dice_min, dice_max)
		
		# Wait a frame for dice screen to be ready
		await get_tree().process_frame
		
		# Step 3: Fade from black to reveal dice screen (0.5 seconds)
		if _fade_rect != null:
			var tween_in := create_tween()
			tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween_in.tween_property(_fade_rect, "color:a", 0.0, 0.5)
			await tween_in.finished
			_fade_rect.visible = false
			if debug_logs:
				pass
		
		# Step 4: Wait 3 seconds before starting the roll
		if debug_logs:
			pass
		await get_tree().create_timer(3.0).timeout
		
		# Step 5: Now start the roll animation
		if _dice_roll_screen.has_method("start_roll"):
			if debug_logs:
				pass
			_dice_roll_screen.start_roll(dice_min, dice_max)
		
		# Animation continues in DiceRollScreen, will emit roll_completed when done
	else:
		push_error("[BossEncounterWorld3] DiceRollScreen not available!")

func _on_dice_roll_completed(result: int) -> void:
	"""Called when dice roll animation completes (after 3s result display)"""
	if debug_logs:
		pass
	
	# Store result in transition data for FinalWorld to use
	if FinalBossTransitionData != null:
		FinalBossTransitionData.set_boss_selection(result)
		if debug_logs:
			pass
	else:
		push_error("[BossEncounterWorld3] FinalBossTransitionData singleton not found!")
	
	# Fade to black before transitioning (no extra wait - result was already displayed for 3s)
	if _fade_rect != null and _dice_roll_screen != null:
		_fade_rect.visible = true
		_fade_rect.color = Color(0, 0, 0, 0)
		var tween_out := create_tween()
		tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_out.tween_property(_fade_rect, "color:a", 1.0, 1.0)
		await tween_out.finished
		
		# Hide dice screen
		_dice_roll_screen.hide_screen()
		
		if debug_logs:
			pass
		
		# Transition to FinalWorld
		var tree := get_tree()
		if tree != null:
			tree.change_scene_to_file("res://scenes/world/FinalWorld.tscn")
		else:
			push_error("[BossEncounterWorld3] SceneTree not available for transition!")
		
	if debug_logs:
		pass

func _on_relic_chosen(_index: int) -> void:
	if debug_logs:
		pass

func _on_victory_input_lock_changed(locked: bool) -> void:
	if not is_inside_tree():
		return
	
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(locked)
	
	if debug_logs:
		pass
