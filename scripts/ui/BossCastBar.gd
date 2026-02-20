extends Control
class_name BossCastBar

# BossCastBar (Godot 4.x)
# - Self-wires to BossController via boss_path OR group "boss"
# - Listens to boss signals: cast_started(spell_name, cast_time), cast_ended(spell_name)
# - Shows a progress bar from 0..1 during cast, then hides shortly after end
# - Race-safe: old hide timers won't hide a newer cast (token guard)
# - Does NOT depend on EncounterUI

@export var boss_path: NodePath = NodePath() # optional; if empty, uses group "boss"
@export var spell_label_path: NodePath = ^"SpellLabel"
@export var bar_path: NodePath = ^"Bar"

# If you want the bar hidden instantly at cast end, set to 0.0
@export var hide_delay: float = 0.15

var _boss: Node = null
var _label: Label = null
var _bar: ProgressBar = null

var _active: bool = false
var _t: float = 0.0
var _dur: float = 1.0

# Token invalidates old hide timers (timers cannot be cancelled)
var _hide_token: int = 0


func _ready() -> void:
	_label = get_node_or_null(spell_label_path) as Label
	_bar = get_node_or_null(bar_path) as ProgressBar

	visible = false
	set_process(true)

	if _bar != null:
		_bar.min_value = 0.0
		_bar.max_value = 1.0
		_bar.value = 0.0

	_boss = _resolve_boss()
	if _boss == null:
		# Only warn in main world scenes (sub-arenas and FinalWorld don't have bosses)
		var scene_name: String = ""
		if get_tree().current_scene:
			scene_name = String(get_tree().current_scene.name)
		if not ("SubArena" in scene_name or "FinalWorld" in scene_name):
			push_warning("[BossCastBar] Boss not found. Set boss_path OR add boss to group 'boss'.")
		# Hide the entire cast bar when no boss present
		visible = false
		return

	_connect_to_boss(_boss)
	visible = true


func _exit_tree() -> void:
	_disconnect_from_boss()


func _resolve_boss() -> Node:
	if boss_path != NodePath():
		var n: Node = get_node_or_null(boss_path)
		if n != null:
			return n
	return get_tree().get_first_node_in_group("boss")


func _connect_to_boss(boss: Node) -> void:
	_disconnect_from_boss()

	_boss = boss

	if _boss.has_signal("cast_started"):
		var c1 := Callable(self, "_on_cast_started")
		if not _boss.is_connected("cast_started", c1):
			_boss.connect("cast_started", c1)

	if _boss.has_signal("cast_ended"):
		var c2 := Callable(self, "_on_cast_ended")
		if not _boss.is_connected("cast_ended", c2):
			_boss.connect("cast_ended", c2)


func _disconnect_from_boss() -> void:
	if _boss == null or not is_instance_valid(_boss):
		_boss = null
		return

	var c1 := Callable(self, "_on_cast_started")
	if _boss.has_signal("cast_started") and _boss.is_connected("cast_started", c1):
		_boss.disconnect("cast_started", c1)

	var c2 := Callable(self, "_on_cast_ended")
	if _boss.has_signal("cast_ended") and _boss.is_connected("cast_ended", c2):
		_boss.disconnect("cast_ended", c2)

	_boss = null


func _process(delta: float) -> void:
	if not _active:
		return

	_t += delta
	if _bar != null:
		_bar.value = clampf(_t / _dur, 0.0, 1.0)


# -----------------------------
# Boss signal handlers
# -----------------------------
func _on_cast_started(spell_name: String, cast_time: float) -> void:
	start_cast(spell_name, cast_time)


func _on_cast_ended(_spell_name: String) -> void:
	end_cast()


# -----------------------------
# Public API (optional)
# -----------------------------
func start_cast(spell_name: String, cast_time: float) -> void:
	_hide_token += 1 # invalidate any pending hide from an older cast

	if _label != null:
		_label.text = spell_name

	visible = true
	_dur = maxf(cast_time, 0.01)
	_t = 0.0
	_active = true

	if _bar != null:
		_bar.value = 0.0


func end_cast() -> void:
	_active = false
	if _bar != null:
		_bar.value = 1.0

	var token_at_end: int = _hide_token
	var d: float = maxf(hide_delay, 0.0)

	if d <= 0.0:
		visible = false
		return

	get_tree().create_timer(d).timeout.connect(func() -> void:
		# If another cast started after this end, ignore this stale hide
		if token_at_end != _hide_token:
			return
		visible = false
	)
