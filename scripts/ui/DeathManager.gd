extends Node
class_name DeathManager

@export var player_health_path: NodePath = ^"../../Player/Health"
@export var player_controller_path: NodePath = ^"../../Player"

@export var overlay_path: NodePath = ^"../DeathOverlay"
@export var fade_rect_path: NodePath = ^"../DeathOverlay/Fade"
@export var you_died_label_path: NodePath = ^"../DeathOverlay/YouDied"
@export var press_enter_label_path: NodePath = ^"../DeathOverlay/PressEnter"

@export var debug_death: bool = true

@export var reset_run_on_retry: bool = true
@export var fade_in_time: float = 0.6
@export var accept_action: StringName = &"ui_accept"

# wait before showing overlay (lets death anim land)
@export var pre_overlay_delay: float = 1.2

# Run Summary (reusable panel)
@export var style: HUDStyle
@export var design_height: float = 1440.0
@export var run_summary_path: NodePath = ^"../DeathOverlay/RunSummaryPanel"
@export var death_summary_top_y_design: float = 90.0

var _health: PlayerHealth = null
var _player: Node = null

var _overlay: Control = null
var _fade: ColorRect = null
var _you_died: Label = null
var _press_enter: Label = null

var _run_summary: RunSummaryPanel = null

var _running: bool = false
var _waiting_for_accept: bool = false


func _ready() -> void:
	_health = get_node_or_null(player_health_path) as PlayerHealth
	_player = get_node_or_null(player_controller_path)

	_overlay = get_node_or_null(overlay_path) as Control
	_fade = get_node_or_null(fade_rect_path) as ColorRect
	_you_died = get_node_or_null(you_died_label_path) as Label
	_press_enter = get_node_or_null(press_enter_label_path) as Label

	_run_summary = get_node_or_null(run_summary_path) as RunSummaryPanel

	if _overlay == null or _fade == null or _you_died == null or _press_enter == null:
		push_warning("[Death] Missing UI nodes. Check DeathOverlay paths.")
		return

	# Start hidden
	_overlay.visible = false
	_set_fade_alpha(0.0)
	_set_label_alpha(_you_died, 0.0)
	_set_label_alpha(_press_enter, 0.0)

	# Run summary starts hidden + configured
	if _run_summary != null:
		_run_summary.visible = false
		
		# IMPORTANT: don't overwrite the panel's style with null
		if style != null:
			_run_summary.style = style
			_run_summary.design_height = design_height
		elif _run_summary.style != null:
			# fallback to panel-provided style
			style = _run_summary.style
			design_height = _run_summary.design_height
		_run_summary.show_subtitle = false # death screen: no subtitle

	_waiting_for_accept = false
	set_process_unhandled_input(false)

	if _health != null and not _health.died.is_connected(_on_player_died):
		_health.died.connect(_on_player_died)

	# Resize handling (re-layout the run summary if it is visible)
	get_viewport().size_changed.connect(func() -> void:
		if _run_summary != null and _run_summary.visible and style != null:
			_layout_run_summary()
	)

	if debug_death:
		pass

func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_for_accept:
		return

	if event.is_action_pressed(accept_action):
		_waiting_for_accept = false
		_reload_scene()


func _on_player_died() -> void:
	if debug_death:
		pass
	if _running:
		return
	_running = true

	_waiting_for_accept = false
	set_process_unhandled_input(false)

	# Reset overlay
	_overlay.visible = false
	_set_fade_alpha(0.0)
	_set_label_alpha(_you_died, 0.0)
	_set_label_alpha(_press_enter, 0.0)

	if _run_summary != null:
		_run_summary.visible = false

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if pre_overlay_delay > 0.0:
		tween.tween_interval(pre_overlay_delay)

	tween.tween_callback(Callable(self, "_begin_death_overlay_flow"))

	# Fade screen
	tween.tween_method(Callable(self, "_set_fade_alpha"), 0.0, 1.0, fade_in_time)

	# Fade in YOU DIED
	tween.tween_interval(0.10)
	tween.tween_method(
		func(a: float) -> void:
			_set_label_alpha(_you_died, a),
		0.0, 1.0, 1.2
	)

	# Fade in Press Enter after
	tween.tween_interval(0.25)
	tween.tween_method(
		func(a: float) -> void:
			_set_label_alpha(_press_enter, a),
		0.0, 1.0, 1.2
	)

	tween.tween_callback(Callable(self, "_enable_accept"))


func _begin_death_overlay_flow() -> void:
	if debug_death:
		pass

	_disable_player()
	_overlay.visible = true

	# Show + layout run summary (top-center)
	if _run_summary != null:
		# Never overwrite the panel's style with null
		if style != null:
			_run_summary.style = style
			_run_summary.design_height = design_height

		_run_summary.show_subtitle = false
		_run_summary.visible = true
		_layout_run_summary()
		

func _layout_run_summary() -> void:
	if _run_summary == null:
		return

	# Use DeathManager style if set, otherwise the panel's own style
	var s: HUDStyle = style if style != null else _run_summary.style
	if s == null:
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ui_scale: float = s.ui_scale_for_viewport(vp, design_height)

	var top_y: float = s.s(death_summary_top_y_design, ui_scale)
	var max_w: float = vp.x * 0.92

	_run_summary.layout_top_center(max_w, top_y)

func _enable_accept() -> void:
	_waiting_for_accept = true
	set_process_unhandled_input(true)


func _disable_player() -> void:
	if _player == null:
		return

	# Optional hook if your PlayerController supports it
	if _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", false)

	_player.set_process(false)
	_player.set_physics_process(false)


func _reload_scene() -> void:
	"""Reset to World1 with starting dice range on death"""
	if reset_run_on_retry and RunStateSingleton != null:
		# Start a new run - clears relics, modifiers, resets to starting dice range
		if RunStateSingleton.has_method("start_new_run"):
			RunStateSingleton.start_new_run()
			if debug_death:
				pass
		elif RunStateSingleton.has_method("reset_on_death_and_retry"):
			RunStateSingleton.reset_on_death_and_retry()
	
	# Always return to World1 (not reload current scene)
	if debug_death:
		pass
	get_tree().change_scene_to_file("res://scenes/world/World1.tscn")


func _set_fade_alpha(a: float) -> void:
	var c := _fade.color
	c.a = a
	_fade.color = c


func _set_label_alpha(label: Label, a: float) -> void:
	var m := label.modulate
	m.a = a
	label.modulate = m
