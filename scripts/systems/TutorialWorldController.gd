extends Node2D

signal intro_advance_requested
signal dice_advance_requested
signal put_together_advance_requested
signal modifier_explainer_advance_requested

@onready var intro_overlay: CanvasLayer = $TutorialIntroOverlay
@onready var intro_dim: ColorRect = $TutorialIntroOverlay/Dim
@onready var intro_dialog: PanelContainer = $TutorialIntroOverlay/IntroDialog
@onready var intro_text: Label = $TutorialIntroOverlay/IntroDialog/Margin/VBox/LoreText
@onready var intro_hint: Label = $TutorialIntroOverlay/IntroDialog/Margin/VBox/HintText
@onready var move_dialog: PanelContainer = $TutorialIntroOverlay/MoveDialog
@onready var move_text: Label = $TutorialIntroOverlay/MoveDialog/Margin/VBox/MoveText
@onready var move_hint: Label = $TutorialIntroOverlay/MoveDialog/Margin/VBox/MoveHint
@onready var jump_dialog: PanelContainer = $TutorialIntroOverlay/JumpDialog
@onready var jump_text: Label = $TutorialIntroOverlay/JumpDialog/Margin/VBox/JumpText
@onready var jump_hint: Label = $TutorialIntroOverlay/JumpDialog/Margin/VBox/JumpHint
@onready var dash_dialog: PanelContainer = $TutorialIntroOverlay/DashDialog
@onready var dash_text: Label = $TutorialIntroOverlay/DashDialog/Margin/VBox/DashText
@onready var dash_hint: Label = $TutorialIntroOverlay/DashDialog/Margin/VBox/DashHint
@onready var attack_dialog: PanelContainer = $TutorialIntroOverlay/AttackDialog
@onready var attack_text: Label = $TutorialIntroOverlay/AttackDialog/Margin/VBox/AttackText
@onready var attack_hint: Label = $TutorialIntroOverlay/AttackDialog/Margin/VBox/AttackHint
@onready var heavy_dialog: PanelContainer = $TutorialIntroOverlay/HeavyDialog
@onready var heavy_text: Label = $TutorialIntroOverlay/HeavyDialog/Margin/VBox/HeavyText
@onready var heavy_hint: Label = $TutorialIntroOverlay/HeavyDialog/Margin/VBox/HeavyHint
@onready var ultimate_dialog: PanelContainer = $TutorialIntroOverlay/UltimateDialog
@onready var ultimate_text: Label = $TutorialIntroOverlay/UltimateDialog/Margin/VBox/UltimateText
@onready var ultimate_hint: Label = $TutorialIntroOverlay/UltimateDialog/Margin/VBox/UltimateHint
@onready var dice_dialog: PanelContainer = $TutorialIntroOverlay/DiceDialog
@onready var dice_text: Label = $TutorialIntroOverlay/DiceDialog/Margin/VBox/DiceText
@onready var dice_hint: Label = $TutorialIntroOverlay/DiceDialog/Margin/VBox/DiceHint
@onready var perfect_dodge_dialog: PanelContainer = $TutorialIntroOverlay/PerfectDodgeDialog
@onready var perfect_dodge_text: Label = $TutorialIntroOverlay/PerfectDodgeDialog/Margin/VBox/PerfectDodgeText
@onready var perfect_dodge_hint: Label = $TutorialIntroOverlay/PerfectDodgeDialog/Margin/VBox/PerfectDodgeHint
@onready var final_challenge_dialog: PanelContainer = $TutorialIntroOverlay/FinalChallengeDialog
@onready var final_challenge_text: Label = $TutorialIntroOverlay/FinalChallengeDialog/Margin/VBox/FinalChallengeText
@onready var final_challenge_hint: Label = $TutorialIntroOverlay/FinalChallengeDialog/Margin/VBox/FinalChallengeHint
@onready var player_node: Node = $Player
@onready var floor_enemy_spawner: Node = $FloorEnemySpawner
@onready var dice_modifier_choice: Node = $DiceModifierChoice
@onready var tutorial_exit_portal: Node2D = $TutorialExitPortal
var tutorial_chest_spawn_marker: Node2D = null

const INTRO_LORE_PLACEHOLDER: String = "Chosen by the Dice, you are called to challenge the Twentyfold Edict. Step forward, and begin the path to break their grasp."
const ATTACK_DUMMY_POS: Vector2 = Vector2(4100.0, 350.0)
const ATTACK_COMBO_HIT_CONFIRM_WINDOW: float = 0.45
const HEAVY_HIT_CONFIRM_WINDOW: float = 0.55
const DICE_TUTORIAL_HP_RATIO: float = 0.20
const CRIMSON_BENEDICTION_EVENT_PATH: String = "res://data/dice_meter/events_v2/Roll10_Blood_Divine.tres"
const ENEMY_MELEE_HITBOX_SCENE: PackedScene = preload("res://scenes/enemies/EnemyMeleeHitbox.tscn")
const REWARD_CHEST_SCENE: PackedScene = preload("res://scenes/world/RewardChest.tscn")
const TUTORIAL_REWARD_CHEST_POS: Vector2 = Vector2(3000.0, 350.0)
const DUMMY_FLOOR_RAY_UP: float = 180.0
const DUMMY_FLOOR_RAY_DOWN: float = 2200.0
const TUTORIAL_DUMMY_LOCKED_MAX_HP: int = 999999

var _intro_active: bool = false
var _move_prompt_active: bool = false
var _move_left_done: bool = false
var _move_right_done: bool = false
var _jump_prompt_active: bool = false
var _jump_hold_time: float = 0.0
var _jump_holding: bool = false
var _jump_airborne_during_hold: bool = false
var _jump_success_announced: bool = false
var _dash_prompt_active: bool = false
var _dash_ground_done: bool = false
var _dash_air_done: bool = false
var _sprint_done: bool = false
var _sprint_hold_time: float = 0.0
var _attack_prompt_active: bool = false
var _combo_step_1_done: bool = false
var _combo_step_2_done: bool = false
var _combo_step_3_done: bool = false
var _attack_dummy: Node2D = null
var _player_combat_node: Node = null
var _expected_combo_step_hit: int = 1
var _pending_combo_step_hit: int = 0
var _pending_combo_hit_time_left: float = 0.0
var _heavy_prompt_active: bool = false
var _heavy_hit_done: bool = false
var _pending_heavy_hit_confirm: bool = false
var _pending_heavy_hit_time_left: float = 0.0
var _ultimate_prompt_active: bool = false
var _ultimate_hit_done: bool = false
var _attack_dummy_spawn_requested: bool = false
var _dice_prompt_active: bool = false
var _dice_explainer_active: bool = false
var _dice_waiting_for_roll: bool = false
var _dice_roll_completed: bool = false
var _dice_recovery_phase_active: bool = false
var _dice_recovered_health_done: bool = false
var _dice_hp_at_roll_start: int = -1
var _dice_meter_node: Node = null
var _dice_intro_overlay_prev_layer: int = 50
var _dice_meter_prev_trigger_action: StringName = &""
var _dice_trigger_override_active: bool = false
var _perfect_dodge_prompt_active: bool = false
var _perfect_dodge_done: bool = false
var _put_together_intro_active: bool = false
var _put_together_objective_active: bool = false
var _put_together_completed: bool = false
var _put_together_enemy_defeated: bool = false
var _put_together_chest_spawned: bool = false
var _put_together_chest_opened: bool = false
var _put_together_modifier_chosen: bool = false
var _modifier_explainer_active: bool = false
var _put_together_reward_chest: Node2D = null
var _dummy_health_lock_enabled: bool = true
var _attack_dummy_base_max_hp: int = 60
var _attack_dummy_base_move_speed: float = 140.0
var _attack_dummy_base_attack_damage: int = 12
var _attack_dummy_base_attack_cooldown: float = 1.25
var _attack_dummy_base_aggro_range: float = 1200.0
var _attack_dummy_base_lose_aggro_range: float = 1440.0
var _attack_dummy_base_patrol_enabled: bool = true
var _attack_dummy_base_strikezone_scene: Variant = null

@export var tutorial_chest_spawn_path: NodePath = ^"Arena/Spawns/ChestSpawns/ChestSpawn_Default"

const JUMP_HOLD_REQUIRED_SECONDS: float = 0.25
const JUMP_SUCCESS_VISIBLE_SECONDS: float = 0.95
const SPRINT_HOLD_REQUIRED_SECONDS: float = 0.45
const DASH_SUCCESS_VISIBLE_SECONDS: float = 1.0
const TUTORIAL_LOCKED_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"jump",
	&"dash",
	&"Dodge",
	&"attack_light",
	&"attack_heavy",
	&"defend",
	&"ultimate",
	&"dice_meter_trigger",
	&"interact"
]
enum TutorialStep {
	INTRO,
	MOVE,
	JUMP,
	DASH,
	ATTACK_LIGHT_COMBO,
	ATTACK_HEAVY,
	ATTACK_ULTIMATE,
	DICE_METER,
	PERFECT_DODGE,
	PUT_IT_ALL_TOGETHER,
	COMPLETE
}
const STEP_ALLOWED_ACTIONS: Dictionary = {
	TutorialStep.INTRO: [],
	TutorialStep.MOVE: [&"move_left", &"move_right"],
	TutorialStep.JUMP: [&"move_left", &"move_right", &"jump"],
	TutorialStep.DASH: [&"move_left", &"move_right", &"jump", &"dash"],
	TutorialStep.ATTACK_LIGHT_COMBO: [&"move_left", &"move_right", &"jump", &"dash", &"attack_light"],
	TutorialStep.ATTACK_HEAVY: [&"move_left", &"move_right", &"jump", &"dash", &"attack_light", &"attack_heavy"],
	TutorialStep.ATTACK_ULTIMATE: [&"move_left", &"move_right", &"jump", &"dash", &"attack_light", &"attack_heavy", &"ultimate"],
	TutorialStep.DICE_METER: [&"move_left", &"move_right", &"jump", &"dash", &"Dodge", &"attack_light", &"attack_heavy", &"ultimate", &"dice_meter_trigger"],
	TutorialStep.PERFECT_DODGE: [&"move_left", &"move_right", &"jump", &"dash", &"Dodge"],
	TutorialStep.PUT_IT_ALL_TOGETHER: [&"move_left", &"move_right", &"jump", &"dash", &"Dodge", &"attack_light", &"attack_heavy", &"ultimate", &"defend", &"dice_meter_trigger", &"interact"],
	TutorialStep.COMPLETE: TUTORIAL_LOCKED_ACTIONS
}

var _input_gate_snapshot: Dictionary = {}
var _input_gate_captured: bool = false
var _current_step: int = TutorialStep.INTRO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_unhandled_input(true)
	tutorial_chest_spawn_marker = get_node_or_null(tutorial_chest_spawn_path) as Node2D
	_capture_input_gate_snapshot()
	_prepare_intro_ui()
	_set_exit_portal_enabled(false)
	_bind_player_tutorial_signals()
	_connect_dice_meter_signals()
	_connect_modifier_choice_signal()
	call_deferred("_run_intro_sequence")

func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.paused:
		tree.paused = false
	_set_player_intro_lock(false)
	_end_dice_tutorial_overrides()
	_disconnect_dice_meter_signals()
	_disconnect_modifier_choice_signal()
	_clear_tutorial_reward_chest()
	_restore_all_tutorial_inputs()

func _prepare_intro_ui() -> void:
	if intro_overlay != null:
		# Keep overlay visible immediately to prevent a one-frame world flash
		# between TransitionLayer fade-out and tutorial intro activation.
		intro_overlay.visible = true
	if intro_dim != null:
		# Translucent black so the world remains visible behind the intro.
		intro_dim.color = Color(0.0, 0.0, 0.0, 0.72)
	if intro_dialog != null:
		intro_dialog.modulate.a = 0.0
	if move_dialog != null:
		move_dialog.visible = false
		move_dialog.modulate.a = 0.0
	if jump_dialog != null:
		jump_dialog.visible = false
		jump_dialog.modulate.a = 0.0
	if dash_dialog != null:
		dash_dialog.visible = false
		dash_dialog.modulate.a = 0.0
	if attack_dialog != null:
		attack_dialog.visible = false
		attack_dialog.modulate.a = 0.0
	if heavy_dialog != null:
		heavy_dialog.visible = false
		heavy_dialog.modulate.a = 0.0
	if ultimate_dialog != null:
		ultimate_dialog.visible = false
		ultimate_dialog.modulate.a = 0.0
	if dice_dialog != null:
		dice_dialog.visible = false
		dice_dialog.modulate.a = 0.0
	if perfect_dodge_dialog != null:
		perfect_dodge_dialog.visible = false
		perfect_dodge_dialog.modulate.a = 0.0
	if final_challenge_dialog != null:
		final_challenge_dialog.visible = false
		final_challenge_dialog.modulate.a = 0.0
	if intro_text != null:
		intro_text.text = INTRO_LORE_PLACEHOLDER
	if intro_hint != null:
		intro_hint.text = "Press Enter to continue"
	_move_left_done = false
	_move_right_done = false
	_refresh_move_prompt_text()
	_reset_jump_prompt_state()
	_refresh_jump_prompt_text()
	_reset_dash_prompt_state()
	_refresh_dash_prompt_text()
	_reset_attack_prompt_state()
	_refresh_attack_prompt_text()
	_reset_heavy_prompt_state()
	_refresh_heavy_prompt_text()
	_reset_ultimate_prompt_state()
	_refresh_ultimate_prompt_text()
	_reset_dice_prompt_state()
	_refresh_dice_prompt_text()
	_reset_perfect_dodge_prompt_state()
	_refresh_perfect_dodge_prompt_text()
	_reset_put_together_state()
	_refresh_put_together_text()
	_apply_tutorial_text_alignment_and_spacing()

func _run_intro_sequence() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await _wait_for_loading_transition_to_finish(2.0)
	_set_tutorial_step(TutorialStep.INTRO)
	_intro_active = true
	_set_player_intro_lock(true)
	tree.paused = true
	await get_tree().process_frame
	await _fade_canvas_item_alpha(intro_dialog, 0.0, 1.0, 0.35)
	await intro_advance_requested
	var fade_out_dialog: Tween = create_tween()
	fade_out_dialog.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out_dialog.set_parallel(true)
	fade_out_dialog.tween_property(intro_dialog, "modulate:a", 0.0, 0.35)
	fade_out_dialog.tween_property(intro_dim, "color:a", 0.0, 0.45)
	await fade_out_dialog.finished
	if intro_overlay != null:
		intro_overlay.visible = true
	if intro_dim != null:
		intro_dim.visible = false
	tree.paused = false
	_set_player_intro_lock(false)
	_intro_active = false
	_start_move_prompt()

func _fade_canvas_item_alpha(item: CanvasItem, from_alpha: float, to_alpha: float, duration: float) -> void:
	if item == null:
		return
	item.modulate.a = from_alpha
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(item, "modulate:a", to_alpha, maxf(duration, 0.01))
	await tween.finished

func _unhandled_input(event: InputEvent) -> void:
	if _intro_active and _is_intro_advance_event(event):
		intro_advance_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _dice_explainer_active and _is_intro_advance_event(event):
		dice_advance_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _put_together_intro_active and _is_intro_advance_event(event):
		put_together_advance_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _modifier_explainer_active and _is_intro_advance_event(event):
		modifier_explainer_advance_requested.emit()
		get_viewport().set_input_as_handled()

func _is_intro_advance_event(event: InputEvent) -> bool:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			return true
	if event.is_action_pressed(&"ui_accept"):
		return true
	return false

func _process(_delta: float) -> void:
	if _move_prompt_active:
		if Input.is_action_just_pressed(&"move_left"):
			_move_left_done = true
		if Input.is_action_just_pressed(&"move_right"):
			_move_right_done = true
		if _move_left_done or _move_right_done:
			_refresh_move_prompt_text()
		if _move_left_done and _move_right_done:
			_finish_move_prompt()
	if _jump_prompt_active:
		_tick_jump_prompt(_delta)
	if _dash_prompt_active:
		_tick_dash_prompt(_delta)
	if _attack_prompt_active:
		_tick_attack_prompt(_delta)
	if _heavy_prompt_active:
		_tick_heavy_prompt(_delta)
	if _ultimate_prompt_active:
		_tick_ultimate_prompt(_delta)
	if _dice_prompt_active:
		_tick_dice_prompt(_delta)
	if _perfect_dodge_prompt_active:
		_tick_perfect_dodge_prompt(_delta)
	if _put_together_objective_active:
		_tick_put_together_objective(_delta)
	_sync_tutorial_reward_chest_to_marker()

func _start_move_prompt() -> void:
	_set_tutorial_step(TutorialStep.MOVE)
	_move_prompt_active = true
	_move_left_done = false
	_move_right_done = false
	_refresh_move_prompt_text()
	if move_dialog != null:
		move_dialog.visible = true
		move_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(move_dialog, "modulate:a", 1.0, 0.25)

func _finish_move_prompt() -> void:
	_move_prompt_active = false
	if move_dialog == null:
		_start_jump_prompt()
		return
	var tween: Tween = create_tween()
	tween.tween_property(move_dialog, "modulate:a", 0.0, 0.22)
	await tween.finished
	move_dialog.visible = false
	_start_jump_prompt()

func _refresh_move_prompt_text() -> void:
	var left_label: String = _get_action_label(&"move_left")
	var right_label: String = _get_action_label(&"move_right")
	if move_text != null:
		move_text.text = "It is time to begin your journey.\nUse %s and %s to move." % [left_label, right_label]
	if move_hint != null:
		var left_state: String = "Done" if _move_left_done else "Pending"
		var right_state: String = "Done" if _move_right_done else "Pending"
		move_hint.text = "Move Left: %s    Move Right: %s" % [left_state, right_state]

func _start_jump_prompt() -> void:
	_set_tutorial_step(TutorialStep.JUMP)
	_jump_prompt_active = true
	_reset_jump_prompt_state()
	_refresh_jump_prompt_text()
	if jump_dialog != null:
		jump_dialog.visible = true
		jump_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(jump_dialog, "modulate:a", 1.0, 0.25)

func _tick_jump_prompt(delta: float) -> void:
	if Input.is_action_just_pressed(&"jump"):
		_jump_holding = true
		_jump_hold_time = 0.0
		_jump_airborne_during_hold = false
	if _jump_holding and Input.is_action_pressed(&"jump"):
		_jump_hold_time += maxf(delta, 0.0)
		if _is_player_airborne():
			_jump_airborne_during_hold = true
	if Input.is_action_just_released(&"jump"):
		_jump_holding = false
	_refresh_jump_prompt_text()
	if _jump_airborne_during_hold and _jump_hold_time >= JUMP_HOLD_REQUIRED_SECONDS and not _jump_success_announced:
		_jump_success_announced = true
		_complete_jump_prompt_with_success()

func _complete_jump_prompt_with_success() -> void:
	_jump_prompt_active = false
	if jump_hint != null:
		jump_hint.text = "Great jump! You held long enough."
	await get_tree().create_timer(JUMP_SUCCESS_VISIBLE_SECONDS).timeout
	await _fade_out_dialog(jump_dialog, 0.22)
	_start_dash_prompt()

func _reset_jump_prompt_state() -> void:
	_jump_hold_time = 0.0
	_jump_holding = false
	_jump_airborne_during_hold = false
	_jump_success_announced = false

func _refresh_jump_prompt_text() -> void:
	var jump_label: String = _get_action_label(&"jump")
	if jump_text != null:
		jump_text.text = "Next, jump the gap.\nPress and hold %s for a higher jump." % jump_label
	if jump_hint != null:
		var progress_ratio: float = clampf(_jump_hold_time / JUMP_HOLD_REQUIRED_SECONDS, 0.0, 1.0)
		var progress_percent: int = int(round(progress_ratio * 100.0))
		if _jump_success_announced:
			jump_hint.text = "Great jump! You held long enough."
		elif _jump_holding:
			jump_hint.text = "Keep holding jump... %d%%" % progress_percent
		else:
			jump_hint.text = "Tip: Hold jump a little longer while in the air for extra height."

func _start_dash_prompt() -> void:
	_set_tutorial_step(TutorialStep.DASH)
	_dash_prompt_active = true
	_reset_dash_prompt_state()
	_refresh_dash_prompt_text()
	if dash_dialog != null:
		dash_dialog.visible = true
		dash_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(dash_dialog, "modulate:a", 1.0, 0.25)

func _tick_dash_prompt(delta: float) -> void:
	if _is_player_sprinting_now():
		_sprint_hold_time += maxf(delta, 0.0)
	else:
		_sprint_hold_time = 0.0
	if _sprint_hold_time >= SPRINT_HOLD_REQUIRED_SECONDS:
		_sprint_done = true
	_refresh_dash_prompt_text()
	if _dash_ground_done and _dash_air_done and _sprint_done:
		_complete_dash_prompt_with_success()

func _complete_dash_prompt_with_success() -> void:
	_dash_prompt_active = false
	if dash_hint != null:
		dash_hint.text = "Perfect. Dash and sprint basics complete."
	await get_tree().create_timer(DASH_SUCCESS_VISIBLE_SECONDS).timeout
	await _fade_out_dialog(dash_dialog, 0.22)
	_start_attack_prompt()

func _reset_dash_prompt_state() -> void:
	_dash_ground_done = false
	_dash_air_done = false
	_sprint_done = false
	_sprint_hold_time = 0.0

func _refresh_dash_prompt_text() -> void:
	var dash_label: String = _get_action_label(&"dash")
	var move_left_label: String = _get_action_label(&"move_left")
	var move_right_label: String = _get_action_label(&"move_right")
	if dash_text != null:
		dash_text.text = "Now master mobility.\nTap %s to dash.\nTap %s in air to dash.\nHold %s + %s/%s to sprint." % [dash_label, dash_label, dash_label, move_left_label, move_right_label]
	if dash_hint != null:
		var ground_state: String = "Done" if _dash_ground_done else "Pending"
		var air_state: String = "Done" if _dash_air_done else "Pending"
		var sprint_state: String = "Done" if _sprint_done else "Pending"
		dash_hint.text = "Ground Dash: %s    Air Dash: %s    Sprint: %s" % [ground_state, air_state, sprint_state]

func _bind_player_tutorial_signals() -> void:
	if player_node == null or not is_instance_valid(player_node):
		return
	if player_node.has_signal("dash_started") and not player_node.is_connected("dash_started", Callable(self, "_on_player_dash_started")):
		player_node.connect("dash_started", Callable(self, "_on_player_dash_started"))
	if player_node.has_signal("light_attack_started") and not player_node.is_connected("light_attack_started", Callable(self, "_on_player_light_attack_started")):
		player_node.connect("light_attack_started", Callable(self, "_on_player_light_attack_started"))
	if player_node.has_signal("heavy_attack_started") and not player_node.is_connected("heavy_attack_started", Callable(self, "_on_player_heavy_attack_started")):
		player_node.connect("heavy_attack_started", Callable(self, "_on_player_heavy_attack_started"))
	if player_node.has_signal("ultimate_attack_hit") and not player_node.is_connected("ultimate_attack_hit", Callable(self, "_on_player_ultimate_attack_hit")):
		player_node.connect("ultimate_attack_hit", Callable(self, "_on_player_ultimate_attack_hit"))
	if player_node.has_signal("knight_ultimate_hit") and not player_node.is_connected("knight_ultimate_hit", Callable(self, "_on_player_knight_ultimate_hit")):
		player_node.connect("knight_ultimate_hit", Callable(self, "_on_player_knight_ultimate_hit"))
	_player_combat_node = player_node.get_node_or_null("Combat")
	if _player_combat_node != null and _player_combat_node.has_signal("attack_hit"):
		var cb: Callable = Callable(self, "_on_player_attack_hit")
		if not _player_combat_node.is_connected("attack_hit", cb):
			_player_combat_node.connect("attack_hit", cb)
	var perfect_detector: Node = player_node.get_node_or_null("PerfectDodgeDetector")
	if perfect_detector != null and perfect_detector.has_signal("perfect_dodge"):
		var pd_cb: Callable = Callable(self, "_on_player_perfect_dodge")
		if not perfect_detector.is_connected("perfect_dodge", pd_cb):
			perfect_detector.connect("perfect_dodge", pd_cb)

func _on_player_dash_started(_facing_direction: int, is_airborne: bool) -> void:
	if not _dash_prompt_active:
		return
	if is_airborne:
		_dash_air_done = true
	else:
		_dash_ground_done = true

func _is_player_sprinting_now() -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false
	if "_is_sprinting" in player_node and bool(player_node.get("_is_sprinting")):
		return true
	return false

func _on_player_light_attack_started(_character_name: String, combo_step: int, _facing_direction: int) -> void:
	if not _attack_prompt_active:
		return
	if combo_step != _expected_combo_step_hit:
		return
	_pending_combo_step_hit = combo_step
	_pending_combo_hit_time_left = ATTACK_COMBO_HIT_CONFIRM_WINDOW

func _on_player_attack_hit(kind: StringName, target: Node, _dealt_damage: int) -> void:
	if _attack_prompt_active:
		if kind != &"light":
			return
		if _pending_combo_step_hit == 0:
			return
		if not _is_target_from_attack_dummy(target):
			return
		_mark_combo_step_landed(_pending_combo_step_hit)
		return
	if _heavy_prompt_active:
		if kind != &"heavy":
			return
		if not _pending_heavy_hit_confirm:
			return
		if not _is_target_from_attack_dummy(target):
			return
		_heavy_hit_done = true
		_pending_heavy_hit_confirm = false
		_pending_heavy_hit_time_left = 0.0
		_refresh_heavy_prompt_text()

func _on_player_heavy_attack_started(_character_name: String, _facing_direction: int) -> void:
	if not _heavy_prompt_active:
		return
	_pending_heavy_hit_confirm = true
	_pending_heavy_hit_time_left = HEAVY_HIT_CONFIRM_WINDOW

func _on_player_ultimate_attack_hit(_character_name: String, _enemy_position: Vector2, _facing_direction: int) -> void:
	if not _ultimate_prompt_active:
		return
	_ultimate_hit_done = true
	_refresh_ultimate_prompt_text()

func _on_player_knight_ultimate_hit(enemy: Node, _enemy_position: Vector2) -> void:
	if not _ultimate_prompt_active:
		return
	if not _is_target_from_attack_dummy(enemy):
		return
	_ultimate_hit_done = true
	_refresh_ultimate_prompt_text()

func _on_player_perfect_dodge(_trigger_source: Node, _attempted_damage: int) -> void:
	if not _perfect_dodge_prompt_active:
		return
	_perfect_dodge_done = true
	_refresh_perfect_dodge_prompt_text()

func _mark_combo_step_landed(step: int) -> void:
	match step:
		1:
			_combo_step_1_done = true
			_expected_combo_step_hit = 2
		2:
			_combo_step_2_done = true
			_expected_combo_step_hit = 3
		3:
			_combo_step_3_done = true
			_expected_combo_step_hit = 4
		_:
			return
	_pending_combo_step_hit = 0
	_pending_combo_hit_time_left = 0.0
	_refresh_attack_prompt_text()

func _is_target_from_attack_dummy(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if _attack_dummy == null or not is_instance_valid(_attack_dummy):
		return false
	var cursor: Node = target
	while cursor != null:
		if cursor == _attack_dummy:
			return true
		cursor = cursor.get_parent()
	return false

func _start_attack_prompt() -> void:
	_set_tutorial_step(TutorialStep.ATTACK_LIGHT_COMBO)
	_attack_prompt_active = true
	_reset_attack_prompt_state()
	_spawn_attack_dummy_if_needed()
	_refresh_attack_prompt_text()
	if attack_dialog != null:
		attack_dialog.visible = true
		attack_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(attack_dialog, "modulate:a", 1.0, 0.25)

func _tick_attack_prompt(_delta: float) -> void:
	_lock_dummy_health_full()
	if _pending_combo_step_hit != 0:
		_pending_combo_hit_time_left = maxf(0.0, _pending_combo_hit_time_left - maxf(_delta, 0.0))
		if _pending_combo_hit_time_left <= 0.0:
			_pending_combo_step_hit = 0
	if _combo_step_1_done and _combo_step_2_done and _combo_step_3_done:
		_complete_attack_prompt()

func _complete_attack_prompt() -> void:
	_attack_prompt_active = false
	if attack_hint != null:
		attack_hint.text = "Excellent combo. Steps 1, 2, and 3 complete."
	await get_tree().create_timer(0.95).timeout
	await _fade_out_dialog(attack_dialog, 0.22)
	_start_heavy_prompt()

func _reset_attack_prompt_state() -> void:
	_combo_step_1_done = false
	_combo_step_2_done = false
	_combo_step_3_done = false
	_expected_combo_step_hit = 1
	_pending_combo_step_hit = 0
	_pending_combo_hit_time_left = 0.0

func _start_heavy_prompt() -> void:
	_set_tutorial_step(TutorialStep.ATTACK_HEAVY)
	_heavy_prompt_active = true
	_reset_heavy_prompt_state()
	_refresh_heavy_prompt_text()
	if heavy_dialog != null:
		heavy_dialog.visible = true
		heavy_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(heavy_dialog, "modulate:a", 1.0, 0.25)

func _tick_heavy_prompt(delta: float) -> void:
	_lock_dummy_health_full()
	if _pending_heavy_hit_confirm:
		_pending_heavy_hit_time_left = maxf(0.0, _pending_heavy_hit_time_left - maxf(delta, 0.0))
		if _pending_heavy_hit_time_left <= 0.0:
			_pending_heavy_hit_confirm = false
	if _heavy_hit_done:
		_complete_heavy_prompt()

func _complete_heavy_prompt() -> void:
	_heavy_prompt_active = false
	if heavy_hint != null:
		heavy_hint.text = "Great strike. Heavy attack complete."
	await get_tree().create_timer(0.95).timeout
	await _fade_out_dialog(heavy_dialog, 0.22)
	_start_ultimate_prompt()

func _reset_heavy_prompt_state() -> void:
	_heavy_hit_done = false
	_pending_heavy_hit_confirm = false
	_pending_heavy_hit_time_left = 0.0

func _refresh_heavy_prompt_text() -> void:
	var heavy_label: String = _get_action_label(&"attack_heavy")
	if heavy_text != null:
		heavy_text.text = "Now use your Heavy Attack.\nPress %s and land one heavy hit on the target." % heavy_label
	if heavy_hint != null:
		heavy_hint.text = "Heavy Hit: %s" % ("Done" if _heavy_hit_done else "Pending")

func _start_ultimate_prompt() -> void:
	_set_tutorial_step(TutorialStep.ATTACK_ULTIMATE)
	_ultimate_prompt_active = true
	_reset_ultimate_prompt_state()
	_refresh_ultimate_prompt_text()
	if ultimate_dialog != null:
		ultimate_dialog.visible = true
		ultimate_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(ultimate_dialog, "modulate:a", 1.0, 0.25)

func _tick_ultimate_prompt(_delta: float) -> void:
	_lock_dummy_health_full()
	if _ultimate_hit_done:
		_complete_ultimate_prompt()

func _complete_ultimate_prompt() -> void:
	_ultimate_prompt_active = false
	if ultimate_hint != null:
		ultimate_hint.text = "Excellent. Ultimate attack complete."
	await get_tree().create_timer(0.95).timeout
	await _fade_out_dialog(ultimate_dialog, 0.22)
	_start_perfect_dodge_prompt()

func _start_dice_prompt() -> void:
	_set_tutorial_step(TutorialStep.DICE_METER)
	_dice_prompt_active = true
	_dice_explainer_active = true
	_dice_waiting_for_roll = false
	_dice_roll_completed = false
	_dice_recovery_phase_active = false
	_dice_recovered_health_done = false
	_dice_hp_at_roll_start = -1
	_disable_dummy_attacks_for_dice_tutorial()
	_begin_dice_tutorial_overrides()
	_refresh_dice_prompt_text()
	_fill_dice_meter_for_tutorial()
	_set_dice_overlay_hud_priority_enabled(true)
	if intro_overlay != null:
		intro_overlay.visible = true
	if intro_dim != null:
		intro_dim.visible = true
		intro_dim.color = Color(0.0, 0.0, 0.0, 0.72)
	if dice_dialog != null:
		dice_dialog.visible = true
		dice_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(dice_dialog, "modulate:a", 1.0, 0.25)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = true
	_set_player_intro_lock(true)
	await dice_advance_requested
	_dismiss_dice_explainer_and_wait_for_roll()

func _dismiss_dice_explainer_and_wait_for_roll() -> void:
	_dice_explainer_active = false
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
	_set_player_intro_lock(false)
	var trigger_label: String = _get_action_label(&"dice_meter_trigger")
	if dice_text != null:
		dice_text.text = "Activate the Dice Meter now.\n\nPress %s once to roll and apply Crimson Benediction.\n\nThis roll is required to continue." % trigger_label
	if dice_hint != null:
		dice_hint.text = "Objective 1: Activate Dice Meter (%s)\nObjective 2: Recover health during Crimson Benediction (Pending)" % ("Done" if _dice_roll_completed else "Pending")
	_dice_waiting_for_roll = true
	if intro_dim != null:
		intro_dim.visible = false

func _tick_dice_prompt(_delta: float) -> void:
	if _dice_waiting_for_roll and Input.is_action_just_pressed(&"dice_meter_trigger"):
		_trigger_tutorial_crimson_benediction_roll()
	if _dice_recovery_phase_active:
		_tick_dice_recovery_phase()
	if _dice_roll_completed:
		_complete_dice_prompt()

func _complete_dice_prompt() -> void:
	_dice_prompt_active = false
	_dice_explainer_active = false
	_dice_waiting_for_roll = false
	if dice_hint != null:
		dice_hint.text = "Objective: Activate Dice Meter (Done)"
	await get_tree().create_timer(0.45).timeout
	await _fade_out_dialog(dice_dialog, 0.22)
	_set_dice_overlay_hud_priority_enabled(false)
	_end_dice_tutorial_overrides()
	await get_tree().create_timer(1.0).timeout
	_start_put_together_step()

func _start_perfect_dodge_prompt() -> void:
	_set_tutorial_step(TutorialStep.PERFECT_DODGE)
	_perfect_dodge_prompt_active = true
	_reset_perfect_dodge_prompt_state()
	_configure_dummy_for_perfect_dodge()
	_refresh_perfect_dodge_prompt_text()
	if perfect_dodge_dialog != null:
		perfect_dodge_dialog.visible = true
		perfect_dodge_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(perfect_dodge_dialog, "modulate:a", 1.0, 0.25)

func _tick_perfect_dodge_prompt(_delta: float) -> void:
	if _dummy_health_lock_enabled:
		_lock_dummy_health_full()
	_face_dummy_toward_player(_attack_dummy)
	if _perfect_dodge_done:
		_complete_perfect_dodge_prompt()

func _complete_perfect_dodge_prompt() -> void:
	_perfect_dodge_prompt_active = false
	if perfect_dodge_hint != null:
		perfect_dodge_hint.text = "Perfect timing. You can now read enemy strikes safely."
	await get_tree().create_timer(0.95).timeout
	await _fade_out_dialog(perfect_dodge_dialog, 0.22)
	_start_dice_prompt()

func _start_put_together_step() -> void:
	_set_tutorial_step(TutorialStep.PUT_IT_ALL_TOGETHER)
	_put_together_intro_active = true
	_put_together_objective_active = false
	_put_together_completed = false
	_put_together_enemy_defeated = false
	_put_together_chest_spawned = false
	_put_together_chest_opened = false
	_put_together_modifier_chosen = false
	_clear_tutorial_reward_chest()
	_set_exit_portal_enabled(false)
	_refresh_put_together_text()
	if intro_overlay != null:
		intro_overlay.visible = true
	if intro_dim != null:
		intro_dim.visible = true
		intro_dim.color = Color(0.0, 0.0, 0.0, 0.72)
	if final_challenge_dialog != null:
		final_challenge_dialog.visible = true
		final_challenge_dialog.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(final_challenge_dialog, "modulate:a", 1.0, 0.25)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = true
	_set_player_intro_lock(true)
	await put_together_advance_requested
	_put_together_intro_active = false
	if tree != null:
		tree.paused = false
	_set_player_intro_lock(false)
	_configure_dummy_for_final_challenge()
	if intro_dim != null:
		intro_dim.visible = false
	_put_together_objective_active = true
	if final_challenge_text != null:
		final_challenge_text.text = "Defeat the enemy in front of you to proceed."
	if final_challenge_hint != null:
		final_challenge_hint.text = "Objective: Defeat the enemy (Pending)"

func _tick_put_together_objective(_delta: float) -> void:
	if _put_together_completed:
		return
	if not _put_together_enemy_defeated and _is_dummy_defeated():
		_put_together_enemy_defeated = true
		if final_challenge_hint != null:
			final_challenge_hint.text = "Objective: Defeat the enemy (Done)"
		_spawn_tutorial_reward_chest()
		_refresh_put_together_chest_objective_text()
		return
	if _put_together_enemy_defeated and _put_together_modifier_chosen:
		_put_together_completed = true
		_complete_put_together_step()

func _complete_put_together_step() -> void:
	_put_together_objective_active = false
	if final_challenge_hint != null:
		final_challenge_hint.text = "Objective: Loot chest and choose modifier (Done)"
	_set_exit_portal_enabled(true)
	await get_tree().create_timer(0.8).timeout
	await _fade_out_dialog(final_challenge_dialog, 0.22)
	_set_tutorial_step(TutorialStep.COMPLETE)
	_restore_all_tutorial_inputs()
	if intro_overlay != null:
		intro_overlay.visible = false

func _reset_put_together_state() -> void:
	_put_together_intro_active = false
	_put_together_objective_active = false
	_put_together_completed = false
	_put_together_enemy_defeated = false
	_put_together_chest_spawned = false
	_put_together_chest_opened = false
	_put_together_modifier_chosen = false
	_modifier_explainer_active = false
	_clear_tutorial_reward_chest()
	_set_exit_portal_enabled(false)

func _refresh_put_together_text() -> void:
	if final_challenge_text != null:
		final_challenge_text.text = "Time to put everything together.\nDefeat the enemy in front of you."
	if final_challenge_hint != null:
		final_challenge_hint.text = "Press Enter to begin."

func _refresh_put_together_chest_objective_text() -> void:
	if final_challenge_text != null:
		final_challenge_text.text = "Well done.\nOpen the reward chest and choose one modifier."
	if final_challenge_hint != null:
		var chest_state: String = "Done" if _put_together_chest_opened else "Pending"
		var mod_state: String = "Done" if _put_together_modifier_chosen else "Pending"
		final_challenge_hint.text = "Open chest: %s    Choose modifier: %s" % [chest_state, mod_state]

func _spawn_tutorial_reward_chest() -> void:
	if _put_together_chest_spawned:
		return
	if REWARD_CHEST_SCENE == null:
		return
	var chest_node: Node = REWARD_CHEST_SCENE.instantiate()
	var chest2d: Node2D = chest_node as Node2D
	if chest2d == null:
		if chest_node != null and is_instance_valid(chest_node):
			chest_node.queue_free()
		return
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = self
	root_scene.add_child(chest2d)
	chest2d.global_position = _get_tutorial_reward_chest_spawn_position()
	_put_together_reward_chest = chest2d
	_put_together_chest_spawned = true
	if chest2d.has_signal("opened"):
		chest2d.connect("opened", Callable(self, "_on_tutorial_reward_chest_opened"))

func _on_tutorial_reward_chest_opened(_chest: Node) -> void:
	_put_together_chest_opened = true
	_refresh_put_together_chest_objective_text()
	await _show_modifier_explainer_before_modifier_selection()
	if dice_modifier_choice != null and dice_modifier_choice.has_method("open_from_chest"):
		dice_modifier_choice.call("open_from_chest", 1, _put_together_reward_chest)

func _show_modifier_explainer_before_modifier_selection() -> void:
	_modifier_explainer_active = true
	if intro_overlay != null:
		intro_overlay.visible = true
	if intro_dim != null:
		intro_dim.visible = true
		intro_dim.color = Color(0.0, 0.0, 0.0, 0.72)
	if final_challenge_dialog != null:
		final_challenge_dialog.visible = true
		final_challenge_dialog.modulate.a = 1.0
	if final_challenge_text != null:
		final_challenge_text.text = "Modifiers apply only to the world you are in.\nEach choice shifts your Dice range and adds a gameplay effect.\nEach new world starts with no modifiers."
	if final_challenge_hint != null:
		final_challenge_hint.text = "Press Enter to view modifier choices."
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = true
	_set_player_intro_lock(true)
	await modifier_explainer_advance_requested
	_modifier_explainer_active = false
	if tree != null:
		tree.paused = false
	_set_player_intro_lock(false)
	if final_challenge_dialog != null:
		final_challenge_dialog.visible = false
	# Disable tutorial overlay while cards are open so nothing blocks clicks.
	if intro_overlay != null:
		intro_overlay.visible = false

func _connect_modifier_choice_signal() -> void:
	if dice_modifier_choice == null:
		return
	if not dice_modifier_choice.has_signal("modifier_chosen"):
		return
	var cb: Callable = Callable(self, "_on_modifier_chosen_for_tutorial")
	if not dice_modifier_choice.is_connected("modifier_chosen", cb):
		dice_modifier_choice.connect("modifier_chosen", cb)

func _disconnect_modifier_choice_signal() -> void:
	if dice_modifier_choice == null:
		return
	if not dice_modifier_choice.has_signal("modifier_chosen"):
		return
	var cb: Callable = Callable(self, "_on_modifier_chosen_for_tutorial")
	if dice_modifier_choice.is_connected("modifier_chosen", cb):
		dice_modifier_choice.disconnect("modifier_chosen", cb)

func _on_modifier_chosen_for_tutorial() -> void:
	if not _put_together_enemy_defeated:
		return
	_put_together_modifier_chosen = true
	_refresh_put_together_chest_objective_text()

func _clear_tutorial_reward_chest() -> void:
	if _put_together_reward_chest != null and is_instance_valid(_put_together_reward_chest):
		_put_together_reward_chest.queue_free()
	_put_together_reward_chest = null

func _get_tutorial_reward_chest_spawn_position() -> Vector2:
	if tutorial_chest_spawn_marker != null and is_instance_valid(tutorial_chest_spawn_marker):
		return tutorial_chest_spawn_marker.global_position
	return TUTORIAL_REWARD_CHEST_POS

func _sync_tutorial_reward_chest_to_marker() -> void:
	if _put_together_reward_chest == null or not is_instance_valid(_put_together_reward_chest):
		return
	_put_together_reward_chest.global_position = _get_tutorial_reward_chest_spawn_position()

func _set_exit_portal_enabled(enabled: bool) -> void:
	if tutorial_exit_portal == null or not is_instance_valid(tutorial_exit_portal):
		return
	tutorial_exit_portal.visible = enabled
	tutorial_exit_portal.set_process(enabled)
	var interaction_area: Area2D = tutorial_exit_portal.get_node_or_null("InteractionArea") as Area2D
	if interaction_area != null:
		interaction_area.monitoring = enabled
		interaction_area.monitorable = enabled
		if enabled:
			var has_player_overlap: bool = false
			for body: Node2D in interaction_area.get_overlapping_bodies():
				if body != null and body.is_in_group(&"player"):
					has_player_overlap = true
					break
			if "_player_nearby" in tutorial_exit_portal:
				tutorial_exit_portal.set("_player_nearby", has_player_overlap)
		elif "_player_nearby" in tutorial_exit_portal:
			tutorial_exit_portal.set("_player_nearby", false)
	if enabled:
		if not tutorial_exit_portal.is_in_group(&"interactable"):
			tutorial_exit_portal.add_to_group(&"interactable")
		if not tutorial_exit_portal.is_in_group(&"portal"):
			tutorial_exit_portal.add_to_group(&"portal")
	else:
		if tutorial_exit_portal.is_in_group(&"interactable"):
			tutorial_exit_portal.remove_from_group(&"interactable")
		if tutorial_exit_portal.is_in_group(&"portal"):
			tutorial_exit_portal.remove_from_group(&"portal")

func _reset_perfect_dodge_prompt_state() -> void:
	_perfect_dodge_done = false

func _refresh_perfect_dodge_prompt_text() -> void:
	var dodge_label: String = _get_action_label(&"Dodge")
	if String(dodge_label) == "Dodge":
		dodge_label = _get_action_label(&"dash")
	if perfect_dodge_text != null:
		perfect_dodge_text.text = "Perfect Dodge Tutorial\n\nHold your ground. Let the enemy swing, then dodge at the last moment.\nUse %s right before impact to trigger a Perfect Dodge." % dodge_label
	if perfect_dodge_hint != null:
		perfect_dodge_hint.text = "Objective: Complete 1 Perfect Dodge (%s)" % ("Done" if _perfect_dodge_done else "Pending")

func _reset_ultimate_prompt_state() -> void:
	_ultimate_hit_done = false

func _refresh_ultimate_prompt_text() -> void:
	var ultimate_label: String = _get_action_label(&"ultimate")
	if ultimate_text != null:
		ultimate_text.text = "Finish this sequence with your Ultimate.\nPress %s and land one ultimate hit." % ultimate_label
	if ultimate_hint != null:
		ultimate_hint.text = "Ultimate Hit: %s" % ("Done" if _ultimate_hit_done else "Pending")

func _reset_dice_prompt_state() -> void:
	_dice_prompt_active = false
	_dice_explainer_active = false
	_dice_waiting_for_roll = false
	_dice_roll_completed = false
	_dice_recovery_phase_active = false
	_dice_recovered_health_done = false
	_dice_hp_at_roll_start = -1

func _refresh_dice_prompt_text() -> void:
	var trigger_label: String = _get_action_label(&"dice_meter_trigger")
	var min_roll: int = int(RunStateSingleton.dice_min) if RunStateSingleton != null else 1
	var max_roll: int = int(RunStateSingleton.dice_max) if RunStateSingleton != null else 20
	var hp_percent: int = int(round(DICE_TUTORIAL_HP_RATIO * 100.0))
	if dice_text != null:
		dice_text.text = "The Dice Meter charges from damage dealt, enemy kills, and perfect dodges.\n\nWhen full, press %s to consume the meter and roll within your current range.\n\nLow rolls lean dangerous, high rolls lean divine, and extremes can trigger catastrophe or miracle.\n\nTutorial setup: your HP is reduced to %d%% to showcase Crimson Benediction sustain.\nCurrent range: %d-%d." % [trigger_label, hp_percent, min_roll, max_roll]
	if dice_hint != null:
		dice_hint.text = "Warning: HP reduced to %d%% for this step. Press Enter to continue." % hp_percent

func _set_dice_overlay_hud_priority_enabled(enabled: bool) -> void:
	if intro_overlay == null:
		return
	if enabled:
		_dice_intro_overlay_prev_layer = intro_overlay.layer
		# Place overlay below UI CanvasLayer so Dice HUD remains visible.
		intro_overlay.layer = 0
	else:
		intro_overlay.layer = _dice_intro_overlay_prev_layer

func _get_dice_meter_singleton() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DiceMeterSingleton")

func _connect_dice_meter_signals() -> void:
	_dice_meter_node = _get_dice_meter_singleton()
	if _dice_meter_node == null:
		return
	if _dice_meter_node.has_signal("roll_resolved"):
		var cb: Callable = Callable(self, "_on_dice_roll_resolved")
		if not _dice_meter_node.is_connected("roll_resolved", cb):
			_dice_meter_node.connect("roll_resolved", cb)

func _disconnect_dice_meter_signals() -> void:
	if _dice_meter_node == null:
		return
	if _dice_meter_node.has_signal("roll_resolved"):
		var cb: Callable = Callable(self, "_on_dice_roll_resolved")
		if _dice_meter_node.is_connected("roll_resolved", cb):
			_dice_meter_node.disconnect("roll_resolved", cb)

func _fill_dice_meter_for_tutorial() -> void:
	var meter: Node = _get_dice_meter_singleton()
	if meter == null:
		return
	_dice_meter_node = meter
	var max_charge_v: Variant = meter.get("max_charge")
	var current_charge_v: Variant = meter.get("current_charge")
	var max_charge: float = float(max_charge_v) if (max_charge_v is float or max_charge_v is int) else 100.0
	var current_charge: float = float(current_charge_v) if (current_charge_v is float or current_charge_v is int) else 0.0
	var need: float = maxf(0.0, max_charge - current_charge)
	if meter.has_method("add_charge"):
		meter.call("add_charge", maxf(need, max_charge), &"tutorial_dice_meter")
	var new_current_v: Variant = meter.get("current_charge")
	var new_current: float = float(new_current_v) if (new_current_v is float or new_current_v is int) else 0.0
	if new_current + 0.001 < max_charge:
		meter.set("current_charge", max_charge)
		if meter.has_signal("charge_changed"):
			meter.emit_signal("charge_changed", max_charge, max_charge)
		if meter.has_signal("meter_filled"):
			meter.emit_signal("meter_filled")

func _on_dice_roll_resolved(_roll_value: int, event_id: StringName, _band: int) -> void:
	if not _dice_prompt_active or not _dice_waiting_for_roll:
		return
	if event_id != &"dm2_roll10_blood_divine":
		_fill_dice_meter_for_tutorial()
		if dice_hint != null:
			var trigger_label: String = _get_action_label(&"dice_meter_trigger")
			dice_hint.text = "Tutorial requires Crimson Benediction. Press %s again." % trigger_label
		return
	_dice_waiting_for_roll = false
	_dice_recovery_phase_active = true
	_dice_recovered_health_done = false
	_dice_roll_completed = false
	_dice_hp_at_roll_start = _get_player_current_hp()
	_refresh_dice_recovery_text()

func _tick_dice_recovery_phase() -> void:
	var current_hp: int = _get_player_current_hp()
	if _dice_hp_at_roll_start >= 0 and current_hp > _dice_hp_at_roll_start:
		_dice_recovered_health_done = true
	var effect_active: bool = _is_crimson_benediction_active()
	_refresh_dice_recovery_hint(effect_active)
	if effect_active:
		return
	# Effect expired.
	if _dice_recovered_health_done:
		_dice_recovery_phase_active = false
		_dice_roll_completed = true
		return
	# No recovery detected; require another activation attempt.
	_dice_recovery_phase_active = false
	_dice_waiting_for_roll = true
	_fill_dice_meter_for_tutorial()
	if dice_text != null:
		var trigger_label: String = _get_action_label(&"dice_meter_trigger")
		dice_text.text = "No health recovery was detected before Crimson Benediction ended.\n\nPress %s again, then attack to recover health during the effect." % trigger_label

func _refresh_dice_recovery_text() -> void:
	if dice_text != null:
		dice_text.text = "Crimson Benediction is active.\n\nAttack enemies to recover health while the effect lasts.\n\nThis objective is required to continue."
	_refresh_dice_recovery_hint(true)

func _refresh_dice_recovery_hint(effect_active: bool) -> void:
	if dice_hint == null:
		return
	var activate_state: String = "Done"
	var recover_state: String = "Done" if _dice_recovered_health_done else "Pending"
	var timer_text: String = ""
	if effect_active and _dice_meter_node != null and is_instance_valid(_dice_meter_node) and ("active_effect_time_left" in _dice_meter_node):
		var t_left: float = float(_dice_meter_node.get("active_effect_time_left"))
		timer_text = " | Effect time: %.1fs" % maxf(t_left, 0.0)
	dice_hint.text = "Objective 1: Activate Dice Meter (%s)\nObjective 2: Recover health during Crimson Benediction (%s)%s" % [activate_state, recover_state, timer_text]

func _is_crimson_benediction_active() -> bool:
	if _dice_meter_node == null or not is_instance_valid(_dice_meter_node):
		return false
	if not ("active_effect_name" in _dice_meter_node):
		return false
	var effect_name: String = String(_dice_meter_node.get("active_effect_name"))
	if effect_name != "Crimson Benediction":
		return false
	if "active_effect_time_left" in _dice_meter_node:
		return float(_dice_meter_node.get("active_effect_time_left")) > 0.0
	return true

func _get_player_current_hp() -> int:
	if player_node == null or not is_instance_valid(player_node):
		return -1
	var health_node: Node = player_node.get_node_or_null("Health")
	if health_node == null:
		return -1
	if "hp" in health_node:
		return int(health_node.get("hp"))
	return -1

func _begin_dice_tutorial_overrides() -> void:
	var meter: Node = _get_dice_meter_singleton()
	if meter != null:
		_dice_meter_node = meter
		if "trigger_action" in meter:
			_dice_meter_prev_trigger_action = StringName(meter.get("trigger_action"))
			meter.set("trigger_action", StringName(""))
			_dice_trigger_override_active = true
	_set_player_health_to_tutorial_ten_percent()

func _end_dice_tutorial_overrides() -> void:
	if _dice_trigger_override_active and _dice_meter_node != null and is_instance_valid(_dice_meter_node):
		if "trigger_action" in _dice_meter_node:
			_dice_meter_node.set("trigger_action", _dice_meter_prev_trigger_action)
	_dice_trigger_override_active = false

func _set_player_health_to_tutorial_ten_percent() -> void:
	if player_node == null or not is_instance_valid(player_node):
		return
	var health_node: Node = player_node.get_node_or_null("Health")
	if health_node == null:
		return
	if not ("max_hp" in health_node) or not ("hp" in health_node):
		return
	var max_hp: int = int(health_node.get("max_hp"))
	if max_hp <= 0:
		return
	var target_hp: int = maxi(1, int(round(float(max_hp) * DICE_TUTORIAL_HP_RATIO)))
	health_node.set("hp", target_hp)
	if health_node.has_signal("health_changed"):
		health_node.emit_signal("health_changed", target_hp, max_hp)

func _trigger_tutorial_crimson_benediction_roll() -> void:
	if _dice_meter_node == null or not is_instance_valid(_dice_meter_node):
		_dice_meter_node = _get_dice_meter_singleton()
	if _dice_meter_node == null:
		return
	var can_roll: bool = true
	if _dice_meter_node.has_method("can_trigger_roll"):
		can_roll = bool(_dice_meter_node.call("can_trigger_roll"))
	if not can_roll:
		return
	var event_res: Resource = load(CRIMSON_BENEDICTION_EVENT_PATH) as Resource
	if event_res == null:
		return
	var payload: Dictionary = {}
	if _dice_meter_node.has_method("_event_resource_to_payload"):
		payload = _dice_meter_node.call("_event_resource_to_payload", event_res) as Dictionary
	if payload.is_empty():
		return
	var roll: int = 10
	var event_id: StringName = payload.get("event_id", &"dm2_roll10_blood_divine")
	var display_name: String = String(payload.get("display_name", "Crimson Benediction"))
	var brief_text: String = String(payload.get("brief_text", "Your strikes return a trickle of vitality."))
	var description: String = String(payload.get("description", "Divine bloodrite stabilizes sustain through combat pressure."))
	var effect_id: StringName = payload.get("effect_id", &"apply_player_lifesteal")
	var duration_seconds: float = float(payload.get("duration_seconds", 8.0))
	var effect_params: Dictionary = payload.get("effect_params", {"lifesteal_ratio": 0.3})
	var miracle_band: int = 2
	_dice_meter_node.set("current_charge", 0.0)
	if "_pending_outgoing_damage" in _dice_meter_node:
		_dice_meter_node.set("_pending_outgoing_damage", 0.0)
	_dice_meter_node.set("last_roll", roll)
	_dice_meter_node.set("last_event_id", event_id)
	_dice_meter_node.set("last_event_band", miracle_band)
	if _dice_meter_node.has_method("_sync_roll_to_run_state"):
		_dice_meter_node.call("_sync_roll_to_run_state", roll)
	var tutorial_result: Dictionary = {
		"ok": true,
		"roll": roll,
		"event_id": event_id,
		"display_name": display_name,
		"brief_text": brief_text,
		"description": description,
		"band": miracle_band,
		"alignment": 3,
		"alignment_label": "DIVINE",
		"midpoint": 10.0,
		"member_number": roll,
		"member_name": "Blood",
		"member_theme": "Blood",
		"effect_id": effect_id,
		"duration_seconds": duration_seconds,
		"effect_params": effect_params
	}
	_dice_meter_node.set("last_result", tutorial_result)
	_dice_meter_node.set("active_effect_name", display_name)
	_dice_meter_node.set("active_effect_brief_text", brief_text)
	_dice_meter_node.set("active_effect_band", miracle_band)
	_dice_meter_node.set("active_effect_time_left", duration_seconds)
	_dice_meter_node.set("active_effect_hide_timer", false)
	if _dice_meter_node.has_method("_apply_event_result"):
		_dice_meter_node.call("_apply_event_result", tutorial_result)
	if _dice_meter_node.has_signal("roll_resolved"):
		_dice_meter_node.emit_signal("roll_resolved", roll, event_id, miracle_band)
	if _dice_meter_node.has_method("_emit_charge_changed"):
		_dice_meter_node.call("_emit_charge_changed")

func _apply_tutorial_text_alignment_and_spacing() -> void:
	var labels: Array[Label] = [
		intro_text, intro_hint,
		move_text, move_hint,
		jump_text, jump_hint,
		dash_text, dash_hint,
		attack_text, attack_hint,
		heavy_text, heavy_hint,
		ultimate_text, ultimate_hint,
		dice_text, dice_hint,
		perfect_dodge_text, perfect_dodge_hint,
		final_challenge_text, final_challenge_hint
	]
	for label_node: Label in labels:
		if label_node == null:
			continue
		label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_node.add_theme_constant_override("line_spacing", 6)

func _refresh_attack_prompt_text() -> void:
	var light_label: String = _get_action_label(&"attack_light")
	if attack_text != null:
		attack_text.text = "A target stands ahead.\nUse %s and land your full light combo." % light_label
	if attack_hint != null:
		var step1: String = "Done" if _combo_step_1_done else "Pending"
		var step2: String = "Done" if _combo_step_2_done else "Pending"
		var step3: String = "Done" if _combo_step_3_done else "Pending"
		attack_hint.text = "Land Hit 1: %s    Land Hit 2: %s    Land Hit 3: %s" % [step1, step2, step3]

func _spawn_attack_dummy_if_needed() -> void:
	if _attack_dummy != null and is_instance_valid(_attack_dummy):
		return
	if _attack_dummy_spawn_requested:
		return
	if floor_enemy_spawner == null or not is_instance_valid(floor_enemy_spawner):
		return
	if not floor_enemy_spawner.has_method("spawn_floor"):
		return
	_attack_dummy_spawn_requested = true
	floor_enemy_spawner.call("spawn_floor", 0)
	call_deferred("_resolve_spawned_attack_dummy_from_spawner")

func _resolve_spawned_attack_dummy_from_spawner() -> void:
	if _attack_dummy != null and is_instance_valid(_attack_dummy):
		return
	var candidates: Array[Node] = get_tree().get_nodes_in_group("floor1_enemies")
	var best: Node2D = null
	var best_dist: float = INF
	for node: Node in candidates:
		var n2d: Node2D = node as Node2D
		if n2d == null or not is_instance_valid(n2d):
			continue
		var d: float = n2d.global_position.distance_to(ATTACK_DUMMY_POS)
		if d < best_dist:
			best_dist = d
			best = n2d
	if best == null:
		return
	best.name = "TutorialDummyEnemyKnight"
	best.set_meta("tutorial_dummy", true)
	if not best.is_in_group("floor1_enemies"):
		best.add_to_group("floor1_enemies")
	_capture_dummy_baseline(best)
	_attack_dummy = best
	_disable_enemy_ai_for_dummy(best)
	_configure_attack_dummy_visual_and_ground(best)

func _capture_dummy_baseline(dummy: Node2D) -> void:
	if dummy == null or not is_instance_valid(dummy):
		return
	if "move_speed" in dummy:
		_attack_dummy_base_move_speed = float(dummy.get("move_speed"))
	if "attack_damage" in dummy:
		_attack_dummy_base_attack_damage = int(dummy.get("attack_damage"))
	if "attack_cooldown" in dummy:
		_attack_dummy_base_attack_cooldown = float(dummy.get("attack_cooldown"))
	if "aggro_range" in dummy:
		_attack_dummy_base_aggro_range = float(dummy.get("aggro_range"))
	if "lose_aggro_range" in dummy:
		_attack_dummy_base_lose_aggro_range = float(dummy.get("lose_aggro_range"))
	if "patrol_enabled" in dummy:
		_attack_dummy_base_patrol_enabled = bool(dummy.get("patrol_enabled"))
	if "strikezone_scene" in dummy:
		_attack_dummy_base_strikezone_scene = dummy.get("strikezone_scene")
	var health_node: Node = dummy.get_node_or_null("Health")
	if health_node != null and "max_hp" in health_node:
		_attack_dummy_base_max_hp = int(health_node.get("max_hp"))

func _disable_enemy_ai_for_dummy(dummy: Node2D) -> void:
	if dummy == null or not is_instance_valid(dummy):
		return
	# Keep processing ON so it uses the same floor settle + animation refresh path
	# as normal world enemies; disable behavior by zeroing aggro/patrol/attack.
	if "patrol_enabled" in dummy:
		dummy.set("patrol_enabled", false)
	if "aggro_range" in dummy:
		dummy.set("aggro_range", 0.0)
	if "lose_aggro_range" in dummy:
		dummy.set("lose_aggro_range", 0.0)
	if "aggro_by_same_floor_presence" in dummy:
		dummy.set("aggro_by_same_floor_presence", false)
	if "move_speed" in dummy:
		dummy.set("move_speed", 0.0)
	if "contact_damage" in dummy:
		dummy.set("contact_damage", 0)
	if "attack_damage" in dummy:
		dummy.set("attack_damage", 0)
	if "strikezone_scene" in dummy:
		dummy.set("strikezone_scene", null)
	if "use_floor_activation" in dummy:
		dummy.set("use_floor_activation", false)
	if "_active" in dummy:
		dummy.set("_active", true)
	dummy.set_process(true)
	dummy.set_physics_process(true)
	if dummy is CharacterBody2D:
		(dummy as CharacterBody2D).velocity = Vector2.ZERO
	_configure_dummy_health_lock(dummy)
	_bind_dummy_idle_recovery_on_hit(dummy)

func _configure_dummy_for_perfect_dodge() -> void:
	if _attack_dummy == null or not is_instance_valid(_attack_dummy):
		return
	# Keep the dummy rooted in place but combat-active for dodge practice.
	if "move_speed" in _attack_dummy:
		_attack_dummy.set("move_speed", 0.0)
	if "patrol_enabled" in _attack_dummy:
		_attack_dummy.set("patrol_enabled", false)
	if "aggro_by_same_floor_presence" in _attack_dummy:
		_attack_dummy.set("aggro_by_same_floor_presence", true)
	if "aggro_range" in _attack_dummy:
		_attack_dummy.set("aggro_range", 900.0)
	if "lose_aggro_range" in _attack_dummy:
		_attack_dummy.set("lose_aggro_range", 1200.0)
	if "contact_damage" in _attack_dummy:
		_attack_dummy.set("contact_damage", 0)
	if "attack_damage" in _attack_dummy:
		_attack_dummy.set("attack_damage", 12)
	if "attack_cooldown" in _attack_dummy:
		_attack_dummy.set("attack_cooldown", 1.25)
	if "stop_when_in_attack_range" in _attack_dummy:
		_attack_dummy.set("stop_when_in_attack_range", true)
	if "strikezone_scene" in _attack_dummy:
		_attack_dummy.set("strikezone_scene", ENEMY_MELEE_HITBOX_SCENE)
	if "use_floor_activation" in _attack_dummy:
		_attack_dummy.set("use_floor_activation", false)
	if "_active" in _attack_dummy:
		_attack_dummy.set("_active", true)
	_face_dummy_toward_player(_attack_dummy)

func _configure_dummy_for_final_challenge() -> void:
	if _attack_dummy == null or not is_instance_valid(_attack_dummy):
		return
	_dummy_health_lock_enabled = false
	if "patrol_enabled" in _attack_dummy:
		_attack_dummy.set("patrol_enabled", _attack_dummy_base_patrol_enabled)
	if "move_speed" in _attack_dummy:
		_attack_dummy.set("move_speed", _attack_dummy_base_move_speed)
	if "aggro_range" in _attack_dummy:
		_attack_dummy.set("aggro_range", _attack_dummy_base_aggro_range)
	if "lose_aggro_range" in _attack_dummy:
		_attack_dummy.set("lose_aggro_range", _attack_dummy_base_lose_aggro_range)
	if "attack_damage" in _attack_dummy:
		_attack_dummy.set("attack_damage", _attack_dummy_base_attack_damage)
	if "attack_cooldown" in _attack_dummy:
		_attack_dummy.set("attack_cooldown", _attack_dummy_base_attack_cooldown)
	if "strikezone_scene" in _attack_dummy:
		_attack_dummy.set("strikezone_scene", _attack_dummy_base_strikezone_scene)
	if "_attack_cd" in _attack_dummy:
		_attack_dummy.set("_attack_cd", 0.0)
	if "_active" in _attack_dummy:
		_attack_dummy.set("_active", true)
	var health_node: Node = _attack_dummy.get_node_or_null("Health")
	if health_node != null:
		if "max_hp" in health_node:
			health_node.set("max_hp", _attack_dummy_base_max_hp)
		if "hp" in health_node:
			health_node.set("hp", _attack_dummy_base_max_hp)
		if health_node.has_signal("health_changed"):
			health_node.emit_signal("health_changed", _attack_dummy_base_max_hp, _attack_dummy_base_max_hp)
	var health_bar: ProgressBar = _attack_dummy.get_node_or_null("HealthBar") as ProgressBar
	if health_bar != null:
		health_bar.visible = true
		health_bar.max_value = float(_attack_dummy_base_max_hp)
		health_bar.value = float(_attack_dummy_base_max_hp)

func _is_dummy_defeated() -> bool:
	if _attack_dummy == null or not is_instance_valid(_attack_dummy):
		return true
	var health_node: Node = _attack_dummy.get_node_or_null("Health")
	if health_node == null:
		return false
	if "hp" in health_node:
		return int(health_node.get("hp")) <= 0
	return false

func _disable_dummy_attacks_for_dice_tutorial() -> void:
	if _attack_dummy == null or not is_instance_valid(_attack_dummy):
		return
	if "attack_damage" in _attack_dummy:
		_attack_dummy.set("attack_damage", 0)
	if "strikezone_scene" in _attack_dummy:
		_attack_dummy.set("strikezone_scene", null)
	if "_attack_cd" in _attack_dummy:
		_attack_dummy.set("_attack_cd", 9999.0)
	# Ensure dummy remains non-aggressive while Dice tutorial is active.
	if "aggro_range" in _attack_dummy:
		_attack_dummy.set("aggro_range", 0.0)
	if "lose_aggro_range" in _attack_dummy:
		_attack_dummy.set("lose_aggro_range", 0.0)

func _configure_attack_dummy_visual_and_ground(dummy: Node2D) -> void:
	if dummy == null or not is_instance_valid(dummy):
		return
	# Use FloorEnemySpawner marker placement directly (same as Worlds 1/2/3).
	# Extra manual floor snapping can over-correct and sink the enemy visually.
	_face_dummy_toward_player(dummy)
	_force_dummy_idle_animation(dummy)

func _bind_dummy_idle_recovery_on_hit(dummy: Node2D) -> void:
	var health_node: Node = dummy.get_node_or_null("Health")
	if health_node == null:
		return
	if health_node.has_signal("damaged"):
		var damaged_cb: Callable = Callable(self, "_on_dummy_damaged_plain")
		if not health_node.is_connected("damaged", damaged_cb):
			health_node.connect("damaged", damaged_cb)
	if health_node.has_signal("damaged_tagged"):
		var tagged_cb: Callable = Callable(self, "_on_dummy_damaged_tagged")
		if not health_node.is_connected("damaged_tagged", tagged_cb):
			health_node.connect("damaged_tagged", tagged_cb)
	if health_node.has_signal("damaged_tagged_crit"):
		var crit_cb: Callable = Callable(self, "_on_dummy_damaged_tagged_crit")
		if not health_node.is_connected("damaged_tagged_crit", crit_cb):
			health_node.connect("damaged_tagged_crit", crit_cb)

func _on_dummy_damaged_plain(_amount: int) -> void:
	_schedule_dummy_idle_recover()

func _on_dummy_damaged_tagged(_amount: int, _tag: StringName) -> void:
	if _ultimate_prompt_active and _tag == &"ultimate":
		_ultimate_hit_done = true
		_refresh_ultimate_prompt_text()
	_schedule_dummy_idle_recover()

func _on_dummy_damaged_tagged_crit(_amount: int, _tag: StringName, _is_crit: bool) -> void:
	_schedule_dummy_idle_recover()

func _schedule_dummy_idle_recover() -> void:
	if _attack_dummy == null or not is_instance_valid(_attack_dummy):
		return
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if _attack_dummy == null or not is_instance_valid(_attack_dummy):
			return
		_force_dummy_idle_animation(_attack_dummy)
	)

func _snap_dummy_to_floor(dummy: Node2D) -> void:
	var world: World2D = dummy.get_world_2d()
	if world == null:
		return
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	var from_pos: Vector2 = dummy.global_position + Vector2(0.0, -DUMMY_FLOOR_RAY_UP)
	var to_pos: Vector2 = dummy.global_position + Vector2(0.0, DUMMY_FLOOR_RAY_DOWN)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1
	query.exclude = [dummy]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return
	var floor_y: float = (hit.get("position", to_pos) as Vector2).y
	var bottom_offset: float = 28.0
	if "ground_probe_origin_y" in dummy:
		bottom_offset = float(dummy.get("ground_probe_origin_y"))
	var pos: Vector2 = dummy.global_position
	pos.y = floor_y - bottom_offset
	dummy.global_position = pos
	if dummy is CharacterBody2D:
		(dummy as CharacterBody2D).velocity = Vector2.ZERO

func _configure_dummy_health_lock(dummy: Node2D) -> void:
	_dummy_health_lock_enabled = true
	var health_node: Node = dummy.get_node_or_null("Health")
	if health_node == null:
		return
	if "max_hp" in health_node:
		health_node.set("max_hp", TUTORIAL_DUMMY_LOCKED_MAX_HP)
	if "hp" in health_node:
		health_node.set("hp", TUTORIAL_DUMMY_LOCKED_MAX_HP)
	var health_bar: ProgressBar = dummy.get_node_or_null("HealthBar") as ProgressBar
	if health_bar != null:
		health_bar.visible = false
		health_bar.max_value = float(TUTORIAL_DUMMY_LOCKED_MAX_HP)
		health_bar.value = float(TUTORIAL_DUMMY_LOCKED_MAX_HP)

func _lock_dummy_health_full() -> void:
	if _attack_dummy == null or not is_instance_valid(_attack_dummy):
		return
	var health_node: Node = _attack_dummy.get_node_or_null("Health")
	if health_node == null:
		return
	var max_hp: int = TUTORIAL_DUMMY_LOCKED_MAX_HP
	if "max_hp" in health_node:
		max_hp = max(max_hp, int(health_node.get("max_hp")))
		health_node.set("max_hp", max_hp)
	if "hp" in health_node:
		health_node.set("hp", max_hp)
	var health_bar: ProgressBar = _attack_dummy.get_node_or_null("HealthBar") as ProgressBar
	if health_bar != null:
		health_bar.visible = false
		health_bar.max_value = float(max_hp)
		health_bar.value = float(max_hp)

func _face_dummy_toward_player(dummy: Node2D) -> void:
	if dummy == null or not is_instance_valid(dummy):
		return
	if player_node == null or not is_instance_valid(player_node):
		return
	if not (player_node is Node2D):
		return
	var player_pos: Vector2 = (player_node as Node2D).global_position
	var dir: int = 1 if player_pos.x >= dummy.global_position.x else -1
	if "_facing_dir" in dummy:
		dummy.set("_facing_dir", dir)
	if dummy.has_method("_apply_sprite_facing"):
		dummy.call("_apply_sprite_facing", dir)
	var view: Node = dummy.get_node_or_null("Enemy3DView")
	if view != null and view.has_method("set_facing"):
		view.call("set_facing", dir)

func _force_dummy_idle_animation(dummy: Node2D) -> void:
	var idle_anim: StringName = &""
	if "anim_idle" in dummy:
		var idle_v: Variant = dummy.get("anim_idle")
		if idle_v is StringName:
			idle_anim = idle_v as StringName
	if idle_anim == &"":
		idle_anim = &"Player/Skeletons_Idle"
	if dummy.has_method("_play_anim"):
		dummy.call("_play_anim", idle_anim, false)

func _fade_out_dialog(dialog: CanvasItem, duration: float) -> void:
	if dialog == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(dialog, "modulate:a", 0.0, maxf(duration, 0.01))
	await tween.finished
	if dialog is Control:
		(dialog as Control).visible = false

func _capture_input_gate_snapshot() -> void:
	if _input_gate_captured:
		return
	for action: StringName in TUTORIAL_LOCKED_ACTIONS:
		var action_s: String = String(action)
		if not InputMap.has_action(action_s):
			continue
		_input_gate_snapshot[action] = InputMap.action_get_events(action_s).duplicate(true)
	_input_gate_captured = true

func _set_tutorial_step(step_id: int) -> void:
	_current_step = step_id
	var allowed_variant: Variant = STEP_ALLOWED_ACTIONS.get(step_id, [])
	var allowed_actions: Array[StringName] = []
	if allowed_variant is Array:
		for a: Variant in (allowed_variant as Array):
			if a is StringName:
				allowed_actions.append(a as StringName)
	_apply_allowed_tutorial_actions(allowed_actions)

func _apply_allowed_tutorial_actions(allowed_actions: Array[StringName]) -> void:
	_capture_input_gate_snapshot()
	var allowed_map: Dictionary = {}
	for a: StringName in allowed_actions:
		allowed_map[a] = true
	for action: StringName in TUTORIAL_LOCKED_ACTIONS:
		var action_s: String = String(action)
		if not InputMap.has_action(action_s):
			continue
		InputMap.action_erase_events(action_s)
		if not allowed_map.has(action):
			continue
		var saved_v: Variant = _input_gate_snapshot.get(action, null)
		if not (saved_v is Array):
			continue
		for e: InputEvent in (saved_v as Array):
			if e != null:
				InputMap.action_add_event(action_s, e)

func _restore_all_tutorial_inputs() -> void:
	if not _input_gate_captured:
		return
	for action: StringName in TUTORIAL_LOCKED_ACTIONS:
		var action_s: String = String(action)
		if not InputMap.has_action(action_s):
			continue
		InputMap.action_erase_events(action_s)
		var saved_v: Variant = _input_gate_snapshot.get(action, null)
		if not (saved_v is Array):
			continue
		for e: InputEvent in (saved_v as Array):
			if e != null:
				InputMap.action_add_event(action_s, e)

func _is_player_airborne() -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false
	if player_node.has_method("is_on_floor"):
		return not bool(player_node.call("is_on_floor"))
	return false

func _get_action_label(action: StringName) -> String:
	if not InputMap.has_action(String(action)):
		return String(action)
	var events: Array[InputEvent] = InputMap.action_get_events(String(action))
	for e: InputEvent in events:
		if e is InputEventKey:
			var k: InputEventKey = e as InputEventKey
			if k.physical_keycode != 0:
				return OS.get_keycode_string(k.physical_keycode)
			if k.keycode != 0:
				return OS.get_keycode_string(k.keycode)
	for em: InputEvent in events:
		if em is InputEventMouseButton:
			var mb: InputEventMouseButton = em as InputEventMouseButton
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					return "Left Click"
				MOUSE_BUTTON_RIGHT:
					return "Right Click"
				MOUSE_BUTTON_MIDDLE:
					return "Middle Click"
				_:
					return "Mouse Button %d" % mb.button_index
	for e2: InputEvent in events:
		if e2 is InputEventJoypadButton:
			var jb: InputEventJoypadButton = e2 as InputEventJoypadButton
			return "Joypad Button %d" % jb.button_index
		if e2 is InputEventJoypadMotion:
			var jm: InputEventJoypadMotion = e2 as InputEventJoypadMotion
			return "Joypad Axis %d" % jm.axis
	return String(action)

func _set_player_intro_lock(locked: bool) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return
	if player_node.has_method("set_cutscene_motion_lock"):
		player_node.call("set_cutscene_motion_lock", locked)
	if player_node.has_method("set_input_locked"):
		player_node.call("set_input_locked", locked)
	if "input_locked" in player_node:
		player_node.set("input_locked", locked)

func _wait_for_loading_transition_to_finish(timeout_seconds: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var t_left: float = maxf(timeout_seconds, 0.0)
	while t_left > 0.0:
		var tl: Node = tree.root.get_node_or_null("TransitionLayer")
		if tl == null or not is_instance_valid(tl):
			return
		var still_loading: bool = false
		if tl is CanvasLayer and (tl as CanvasLayer).visible:
			still_loading = true
		if "_is_transitioning" in tl and bool(tl.get("_is_transitioning")):
			still_loading = true
		var rect: CanvasItem = tl.get_node_or_null("ColorRect") as CanvasItem
		if rect != null and rect.modulate.a > 0.01:
			still_loading = true
		var label: CanvasItem = tl.get_node_or_null("Label") as CanvasItem
		if label != null and label.modulate.a > 0.01:
			still_loading = true
		if not still_loading:
			return
		await tree.process_frame
		t_left -= 1.0 / 60.0
