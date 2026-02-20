extends CanvasLayer
class_name DiceRollScreen

signal roll_completed(result: int)

@export var style: HUDStyle
@export var design_height: float = 1440.0

# Roll animation settings
@export var roll_duration: float = 3.0
@export var initial_roll_speed: float = 0.05  # Change number every 0.05s initially
@export var slowdown_start_percent: float = 0.6  # Start slowing down at 60% through animation
@export var final_roll_speed: float = 0.2  # Slow final rolls

# Result display
@export var result_display_duration: float = 3.0

# Debug
@export var debug_logs: bool = true

# UI References
@onready var _overlay: ColorRect = $Overlay
@onready var _root: Control = $Root
@onready var _dice_range_label: Label = $Root/DiceRangeLabel
@onready var _rolling_number_label: Label = $Root/RollingNumberLabel
@onready var _boss_name_label: Label = $Root/BossNameLabel

var _is_rolling: bool = false
var _dice_min: int = 1
var _dice_max: int = 20
var _current_displayed_number: int = 1
var _final_result: int = 1

# Boss name mapping (placeholder)
var _boss_names: Dictionary = {
	1: "Boss A (Placeholder)",
	2: "Boss B (Placeholder)",
	3: "Boss B (Placeholder)",
	4: "Boss B (Placeholder)",
	5: "Boss B (Placeholder)",
	6: "Boss B (Placeholder)",
	7: "Boss B (Placeholder)",
	8: "Boss C (Placeholder)",
	9: "Boss C (Placeholder)",
	10: "Boss C (Placeholder)",
	11: "Boss C (Placeholder)",
	12: "Boss C (Placeholder)",
	13: "Boss C (Placeholder)",
	14: "Boss D (Placeholder)",
	15: "Boss D (Placeholder)",
	16: "Boss D (Placeholder)",
	17: "Boss D (Placeholder)",
	18: "Boss D (Placeholder)",
	19: "Boss D (Placeholder)",
	20: "Boss E (Placeholder)"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_overlay.color = Color(0, 0, 0, 1.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_boss_name_label.visible = false
	
	_apply_style()

func _apply_style() -> void:
	if style == null:
		return
	
	# Dice range label at top (small)
	if _dice_range_label != null:
		_dice_range_label.add_theme_font_override("font", style.font_body)
		_dice_range_label.add_theme_font_size_override("font_size", _scale_for_height(24))
		_dice_range_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Rolling number (large)
	if _rolling_number_label != null:
		_rolling_number_label.add_theme_font_override("font", style.font_title)
		_rolling_number_label.add_theme_font_size_override("font_size", _scale_for_height(100))
		_rolling_number_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Boss name label (title font)
	if _boss_name_label != null:
		_boss_name_label.add_theme_font_override("font", style.font_title)
		_boss_name_label.add_theme_font_size_override("font_size", _scale_for_height(48))
		_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))  # Gold color

func _scale_for_height(base_size: float) -> int:
	var vh := get_viewport().get_visible_rect().size.y
	return int(base_size * (vh / design_height))

func prepare_roll(dice_min: int, dice_max: int) -> void:
	"""Prepare the screen with range (but don't start rolling yet)"""
	_dice_min = dice_min
	_dice_max = dice_max
	visible = true
	
	# Set range label
	_dice_range_label.text = "Dice Range: %d-%d" % [_dice_min, _dice_max]
	_dice_range_label.visible = true
	
	# Show initial number (static, not rolling)
	_current_displayed_number = dice_min
	_rolling_number_label.text = str(_current_displayed_number)
	_rolling_number_label.visible = true
	
	# Hide boss name initially
	_boss_name_label.visible = false
	
	if debug_logs:
		pass

func start_roll(dice_min: int, dice_max: int) -> void:
	"""Start the dice roll animation with the given range"""
	if _is_rolling:
		return
	
	_dice_min = dice_min
	_dice_max = dice_max
	_is_rolling = true
	
	# Roll final result
	_final_result = randi_range(_dice_min, _dice_max)
	_current_displayed_number = randi_range(_dice_min, _dice_max)
	
	if debug_logs:
		pass
	
	# Start animation
	_roll_animation()

func _roll_animation() -> void:
	"""Animate the rolling dice with slowdown effect"""
	var elapsed: float = 0.0
	var next_change_time: float = 0.0
	
	while elapsed < roll_duration:
		var delta := get_process_delta_time()
		elapsed += delta
		
		# Calculate progress
		var progress := elapsed / roll_duration
		
		# Determine current roll speed (with slowdown)
		var current_speed: float
		if progress < slowdown_start_percent:
			current_speed = initial_roll_speed
		else:
			# Linear interpolation from initial to final speed
			var slowdown_progress := (progress - slowdown_start_percent) / (1.0 - slowdown_start_percent)
			current_speed = lerp(initial_roll_speed, final_roll_speed, slowdown_progress)
		
		# Update number if enough time has passed
		if elapsed >= next_change_time:
			_current_displayed_number = randi_range(_dice_min, _dice_max)
			_rolling_number_label.text = str(_current_displayed_number)
			next_change_time = elapsed + current_speed
		
		await get_tree().process_frame
	
	# Show final result
	_current_displayed_number = _final_result
	_rolling_number_label.text = str(_final_result)
	
	pass
	
	# Wait to display result
	await get_tree().create_timer(0.5).timeout
	
	# Show boss name
	var boss_name := _get_boss_name(_final_result)
	_boss_name_label.text = boss_name
	_boss_name_label.visible = true
	
	pass
	
	# Wait for result display duration
	await get_tree().create_timer(result_display_duration).timeout
	
	# Complete
	_is_rolling = false
	roll_completed.emit(_final_result)

func _get_boss_name(roll_result: int) -> String:
	"""Get boss name from roll result"""
	if _boss_names.has(roll_result):
		return _boss_names[roll_result]
	
	# Fallback based on ranges
	if roll_result == 1:
		return "Boss A (Placeholder)"
	elif roll_result >= 2 and roll_result <= 7:
		return "Boss B (Placeholder)"
	elif roll_result >= 8 and roll_result <= 13:
		return "Boss C (Placeholder)"
	elif roll_result >= 14 and roll_result <= 19:
		return "Boss D (Placeholder)"
	elif roll_result >= 20:
		return "Boss E (Placeholder)"
	
	return "Unknown Boss"

func hide_screen() -> void:
	"""Hide the dice roll screen"""
	visible = false
	_is_rolling = false
