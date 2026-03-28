extends Control
class_name PauseMenu

signal resume_pressed()
signal settings_pressed()
signal quit_confirmed()

@export var style: HUDStyle
@export var design_height: float = 1440.0
@export var settings_menu_scene: PackedScene  # Reference to SettingsMenu.tscn

# Layout
@export var summary_to_button_gap: float = 50.0  # Gap between RunSummary bottom and Resume button top

@export_group("Debug")
@export var debug_reset_run_enabled: bool = false
@export var debug_reset_world_scene_path: String = "res://scenes/world/World1.tscn"

# Button sizing (match MainMenu style)
@export var button_width: float = 900.0
@export var button_font_size: int = 80
@export var button_spacing: float = 20.0

@onready var _overlay: ColorRect = $Overlay
@onready var _root: Control = $Root
@onready var _run_summary: RunSummaryPanel = $Root/RunSummaryPanel
@onready var _buttons_container: VBoxContainer = $Root/ButtonsContainer
@onready var _resume_button: Button = $Root/ButtonsContainer/ResumeButton
@onready var _settings_button: Button = $Root/ButtonsContainer/SettingsButton
@onready var _quit_button: Button = $Root/ButtonsContainer/QuitButton
@onready var _quit_to_desktop_button: Button = $Root/ButtonsContainer/QuitToDesktopButton
var _vfx_toggle_button: Button = null
@onready var _debug_reset_run_button: Button = get_node_or_null("Root/DebugToolsContainer/VBoxContainer/DebugResetRunButton") as Button
@onready var _confirm_dialog: Control = $Root/ConfirmDialog
@onready var _confirm_label: Label = $Root/ConfirmDialog/ConfirmPanel/VBox/ConfirmLabel
@onready var _confirm_yes_button: Button = $Root/ConfirmDialog/ConfirmPanel/VBox/ButtonsHBox/YesButton
@onready var _confirm_no_button: Button = $Root/ConfirmDialog/ConfirmPanel/VBox/ButtonsHBox/NoButton

var _is_open: bool = false
var _input_enabled: bool = false
var _settings_menu_instance: SettingsMenu = null
var _was_paused_before_open: bool = false
var _was_time_scale_before_open: float = 1.0

enum QuitAction { MAIN_MENU, DESKTOP, DEBUG_RESET_RUN }
var _pending_quit_action: QuitAction = QuitAction.MAIN_MENU

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set up overlay
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Configure run summary
	if _run_summary != null:
		_run_summary.visible = false
		if style != null:
			_run_summary.style = style
			_run_summary.design_height = design_height
		_run_summary.show_subtitle = false  # No subtitle in pause menu
	
	# Set pivot offsets for button scaling (scale from center)
	if _resume_button != null:
		_resume_button.pivot_offset = _resume_button.size / 2.0
	if _settings_button != null:
		_settings_button.pivot_offset = _settings_button.size / 2.0
	if _quit_button != null:
		_quit_button.pivot_offset = _quit_button.size / 2.0
	if _quit_to_desktop_button != null:
		_quit_to_desktop_button.pivot_offset = _quit_to_desktop_button.size / 2.0
	if _debug_reset_run_button != null:
		_debug_reset_run_button.pivot_offset = _debug_reset_run_button.size / 2.0
	if _confirm_yes_button != null:
		_confirm_yes_button.pivot_offset = _confirm_yes_button.size / 2.0
	if _confirm_no_button != null:
		_confirm_no_button.pivot_offset = _confirm_no_button.size / 2.0
	
	# Connect button pressed signals
	if _resume_button != null:
		_resume_button.pressed.connect(_on_resume_pressed)
	if _settings_button != null:
		_settings_button.pressed.connect(_on_settings_pressed)
	_create_vfx_toggle_button()
	if _quit_button != null:
		_quit_button.pressed.connect(_on_quit_pressed)
	if _quit_to_desktop_button != null:
		_quit_to_desktop_button.pressed.connect(_on_quit_to_desktop_pressed)
	if _debug_reset_run_button != null:
		_debug_reset_run_button.pressed.connect(_on_debug_reset_run_pressed)
	
	# Connect confirmation dialog buttons
	if _confirm_yes_button != null:
		_confirm_yes_button.pressed.connect(_on_confirm_yes)
	if _confirm_no_button != null:
		_confirm_no_button.pressed.connect(_on_confirm_no)
	
	# ✨ Connect hover signals for button scaling effect (matches MainMenu style)
	_connect_button_hover_effects()
	
	# Hide confirmation dialog initially
	if _confirm_dialog != null:
		_confirm_dialog.visible = false

	_configure_debug_tools()
	
	# Start hidden but input enabled (so we can open it!)
	visible = false
	_is_open = false
	_input_enabled = true  # ⚡ FIXED: Must be true to receive input
	
	# Handle viewport resize
	get_viewport().size_changed.connect(_on_viewport_resized)


func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	
	# Toggle pause menu with "menu" action
	if event.is_action_pressed("menu"):
		if _is_open:
			if _confirm_dialog != null and _confirm_dialog.visible:
				# Close confirmation dialog instead of closing pause menu
				_hide_confirmation_dialog()
			else:
				close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	
	_is_open = true
	visible = true
	# _input_enabled stays true (set in _ready)
	
	# Capture previous pause state so we can restore it on close.
	# This prevents unpausing flows that intentionally paused the tree
	# (e.g. DiceModifierChoice while selecting a modifier).
	_was_paused_before_open = get_tree().paused
	_was_time_scale_before_open = Engine.time_scale

	# Hard pause:
	# 1) SceneTree pause stops normal/inherited processing.
	# 2) time_scale=0 freezes nodes that intentionally run in ALWAYS mode.
	get_tree().paused = true
	Engine.time_scale = 0.0
	
	# IMPORTANT: Layout buttons first, then run summary (so summary can position relative to buttons)
	_refresh_vfx_toggle_button_label()
	_layout_buttons()
	_layout_run_summary()
	
	# Emit signal if needed
	# (Could add an "opened" signal here if needed)


func close() -> void:
	if not _is_open:
		return
	
	_is_open = false
	visible = false
	# ⚡ FIXED: Keep _input_enabled true so we can reopen the menu
	
	# Restore pause state from before opening this menu.
	get_tree().paused = _was_paused_before_open
	Engine.time_scale = _was_time_scale_before_open
	
	resume_pressed.emit()


func _on_resume_pressed() -> void:
	close()


func _on_settings_pressed() -> void:
	"""Open settings menu"""
	if settings_menu_scene == null:
		push_warning("[PauseMenu] Settings menu scene not assigned!")
		return
	
	# Instantiate settings menu if not already created
	if _settings_menu_instance == null:
		var instance := settings_menu_scene.instantiate()
		_settings_menu_instance = instance as SettingsMenu
		if _settings_menu_instance == null:
			push_warning("[PauseMenu] Settings menu scene is not a SettingsMenu!")
			instance.queue_free()
			return
		
		# Add to root (same level as this menu)
		get_parent().add_child(_settings_menu_instance)
		
		# Copy style
		if style != null and _settings_menu_instance != null:
			_settings_menu_instance.style = style
		
		# Connect back signal
		_settings_menu_instance.back_pressed.connect(_on_settings_back)
	
	# Hide pause menu, show settings
	visible = false
	_settings_menu_instance.open()
	
	settings_pressed.emit()

func _on_vfx_toggle_pressed() -> void:
	var vfx_ctrl: Node = get_tree().root.get_node_or_null("VFXVisibilityController")
	if vfx_ctrl == null or not vfx_ctrl.has_method("toggle_vfx"):
		return
	vfx_ctrl.call("toggle_vfx")
	_refresh_vfx_toggle_button_label()

func _refresh_vfx_toggle_button_label() -> void:
	if _vfx_toggle_button == null:
		return
	var label: String = "VFX: ON"
	var vfx_ctrl: Node = get_tree().root.get_node_or_null("VFXVisibilityController")
	if vfx_ctrl != null and ("vfx_enabled" in vfx_ctrl):
		label = "VFX: ON" if bool(vfx_ctrl.get("vfx_enabled")) else "VFX: OFF"
	_vfx_toggle_button.text = label

func _create_vfx_toggle_button() -> void:
	if _buttons_container == null:
		return
	if _vfx_toggle_button != null:
		return
	_vfx_toggle_button = Button.new()
	_vfx_toggle_button.name = "VFXToggleButton"
	_vfx_toggle_button.custom_minimum_size = Vector2(button_width, 0.0)
	_vfx_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vfx_toggle_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_vfx_toggle_button.focus_mode = Control.FOCUS_ALL
	_vfx_toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_vfx_toggle_button.theme_type_variation = "MainMenuButton"
	_vfx_toggle_button.add_theme_font_size_override("font_size", button_font_size)
	_vfx_toggle_button.pressed.connect(_on_vfx_toggle_pressed)
	_vfx_toggle_button.mouse_entered.connect(_on_button_hover.bind(_vfx_toggle_button))
	_vfx_toggle_button.mouse_exited.connect(_on_button_unhover.bind(_vfx_toggle_button))
	_buttons_container.add_child(_vfx_toggle_button)
	_buttons_container.move_child(_vfx_toggle_button, 2)
	_vfx_toggle_button.pivot_offset = _vfx_toggle_button.size / 2.0
	_refresh_vfx_toggle_button_label()


func _on_settings_back() -> void:
	"""Return from settings menu to pause menu"""
	# Show pause menu again
	visible = true
	
	# Hide settings
	if _settings_menu_instance != null:
		_settings_menu_instance.visible = false


func _on_quit_pressed() -> void:
	_pending_quit_action = QuitAction.MAIN_MENU
	# Show confirmation dialog
	_show_confirmation_dialog()

func _on_quit_to_desktop_pressed() -> void:
	_pending_quit_action = QuitAction.DESKTOP
	_show_confirmation_dialog()

func _on_debug_reset_run_pressed() -> void:
	if not _is_debug_reset_available():
		return
	_pending_quit_action = QuitAction.DEBUG_RESET_RUN
	_show_confirmation_dialog()


func _show_confirmation_dialog() -> void:
	if _confirm_dialog == null:
		return
	
	_confirm_dialog.visible = true
	_confirm_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Update label text
	if _confirm_label != null:
		match _pending_quit_action:
			QuitAction.DESKTOP:
				_confirm_label.text = "Quit to desktop? Progress will be lost."
			QuitAction.DEBUG_RESET_RUN:
				_confirm_label.text = "Reset run and return to World 1? Progress will be lost."
			_:
				_confirm_label.text = "Are you sure? Progress will be lost."


func _hide_confirmation_dialog() -> void:
	if _confirm_dialog == null:
		return
	
	_confirm_dialog.visible = false
	_confirm_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_confirm_yes() -> void:
	_hide_confirmation_dialog()
	
	# Unpause before changing scene
	get_tree().paused = false
	Engine.time_scale = _was_time_scale_before_open

	if _pending_quit_action == QuitAction.DEBUG_RESET_RUN:
		_perform_debug_reset_run()
		return
	
	# Emit quit signal (handled by scene to clean up/return to main menu)
	quit_confirmed.emit()

	if _pending_quit_action == QuitAction.DESKTOP:
		get_tree().quit()
		return
	
	# Return to main menu
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/MainMenu.tscn")

func _perform_debug_reset_run() -> void:
	if RunStateSingleton != null:
		if RunStateSingleton.has_method("start_new_run"):
			RunStateSingleton.start_new_run()
		elif RunStateSingleton.has_method("reset_on_death_and_retry"):
			RunStateSingleton.reset_on_death_and_retry()
	var target_scene: String = debug_reset_world_scene_path.strip_edges()
	if target_scene == "":
		target_scene = "res://scenes/world/World1.tscn"
	get_tree().call_deferred("change_scene_to_file", target_scene)

func _is_debug_reset_available() -> bool:
	return debug_reset_run_enabled and OS.is_debug_build()

func _configure_debug_tools() -> void:
	if _debug_reset_run_button == null:
		return
	var enabled: bool = _is_debug_reset_available()
	_debug_reset_run_button.visible = enabled


func _on_confirm_no() -> void:
	_hide_confirmation_dialog()


func _layout_run_summary() -> void:
	if _run_summary == null or style == null or _buttons_container == null:
		return
	
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var max_w: float = vp.x * 0.92  # 92% of screen width
	
	# Position above the Resume button with specified gap
	var buttons_top_y: float = _buttons_container.position.y
	
	# We need to account for the summary panel's height
	# First, let it calculate its size
	_run_summary.visible = true
	_run_summary.layout_top_center(max_w, 0)  # Temp position to calculate size
	
	# Now position it properly (gap above buttons, accounting for its height)
	var summary_bottom_y: float = buttons_top_y - summary_to_button_gap
	var summary_top_y: float = summary_bottom_y - _run_summary.size.y
	
	_run_summary.layout_top_center(max_w, summary_top_y)


func _layout_buttons() -> void:
	if _buttons_container == null:
		return
	
	# Center buttons on screen
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_buttons_container.position = Vector2(
		(vp.x - button_width) * 0.5,
		vp.y * 0.5 - 100.0  # Slightly above center
	)
	
	_buttons_container.custom_minimum_size = Vector2(button_width, 0)


func _on_viewport_resized() -> void:
	if _is_open:
		# Layout buttons first, then run summary (so summary positions relative to buttons)
		if _buttons_container != null:
			_layout_buttons()
		if _run_summary != null:
			_layout_run_summary()


# ✨ Button hover effects (matches MainMenu style)
func _connect_button_hover_effects() -> void:
	"""Connect mouse_entered/exited signals for button scaling animation"""
	if _resume_button != null:
		_resume_button.mouse_entered.connect(_on_button_hover.bind(_resume_button))
		_resume_button.mouse_exited.connect(_on_button_unhover.bind(_resume_button))
	if _settings_button != null:
		_settings_button.mouse_entered.connect(_on_button_hover.bind(_settings_button))
		_settings_button.mouse_exited.connect(_on_button_unhover.bind(_settings_button))
	if _quit_button != null:
		_quit_button.mouse_entered.connect(_on_button_hover.bind(_quit_button))
		_quit_button.mouse_exited.connect(_on_button_unhover.bind(_quit_button))
	if _quit_to_desktop_button != null:
		_quit_to_desktop_button.mouse_entered.connect(_on_button_hover.bind(_quit_to_desktop_button))
		_quit_to_desktop_button.mouse_exited.connect(_on_button_unhover.bind(_quit_to_desktop_button))
	if _debug_reset_run_button != null:
		_debug_reset_run_button.mouse_entered.connect(_on_button_hover.bind(_debug_reset_run_button))
		_debug_reset_run_button.mouse_exited.connect(_on_button_unhover.bind(_debug_reset_run_button))
	if _confirm_yes_button != null:
		_confirm_yes_button.mouse_entered.connect(_on_button_hover.bind(_confirm_yes_button))
		_confirm_yes_button.mouse_exited.connect(_on_button_unhover.bind(_confirm_yes_button))
	if _confirm_no_button != null:
		_confirm_no_button.mouse_entered.connect(_on_button_hover.bind(_confirm_no_button))
		_confirm_no_button.mouse_exited.connect(_on_button_unhover.bind(_confirm_no_button))


func _on_button_hover(btn: Button) -> void:
	"""Scale button to 105% on hover (matches MainMenu)"""
	create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)


func _on_button_unhover(btn: Button) -> void:
	"""Scale button back to 100% when not hovered (matches MainMenu)"""
	create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
