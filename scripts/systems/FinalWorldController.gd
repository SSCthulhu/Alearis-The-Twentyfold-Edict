extends Node

## Controller for FinalWorld that dynamically loads the correct boss
## based on the dice roll result stored in FinalBossTransitionData

@export var boss_spawn_position: Vector2 = Vector2(4, 1123)
@export var default_boss_path: NodePath = ^"../Boss"
@export var fade_in_duration: float = 1.5
@export var fade_rect_path: NodePath = ^"../UI/ScreenRoot/HUDRoot/FinalWorldFade"
@export var victory_screen_path: NodePath = ^"../FinalVictoryScreen"
@export var debug_logs: bool = true

@export_group("Final Boss Arena Camera")
@export var enable_final_boss_arena_camera: bool = true
@export var final_boss_arena_camera_path: NodePath = ^"../BossArenaCamera"
@export var final_boss_camera_left: float = -2200.0
@export var final_boss_camera_right: float = 2200.0
@export var final_boss_camera_top: float = -1200.0
@export var final_boss_camera_bottom: float = 2200.0
@export var final_boss_camera_transition_time: float = 0.75
@export var final_boss_camera_live_tuning: bool = false
@export var final_boss_camera_use_manual_center: bool = false
@export var final_boss_camera_center: Vector2 = Vector2(0.0, 700.0)
@export var final_boss_camera_auto_fit_zoom: bool = true
@export var final_boss_camera_fit_padding_px: float = 80.0
@export var final_boss_camera_min_zoom: float = 0.5
@export var final_boss_camera_max_zoom: float = 1.0

var _boss: Node2D = null
var _fade_rect: ColorRect = null
var _victory_screen: CanvasLayer = null
var _final_boss_camera_activated: bool = false
var _final_boss_camera_ref: Camera2D = null

func _ready() -> void:
	if debug_logs:
		pass
	
	# Get fade rect for fade-in effect
	_fade_rect = get_node_or_null(fade_rect_path)
	if _fade_rect == null:
		if debug_logs:
			pass
	else:
		# Start with black screen
		_fade_rect.visible = true
		_fade_rect.color = Color(0, 0, 0, 1)
	
	# Get victory screen
	_victory_screen = get_node_or_null(victory_screen_path)
	if _victory_screen == null:
		push_warning("[FinalWorldController] FinalVictoryScreen not found at: %s" % victory_screen_path)
	else:
		# Connect victory screen signals
		if _victory_screen.has_signal("play_again_pressed"):
			_victory_screen.play_again_pressed.connect(_on_play_again_pressed)
			if debug_logs:
				pass
		if _victory_screen.has_signal("main_menu_pressed"):
			_victory_screen.main_menu_pressed.connect(_on_main_menu_pressed)
			if debug_logs:
				pass
		if _victory_screen.has_signal("input_lock_changed"):
			_victory_screen.input_lock_changed.connect(_on_victory_input_lock_changed)
			if debug_logs:
				pass
		else:
			push_warning("[FinalWorldController] ⚠️ input_lock_changed signal not found!")
		if debug_logs:
			pass
	
	# Replace boss with correct final boss
	call_deferred("_setup_final_boss")

func _process(_delta: float) -> void:
	_update_final_boss_camera_live_tuning()

func _setup_final_boss() -> void:
	"""Replace default boss with the selected final boss"""
	
	# Check if we have transition data
	if FinalBossTransitionData == null:
		push_error("[FinalWorldController] FinalBossTransitionData singleton not found!")
		_complete_setup()
		return
	
	if not FinalBossTransitionData.has_data:
		push_warning("[FinalWorldController] No boss selection data found, using default boss")
		_complete_setup()
		return
	
	# Get the boss scene path
	var boss_scene_path: String = FinalBossTransitionData.get_boss_scene_path()
	if debug_logs:
		pass
	
	# Load the boss scene
	var boss_scene: PackedScene = load(boss_scene_path)
	if boss_scene == null:
		push_error("[FinalWorldController] Failed to load boss scene: %s" % boss_scene_path)
		_complete_setup()
		return
	
	# Wait a frame to ensure old boss is fully removed
	await get_tree().process_frame
	
	# Instance new boss
	_boss = boss_scene.instantiate()
	if _boss == null:
		push_error("[FinalWorldController] Failed to instantiate boss!")
		_complete_setup()
		return
	
	# Set boss properties
	_boss.name = "Boss"
	_boss.position = boss_spawn_position
	
	# Match collision mask from FinalWorld.tscn
	if _boss is CharacterBody2D:
		_boss.collision_mask = 3
	
	# Add to scene
	var parent := get_parent()
	if parent != null:
		parent.add_child(_boss)
		if debug_logs:
			pass
	else:
		push_error("[FinalWorldController] No parent node found!")
	
	# Update EncounterHUDWiring to recognize new boss
	var hud_wiring := get_node_or_null("../UI/ScreenRoot/HUDRoot/EncounterHUDWiring")
	if hud_wiring != null:
		# Wait for multiple frames to ensure boss is fully in scene tree
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Update the boss path (relative from EncounterHUDWiring to Boss)
		if hud_wiring.has_method("set"):
			hud_wiring.set("boss_path", NodePath("../../../../Boss"))
			if debug_logs:
				pass
		
		# Refresh the boss connection to update name and health
		if hud_wiring.has_method("refresh_boss_connection"):
			hud_wiring.call("refresh_boss_connection")
			if debug_logs:
				pass
				# Debug: check what boss name was retrieved
				if _boss != null and _boss.has_method("get_boss_name"):
					pass
		else:
			if debug_logs:
				pass
	else:
		if debug_logs:
			pass
	
	# DON'T clear transition data yet - we need it for the victory screen!
	# It will be cleared when the player leaves FinalWorld
	
	# Complete setup with fade-in
	_complete_setup()

func _complete_setup() -> void:
	"""Fade in and start encounter"""
	if debug_logs:
		pass
	
	# Wait a frame for everything to settle
	await get_tree().process_frame

	# Set arena camera while fade is still black.
	_activate_final_boss_arena_camera()
	
	# Fade in
	if _fade_rect != null:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(_fade_rect, "color:a", 0.0, fade_in_duration)
		await tween.finished
		_fade_rect.visible = false
		if debug_logs:
			pass
	
	# Configure boss for pure DPS fight (no immunity, no encounter system)
	if _boss != null:
		if debug_logs:
			pass
		
		# Connect boss death signal
		if _boss.has_signal("died"):
			_boss.died.connect(_on_boss_died)
			if debug_logs:
				pass
		
		# Make boss vulnerable and enable attacks immediately
		if _boss.has_method("set_vulnerable"):
			_boss.set_vulnerable(true)
			if debug_logs:
				pass
		
		if _boss.has_method("set_attacks_enabled"):
			_boss.set_attacks_enabled(true)
			if debug_logs:
				pass
		
		if debug_logs:
			pass
	else:
		push_warning("[FinalWorldController] Boss not found, cannot start encounter")
	
	if debug_logs:
		pass

func _activate_final_boss_arena_camera() -> void:
	if not enable_final_boss_arena_camera:
		return
	if _final_boss_camera_activated:
		return
	_final_boss_camera_activated = true

	var boss_cam: Camera2D = get_node_or_null(final_boss_arena_camera_path) as Camera2D
	if boss_cam == null:
		push_warning("[FinalWorldController] Final boss arena camera not found: %s" % String(final_boss_arena_camera_path))
		return
	_final_boss_camera_ref = boss_cam

	var player: Node2D = get_node_or_null("../Player") as Node2D
	if player != null:
		var player_cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if player_cam != null:
			boss_cam.global_position = player_cam.global_position
			boss_cam.zoom = player_cam.zoom
		else:
			boss_cam.global_position = player.global_position
			boss_cam.zoom = Vector2.ONE

	boss_cam.limit_left = int(final_boss_camera_left)
	boss_cam.limit_right = int(final_boss_camera_right)
	boss_cam.limit_top = int(final_boss_camera_top)
	boss_cam.limit_bottom = int(final_boss_camera_bottom)
	boss_cam.position_smoothing_enabled = false
	boss_cam.enabled = true
	boss_cam.make_current()

	var center: Vector2 = _get_final_boss_camera_target_center()
	var target_zoom: Vector2 = _get_final_boss_arena_fit_zoom()
	var duration: float = maxf(final_boss_camera_transition_time, 0.01)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(boss_cam, "global_position", center, duration)
	if final_boss_camera_auto_fit_zoom:
		tween.parallel().tween_property(boss_cam, "zoom", target_zoom, duration)

func _get_final_boss_camera_target_center() -> Vector2:
	if final_boss_camera_use_manual_center:
		return final_boss_camera_center
	return Vector2(
		(final_boss_camera_left + final_boss_camera_right) * 0.5,
		(final_boss_camera_top + final_boss_camera_bottom) * 0.5
	)

func _get_final_boss_arena_fit_zoom() -> Vector2:
	if not final_boss_camera_auto_fit_zoom:
		return Vector2.ONE
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.ONE
	var view_size: Vector2 = vp.get_visible_rect().size
	var arena_w: float = absf(final_boss_camera_right - final_boss_camera_left) + final_boss_camera_fit_padding_px * 2.0
	var arena_h: float = absf(final_boss_camera_bottom - final_boss_camera_top) + final_boss_camera_fit_padding_px * 2.0
	if arena_w <= 1.0 or arena_h <= 1.0:
		return Vector2.ONE
	var zx: float = view_size.x / arena_w
	var zy: float = view_size.y / arena_h
	var z: float = minf(zx, zy)
	z = clampf(z, final_boss_camera_min_zoom, final_boss_camera_max_zoom)
	return Vector2(z, z)

func _update_final_boss_camera_live_tuning() -> void:
	if not enable_final_boss_arena_camera:
		return
	if not final_boss_camera_live_tuning:
		return
	if not _final_boss_camera_activated:
		return
	if _final_boss_camera_ref == null or not is_instance_valid(_final_boss_camera_ref):
		_final_boss_camera_ref = get_node_or_null(final_boss_arena_camera_path) as Camera2D
		if _final_boss_camera_ref == null:
			return
	if not _final_boss_camera_ref.is_current():
		_final_boss_camera_ref.enabled = true
		_final_boss_camera_ref.make_current()
	_final_boss_camera_ref.limit_left = int(final_boss_camera_left)
	_final_boss_camera_ref.limit_right = int(final_boss_camera_right)
	_final_boss_camera_ref.limit_top = int(final_boss_camera_top)
	_final_boss_camera_ref.limit_bottom = int(final_boss_camera_bottom)
	if final_boss_camera_auto_fit_zoom:
		_final_boss_camera_ref.zoom = _get_final_boss_arena_fit_zoom()
	if final_boss_camera_use_manual_center:
		_final_boss_camera_ref.global_position = _get_final_boss_camera_target_center()

func _on_boss_died() -> void:
	"""Handle final boss death - show victory screen"""
	if debug_logs:
		pass
	
	if _victory_screen == null or not is_instance_valid(_victory_screen):
		push_error("[FinalWorldController] Victory screen not available!")
		return
	
	# Get the dice roll result that selected this boss
	var current_dice: int = 10
	var new_dice: int = 10
	
	if FinalBossTransitionData != null and FinalBossTransitionData.has_data:
		new_dice = FinalBossTransitionData.dice_result
		if debug_logs:
			pass
	else:
		# Fallback: check RunStateSingleton
		if RunStateSingleton != null:
			current_dice = RunStateSingleton.starting_dice_min
			new_dice = current_dice
			if debug_logs:
				pass
	
	# Show victory screen with animation
	if _victory_screen.has_method("show_victory"):
		_victory_screen.show_victory(current_dice, new_dice)
		if debug_logs:
			pass
	else:
		push_error("[FinalWorldController] Victory screen missing show_victory method!")

func _on_play_again_pressed() -> void:
	"""Handle Play Again - Load World1 with new dice range"""
	if debug_logs:
		pass
	
	# Clear transition data before leaving
	if FinalBossTransitionData != null:
		FinalBossTransitionData.clear_data()
	
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file("res://scenes/world/World1.tscn")
	else:
		push_error("[FinalWorldController] SceneTree not available!")

func _on_main_menu_pressed() -> void:
	"""Handle Main Menu - Return to main menu"""
	if debug_logs:
		pass
	
	# Clear transition data before leaving
	if FinalBossTransitionData != null:
		FinalBossTransitionData.clear_data()
	
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	else:
		push_error("[FinalWorldController] SceneTree not available!")

func _on_victory_input_lock_changed(locked: bool) -> void:
	"""Handle victory screen input lock state changes"""
	if debug_logs:
		pass
	
	# Find player and lock/unlock input
	var player := get_node_or_null("../Player")
	if player != null:
		# Try the correct method first
		if player.has_method("set_input_locked"):
			player.set_input_locked(locked)
			if debug_logs:
				pass
		elif player.has_method("set_controls_enabled"):
			player.set_controls_enabled(not locked)
			if debug_logs:
				pass
		else:
			# Fallback: directly disable processing
			player.set_process_input(not locked)
			player.set_process_unhandled_input(not locked)
			if debug_logs:
				pass
	else:
		if debug_logs:
			pass
