# res://scripts/LightBeamStation.gd
extends Area2D
class_name LightBeamStation

signal activated(station: LightBeamStation, activator: Node2D)

@export var interact_action: StringName = &"interact"
@export var player_group: StringName = &"player"
@export var enabled: bool = true
@export var one_shot: bool = true

@export var prompt_label_path: NodePath = NodePath()
@export var prompt_text: String = "Interact"

# ✅ NEW: optional beam visual to show only when enabled/active
@export var beam_visual_path: NodePath = NodePath()
@export var beam_visible_when_enabled: bool = true

@export var debug_prints: bool = false

var _player_inside: Node2D = null
var _used: bool = false
var _prompt_label: Label = null
var _beam_visual: CanvasItem = null

func _ready() -> void:
	monitoring = enabled
	monitorable = enabled
	set_process_unhandled_input(true)

	_prompt_label = get_node_or_null(prompt_label_path) as Label
	if _prompt_label == null and prompt_label_path != NodePath():
		push_warning("[LightBeamStation] prompt_label_path invalid: %s" % String(prompt_label_path))

	_beam_visual = get_node_or_null(beam_visual_path) as CanvasItem
	if _beam_visual == null and beam_visual_path != NodePath():
		push_warning("[LightBeamStation] beam_visual_path invalid: %s" % String(beam_visual_path))

	_update_prompt(false)
	_update_beam_visual()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func set_enabled(v: bool) -> void:
	enabled = v
	monitoring = v
	monitorable = v
	_update_prompt(false)
	_update_beam_visual()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if _used and one_shot:
		return
	if _player_inside == null or not is_instance_valid(_player_inside):
		return

	if event.is_action_pressed(interact_action):
		_used = true
		_update_prompt(false)
		_update_beam_visual()
		if debug_prints:
			pass
		activated.emit(self, _player_inside)

func _on_body_entered(b: Node) -> void:
	if not enabled:
		return
	if _used and one_shot:
		return

	var p := b as Node2D
	if p == null:
		return
	if not p.is_in_group(player_group):
		return

	_player_inside = p
	_update_prompt(true)

	if debug_prints:
		pass

func _on_body_exited(b: Node) -> void:
	if _player_inside == null:
		return
	if b != _player_inside:
		return

	if debug_prints:
		pass

	_player_inside = null
	_update_prompt(false)

func _update_prompt(should_show: bool) -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = should_show and enabled and (not _used or not one_shot)
	_prompt_label.text = prompt_text

func _update_beam_visual() -> void:
	if _beam_visual == null:
		return
	var show_beam := beam_visible_when_enabled and enabled and (not _used or not one_shot)
	_beam_visual.visible = show_beam
