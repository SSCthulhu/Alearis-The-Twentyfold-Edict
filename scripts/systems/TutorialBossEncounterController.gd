extends "res://scripts/systems/EncounterController.gd"
class_name TutorialBossEncounterController

const TutorialFateTileScene: PackedScene = preload("res://scenes/world/TutorialFateTile.tscn")
const TILE_SHAPE_SYMBOLS: Array[String] = ["SQUARE", "DIAMOND", "TRIANGLE", "CIRCLE", "OCTAGON"]

@export var force_world1_scene_path: String = "res://scenes/world/World1.tscn"

@export_group("Tutorial Phases")
@export_range(0.10, 0.95, 0.01) var phase2_hp_threshold: float = 0.78
@export_range(0.10, 0.95, 0.01) var phase3_hp_threshold: float = 0.55
@export_range(0.05, 0.95, 0.01) var phase4_hp_threshold: float = 0.30
@export var phase_intro_text: Array[String] = [
	"",
	"Phase 1 - Read the marker.\nNo attacks yet. Match the shown shape and step onto that tile.",
	"Phase 2 - Bullet pressure begins.\nShape marker stays visible. Match it quickly, then move to DPS.",
	"Phase 3 - Memory test.\nThe marker fades. Remember the shown shape before it vanishes.",
	"Phase 4 - Final exam.\nMarker fades faster. Wrong tiles now hurt, then recover and adapt."
]

@export_group("Fate Tile Mechanics")
@export var fate_tile_spawns_path: NodePath = ^"../Arena/FateTileSpawns"
@export var fate_fx_folder: String = "res://art/Socket"
@export var fate_fx_prefix: String = "A_FX_aqua blue"
@export_range(1, 200, 1) var fate_frame_count: int = 90
@export_range(1, 8, 1) var fate_frame_padding: int = 5
@export var fate_fx_suffix: String = ".png"
@export_range(0.5, 12.0, 0.1) var cycle_interval_phase1: float = 7.4
@export_range(0.5, 12.0, 0.1) var cycle_interval_phase2: float = 6.6
@export_range(0.5, 12.0, 0.1) var cycle_interval_phase3: float = 5.6
@export_range(0.5, 12.0, 0.1) var cycle_interval_phase4: float = 4.9
@export_range(0.2, 8.0, 0.1) var telegraph_phase1: float = 2.6
@export_range(0.2, 8.0, 0.1) var telegraph_phase2: float = 2.2
@export_range(0.2, 8.0, 0.1) var telegraph_phase3: float = 1.7
@export_range(0.2, 8.0, 0.1) var telegraph_phase4: float = 1.35
@export_range(0.5, 12.0, 0.1) var loaded_window_duration_phase1: float = 5.8
@export_range(0.5, 12.0, 0.1) var loaded_window_duration_phase2: float = 5.4
@export_range(0.5, 12.0, 0.1) var loaded_window_duration_phase3: float = 4.8
@export_range(0.5, 12.0, 0.1) var loaded_window_duration_phase4: float = 4.2
@export_range(0.5, 12.0, 0.1) var loaded_engage_timeout_phase1: float = 7.0
@export_range(0.5, 12.0, 0.1) var loaded_engage_timeout_phase2: float = 6.0
@export_range(0.5, 12.0, 0.1) var loaded_engage_timeout_phase3: float = 5.0
@export_range(0.5, 12.0, 0.1) var loaded_engage_timeout_phase4: float = 4.4
@export var dps_engage_zone_path: NodePath = ^"../DpsEngageZone"
@export var loaded_window_prompt: String = "Come forth and show your might."
@export var loaded_window_begin_text: String = "Loaded Fate active. Melee now."
@export var loaded_window_end_text: String = "Loaded Fate closed. Read the next roll."
@export var loaded_window_missed_text: String = "Window missed. Reposition and read again."
@export_range(0, 50, 1) var wrong_tile_damage_phase3: int = 6
@export_range(0, 50, 1) var wrong_tile_damage_phase4: int = 10
@export var wrong_tile_phase4_debuff_id: StringName = &"tutorial_fate_marked"
@export_range(0.0, 5.0, 0.1) var wrong_tile_phase4_debuff_duration: float = 1.4
@export_group("Fate Tile Dwell Cues")
@export_range(0.10, 4.0, 0.05) var wrong_tile_fail_dwell: float = 1.4
@export_range(0.10, 4.0, 0.05) var right_tile_confirm_dwell: float = 1.0
@export var right_tile_confirm_text: String = "Fate aligned. Close in and damage the boss."
@export var right_tile_confirm_hint: String = ""
@export_range(0.10, 1.0, 0.01) var right_tile_flash_peak_alpha: float = 0.90
@export_range(0.01, 0.50, 0.01) var right_tile_flash_up_time: float = 0.06
@export_range(0.01, 0.50, 0.01) var right_tile_flash_down_time: float = 0.14
@export_range(0.2, 5.0, 0.1) var marker_reveal_duration_phase3: float = 1.9
@export_range(0.2, 5.0, 0.1) var marker_reveal_duration_phase4: float = 1.2
@export var marker_outline_color: Color = Color(0.05, 0.08, 0.12, 0.95)
@export_range(8.0, 80.0, 1.0) var marker_tile_radius: float = 20.0
@export_range(8.0, 140.0, 1.0) var marker_boss_radius: float = 46.0
@export_range(1.0, 12.0, 0.5) var marker_outline_width: float = 3.0
@export_group("Debug")
@export var debug_full_boss_log: bool = true
@export_range(0.1, 5.0, 0.1) var debug_snapshot_interval: float = 0.5

@export_group("Relic Tutorial Finale")
@export_range(0.01, 0.20, 0.01) var relic_tutorial_hp_threshold: float = 0.05
@export_multiline var relic_tutorial_text: String = "You have proven yourself. This trial is complete.\n\nNow learn relics.\nRelics are rewards earned after clearing each world.\nThey persist through your run and carry into the next world.\nUnlike modifiers, world modifiers reset when a new world begins."
@export var relic_tutorial_hint_text: String = "Press Enter to roll relic rewards"
@export_range(0.0, 3.0, 0.05) var relic_tutorial_dialog_delay: float = 1.0
@export_range(0.0, 1.5, 0.01) var relic_tutorial_fade_in_time: float = 0.28
@export_range(0.0, 1.5, 0.01) var relic_tutorial_fade_out_time: float = 0.28

@export_group("Boss Intro/Phase Dialog Overlay")
@export var intro_overlay_path: NodePath = ^"../TutorialIntroOverlay"
@export var intro_dim_path: NodePath = ^"../TutorialIntroOverlay/Dim"
@export var intro_dialog_path: NodePath = ^"../TutorialIntroOverlay/IntroDialog"
@export var intro_text_path: NodePath = ^"../TutorialIntroOverlay/IntroDialog/Margin/VBox/LoreText"
@export var intro_hint_path: NodePath = ^"../TutorialIntroOverlay/IntroDialog/Margin/VBox/HintText"
@export_range(0.05, 2.0, 0.01) var transition_dialog_fade_time: float = 0.28
@export var transition_hint_text: String = "Press Enter to continue"
@export var loaded_window_prompt_hint: String = ""

enum TutorialPhase {
	PHASE_1 = 1,
	PHASE_2 = 2,
	PHASE_3 = 3,
	PHASE_4 = 4
}

var _tutorial_phase: int = TutorialPhase.PHASE_1
var _transition_running: bool = false
var _transition_queued_phase: int = 0
var _fate_cycle_timer: float = 0.0
var _fate_resolution_timer: float = 0.0
var _fate_round_active: bool = false
var _fate_tiles: Array[TutorialFateTile] = []
var _tile_shape_markers: Array[Node2D] = []
var _dps_engage_zone: Area2D = null
var _correct_tile_idx: int = -1
var _active_tile_idx: int = -1
var _active_tile_dwell_time: float = 0.0
var _awaiting_melee_engage: bool = false
var _loaded_window_active: bool = false
var _loaded_window_timer: float = 0.0
var _awaiting_melee_timer: float = 0.0
var _last_forced_start_tile_idx: int = -1
var _forced_start_rearm_timer: float = 0.0
var _boss_shape_marker: Node2D = null
var _boss_marker_reveal_timer: float = 0.0
var _boss_marker_visible: bool = false
var _deferred_phase_transition_after_loaded: int = 0
var _relic_tutorial_triggered: bool = false
var _fate_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _player_ref: Node2D = null

var _intro_overlay: CanvasLayer = null
var _intro_dim: ColorRect = null
var _intro_dialog: PanelContainer = null
var _intro_text: Label = null
var _intro_hint: Label = null
var _boss_prompt_tween: Tween = null
var _boss_prompt_sequence: int = 0
var _debug_snapshot_timer: float = 0.0
var _debug_last_selected_idx: int = -2
var _debug_last_selected_visual_state: int = -1

func _ready() -> void:
	super._ready()
	_fate_rng.randomize()
	_resolve_overlay_refs()
	_resolve_player_ref()
	_dbg("ready", {
		"phase2_hp_threshold": phase2_hp_threshold,
		"phase3_hp_threshold": phase3_hp_threshold,
		"phase4_hp_threshold": phase4_hp_threshold,
		"telegraph": [telegraph_phase1, telegraph_phase2, telegraph_phase3, telegraph_phase4],
		"cycle": [cycle_interval_phase1, cycle_interval_phase2, cycle_interval_phase3, cycle_interval_phase4]
	})
	call_deferred("_spawn_fate_tiles")

func begin_boss_encounter() -> void:
	_activate_encounter()
	_boss_mode = true
	_resolve_dps_engage_zone_ref()
	_apply_tutorial_boss_health_floor()
	_show_encounter_elements()
	_cancel_boss_prompt_tween()
	_tutorial_phase = TutorialPhase.PHASE_1
	_transition_running = false
	_transition_queued_phase = 0
	_fate_round_active = false
	_reset_active_tile_tracking()
	_last_forced_start_tile_idx = -1
	_forced_start_rearm_timer = 0.0
	_awaiting_melee_engage = false
	_loaded_window_active = false
	_loaded_window_timer = 0.0
	_awaiting_melee_timer = 0.0
	_deferred_phase_transition_after_loaded = 0
	_relic_tutorial_triggered = false
	_apply_phase_combat_tuning(_tutorial_phase)
	_set_fate_cycle_timer_for_phase(_tutorial_phase)
	_dbg("begin_boss_encounter", {"phase": _tutorial_phase, "boss_mode": _boss_mode})
	_start_fate_round()

func _apply_tutorial_boss_health_floor() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if not _boss.has_method("set_min_hp_floor"):
		return
	var max_hp_value: int = 1
	if "max_hp" in _boss:
		max_hp_value = maxi(int(_boss.get("max_hp")), 1)
	var hp_floor: int = maxi(ceili(float(max_hp_value) * clampf(relic_tutorial_hp_threshold, 0.0, 1.0)), 1)
	_boss.call("set_min_hp_floor", hp_floor)
	_dbg("tutorial_hp_floor_applied", {"max_hp": max_hp_value, "hp_floor": hp_floor})

func _physics_process(delta: float) -> void:
	if not encounter_active:
		return
	if _ended:
		return
	if _transition_running:
		return
	if _maybe_trigger_relic_tutorial_finale():
		return
	_update_phase_transitions_from_health()
	if _transition_running:
		return
	_tick_fate_round(delta)
	_tick_loaded_window(delta)
	_tick_debug_snapshot(delta)

func _maybe_trigger_relic_tutorial_finale() -> bool:
	if _relic_tutorial_triggered:
		return false
	if _ended:
		return false
	if _get_boss_hp_ratio() > relic_tutorial_hp_threshold:
		return false
	_relic_tutorial_triggered = true
	_dbg("relic_tutorial_finale_triggered", {
		"hp_ratio": _get_boss_hp_ratio(),
		"threshold": relic_tutorial_hp_threshold
	})
	call_deferred("_run_relic_tutorial_finale_sequence")
	return true

func _run_relic_tutorial_finale_sequence() -> void:
	if _ended:
		return
	_transition_running = true
	encounter_active = false
	_cancel_boss_prompt_tween()
	_reset_fate_runtime_state()
	_apply_boss_rules(false, false)
	if _boss != null and is_instance_valid(_boss):
		if _boss.has_method("set_attacks_enabled"):
			_boss.call("set_attacks_enabled", false)
		if _boss.has_method("set_vulnerable"):
			_boss.call("set_vulnerable", false)
		if _boss.has_method("set_combat_paused"):
			_boss.call("set_combat_paused", true)
	_on_victory_input_lock_changed(true)
	if relic_tutorial_dialog_delay > 0.0:
		await get_tree().create_timer(relic_tutorial_dialog_delay).timeout
	await _show_transition_dialog_with_fade(relic_tutorial_text, relic_tutorial_hint_text, relic_tutorial_fade_in_time)
	await _wait_for_intro_advance_fresh_press()
	await _fade_out_transition_overlay_with_dialog(relic_tutorial_fade_out_time, true)
	if _ended:
		return
	_transition_running = false
	_end_encounter_and_show_victory()
	await _release_black_overlay_after_victory_ui_ready()

func _show_transition_dialog_with_fade(text: String, hint: String, fade_time: float) -> void:
	_resolve_overlay_refs()
	if _intro_overlay != null:
		_intro_overlay.visible = true
	if _intro_text != null:
		_intro_text.text = text
	if _intro_hint != null:
		_intro_hint.text = hint
	if _intro_dim != null:
		_intro_dim.visible = true
		var dim_color: Color = _intro_dim.color
		dim_color.a = 0.0
		_intro_dim.color = dim_color
	if _intro_dialog != null:
		_intro_dialog.visible = true
		_intro_dialog.modulate.a = 0.0
	if fade_time <= 0.0:
		if _intro_dim != null:
			var dim_color_instant: Color = _intro_dim.color
			dim_color_instant.a = 0.72
			_intro_dim.color = dim_color_instant
		if _intro_dialog != null:
			_intro_dialog.modulate.a = 1.0
		return
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _intro_dialog != null:
		tween.tween_property(_intro_dialog, "modulate:a", 1.0, fade_time)
	if _intro_dim != null:
		if _intro_dialog != null:
			tween.parallel().tween_property(_intro_dim, "color:a", 0.72, fade_time)
		else:
			tween.tween_property(_intro_dim, "color:a", 0.72, fade_time)
	await tween.finished

func _wait_for_intro_advance_fresh_press() -> void:
	while _is_intro_advance_pressed():
		await get_tree().process_frame
	while true:
		await get_tree().process_frame
		if _is_intro_advance_pressed():
			break

func _fade_out_transition_overlay_with_dialog(fade_time: float, hold_black_overlay: bool = false) -> void:
	var do_dialog: bool = _intro_dialog != null and _intro_dialog.visible
	var do_dim: bool = _intro_dim != null and _intro_dim.visible
	if do_dialog:
		_intro_dialog.modulate.a = 1.0
	if do_dim:
		var dim_start: Color = _intro_dim.color
		dim_start.a = clampf(dim_start.a, 0.0, 1.0)
		_intro_dim.color = dim_start
	if do_dim:
		var tween: Tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(_intro_dim, "color:a", 1.0, maxf(fade_time, 0.0))
		await tween.finished
	elif fade_time > 0.0:
		await get_tree().create_timer(fade_time).timeout
	if _intro_dialog != null:
		_intro_dialog.visible = false
		_intro_dialog.modulate.a = 1.0
	if hold_black_overlay:
		if _intro_dim != null:
			_intro_dim.visible = true
			var hold_color: Color = _intro_dim.color
			hold_color.a = 1.0
			_intro_dim.color = hold_color
		if _intro_overlay != null:
			_intro_overlay.visible = true
		return
	if _intro_dim != null:
		_intro_dim.visible = false
	if _intro_overlay != null:
		_intro_overlay.visible = false

func _release_black_overlay_after_victory_ui_ready() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timeout_s: float = 2.2
	var elapsed: float = 0.0
	var roll_black_ready: bool = false
	var victory_ready: bool = false
	while elapsed < timeout_s:
		await tree.process_frame
		elapsed += 1.0 / maxf(Engine.get_frames_per_second(), 1.0)
		if _relic_roll_screen != null and is_instance_valid(_relic_roll_screen) and _relic_roll_screen.visible:
			var roll_overlay: ColorRect = _relic_roll_screen.get_node_or_null("Overlay") as ColorRect
			if roll_overlay != null and roll_overlay.modulate.a >= 0.98:
				roll_black_ready = true
				break
		if _victory_ui != null and is_instance_valid(_victory_ui) and _victory_ui.visible:
			victory_ready = true
			break
	if _intro_dim != null and _intro_dim.visible:
		if roll_black_ready:
			# Seamless black-to-black handoff: drop our layer only after dice screen owns black.
			var c: Color = _intro_dim.color
			c.a = 0.0
			_intro_dim.color = c
		elif victory_ready:
			var tween: Tween = create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_property(_intro_dim, "color:a", 0.0, 0.20)
			await tween.finished
		else:
			# Fallback: avoid getting stuck on black.
			var tween_fallback: Tween = create_tween()
			tween_fallback.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween_fallback.tween_property(_intro_dim, "color:a", 0.0, 0.20)
			await tween_fallback.finished
	if _intro_dim != null:
		_intro_dim.visible = false
	if _intro_overlay != null:
		_intro_overlay.visible = false

func _update_phase_transitions_from_health() -> void:
	var hp_ratio: float = _get_boss_hp_ratio()
	var requested_phase: int = 0
	if _tutorial_phase == TutorialPhase.PHASE_1 and hp_ratio <= phase2_hp_threshold:
		requested_phase = TutorialPhase.PHASE_2
	elif _tutorial_phase == TutorialPhase.PHASE_2 and hp_ratio <= phase3_hp_threshold:
		requested_phase = TutorialPhase.PHASE_3
	elif _tutorial_phase == TutorialPhase.PHASE_3 and hp_ratio <= phase4_hp_threshold:
		requested_phase = TutorialPhase.PHASE_4
	if requested_phase <= _tutorial_phase:
		return
	if _loaded_window_active:
		if requested_phase > _deferred_phase_transition_after_loaded:
			_deferred_phase_transition_after_loaded = requested_phase
			_dbg("phase_transition_deferred_until_loaded_end", {
				"from": _tutorial_phase,
				"to": requested_phase,
				"hp_ratio": hp_ratio
			})
		return
	_queue_phase_transition(requested_phase)

func _queue_phase_transition(next_phase: int) -> void:
	if _transition_running:
		return
	if next_phase <= _tutorial_phase:
		return
	_transition_running = true
	_transition_queued_phase = next_phase
	_dbg("queue_phase_transition", {"from": _tutorial_phase, "to": next_phase, "hp_ratio": _get_boss_hp_ratio()})
	call_deferred("_run_phase_transition")

func _run_phase_transition() -> void:
	var next_phase: int = _transition_queued_phase
	if next_phase <= _tutorial_phase:
		_transition_running = false
		return
	_dbg("run_phase_transition_start", {"from": _tutorial_phase, "to": next_phase})
	_cancel_boss_prompt_tween()
	_reset_fate_runtime_state()
	await _pause_for_transition_dialog(_get_phase_intro_text(next_phase), transition_hint_text)
	_tutorial_phase = next_phase
	_apply_phase_combat_tuning(_tutorial_phase)
	_set_fate_cycle_timer_for_phase(_tutorial_phase)
	_start_fate_round()
	_transition_running = false
	_dbg("run_phase_transition_end", {"phase": _tutorial_phase})

func _apply_phase_combat_tuning(phase_id: int) -> void:
	if _boss != null and _boss.has_method("set_attack_speed_multiplier"):
		match phase_id:
			TutorialPhase.PHASE_1:
				_boss.call("set_attack_speed_multiplier", 0.65)
			TutorialPhase.PHASE_2:
				_boss.call("set_attack_speed_multiplier", 0.75)
			TutorialPhase.PHASE_3:
				_boss.call("set_attack_speed_multiplier", 0.90)
			TutorialPhase.PHASE_4:
				_boss.call("set_attack_speed_multiplier", 1.15)
	if phase_id == TutorialPhase.PHASE_1:
		_apply_boss_rules(false, false)
	elif phase_id == TutorialPhase.PHASE_2:
		_apply_boss_rules(false, true)
	elif phase_id == TutorialPhase.PHASE_3:
		_apply_boss_rules(false, true)
	else:
		_apply_boss_rules(false, true)
	_dbg("apply_phase_combat_tuning", {"phase": phase_id})

func _set_fate_cycle_timer_for_phase(phase_id: int) -> void:
	match phase_id:
		TutorialPhase.PHASE_1:
			_fate_cycle_timer = cycle_interval_phase1
		TutorialPhase.PHASE_2:
			_fate_cycle_timer = cycle_interval_phase2
		TutorialPhase.PHASE_3:
			_fate_cycle_timer = cycle_interval_phase3
		_:
			_fate_cycle_timer = cycle_interval_phase4

func _get_phase_telegraph_time(phase_id: int) -> float:
	match phase_id:
		TutorialPhase.PHASE_1:
			return telegraph_phase1
		TutorialPhase.PHASE_2:
			return telegraph_phase2
		TutorialPhase.PHASE_3:
			return telegraph_phase3
		_:
			return telegraph_phase4

func _tick_fate_round(delta: float) -> void:
	if _fate_tiles.is_empty():
		return
	if _awaiting_melee_engage or _loaded_window_active:
		return
	if _fate_round_active:
		_fate_resolution_timer -= delta
		_tick_boss_marker_reveal(delta)
		_update_fate_tile_dwell_feedback(delta)
		return
	if _correct_tile_idx >= 0:
		# Keep current roll objective stable until resolved.
		_fate_round_active = true
		_fate_resolution_timer = _get_phase_telegraph_time(_tutorial_phase)
		_dbg("fate_round_rearmed_existing_roll", {"correct_tile_idx": _correct_tile_idx})
		return
	_fate_cycle_timer -= delta
	var selected_idx_downtime: int = _get_player_tile_index()
	if selected_idx_downtime < 0:
		_forced_start_rearm_timer += maxf(delta, 0.0)
		if _forced_start_rearm_timer >= 0.20:
			_last_forced_start_tile_idx = -1
	else:
		_forced_start_rearm_timer = 0.0
	if selected_idx_downtime >= 0 and selected_idx_downtime != _last_forced_start_tile_idx:
		_last_forced_start_tile_idx = selected_idx_downtime
		_dbg("fate_round_forced_start_on_overlap", {
			"selected_idx": selected_idx_downtime,
			"remaining_cycle_timer": _fate_cycle_timer
		})
		_start_fate_round()
		return
	# Prevent passive re-roll while player camps on a tile.
	if selected_idx_downtime >= 0:
		return
	if _fate_cycle_timer <= 0.0:
		_start_fate_round()

func _start_fate_round() -> void:
	if _fate_tiles.is_empty():
		return
	if _correct_tile_idx < 0:
		_correct_tile_idx = _fate_rng.randi_range(0, _fate_tiles.size() - 1)
	_ensure_shape_marker_nodes()
	for i: int in range(_fate_tiles.size()):
		var tile: TutorialFateTile = _fate_tiles[i]
		if tile == null or not is_instance_valid(tile):
			continue
		tile.configure(i == _correct_tile_idx)
	_reset_active_tile_tracking()
	_fate_round_active = true
	_fate_resolution_timer = _get_phase_telegraph_time(_tutorial_phase)
	_show_boss_marker_for_correct_tile()
	_dbg("fate_round_start", {"correct_tile_idx": _correct_tile_idx, "resolution_timer": _fate_resolution_timer})

func _update_fate_tile_dwell_feedback(delta: float) -> void:
	var selected_idx: int = _get_player_tile_index()
	if selected_idx < 0:
		if _active_tile_idx != -1:
			_dbg("tile_selection_cleared", {"prev_active_idx": _active_tile_idx, "prev_dwell": _active_tile_dwell_time})
		_reset_active_tile_tracking()
		_set_all_tiles_idle()
		return
	if selected_idx != _active_tile_idx:
		_dbg("tile_selection_changed", {"from": _active_tile_idx, "to": selected_idx})
		_active_tile_idx = selected_idx
		_active_tile_dwell_time = 0.0
		_debug_last_selected_visual_state = -1
	else:
		_active_tile_dwell_time += maxf(delta, 0.0)
	for i: int in range(_fate_tiles.size()):
		var tile_iter: TutorialFateTile = _fate_tiles[i]
		if tile_iter == null or not is_instance_valid(tile_iter):
			continue
		if i != selected_idx:
			tile_iter.set_base_visual()
	var selected_tile: TutorialFateTile = _fate_tiles[selected_idx]
	if selected_tile == null or not is_instance_valid(selected_tile):
		return
	var dwell_time: float = _active_tile_dwell_time
	var is_selected_correct: bool = selected_tile.is_correct_tile
	if selected_idx != _correct_tile_idx:
		# Keep tile metadata as source of truth if spawn order shifts.
		is_selected_correct = selected_tile.is_correct_tile
	if is_selected_correct:
		selected_tile.mark_right_confirm()
		_dbg_visual_state_change(selected_idx, selected_tile.get_visual_state(), dwell_time, is_selected_correct)
		if dwell_time >= right_tile_confirm_dwell:
			_resolve_correct_tile_dwell_confirmation()
		return
	# Wrong tile goes yellow immediately on overlap.
	selected_tile.mark_wrong_warning()
	_dbg_visual_state_change(selected_idx, selected_tile.get_visual_state(), dwell_time, is_selected_correct)
	if dwell_time >= wrong_tile_fail_dwell:
		selected_tile.mark_wrong_fail()
		_dbg_visual_state_change(selected_idx, selected_tile.get_visual_state(), dwell_time, is_selected_correct)
		_resolve_wrong_tile_dwell_fail()

func _get_player_tile_index() -> int:
	_resolve_player_ref()
	var nearest_idx: int = -1
	var nearest_dist_sq: float = INF
	for i: int in range(_fate_tiles.size()):
		var tile: TutorialFateTile = _fate_tiles[i]
		if tile == null or not is_instance_valid(tile):
			continue
		tile._refresh_overlap_cache()
		if not tile.player_overlapping:
			continue
		if _player_ref == null or not is_instance_valid(_player_ref):
			return i
		var d2: float = _player_ref.global_position.distance_squared_to(tile.global_position)
		if d2 < nearest_dist_sq:
			nearest_dist_sq = d2
			nearest_idx = i
	return nearest_idx

func _start_loaded_window_wait_for_melee(show_prompt: bool = true) -> void:
	_awaiting_melee_engage = true
	_loaded_window_active = false
	_loaded_window_timer = 0.0
	_awaiting_melee_timer = _get_phase_loaded_engage_timeout(_tutorial_phase)
	if _tutorial_phase == TutorialPhase.PHASE_1:
		_apply_boss_rules(false, false)
	else:
		_apply_boss_rules(false, true)
	_dbg("loaded_wait_for_melee_start", {
		"show_prompt": show_prompt,
		"engage_timeout": _awaiting_melee_timer,
		"phase": _tutorial_phase
	})
	if show_prompt:
		_show_boss_prompt(loaded_window_prompt, loaded_window_prompt_hint)

func _tick_loaded_window(delta: float) -> void:
	if _awaiting_melee_engage:
		_awaiting_melee_timer = maxf(_awaiting_melee_timer - delta, 0.0)
		if _is_player_within_melee_engage_range():
			_awaiting_melee_engage = false
			_loaded_window_active = true
			_loaded_window_timer = _get_phase_loaded_duration(_tutorial_phase)
			_apply_boss_rules(true, false)
			_dbg("loaded_window_start", {"duration": _loaded_window_timer, "phase": _tutorial_phase})
		return
	if not _loaded_window_active:
		return
	_loaded_window_timer -= delta
	if _loaded_window_timer <= 0.0:
		_loaded_window_active = false
		_apply_phase_combat_tuning(_tutorial_phase)
		_set_all_tiles_idle()
		_dbg("loaded_window_end", {"phase": _tutorial_phase})
		_show_boss_prompt(loaded_window_end_text, "")
		if _deferred_phase_transition_after_loaded > _tutorial_phase:
			var next_phase: int = _deferred_phase_transition_after_loaded
			_deferred_phase_transition_after_loaded = 0
			_queue_phase_transition(next_phase)
			return
		_start_fate_round()

func _is_player_within_melee_engage_range() -> bool:
	_resolve_player_ref()
	if _player_ref == null or not is_instance_valid(_player_ref):
		return false
	_resolve_dps_engage_zone_ref()
	if _dps_engage_zone != null and is_instance_valid(_dps_engage_zone):
		for body: Node in _dps_engage_zone.get_overlapping_bodies():
			if body == _player_ref:
				return true
		var zone_shape: CollisionShape2D = _dps_engage_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if zone_shape != null and zone_shape.shape != null:
			var local_player: Vector2 = zone_shape.to_local(_player_ref.global_position)
			if zone_shape.shape is CircleShape2D:
				var circle_shape: CircleShape2D = zone_shape.shape as CircleShape2D
				return local_player.length() <= circle_shape.radius
			if zone_shape.shape is RectangleShape2D:
				var rect_shape: RectangleShape2D = zone_shape.shape as RectangleShape2D
				return absf(local_player.x) <= rect_shape.size.x * 0.5 and absf(local_player.y) <= rect_shape.size.y * 0.5
	# Safety fallback in case zone node is missing or misconfigured.
	if _boss == null or not is_instance_valid(_boss):
		return false
	var dist: float = _player_ref.global_position.distance_to((_boss as Node2D).global_position)
	return dist <= _get_player_melee_range_estimate()

func _get_player_melee_range_estimate() -> float:
	var base_range: float = 204.0
	_resolve_player_ref()
	if _player_ref == null:
		return base_range
	var combat: Node = _player_ref.get_node_or_null("Combat")
	if combat == null:
		return base_range
	var offset_mag: float = 28.0
	var size_mult: float = 1.2
	if "hitbox_offset" in combat:
		offset_mag = (combat.get("hitbox_offset") as Vector2).length()
	if "hitbox_size_mult" in combat:
		size_mult = float(combat.get("hitbox_size_mult"))
	return maxf(base_range, offset_mag + (64.0 * maxf(size_mult, 0.5)) + 42.0)

func _show_right_tile_confirmation_feedback(tile_idx: int, dwell_time: float) -> void:
	_dbg("right_tile_confirmed", {
		"tile_idx": tile_idx,
		"dwell_time": dwell_time,
		"right_confirm_dwell": right_tile_confirm_dwell
	})
	_show_boss_prompt(right_tile_confirm_text, right_tile_confirm_hint)
	_resolve_overlay_refs()
	if _intro_dim == null:
		return
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(
		_intro_dim,
		"color:a",
		clampf(right_tile_flash_peak_alpha, 0.0, 1.0),
		maxf(right_tile_flash_up_time, 0.01)
	)
	tween.tween_property(_intro_dim, "color:a", 0.36, maxf(right_tile_flash_down_time, 0.01))

func _apply_wrong_tile_consequence_for_phase() -> void:
	_resolve_player_ref()
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	match _tutorial_phase:
		TutorialPhase.PHASE_1:
			_dbg("wrong_tile_consequence", {"phase": _tutorial_phase, "effect": "none"})
			return
		TutorialPhase.PHASE_2:
			_dbg("wrong_tile_consequence", {"phase": _tutorial_phase, "effect": "none"})
			return
		TutorialPhase.PHASE_3:
			_dbg("wrong_tile_consequence", {"phase": _tutorial_phase, "effect": "none"})
			return
		TutorialPhase.PHASE_4:
			_dbg("wrong_tile_consequence", {
				"phase": _tutorial_phase,
				"effect": "damage+debuff",
				"amount": wrong_tile_damage_phase4,
				"debuff_id": wrong_tile_phase4_debuff_id,
				"debuff_duration": wrong_tile_phase4_debuff_duration
			})
			_apply_damage_to_player(wrong_tile_damage_phase4)
			_apply_debuff_to_player(wrong_tile_phase4_debuff_id, wrong_tile_phase4_debuff_duration)
		_:
			return

func _apply_damage_to_player(amount: int) -> void:
	if amount <= 0:
		return
	_resolve_player_ref()
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	var health: Node = _player_ref.get_node_or_null("Health")
	if health == null or not health.has_method("take_damage"):
		return
	var argc: int = health.get_method_argument_count("take_damage")
	if argc >= 3:
		health.call("take_damage", amount, self, false)
	elif argc == 2:
		health.call("take_damage", amount, self)
	else:
		health.call("take_damage", amount)

func _apply_debuff_to_player(id: StringName, duration: float) -> void:
	if id == StringName():
		return
	if duration <= 0.0:
		return
	_resolve_player_ref()
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	var debuffs: PlayerDebuffs = _player_ref.get_node_or_null("Debuffs") as PlayerDebuffs
	if debuffs == null:
		return
	debuffs.apply_debuff(id, duration)

func _get_phase_loaded_duration(phase_id: int) -> float:
	match phase_id:
		TutorialPhase.PHASE_1:
			return maxf(loaded_window_duration_phase1, 0.1)
		TutorialPhase.PHASE_2:
			return maxf(loaded_window_duration_phase2, 0.1)
		TutorialPhase.PHASE_3:
			return maxf(loaded_window_duration_phase3, 0.1)
		_:
			return maxf(loaded_window_duration_phase4, 0.1)

func _get_phase_loaded_engage_timeout(phase_id: int) -> float:
	match phase_id:
		TutorialPhase.PHASE_1:
			return maxf(loaded_engage_timeout_phase1, 0.1)
		TutorialPhase.PHASE_2:
			return maxf(loaded_engage_timeout_phase2, 0.1)
		TutorialPhase.PHASE_3:
			return maxf(loaded_engage_timeout_phase3, 0.1)
		_:
			return maxf(loaded_engage_timeout_phase4, 0.1)

func _reset_fate_runtime_state() -> void:
	_fate_round_active = false
	_reset_active_tile_tracking()
	_last_forced_start_tile_idx = -1
	_forced_start_rearm_timer = 0.0
	_hide_boss_marker()
	_awaiting_melee_engage = false
	_loaded_window_active = false
	_loaded_window_timer = 0.0
	_awaiting_melee_timer = 0.0
	_deferred_phase_transition_after_loaded = 0
	_correct_tile_idx = -1
	_set_all_tiles_idle()
	_dbg("reset_fate_runtime_state")

func _resolve_correct_tile_dwell_confirmation() -> void:
	var resolved_tile_idx: int = _active_tile_idx
	var resolved_dwell: float = _active_tile_dwell_time
	_fate_round_active = false
	_reset_active_tile_tracking()
	_correct_tile_idx = -1
	_last_forced_start_tile_idx = resolved_tile_idx
	_forced_start_rearm_timer = 0.0
	_set_fate_cycle_timer_for_phase(_tutorial_phase)
	_set_all_tiles_idle()
	_hide_boss_marker()
	_show_right_tile_confirmation_feedback(resolved_tile_idx, resolved_dwell)
	_start_loaded_window_wait_for_melee(true)

func _resolve_wrong_tile_dwell_fail() -> void:
	var failed_tile_idx: int = _active_tile_idx
	_reset_active_tile_tracking()
	_last_forced_start_tile_idx = failed_tile_idx
	_forced_start_rearm_timer = 0.0
	_set_all_tiles_idle()
	_fate_round_active = true
	_fate_resolution_timer = _get_phase_telegraph_time(_tutorial_phase)
	_show_boss_marker_for_correct_tile()
	_dbg("wrong_tile_fail", {"phase": _tutorial_phase})
	_apply_wrong_tile_consequence_for_phase()

func _end_fate_round_without_resolution() -> void:
	_fate_round_active = false
	_reset_active_tile_tracking()
	_set_fate_cycle_timer_for_phase(_tutorial_phase)
	_set_all_tiles_idle()
	if _tutorial_phase != TutorialPhase.PHASE_1 and _tutorial_phase != TutorialPhase.PHASE_2:
		_hide_boss_marker()
	_dbg("fate_round_timeout_without_resolution", {"phase": _tutorial_phase})

func _reset_active_tile_tracking() -> void:
	_active_tile_idx = -1
	_active_tile_dwell_time = 0.0

func _show_boss_prompt(text: String, hint: String) -> void:
	_resolve_overlay_refs()
	if _intro_overlay == null or _intro_dialog == null:
		return
	_cancel_boss_prompt_tween()
	_intro_overlay.visible = true
	if _intro_dim != null:
		_intro_dim.visible = true
		var c: Color = _intro_dim.color
		c.a = 0.36
		_intro_dim.color = c
	_intro_dialog.visible = true
	_intro_dialog.modulate.a = 1.0
	if _intro_text != null:
		_intro_text.text = text
	if _intro_hint != null:
		_intro_hint.text = hint
	var seq: int = _next_boss_prompt_sequence()
	var tween: Tween = create_tween()
	_boss_prompt_tween = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.95)
	tween.tween_property(_intro_dialog, "modulate:a", 0.0, 0.18)
	if _intro_dim != null:
		tween.parallel().tween_property(_intro_dim, "color:a", 0.0, 0.18)
	tween.finished.connect(Callable(self, "_on_boss_prompt_fade_finished").bind(seq), CONNECT_ONE_SHOT)

func _on_boss_prompt_fade_finished(seq: int) -> void:
	if seq != _boss_prompt_sequence:
		return
	_boss_prompt_tween = null
	if _intro_dialog != null:
		_intro_dialog.visible = false
		_intro_dialog.modulate.a = 1.0
	if _intro_dim != null:
		_intro_dim.visible = false
	if _intro_overlay != null:
		_intro_overlay.visible = false

func _pause_for_transition_dialog(text: String, hint: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var was_paused: bool = tree.paused
	# Force gameplay systems inactive while phase instructions are visible.
	_apply_boss_rules(false, false)
	tree.paused = true
	_show_transition_dialog(text, hint)
	while _is_intro_advance_pressed():
		await get_tree().process_frame
	while true:
		await get_tree().process_frame
		if _is_intro_advance_pressed():
			break
	await _hide_transition_dialog()
	tree.paused = was_paused

func _show_transition_dialog(text: String, hint: String) -> void:
	_resolve_overlay_refs()
	if _intro_overlay != null:
		_intro_overlay.visible = true
	if _intro_dim != null:
		_intro_dim.visible = true
		var c: Color = _intro_dim.color
		c.a = 0.72
		_intro_dim.color = c
	if _intro_dialog != null:
		_intro_dialog.visible = true
		_intro_dialog.modulate.a = 1.0
	if _intro_text != null:
		_intro_text.text = text
	if _intro_hint != null:
		_intro_hint.text = hint

func _hide_transition_dialog() -> void:
	var fade_dialog: bool = _intro_dialog != null and _intro_dialog.visible
	var fade_dim: bool = _intro_dim != null and _intro_dim.visible
	if fade_dialog or fade_dim:
		var tween: Tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		if fade_dialog:
			tween.tween_property(_intro_dialog, "modulate:a", 0.0, maxf(transition_dialog_fade_time, 0.01))
		if fade_dim:
			if fade_dialog:
				tween.parallel().tween_property(_intro_dim, "color:a", 0.0, maxf(transition_dialog_fade_time, 0.01))
			else:
				tween.tween_property(_intro_dim, "color:a", 0.0, maxf(transition_dialog_fade_time, 0.01))
		await tween.finished
	if _intro_dialog != null:
		_intro_dialog.visible = false
		_intro_dialog.modulate.a = 1.0
	if _intro_dim != null:
		_intro_dim.visible = false
	if _intro_overlay != null:
		_intro_overlay.visible = false

func _is_intro_advance_pressed() -> bool:
	if Input.is_action_pressed(&"ui_accept"):
		return true
	if Input.is_key_pressed(KEY_ENTER):
		return true
	return Input.is_key_pressed(KEY_KP_ENTER)

func _next_boss_prompt_sequence() -> int:
	_boss_prompt_sequence += 1
	return _boss_prompt_sequence

func _cancel_boss_prompt_tween() -> void:
	_boss_prompt_sequence += 1
	if _boss_prompt_tween != null and is_instance_valid(_boss_prompt_tween):
		_boss_prompt_tween.kill()
	_boss_prompt_tween = null

func _resolve_overlay_refs() -> void:
	_intro_overlay = get_node_or_null(intro_overlay_path) as CanvasLayer
	_intro_dim = get_node_or_null(intro_dim_path) as ColorRect
	_intro_dialog = get_node_or_null(intro_dialog_path) as PanelContainer
	_intro_text = get_node_or_null(intro_text_path) as Label
	_intro_hint = get_node_or_null(intro_hint_path) as Label

func _resolve_player_ref() -> void:
	if _player_ref != null and is_instance_valid(_player_ref):
		return
	_player_ref = get_tree().get_first_node_in_group("player") as Node2D

func _resolve_dps_engage_zone_ref() -> void:
	if _dps_engage_zone != null and is_instance_valid(_dps_engage_zone):
		return
	_dps_engage_zone = get_node_or_null(dps_engage_zone_path) as Area2D

func _spawn_fate_tiles() -> void:
	_fate_tiles.clear()
	var root: Node = get_node_or_null(fate_tile_spawns_path)
	if root == null:
		push_warning("[TutorialBossEncounter] FateTileSpawns root not found: %s" % String(fate_tile_spawns_path))
		return
	var placed_tiles: Array[TutorialFateTile] = []
	var markers: Array[Node2D] = []
	for child: Node in root.get_children():
		var placed: TutorialFateTile = child as TutorialFateTile
		if placed != null:
			placed_tiles.append(placed)
			continue
		var n2d: Node2D = child as Node2D
		if n2d != null:
			markers.append(n2d)
	var frames: SpriteFrames = _build_fate_sprite_frames()
	if not placed_tiles.is_empty():
		for tile: TutorialFateTile in placed_tiles:
			if tile == null or not is_instance_valid(tile):
				continue
			var anim_existing: AnimatedSprite2D = tile.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if anim_existing != null and frames != null:
				anim_existing.sprite_frames = frames
			_fate_tiles.append(tile)
		_set_all_tiles_idle()
		_ensure_shape_marker_nodes()
		return
	if markers.is_empty():
		push_warning("[TutorialBossEncounter] FateTileSpawns has no TutorialFateTile nodes or marker children.")
		return
	for marker: Node2D in markers:
		var tile_node: Node = TutorialFateTileScene.instantiate()
		var tile: TutorialFateTile = tile_node as TutorialFateTile
		if tile == null:
			continue
		get_tree().current_scene.add_child(tile)
		tile.global_position = marker.global_position
		tile.set_meta("tutorial_runtime_spawned", true)
		var anim: AnimatedSprite2D = tile.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim != null and frames != null:
			anim.sprite_frames = frames
		_fate_tiles.append(tile)
	_set_all_tiles_idle()
	_ensure_shape_marker_nodes()

func _build_fate_sprite_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	var anim_name: String = "fate"
	frames.add_animation(anim_name)
	var loaded_count: int = 0
	for i: int in range(fate_frame_count):
		var idx_text: String = String.num_int64(i).pad_zeros(fate_frame_padding)
		var path: String = "%s/%s_%s%s" % [fate_fx_folder, fate_fx_prefix, idx_text, fate_fx_suffix]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		frames.add_frame(anim_name, tex)
		loaded_count += 1
	if loaded_count <= 0:
		push_warning("[TutorialBossEncounter] No Fate tile frames loaded from %s with prefix %s." % [fate_fx_folder, fate_fx_prefix])
		return null
	frames.set_animation_loop(anim_name, true)
	frames.set_animation_speed(anim_name, 30.0)
	return frames

func _set_all_tiles_idle() -> void:
	for tile: TutorialFateTile in _fate_tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		tile.set_base_visual()

func _ensure_shape_marker_nodes() -> void:
	_tile_shape_markers.clear()
	for i: int in range(_fate_tiles.size()):
		var tile: TutorialFateTile = _fate_tiles[i]
		if tile == null or not is_instance_valid(tile):
			continue
		var marker: Node2D = tile.get_node_or_null("ShapeMarkerNode") as Node2D
		if marker == null:
			marker = _create_shape_marker_node("ShapeMarkerNode")
			tile.add_child(marker)
		marker.position = Vector2(0.0, 86.0)
		marker.z_index = 25
		marker.z_as_relative = false
		marker.visible = true
		_apply_shape_to_marker(marker, _shape_index_for_tile(i), marker_tile_radius)
		_tile_shape_markers.append(marker)
	_ensure_boss_marker_node()

func _ensure_boss_marker_node() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var existing: Node2D = (_boss as Node).get_node_or_null("BossShapeMarkerNode") as Node2D
	if existing == null:
		existing = _create_shape_marker_node("BossShapeMarkerNode")
		(_boss as Node).add_child(existing)
	_boss_shape_marker = existing
	_boss_shape_marker.z_index = 900
	_boss_shape_marker.z_as_relative = false
	_boss_shape_marker.position = Vector2(0.0, -170.0)
	_boss_shape_marker.visible = false

func _create_shape_marker_node(node_name: String) -> Node2D:
	var marker_root: Node2D = Node2D.new()
	marker_root.name = node_name
	var fill: Polygon2D = Polygon2D.new()
	fill.name = "Fill"
	fill.antialiased = true
	marker_root.add_child(fill)
	var outline: Line2D = Line2D.new()
	outline.name = "Outline"
	outline.closed = true
	outline.antialiased = true
	outline.default_color = marker_outline_color
	outline.width = marker_outline_width
	marker_root.add_child(outline)
	return marker_root

func _shape_index_for_tile(tile_idx: int) -> int:
	if tile_idx < 0:
		return 0
	if TILE_SHAPE_SYMBOLS.is_empty():
		return 0
	return tile_idx % TILE_SHAPE_SYMBOLS.size()

func _shape_name_for_tile(tile_idx: int) -> String:
	if tile_idx < 0 or TILE_SHAPE_SYMBOLS.is_empty():
		return "UNKNOWN"
	return TILE_SHAPE_SYMBOLS[_shape_index_for_tile(tile_idx)]

func _shape_color_for_index(shape_idx: int) -> Color:
	match _shape_index_for_tile(shape_idx):
		0:
			return Color(0.16, 0.84, 0.30, 0.97) # Square = Green
		1:
			return Color(0.67, 0.29, 0.87, 0.97) # Diamond = Purple
		2:
			return Color(0.20, 0.49, 0.96, 0.97) # Triangle = Blue
		3:
			return Color(0.93, 0.20, 0.20, 0.97) # Circle = Red
		_:
			return Color(0.06, 0.06, 0.08, 0.97) # Octagon = Black

func _outline_color_for_fill(fill_color: Color) -> Color:
	var luminance: float = (fill_color.r * 0.2126) + (fill_color.g * 0.7152) + (fill_color.b * 0.0722)
	if luminance < 0.16:
		return Color(0.92, 0.94, 0.98, fill_color.a)
	return marker_outline_color

func _apply_shape_to_marker(marker: Node2D, shape_idx: int, radius: float) -> void:
	if marker == null or not is_instance_valid(marker):
		return
	var fill: Polygon2D = marker.get_node_or_null("Fill") as Polygon2D
	var outline: Line2D = marker.get_node_or_null("Outline") as Line2D
	if fill == null or outline == null:
		return
	var fill_color: Color = _shape_color_for_index(shape_idx)
	var points: PackedVector2Array = _shape_points_for_index(shape_idx, radius)
	fill.polygon = points
	fill.color = fill_color
	outline.points = points
	outline.width = marker_outline_width
	outline.default_color = _outline_color_for_fill(fill_color)

func _shape_points_for_index(shape_idx: int, radius: float) -> PackedVector2Array:
	var normalized_idx: int = _shape_index_for_tile(shape_idx)
	match normalized_idx:
		0:
			return PackedVector2Array([
				Vector2(-radius, -radius),
				Vector2(radius, -radius),
				Vector2(radius, radius),
				Vector2(-radius, radius)
			])
		1:
			return PackedVector2Array([
				Vector2(0.0, -radius),
				Vector2(radius, 0.0),
				Vector2(0.0, radius),
				Vector2(-radius, 0.0)
			])
		2:
			return PackedVector2Array([
				Vector2(0.0, -radius),
				Vector2(radius * 0.92, radius * 0.72),
				Vector2(-radius * 0.92, radius * 0.72)
			])
		3:
			return _regular_polygon_points(24, radius)
		_:
			return _regular_polygon_points(8, radius)

func _regular_polygon_points(sides: int, radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var count: int = maxi(sides, 3)
	for i: int in range(count):
		var t: float = (TAU * float(i) / float(count)) - (PI * 0.5)
		pts.append(Vector2(cos(t), sin(t)) * radius)
	return pts

func _show_boss_marker_for_correct_tile() -> void:
	_ensure_boss_marker_node()
	if _boss_shape_marker == null:
		return
	if _correct_tile_idx < 0:
		return
	_apply_shape_to_marker(_boss_shape_marker, _shape_index_for_tile(_correct_tile_idx), marker_boss_radius)
	_boss_shape_marker.visible = true
	_boss_marker_visible = true
	_boss_marker_reveal_timer = _get_boss_marker_reveal_duration_for_phase(_tutorial_phase)
	_dbg("boss_marker_show", {
		"correct_idx": _correct_tile_idx,
		"shape": _shape_name_for_tile(_correct_tile_idx),
		"reveal_time": _boss_marker_reveal_timer
	})

func _tick_boss_marker_reveal(delta: float) -> void:
	if not _boss_marker_visible:
		return
	if _tutorial_phase == TutorialPhase.PHASE_1 or _tutorial_phase == TutorialPhase.PHASE_2:
		return
	_boss_marker_reveal_timer -= delta
	if _boss_marker_reveal_timer <= 0.0:
		_hide_boss_marker()

func _get_boss_marker_reveal_duration_for_phase(phase_id: int) -> float:
	match phase_id:
		TutorialPhase.PHASE_1:
			return 9999.0
		TutorialPhase.PHASE_2:
			return 9999.0
		TutorialPhase.PHASE_3:
			return maxf(marker_reveal_duration_phase3, 0.1)
		_:
			return maxf(marker_reveal_duration_phase4, 0.1)

func _hide_boss_marker() -> void:
	_boss_marker_visible = false
	_boss_marker_reveal_timer = 0.0
	if _boss_shape_marker != null and is_instance_valid(_boss_shape_marker):
		_boss_shape_marker.visible = false

func _clear_fate_tiles() -> void:
	_hide_boss_marker()
	_tile_shape_markers.clear()
	for tile: TutorialFateTile in _fate_tiles:
		if tile == null:
			continue
		if is_instance_valid(tile) and bool(tile.get_meta("tutorial_runtime_spawned", false)):
			tile.queue_free()
	_fate_tiles.clear()

func _get_boss_hp_ratio() -> float:
	if _boss == null or not is_instance_valid(_boss):
		return 1.0
	var cur: float = 1.0
	var maxv: float = 1.0
	if _boss.has_method("get_health"):
		cur = float(_boss.call("get_health"))
	elif "hp" in _boss:
		cur = float(_boss.get("hp"))
	if _boss.has_method("get_max_health"):
		maxv = float(_boss.call("get_max_health"))
	elif "max_hp" in _boss:
		maxv = float(_boss.get("max_hp"))
	if maxv <= 0.0:
		return 1.0
	return clampf(cur / maxv, 0.0, 1.0)

func _get_phase_intro_text(next_phase: int) -> String:
	if next_phase >= 0 and next_phase < phase_intro_text.size():
		return phase_intro_text[next_phase]
	return "A new trial begins. Adapt and overcome."

func _on_tree_exiting() -> void:
	_cancel_boss_prompt_tween()
	if _boss != null and is_instance_valid(_boss) and _boss.has_method("clear_min_hp_floor"):
		_boss.call("clear_min_hp_floor")
	_clear_fate_tiles()
	_dbg("tree_exiting")
	super._on_tree_exiting()

func _on_victory_proceed() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if RunStateSingleton != null:
		if RunStateSingleton.has_method("mark_tutorial_completed"):
			RunStateSingleton.call("mark_tutorial_completed")
		# Tutorial rewards are instructional only; do not carry relic inventory into real runs.
		if RunStateSingleton.has_method("clear_relics"):
			RunStateSingleton.call("clear_relics")
		# Tutorial modifier choices are instructional only; clear all world modifiers.
		if RunStateSingleton.has_method("clear_world_modifiers"):
			RunStateSingleton.call("clear_world_modifiers")
		RunStateSingleton.world_index = 1
		RunStateSingleton.floor_index = 1
	# Tutorial should never carry Dice Meter runtime state into World 1.
	var dice_meter: Node = tree.root.get_node_or_null("DiceMeterSingleton")
	if dice_meter != null and dice_meter.has_method("reset_meter"):
		dice_meter.call("reset_meter")
	# Ensure no ability cooldowns or input locks carry into World 1.
	var player_node: Node = tree.get_first_node_in_group(&"player")
	if player_node == null and tree.current_scene != null:
		player_node = tree.current_scene.get_node_or_null("Player")
	if player_node != null:
		if player_node.has_method("set_input_locked"):
			player_node.call("set_input_locked", false)
		if player_node.has_method("set_cutscene_motion_lock"):
			player_node.call("set_cutscene_motion_lock", false)
		var combat_node: Node = player_node.get_node_or_null("Combat")
		if combat_node != null and combat_node.has_method("reset_all_cooldowns_and_combat_state"):
			combat_node.call("reset_all_cooldowns_and_combat_state")
	var next_path: String = force_world1_scene_path
	if not ResourceLoader.exists(next_path):
		push_warning("[TutorialBossEncounter] Missing next world scene: %s" % next_path)
		next_path = "res://scenes/world/World1.tscn"
	tree.paused = false
	_dbg("victory_proceed", {"next_path": next_path})
	call_deferred("_change_scene_safe", next_path)

func _dbg(event_name: String, payload: Dictionary = {}) -> void:
	if not debug_full_boss_log:
		return
	var event_payload: Dictionary = {
		"event": event_name,
		"phase": _tutorial_phase,
		"fate_round": _fate_round_active,
		"correct_idx": _correct_tile_idx,
		"active_idx": _active_tile_idx,
		"active_dwell": snapped(_active_tile_dwell_time, 0.001),
		"awaiting_melee": _awaiting_melee_engage,
		"loaded_active": _loaded_window_active
	}
	for key: Variant in payload.keys():
		event_payload[key] = payload[key]
	print("[TutorialBossDebug] ", event_payload)

func _dbg_visual_state_change(selected_idx: int, visual_state: int, dwell_time: float, is_correct: bool) -> void:
	if not debug_full_boss_log:
		return
	if selected_idx == _debug_last_selected_idx and visual_state == _debug_last_selected_visual_state:
		return
	_debug_last_selected_idx = selected_idx
	_debug_last_selected_visual_state = visual_state
	_dbg("tile_visual_state", {
		"selected_idx": selected_idx,
		"visual_state": visual_state,
		"is_correct": is_correct,
		"dwell": snapped(dwell_time, 0.001)
	})

func _tick_debug_snapshot(delta: float) -> void:
	if not debug_full_boss_log:
		return
	_debug_snapshot_timer += maxf(delta, 0.0)
	if _debug_snapshot_timer < maxf(debug_snapshot_interval, 0.1):
		return
	_debug_snapshot_timer = 0.0
	var tiles: Array[String] = []
	for i: int in range(_fate_tiles.size()):
		var tile: TutorialFateTile = _fate_tiles[i]
		if tile == null or not is_instance_valid(tile):
			continue
		tiles.append("i=%d c=%s o=%s v=%d" % [
			i,
			String.num_int64(1 if tile.is_correct_tile else 0),
			String.num_int64(1 if tile.player_overlapping else 0),
			tile.get_visual_state()
		])
	_dbg("snapshot", {
		"fate_resolution_timer": snapped(_fate_resolution_timer, 0.001),
		"fate_cycle_timer": snapped(_fate_cycle_timer, 0.001),
		"awaiting_melee_timer": snapped(_awaiting_melee_timer, 0.001),
		"loaded_window_timer": snapped(_loaded_window_timer, 0.001),
		"tiles": tiles
	})
