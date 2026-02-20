extends Control
class_name BossHealthHUD

@export var boss_path: NodePath = NodePath() # optional; if empty we use group lookup
@export var boss_name_label_path: NodePath = ^"BossNameLabel"

var _boss: Node = null
var _name_label: Label = null

func _ready() -> void:
	_name_label = get_node_or_null(boss_name_label_path) as Label
	if _name_label == null:
		push_warning("[BossHealthUI] BossNameLabel not found at: " + String(boss_name_label_path))
		return

	_boss = _resolve_boss()
	if _boss == null:
		# Only warn in main world scenes (sub-arenas and FinalWorld don't have bosses)
		var scene_name: String = ""
		if get_tree().current_scene:
			scene_name = String(get_tree().current_scene.name)
		if not ("SubArena" in scene_name or "FinalWorld" in scene_name):
			push_warning("[BossHealthUI] Boss not found. Set boss_path OR add boss to group 'boss'.")
		_name_label.text = ""
		# Hide the entire UI element when no boss present
		visible = false
		return

	_name_label.text = _get_boss_display_name(_boss)
	visible = true

func _resolve_boss() -> Node:
	# 1) Explicit path if provided
	if boss_path != NodePath():
		var n: Node = get_node_or_null(boss_path)
		if n != null:
			return n

	# 2) Group fallback (recommended)
	return get_tree().get_first_node_in_group("boss")

func _get_boss_display_name(b: Node) -> String:
	if b.has_method("get_boss_name"):
		return String(b.call("get_boss_name"))

	var v: Variant = b.get("boss_name")
	if v is String:
		return String(v)

	return b.name
