extends Node2D
class_name Portal

# Portal that becomes visible after Floor 4 is cleared and teleports player to Floor 5

@export var floor_progression_path: NodePath = ^"../../../FloorProgressionController"
@export var player_path: NodePath = ^"../../../Player"
@export var target_position: Vector2 = Vector2(-1091, -21060)
@export var required_floor: int = 4
@export var interact_key: String = "interact"
@export var debug_logs: bool = false
@export var fade_rect_path: NodePath = ^"../../../UI/ScreenRoot/HUDRoot/TeleportFade"
@export var fade_out_time: float = 0.5
@export var camera_settle_time: float = 0.75
@export var encounter_spawn_settle_time: float = 0.1
@export var fade_in_time: float = 0.5

var _floor_progression: Node = null
var _player: CharacterBody2D = null
var _player_nearby: bool = false
var _portal_active: bool = false
var _interaction_area: Area2D = null
var _fade_rect: ColorRect = null

func _ready() -> void:
	# CRITICAL: Print IMMEDIATELY to verify script is running
	pass
	pass
	pass
	pass
	
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Find InteractionArea child (don't use @onready)
	_interaction_area = get_node_or_null("InteractionArea")
	if _interaction_area == null:
		push_error("[Portal] InteractionArea child not found!")
	else:
		# Start disabled - will be enabled when portal activates
		_interaction_area.monitoring = false
		_interaction_area.monitorable = false
		_interaction_area.body_entered.connect(_on_body_entered)
		_interaction_area.body_exited.connect(_on_body_exited)

	_fade_rect = get_node_or_null(fade_rect_path) as ColorRect
	if _fade_rect == null:
		if debug_logs:
			push_warning("[Portal] Fade rect not found at: %s. Will create runtime fallback on first use." % String(fade_rect_path))
	
	# Get references using get_node instead of get_node_or_null to see exact errors
	pass
	_floor_progression = get_node_or_null(floor_progression_path)
	
	if _floor_progression == null:
		push_error("[Portal] FloorProgressionController not found!")
		# Try different paths
		pass
		_floor_progression = get_node_or_null("../../../FloorProgressionController")
		if _floor_progression:
			pass
	else:
		pass
	
	pass
	_player = get_node_or_null(player_path)
	
	if _player == null:
		push_error("[Portal] Player not found!")
		# Try different paths
		pass
		_player = get_node_or_null("../../../Player")
		if _player:
			pass
	else:
		pass
	
	# Connect signal
	if _floor_progression and _floor_progression.has_signal("floor_unlocked"):
		_floor_progression.floor_unlocked.connect(_on_floor_unlocked)
		pass
	else:
		if _floor_progression:
			push_error("[Portal] FloorProgressionController missing 'floor_unlocked' signal!")
		else:
			push_error("[Portal] Cannot connect signal - FloorProgressionController is null")
	
	pass

func _on_floor_unlocked(floor_number: int) -> void:
	pass
	if floor_number == required_floor:
		pass
		_activate_portal()

func _activate_portal() -> void:
	_portal_active = true
	visible = true
	
	# Enable the InteractionArea for player detection
	if _interaction_area:
		_interaction_area.monitoring = true
		_interaction_area.monitorable = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.76, 0.5)
	
	pass
	pass
	if _interaction_area:
		pass
		pass
		pass
		pass
		pass
	else:
		pass

func _on_body_entered(body: Node2D) -> void:
	pass
	if body == _player:
		_player_nearby = true
		pass

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_nearby = false
		pass

func _process(_delta: float) -> void:
	if not _portal_active or not _player_nearby or not _player:
		return
	
	if Input.is_action_just_pressed(interact_key):
		_teleport_player()

func _teleport_player() -> void:
	if _player == null:
		return
	_portal_active = false
	_player_nearby = false
	if _interaction_area != null:
		_interaction_area.monitoring = false
		_interaction_area.monitorable = false

	_set_player_cutscene_lock(true)
	_set_player_input_locked(true)

	await _run_world2_floor4_portal_transition_sequence()

func _run_world2_floor4_portal_transition_sequence() -> void:
	await _fade_screen(0.0, 1.0, maxf(fade_out_time, 0.01))

	_player.global_position = target_position

	var hidden_camera_settle: float = maxf(camera_settle_time, 0.0)
	if _floor_progression != null and _floor_progression.has_method("activate_world2_boss_arena_camera"):
		_floor_progression.call("activate_world2_boss_arena_camera")
		if _floor_progression.has_method("get_world2_boss_camera_hidden_settle_time"):
			hidden_camera_settle = maxf(float(_floor_progression.call("get_world2_boss_camera_hidden_settle_time")), hidden_camera_settle)
	if hidden_camera_settle > 0.0:
		await get_tree().create_timer(hidden_camera_settle).timeout

	# Spawn encounter while screen is black, then freeze combat until fade-in completes.
	if _floor_progression != null and _floor_progression.has_method("trigger_boss_encounter_after_portal"):
		_floor_progression.call("trigger_boss_encounter_after_portal")
		if encounter_spawn_settle_time > 0.0:
			await get_tree().create_timer(encounter_spawn_settle_time).timeout
		await _wait_for_settle_hidden([_player], [&"floor5_enemies"], 1.8)
		if _floor_progression.has_method("set_world2_portal_combat_paused"):
			_floor_progression.call("set_world2_portal_combat_paused", true)

	await _fade_screen(1.0, 0.0, maxf(fade_in_time, 0.01))

	if _floor_progression != null and _floor_progression.has_method("set_world2_portal_combat_paused"):
		_floor_progression.call("set_world2_portal_combat_paused", false)
	_set_player_cutscene_lock(false)
	_set_player_input_locked(false)

func _wait_for_settle_hidden(nodes: Array[Node], groups: Array[StringName], timeout_seconds: float) -> void:
	var timeout: float = maxf(timeout_seconds, 0.0)
	var elapsed: float = 0.0
	while elapsed < timeout:
		if _all_targets_settled(nodes, groups):
			return
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0

func _all_targets_settled(nodes: Array[Node], groups: Array[StringName]) -> bool:
	for n: Node in nodes:
		if not _is_node_settled(n):
			return false
	for g: StringName in groups:
		var group_nodes: Array[Node] = get_tree().get_nodes_in_group(g)
		for gn: Node in group_nodes:
			if not _is_node_settled(gn):
				return false
	return true

func _is_node_settled(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return true
	var body: CharacterBody2D = node as CharacterBody2D
	if body != null:
		if body.is_on_floor():
			return true
		return absf(body.velocity.y) <= 8.0
	if "velocity" in node:
		var v: Vector2 = node.get("velocity")
		return absf(v.y) <= 8.0
	return true

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

func _set_fade_alpha(alpha: float) -> void:
	if _fade_rect == null:
		return
	var c: Color = _fade_rect.color
	c.a = alpha
	_fade_rect.color = c

func _fade_screen(from_alpha: float, to_alpha: float, duration: float) -> void:
	if _fade_rect == null:
		# Create fallback lazily at runtime (safe: scene tree is fully initialized).
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
	layer.name = "PortalTransitionFadeLayer"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.current_scene.add_child(layer)

	var rect: ColorRect = ColorRect.new()
	rect.name = "PortalTransitionFade"
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	layer.add_child(rect)
	return rect
