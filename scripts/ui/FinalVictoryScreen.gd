extends CanvasLayer

## Final Victory Screen - Displayed after defeating the final boss
## Shows the victory message and new starting dice range for the next run

signal play_again_pressed
signal main_menu_pressed
signal input_lock_changed(locked: bool)

@export var style: Resource = null # HUDStyle
@export var dice_range_transition_delay: float = 2.0
@export var dice_range_transition_duration: float = 1.0

@onready var _victory_label: Label = %VictoryLabel
@onready var _dice_range_label: Label = %DiceRangeLabel
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _main_menu_button: Button = %MainMenuButton

var _current_dice_value: int = 10
var _new_dice_value: int = 10
var _buttons_enabled: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ensure Root control also processes always and blocks mouse
	var root := get_node_or_null("Root")
	if root != null:
		root.process_mode = Node.PROCESS_MODE_ALWAYS
		root.mouse_filter = Control.MOUSE_FILTER_STOP
	
	pass
	
	# Apply style
	if style != null:
		_apply_style()
	
	# Connect button signals
	if _play_again_button != null:
		_play_again_button.pressed.connect(_on_play_again_pressed)
		pass
	if _main_menu_button != null:
		_main_menu_button.pressed.connect(_on_main_menu_pressed)
		pass
	
	# Initially hide buttons
	_set_buttons_visible(false)

func _apply_style() -> void:
	"""Apply HUDStyle to labels and buttons"""
	if style == null:
		return
	
	# Victory label (large, bold)
	if _victory_label != null and style.has_method("get_font"):
		var font: Font = style.get_font()
		if font != null:
			_victory_label.add_theme_font_override("font", font)
		_victory_label.add_theme_font_size_override("font_size", 72)
		_victory_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Dice range label (medium size)
	if _dice_range_label != null and style.has_method("get_font"):
		var font: Font = style.get_font()
		if font != null:
			_dice_range_label.add_theme_font_override("font", font)
		_dice_range_label.add_theme_font_size_override("font_size", 48)
		_dice_range_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))
	
	# Buttons
	if style.has_method("get_font"):
		var font: Font = style.get_font()
		if font != null and _play_again_button != null:
			_play_again_button.add_theme_font_override("font", font)
			_play_again_button.add_theme_font_size_override("font_size", 32)
		if font != null and _main_menu_button != null:
			_main_menu_button.add_theme_font_override("font", font)
			_main_menu_button.add_theme_font_size_override("font_size", 32)

func show_victory(current_dice: int, new_dice: int) -> void:
	"""Display the victory screen and animate the dice range transition"""
	_current_dice_value = current_dice
	_new_dice_value = new_dice
	_buttons_enabled = false
	
	# Show screen
	visible = true
	
	# Lock player input
	pass
	input_lock_changed.emit(true)
	
	# Show current range
	_dice_range_label.text = "%d-%d" % [current_dice, current_dice]
	_dice_range_label.modulate = Color.WHITE
	
	# Hide buttons initially
	_set_buttons_visible(false)
	
	pass
	
	# Start transition sequence
	call_deferred("_start_transition_sequence")

func _start_transition_sequence() -> void:
	"""Animate the transition from current to new dice range"""
	# Wait for initial display
	await get_tree().create_timer(dice_range_transition_delay).timeout
	
	# Fade out current range
	var fade_out_tween := create_tween()
	fade_out_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out_tween.tween_property(_dice_range_label, "modulate:a", 0.0, dice_range_transition_duration * 0.3)
	await fade_out_tween.finished
	
	# Update text to new range with label
	_dice_range_label.text = "New Starting Dice Range: %d-%d" % [_new_dice_value, _new_dice_value]
	
	# Fade in new range
	var fade_in_tween := create_tween()
	fade_in_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in_tween.tween_property(_dice_range_label, "modulate:a", 1.0, dice_range_transition_duration * 0.7)
	await fade_in_tween.finished
	
	# Show buttons
	_set_buttons_visible(true)
	_buttons_enabled = true
	
	pass

func _set_buttons_visible(should_show: bool) -> void:
	"""Show or hide the action buttons"""
	if _play_again_button != null:
		_play_again_button.visible = should_show
		_play_again_button.disabled = not should_show
	if _main_menu_button != null:
		_main_menu_button.visible = should_show
		_main_menu_button.disabled = not should_show

func _on_play_again_pressed() -> void:
	"""Handle Play Again button press"""
	if not _buttons_enabled:
		return
	
	_buttons_enabled = false
	pass
	
	# Update RunState with new dice range
	if RunStateSingleton != null:
		RunStateSingleton.update_starting_dice_range(_new_dice_value)
		RunStateSingleton.start_new_run()
	
	play_again_pressed.emit()

func _on_main_menu_pressed() -> void:
	"""Handle Main Menu button press"""
	if not _buttons_enabled:
		return
	
	_buttons_enabled = false
	pass
	
	# Update RunState with new dice range
	if RunStateSingleton != null:
		RunStateSingleton.update_starting_dice_range(_new_dice_value)
	
	main_menu_pressed.emit()

func hide_screen() -> void:
	"""Hide the victory screen"""
	visible = false
	_buttons_enabled = false
	
	# Unlock player input
	input_lock_changed.emit(false)
	pass
