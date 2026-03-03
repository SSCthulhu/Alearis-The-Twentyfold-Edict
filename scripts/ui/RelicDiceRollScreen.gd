extends CanvasLayer
class_name RelicDiceRollScreen

signal roll_completed(result: int)

@export var style: HUDStyle
@export var design_height: float = 1440.0
@export var roll_duration: float = 2.6
@export var initial_roll_speed: float = 0.05
@export var slowdown_start_percent: float = 0.6
@export var final_roll_speed: float = 0.2
@export var result_display_duration: float = 2.8
@export_group("Cinematic Intro")
@export var intro_text: String = "The Twentyfold Edict stirs...\nLet the dice decide your fate."
@export var fade_to_black_time: float = 1.2
@export var intro_fade_in_time: float = 0.7
@export var intro_hold_time: float = 3.0
@export var intro_fade_out_time: float = 0.6
@export var dice_screen_fade_in_time: float = 0.45
@export var pre_roll_buffer_time: float = 0.6
@export var outro_fade_time: float = 0.45

@onready var _overlay: ColorRect = $Overlay
@onready var _root: Control = $Root
@onready var _dice_range_label: Label = $Root/DiceRangeLabel
@onready var _rolling_number_label: Label = $Root/RollingNumberLabel
@onready var _group_label: Label = $Root/RelicGroupLabel
@onready var _intro_label: Label = $Root/IntroLabel

var _is_rolling: bool = false
var _dice_min: int = 1
var _dice_max: int = 20
var _final_result: int = 1
var _target_band: int = int(RelicData.Band.CORE)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_overlay.color = Color(0, 0, 0, 1.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.mouse_filter = Control.MOUSE_FILTER_STOP

	_group_label.visible = false
	_intro_label.visible = false
	_apply_style()

func _apply_style() -> void:
	if style == null:
		return
	if _dice_range_label != null:
		_dice_range_label.add_theme_font_override("font", style.font_body)
		_dice_range_label.add_theme_font_size_override("font_size", _scale_for_height(24))
		_dice_range_label.add_theme_color_override("font_color", Color.WHITE)
	if _rolling_number_label != null:
		_rolling_number_label.add_theme_font_override("font", style.font_title)
		_rolling_number_label.add_theme_font_size_override("font_size", _scale_for_height(100))
		_rolling_number_label.add_theme_color_override("font_color", Color.WHITE)
	if _group_label != null:
		_group_label.add_theme_font_override("font", style.font_title)
		_group_label.add_theme_font_size_override("font_size", _scale_for_height(48))
	if _intro_label != null:
		_intro_label.add_theme_font_override("font", style.font_title)
		_intro_label.add_theme_font_size_override("font_size", _scale_for_height(46))
		_intro_label.add_theme_color_override("font_color", style.gold_accent if style != null else Color(0.86, 0.72, 0.33, 1.0))

func _scale_for_height(base_size: float) -> int:
	var vh: float = get_viewport().get_visible_rect().size.y
	return int(base_size * (vh / design_height))

func prepare_roll(dice_min: int, dice_max: int) -> void:
	_dice_min = dice_min
	_dice_max = dice_max
	visible = true
	_dice_range_label.text = "Dice Range: %d-%d" % [_dice_min, _dice_max]
	_rolling_number_label.text = str(_dice_min)
	_dice_range_label.visible = true
	_rolling_number_label.visible = true
	_group_label.visible = false
	_intro_label.visible = false

func start_relic_roll(dice_min: int, dice_max: int, final_result: int, target_band: int) -> void:
	if _is_rolling:
		return
	_dice_min = dice_min
	_dice_max = dice_max
	_final_result = clampi(final_result, _dice_min, _dice_max)
	_target_band = target_band
	_is_rolling = true
	_start_relic_roll_sequence()

func _start_relic_roll_sequence() -> void:
	await _play_intro_sequence()
	await _roll_animation()

func _play_intro_sequence() -> void:
	visible = true

	# Start with black fade over gameplay.
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_root.visible = true
	_root.modulate.a = 1.0
	_dice_range_label.visible = false
	_rolling_number_label.visible = false
	_intro_label.visible = false
	_group_label.visible = false

	var fade_out_game := create_tween()
	fade_out_game.tween_property(_overlay, "modulate:a", 1.0, maxf(fade_to_black_time, 0.01))
	await fade_out_game.finished

	# Lore line on black before dice appears.
	_intro_label.text = intro_text
	_intro_label.visible = true
	_intro_label.modulate.a = 0.0

	var intro_in := create_tween()
	intro_in.tween_property(_intro_label, "modulate:a", 1.0, maxf(intro_fade_in_time, 0.01))
	await intro_in.finished

	if intro_hold_time > 0.0:
		await get_tree().create_timer(intro_hold_time).timeout

	var intro_out := create_tween()
	intro_out.tween_property(_intro_label, "modulate:a", 0.0, maxf(intro_fade_out_time, 0.01))
	await intro_out.finished
	_intro_label.visible = false

	# Fade in dice UI (overlay remains black background).
	_dice_range_label.visible = true
	_rolling_number_label.visible = true
	_root.modulate.a = 0.0
	var ui_in := create_tween()
	ui_in.tween_property(_root, "modulate:a", 1.0, maxf(dice_screen_fade_in_time, 0.01))
	await ui_in.finished

	if pre_roll_buffer_time > 0.0:
		await get_tree().create_timer(pre_roll_buffer_time).timeout

func _roll_animation() -> void:
	var elapsed: float = 0.0
	var next_change_time: float = 0.0

	while elapsed < roll_duration:
		var delta: float = get_process_delta_time()
		elapsed += delta
		var progress: float = elapsed / maxf(roll_duration, 0.01)

		var current_speed: float = initial_roll_speed
		if progress >= slowdown_start_percent:
			var slowdown_progress: float = (progress - slowdown_start_percent) / maxf(1.0 - slowdown_start_percent, 0.001)
			current_speed = lerpf(initial_roll_speed, final_roll_speed, slowdown_progress)

		if elapsed >= next_change_time:
			_rolling_number_label.text = str(randi_range(_dice_min, _dice_max))
			next_change_time = elapsed + current_speed

		await get_tree().process_frame

	_rolling_number_label.text = str(_final_result)
	await get_tree().create_timer(0.35).timeout

	var group_data: Dictionary = _group_display_for_band(_target_band)
	_group_label.text = "Relic Group: %s" % String(group_data.get("name", "CORE"))
	_group_label.add_theme_color_override("font_color", group_data.get("color", Color.WHITE))
	_group_label.visible = true

	await get_tree().create_timer(result_display_duration).timeout
	_is_rolling = false
	roll_completed.emit(_final_result)

func hide_screen() -> void:
	visible = false
	_is_rolling = false
	_root.modulate.a = 1.0
	_overlay.modulate.a = 1.0

func fade_out_text_only() -> void:
	if not visible:
		return
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, maxf(outro_fade_time, 0.01))
	await t.finished

func _group_display_for_band(band: int) -> Dictionary:
	match band:
		int(RelicData.Band.SURVIVAL):
			return {"name": "SURVIVAL", "color": Color(0.27, 0.88, 0.42, 1.0)}
		int(RelicData.Band.CORE):
			var core_color: Color = Color(0.86, 0.72, 0.33, 1.0)
			if style != null:
				core_color = style.gold_accent
			return {"name": "CORE", "color": core_color}
		_:
			return {"name": "DAMAGE", "color": Color(0.92, 0.22, 0.22, 1.0)}
