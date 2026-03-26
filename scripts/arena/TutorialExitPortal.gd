extends Node2D
class_name TutorialExitPortal

@export var interact_action: StringName = &"interact"
@export var player_path: NodePath = ^"../Player"
@export var destination_spawn_path: NodePath = ^"../Arena/Spawns/PlayerSpawn"
@export var encounter_controller_path: NodePath = ^"../EncounterController"
@export var encounter_hud_wiring_path: NodePath = ^"../UI/ScreenRoot/HUDRoot/EncounterHUDWiring"
@export var boss_path: NodePath = ^"../Boss"
@export var fade_rect_path: NodePath = ^"../UI/ScreenRoot/HUDRoot/TeleportFade"
@export var intro_overlay_path: NodePath = ^"../TutorialIntroOverlay"
@export var intro_dim_path: NodePath = ^"../TutorialIntroOverlay/Dim"
@export var intro_dialog_path: NodePath = ^"../TutorialIntroOverlay/IntroDialog"
@export var intro_text_path: NodePath = ^"../TutorialIntroOverlay/IntroDialog/Margin/VBox/LoreText"
@export var intro_hint_path: NodePath = ^"../TutorialIntroOverlay/IntroDialog/Margin/VBox/HintText"
@export var anim_fps: float = 10.0
@export var total_frames: int = 15
@export var fade_out_time: float = 0.5
@export var hidden_camera_settle_time: float = 0.85
@export var fade_in_time: float = 0.45
@export var boss_hud_hidden_floor_gate: int = 5
@export var boss_hud_visible_floor_gate: int = 1
@export var intro_dialog_fade_time: float = 0.28
@export var intro_dim_alpha: float = 0.72
@export_multiline var boss_intro_text: String = "You have come far, chosen one.\n\nI am the Dice God, and this is your final test.\nProve your strength."
@export var boss_intro_hint_text: String = "Press Enter to begin the final test."

@export_group("Tutorial Boss Arena Camera")
@export var enable_tutorial_boss_arena_camera: bool = true
@export var tutorial_boss_use_player_camera: bool = true
@export var tutorial_boss_arena_camera_path: NodePath = ^"../BossArenaCamera"
@export var tutorial_boss_camera_left: float = 10180.0
@export var tutorial_boss_camera_right: float = 13420.0
@export var tutorial_boss_camera_top: float = -1080.0
@export var tutorial_boss_camera_bottom: float = 2200.0
@export var tutorial_boss_camera_transition_time: float = 0.75
@export var tutorial_boss_camera_live_tuning: bool = false
@export var tutorial_boss_camera_use_center_marker: bool = true
@export var tutorial_boss_camera_center_marker_path: NodePath = ^"../BossArenaCenter"
@export var tutorial_boss_camera_use_manual_center: bool = false
@export var tutorial_boss_camera_center: Vector2 = Vector2(11797.0, 241.0)
@export var tutorial_boss_camera_auto_fit_zoom: bool = true
@export var tutorial_boss_camera_fit_padding_px: float = 80.0
@export var tutorial_boss_camera_min_zoom: float = 0.5
@export var tutorial_boss_camera_max_zoom: float = 1.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _interaction_area: Area2D = $InteractionArea

var _player_nearby: bool = false
var _used: bool = false
var _anim_accum: float = 0.0
var _player: CharacterBody2D = null
var _destination_spawn: Node2D = null
var _fade_rect: ColorRect = null
var _transition_in_progress: bool = false
var _tutorial_boss_camera_activated: bool = false
var _tutorial_boss_camera_ref: Camera2D = null
var _tutorial_boss_center_marker: Node2D = null
var _encounter_controller: Node = null
var _encounter_hud_wiring: Node = null
var _boss_node: CanvasItem = null
var _intro_overlay: CanvasLayer = null
var _intro_dim: ColorRect = null
var _intro_dialog: PanelContainer = null
var _intro_text: Label = null
var _intro_hint: Label = null

func _ready() -> void:
	if _interaction_area != null:
		if not _interaction_area.body_entered.is_connected(_on_body_entered):
			_interaction_area.body_entered.connect(_on_body_entered)
		if not _interaction_area.body_exited.is_connected(_on_body_exited):
			_interaction_area.body_exited.connect(_on_body_exited)
	_player = get_node_or_null(player_path) as CharacterBody2D
	_destination_spawn = get_node_or_null(destination_spawn_path) as Node2D
	_encounter_controller = get_node_or_null(encounter_controller_path)
	_encounter_hud_wiring = get_node_or_null(encounter_hud_wiring_path)
	_boss_node = get_node_or_null(boss_path) as CanvasItem
	_fade_rect = get_node_or_null(fade_rect_path) as ColorRect
	_intro_overlay = get_node_or_null(intro_overlay_path) as CanvasLayer
	_intro_dim = get_node_or_null(intro_dim_path) as ColorRect
	_intro_dialog = get_node_or_null(intro_dialog_path) as PanelContainer
	_intro_text = get_node_or_null(intro_text_path) as Label
	_intro_hint = get_node_or_null(intro_hint_path) as Label
	_tutorial_boss_center_marker = get_node_or_null(tutorial_boss_camera_center_marker_path) as Node2D
	add_to_group(&"portal")
	add_to_group(&"interactable")
	set_process(true)
	_set_boss_hud_enabled(false)

func _process(delta: float) -> void:
	_tick_anim(delta)
	_update_tutorial_boss_camera_live_tuning()
	if _used or _transition_in_progress or not _player_nearby:
		return
	if Input.is_action_just_pressed(interact_action):
		_transition_in_progress = true
		call_deferred("_run_tutorial_portal_transition")

func _tick_anim(delta: float) -> void:
	if _sprite == null:
		return
	var fps: float = maxf(anim_fps, 0.01)
	var frames_count: int = maxi(total_frames, 1)
	_anim_accum += maxf(delta, 0.0)
	var step: float = 1.0 / fps
	while _anim_accum >= step:
		_anim_accum -= step
		_sprite.frame = (_sprite.frame + 1) % frames_count

func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if body.is_in_group(&"player"):
		_player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return
	if body.is_in_group(&"player"):
		_player_nearby = false

func _run_tutorial_portal_transition() -> void:
	if _player == null:
		_transition_in_progress = false
		return
	_set_player_cutscene_lock(true)
	_set_player_input_locked(true)
	await _fade_screen(0.0, 1.0, maxf(fade_out_time, 0.01))
	_set_player_visible(false)
	_teleport_player_to_spawn()
	_activate_tutorial_boss_arena_camera()
	_set_boss_hud_enabled(true)
	var hidden_settle: float = maxf(hidden_camera_settle_time, _get_tutorial_boss_camera_hidden_settle_time())
	if hidden_settle > 0.0:
		await get_tree().create_timer(hidden_settle).timeout
	_set_player_visible(true)
	# Prime the intro overlay while screen is still black so fade-in reveals it immediately.
	_show_boss_intro_overlay()
	await _fade_screen(1.0, 0.0, maxf(fade_in_time, 0.01))
	await _run_boss_intro_gate(false)
	_begin_tutorial_boss_encounter()
	_set_player_cutscene_lock(false)
	_set_player_input_locked(false)
	_used = true
	_transition_in_progress = false

func _teleport_player_to_spawn() -> void:
	if _player == null:
		return
	if _destination_spawn != null and is_instance_valid(_destination_spawn):
		_player.global_position = _destination_spawn.global_position
	if "velocity" in _player:
		_player.velocity = Vector2.ZERO
	var player_cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if player_cam != null:
		player_cam.reset_smoothing()

func _set_player_input_locked(locked: bool) -> void:
	if _player == null:
		return
	if _player.has_method("set_input_locked"):
		_player.call("set_input_locked", locked)
		return
	if "input_locked" in _player:
		_player.set("input_locked", locked)

func _set_player_cutscene_lock(locked: bool) -> void:
	if _player == null:
		return
	if _player.has_method("set_cutscene_motion_lock"):
		_player.call("set_cutscene_motion_lock", locked)
		return
	_set_player_input_locked(locked)

func _set_player_visible(vis: bool) -> void:
	if _player == null:
		return
	var visual: CanvasItem = _player.get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.visible = vis

func _set_fade_alpha(alpha: float) -> void:
	if _fade_rect == null:
		return
	var c: Color = _fade_rect.color
	c.a = alpha
	_fade_rect.color = c

func _fade_screen(from_alpha: float, to_alpha: float, duration: float) -> void:
	if _fade_rect == null:
		_fade_rect = _create_runtime_fade_rect()
	if _fade_rect == null:
		await get_tree().create_timer(duration).timeout
		return
	_fade_rect.visible = true
	_set_fade_alpha(from_alpha)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_fade_alpha, from_alpha, to_alpha, duration)
	await tween.finished
	if is_equal_approx(to_alpha, 0.0):
		_fade_rect.visible = false

func _create_runtime_fade_rect() -> ColorRect:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TutorialPortalFadeLayer"
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.current_scene.add_child(layer)
	var rect: ColorRect = ColorRect.new()
	rect.name = "TutorialPortalFade"
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	layer.add_child(rect)
	return rect

func _activate_tutorial_boss_arena_camera() -> void:
	if not enable_tutorial_boss_arena_camera:
		return
	var boss_cam: Camera2D = _resolve_tutorial_boss_camera_target()
	if boss_cam == null:
		return
	_tutorial_boss_camera_ref = boss_cam
	_tutorial_boss_camera_activated = true
	if _player != null:
		var player_cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
		if player_cam != null:
			boss_cam.global_position = player_cam.global_position
			boss_cam.zoom = player_cam.zoom
		else:
			boss_cam.global_position = _player.global_position
			boss_cam.zoom = Vector2.ONE
	boss_cam.limit_left = int(tutorial_boss_camera_left)
	boss_cam.limit_right = int(tutorial_boss_camera_right)
	boss_cam.limit_top = int(tutorial_boss_camera_top)
	boss_cam.limit_bottom = int(tutorial_boss_camera_bottom)
	boss_cam.position_smoothing_enabled = false
	boss_cam.enabled = true
	boss_cam.make_current()
	var center: Vector2 = _get_tutorial_boss_camera_target_center()
	var target_zoom: Vector2 = _get_tutorial_boss_arena_fit_zoom()
	var duration: float = maxf(tutorial_boss_camera_transition_time, 0.01)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(boss_cam, "global_position", center, duration)
	if tutorial_boss_camera_auto_fit_zoom:
		tween.parallel().tween_property(boss_cam, "zoom", target_zoom, duration)

func _get_tutorial_boss_camera_target_center() -> Vector2:
	if tutorial_boss_camera_use_center_marker:
		if _tutorial_boss_center_marker == null or not is_instance_valid(_tutorial_boss_center_marker):
			_tutorial_boss_center_marker = get_node_or_null(tutorial_boss_camera_center_marker_path) as Node2D
		if _tutorial_boss_center_marker != null and is_instance_valid(_tutorial_boss_center_marker):
			return _tutorial_boss_center_marker.global_position
	if tutorial_boss_camera_use_manual_center:
		return tutorial_boss_camera_center
	return Vector2(
		(tutorial_boss_camera_left + tutorial_boss_camera_right) * 0.5,
		(tutorial_boss_camera_top + tutorial_boss_camera_bottom) * 0.5
	)

func _get_tutorial_boss_arena_fit_zoom() -> Vector2:
	if not tutorial_boss_camera_auto_fit_zoom:
		return Vector2.ONE
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.ONE
	var view_size: Vector2 = vp.get_visible_rect().size
	var arena_w: float = absf(tutorial_boss_camera_right - tutorial_boss_camera_left) + tutorial_boss_camera_fit_padding_px * 2.0
	var arena_h: float = absf(tutorial_boss_camera_bottom - tutorial_boss_camera_top) + tutorial_boss_camera_fit_padding_px * 2.0
	if arena_w <= 1.0 or arena_h <= 1.0:
		return Vector2.ONE
	var zx: float = view_size.x / arena_w
	var zy: float = view_size.y / arena_h
	var z: float = minf(zx, zy)
	z = clampf(z, tutorial_boss_camera_min_zoom, tutorial_boss_camera_max_zoom)
	return Vector2(z, z)

func _update_tutorial_boss_camera_live_tuning() -> void:
	if not enable_tutorial_boss_arena_camera or not tutorial_boss_camera_live_tuning:
		return
	# Do not apply boss camera tuning before portal transition starts.
	if not _tutorial_boss_camera_activated:
		return
	if tutorial_boss_use_player_camera:
		_tutorial_boss_camera_ref = _get_player_camera()
	if _tutorial_boss_camera_ref == null or not is_instance_valid(_tutorial_boss_camera_ref):
		_tutorial_boss_camera_ref = _resolve_tutorial_boss_camera_target()
		if _tutorial_boss_camera_ref == null:
			return
	if not _tutorial_boss_camera_ref.is_current():
		_tutorial_boss_camera_ref.enabled = true
		_tutorial_boss_camera_ref.make_current()
	_tutorial_boss_camera_ref.limit_left = int(tutorial_boss_camera_left)
	_tutorial_boss_camera_ref.limit_right = int(tutorial_boss_camera_right)
	_tutorial_boss_camera_ref.limit_top = int(tutorial_boss_camera_top)
	_tutorial_boss_camera_ref.limit_bottom = int(tutorial_boss_camera_bottom)
	if tutorial_boss_camera_auto_fit_zoom:
		_tutorial_boss_camera_ref.zoom = _get_tutorial_boss_arena_fit_zoom()
	if tutorial_boss_camera_use_center_marker or tutorial_boss_camera_use_manual_center:
		_tutorial_boss_camera_ref.global_position = _get_tutorial_boss_camera_target_center()

func _get_tutorial_boss_camera_hidden_settle_time() -> float:
	if not enable_tutorial_boss_arena_camera:
		return 0.0
	return maxf(tutorial_boss_camera_transition_time, 0.0)

func _resolve_tutorial_boss_camera_target() -> Camera2D:
	if tutorial_boss_use_player_camera:
		return _get_player_camera()
	var scene_cam: Camera2D = get_node_or_null(tutorial_boss_arena_camera_path) as Camera2D
	if scene_cam != null:
		return scene_cam
	return _get_player_camera()

func _get_player_camera() -> Camera2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as CharacterBody2D
	if _player == null:
		return null
	return _player.get_node_or_null("Camera2D") as Camera2D

func _begin_tutorial_boss_encounter() -> void:
	if _boss_node != null and is_instance_valid(_boss_node):
		_boss_node.visible = true
	if _encounter_controller == null or not is_instance_valid(_encounter_controller):
		return
	if _encounter_controller.has_method("begin_boss_encounter"):
		_encounter_controller.call("begin_boss_encounter")

func _set_boss_hud_enabled(enabled: bool) -> void:
	if _encounter_hud_wiring == null or not is_instance_valid(_encounter_hud_wiring):
		return
	if "boss_floor" in _encounter_hud_wiring:
		_encounter_hud_wiring.set("boss_floor", boss_hud_visible_floor_gate if enabled else boss_hud_hidden_floor_gate)
	if _encounter_hud_wiring.has_method("_update_boss_hud_visibility"):
		_encounter_hud_wiring.call("_update_boss_hud_visibility")
	if enabled and _encounter_hud_wiring.has_method("_poll_boss_health_into_hud"):
		_encounter_hud_wiring.call("_poll_boss_health_into_hud")

func _run_boss_intro_gate(show_overlay: bool = true) -> void:
	if show_overlay:
		_show_boss_intro_overlay()
	await _wait_for_boss_intro_confirm()
	await _fade_out_boss_intro_overlay()

func _show_boss_intro_overlay() -> void:
	if _intro_overlay != null:
		_intro_overlay.visible = true
	if _intro_dim != null:
		_intro_dim.visible = true
		var dim_color: Color = _intro_dim.color
		dim_color.a = clampf(intro_dim_alpha, 0.0, 1.0)
		_intro_dim.color = dim_color
	if _intro_dialog != null:
		_intro_dialog.visible = true
		_intro_dialog.modulate.a = 1.0
	if _intro_text != null:
		_intro_text.text = boss_intro_text
	if _intro_hint != null:
		_intro_hint.text = boss_intro_hint_text

func _wait_for_boss_intro_confirm() -> void:
	while true:
		await get_tree().process_frame
		if _is_intro_advance_pressed():
			return

func _is_intro_advance_pressed() -> bool:
	if Input.is_action_just_pressed(&"ui_accept"):
		return true
	if Input.is_key_pressed(KEY_ENTER):
		return true
	return Input.is_key_pressed(KEY_KP_ENTER)

func _fade_out_boss_intro_overlay() -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _intro_dialog != null and _intro_dialog.visible:
		tween.parallel().tween_property(_intro_dialog, "modulate:a", 0.0, maxf(intro_dialog_fade_time, 0.01))
	if _intro_dim != null and _intro_dim.visible:
		tween.parallel().tween_property(_intro_dim, "color:a", 0.0, maxf(intro_dialog_fade_time + 0.06, 0.01))
	await tween.finished
	if _intro_dialog != null:
		_intro_dialog.visible = false
	if _intro_dim != null:
		_intro_dim.visible = false
	if _intro_overlay != null:
		_intro_overlay.visible = false
