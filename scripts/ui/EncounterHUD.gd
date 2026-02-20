extends CanvasLayer
class_name EncounterHUD

@export var encounter_path: NodePath = ^"../EncounterController"

# EncounterLabel can be Label OR RichTextLabel
@export var label_path: NodePath = ^"EncounterLabel"

@export var floor_controller_path: NodePath = ^"../FloorProgressionController"
@export var floor_label_path: NodePath = ^"FloorStatusLabel"

# NEW: TopRight FloorStatusHUD hookup (script on StatusPanel)
@export var floor_status_hud_path: NodePath = ^"ScreenRoot/HUDRoot/TopRight/Pad/StatusPanel"

# Show EncounterLabel starting on floor 5 (boss floor)
@export var show_encounter_text_on_floor: int = 5

# Update floor label at an interval instead of every frame
@export var floor_poll_interval: float = 0.25

# -----------------------------
# Boss -> BossHUDTop hookup
# -----------------------------
@export var boss_path: NodePath = ^"../Boss" # optional; group fallback if empty
@export var boss_hud_top_path: NodePath = ^"BossHUDTop" # path relative to this CanvasLayer

# Optional: how often to poll boss hp if no signals exist
@export var boss_hp_poll_interval: float = 0.10


var _encounter: EncounterController = null

# Encounter label can be Label OR RichTextLabel; store as Control and write via helper
var _encounter_label_node: Control = null

# Legacy fallback label (kept for safety)
var _floor_label: Label = null

var _floors: FloorProgressionController = null
var _floor_poll_t: float = 0.0

# New TopRight view (FloorStatusHUD on StatusPanel)
var _floor_status_hud: Node = null

# Boss + boss HUD
var _boss: Node = null
var _boss_hud: Node = null
var _boss_hp_poll_t: float = 0.0


func _ready() -> void:
	# -----------------------------
	# (Optional debug) sanity prints
	# -----------------------------
	if has_node("ScreenRoot") and has_node("ScreenRoot/HUDRoot"):
		var sr := $ScreenRoot as Control
		var hr := $ScreenRoot/HUDRoot as Control
		pass
		pass

	# -----------------------------
	# Encounter hookup
	# -----------------------------
	_encounter = _resolve_encounter()

	if _encounter == null:
		push_warning("[UI] EncounterController not found.")
	else:
		if not _encounter.phase_changed.is_connected(_on_phase_changed):
			_encounter.phase_changed.connect(_on_phase_changed)
		if not _encounter.dps_time_changed.is_connected(_on_dps_time_changed):
			_encounter.dps_time_changed.connect(_on_dps_time_changed)

	# -----------------------------
	# EncounterLabel hookup (Label OR RichTextLabel)
	# -----------------------------
	_encounter_label_node = _get_node_as_control(label_path)

	if _encounter_label_node == null:
		_encounter_label_node = _find_first_control_named(self, "EncounterLabel")
	if _encounter_label_node == null:
		_encounter_label_node = _find_first_control_named(get_tree().current_scene, "EncounterLabel")

	if _encounter_label_node == null:
		push_warning("[UI] EncounterLabel not found. Set label_path on EncounterHUD.")
	else:
		if _encounter_label_node is RichTextLabel:
			var rtl := _encounter_label_node as RichTextLabel
			rtl.bbcode_enabled = true
			rtl.scroll_active = false
			rtl.scroll_following = false
			rtl.fit_content = true

	# -----------------------------
	# Legacy floor label hookup (fallback only)
	# -----------------------------
	_floor_label = get_node_or_null(floor_label_path) as Label
	if _floor_label == null:
		_floor_label = _find_first_label_named(self, "FloorStatusLabel")
	if _floor_label == null:
		_floor_label = _find_first_label_named(get_tree().current_scene, "FloorStatusLabel")
	# NOTE: we do NOT warn here yet; we only warn if the new FloorStatusHUD is also missing.

	# -----------------------------
	# Floors controller hookup
	# -----------------------------
	_floors = get_tree().get_first_node_in_group("floors") as FloorProgressionController
	if _floors == null and floor_controller_path != NodePath():
		_floors = get_node_or_null(floor_controller_path) as FloorProgressionController
	if _floors == null:
		_floors = _find_first_floors(get_tree().current_scene)

	if _floors == null:
		push_warning("[UI] FloorProgressionController not found (floor UI will not update).")

	# -----------------------------
	# FloorStatusHUD hookup (TopRight)
	# IMPORTANT: must be resolved BEFORE initial refresh
	# -----------------------------
	if floor_status_hud_path != NodePath():
		_floor_status_hud = get_node_or_null(floor_status_hud_path)

	if _floor_status_hud == null:
		# Fallback: try to find the StatusPanel by name
		_floor_status_hud = _find_first_control_named(get_tree().current_scene, "StatusPanel")

	if _floor_status_hud == null and _floor_label == null:
		push_warning("[UI] Floor status UI not found (neither FloorStatusHUD nor fallback label).")

	# -----------------------------
	# Boss + BossHUDTop hookup
	# -----------------------------
	_boss = _resolve_boss()
	_boss_hud = get_node_or_null(boss_hud_top_path)

	if _boss_hud == null:
		push_warning("[UI] BossHUDTop not found. Set boss_hud_top_path on EncounterHUD.")
	else:
		if _boss != null and is_instance_valid(_boss):
			if _boss_hud.has_method("set_boss_name"):
				_boss_hud.call("set_boss_name", _get_boss_display_name(_boss))

	if _boss == null:
		push_warning("[UI] Boss not found. Set boss_path OR add boss to group 'boss'.")
	else:
		# Connect cast signals
		if _boss.has_signal("cast_started"):
			if not _boss.is_connected("cast_started", Callable(self, "_on_boss_cast_started")):
				_boss.connect("cast_started", Callable(self, "_on_boss_cast_started"))
		if _boss.has_signal("cast_ended"):
			if not _boss.is_connected("cast_ended", Callable(self, "_on_boss_cast_ended")):
				_boss.connect("cast_ended", Callable(self, "_on_boss_cast_ended"))

	# -----------------------------
	# Initial refresh (after hookups)
	# -----------------------------
	_floor_poll_t = 0.0
	_boss_hp_poll_t = 0.0
	_update_floor_text()
	_update_encounter_text()

	set_process(true)


func _exit_tree() -> void:
	if _encounter != null and is_instance_valid(_encounter):
		if _encounter.phase_changed.is_connected(_on_phase_changed):
			_encounter.phase_changed.disconnect(_on_phase_changed)
		if _encounter.dps_time_changed.is_connected(_on_dps_time_changed):
			_encounter.dps_time_changed.disconnect(_on_dps_time_changed)

	if _boss != null and is_instance_valid(_boss):
		if _boss.has_signal("cast_started") and _boss.is_connected("cast_started", Callable(self, "_on_boss_cast_started")):
			_boss.disconnect("cast_started", Callable(self, "_on_boss_cast_started"))
		if _boss.has_signal("cast_ended") and _boss.is_connected("cast_ended", Callable(self, "_on_boss_cast_ended")):
			_boss.disconnect("cast_ended", Callable(self, "_on_boss_cast_ended"))


func _process(delta: float) -> void:
	_floor_poll_t += delta
	if _floor_poll_t >= floor_poll_interval:
		_floor_poll_t = 0.0
		_update_floor_text()

	if _encounter != null and is_instance_valid(_encounter) and _encounter.phase == EncounterController.Phase.DPS:
		_update_encounter_text()

	_boss_hp_poll_t += delta
	if _boss_hp_poll_t >= boss_hp_poll_interval:
		_boss_hp_poll_t = 0.0
		_poll_boss_health_into_hud()


func _on_phase_changed(_new_phase: int) -> void:
	_update_encounter_text()


func _on_dps_time_changed(_time_left: float) -> void:
	if _encounter == null or not is_instance_valid(_encounter):
		return
	if _encounter.phase == EncounterController.Phase.DPS:
		_update_encounter_text()


# -----------------------------
# Text updates
# -----------------------------
func _update_encounter_text() -> void:
	if _encounter == null or not is_instance_valid(_encounter):
		return

	var floor_num: int = _get_floor_num()
	var should_show: bool = floor_num >= show_encounter_text_on_floor
	_set_control_visible(_encounter_label_node, should_show)

	if not should_show:
		return

	if _encounter.phase == EncounterController.Phase.ASCENT:
		_set_encounter_label_text(
			"[font_size=30][b]Phase: Ascent[/b][/font_size]\n" +
			"[font_size=20]Kill the glowing enemy to reveal the charging station[/font_size]"
		)
	else:
		var t: float = _encounter.get_dps_time_left()
		_set_encounter_label_text(
			"[font_size=30][b]Phase: DPS[/b][/font_size]\n" +
			"[font_size=20]Time Left: %ss[/font_size]" % str(snapped(t, 0.1))
		)


func _update_floor_text() -> void:
	var floor_num: int = _get_floor_num()

	# If we’re on/after boss floor, hide the lightweight floor chip
	var should_show: bool = floor_num < show_encounter_text_on_floor

	# Prefer the new FloorStatusHUD if present
	if _floor_status_hud != null and is_instance_valid(_floor_status_hud):
		_floor_status_hud.visible = should_show

		if not should_show:
			return

		if _floors == null or not is_instance_valid(_floors):
			_floor_status_hud.visible = false
			return

		var enemies_left: int = _floors.get_enemies_left_current_floor()
		var complete: bool = _floors.is_current_floor_complete()

		if _floor_status_hud.has_method("set_floor"):
			_floor_status_hud.call("set_floor", floor_num)
		if _floor_status_hud.has_method("set_enemies_left"):
			_floor_status_hud.call("set_enemies_left", enemies_left)
		if _floor_status_hud.has_method("set_floor_complete"):
			_floor_status_hud.call("set_floor_complete", complete)

		return

	# Fallback: old Label behavior (keeps you safe if path is wrong)
	if _floor_label == null:
		return

	if not should_show:
		_floor_label.visible = false
		return

	if _floors == null or not is_instance_valid(_floors):
		_floor_label.visible = false
		return

	_floor_label.visible = true

	var enemies_left2: int = _floors.get_enemies_left_current_floor()
	var complete2: bool = _floors.is_current_floor_complete()

	if complete2:
		_floor_label.text = "Floor %d:\nFloor Complete" % floor_num
	else:
		_floor_label.text = "Floor %d:\nEnemies Left - %d" % [floor_num, enemies_left2]


func _get_floor_num() -> int:
	if _floors == null or not is_instance_valid(_floors):
		return 1
	return _floors.get_current_floor_number()


# -----------------------------
# Encounter resolve helpers
# -----------------------------
func _resolve_encounter() -> EncounterController:
	var ec: EncounterController = null

	if encounter_path != NodePath():
		ec = get_node_or_null(encounter_path) as EncounterController

	if ec == null:
		ec = get_tree().get_first_node_in_group("encounter") as EncounterController

	if ec == null:
		ec = _find_first_encounter(get_tree().current_scene)

	return ec


# -----------------------------
# Boss resolve + feed helpers
# -----------------------------
func _resolve_boss() -> Node:
	var b: Node = null

	if boss_path != NodePath():
		b = get_node_or_null(boss_path)

	if b == null:
		b = get_tree().get_first_node_in_group("boss")

	if b == null and get_tree().current_scene != null:
		var maybe := get_tree().current_scene.get_node_or_null("Boss")
		if maybe != null:
			b = maybe

	return b


func _get_boss_display_name(boss: Node) -> String:
	if boss == null:
		return "BOSS"
	if boss.has_method("get_boss_name"):
		return String(boss.call("get_boss_name"))
	var v: Variant = boss.get("boss_name")
	if v is String:
		return String(v)
	return boss.name


func _poll_boss_health_into_hud() -> void:
	if _boss_hud == null or not is_instance_valid(_boss_hud):
		return
	if _boss == null or not is_instance_valid(_boss):
		return
	if not _boss_hud.has_method("set_health"):
		return

	# Try method pairs first
	if _boss.has_method("get_health") and _boss.has_method("get_max_health"):
		var cur := float(_boss.call("get_health"))
		var maxv := float(_boss.call("get_max_health"))
		_boss_hud.call("set_health", cur, maxv)
		return

	if _boss.has_method("get_hp") and _boss.has_method("get_max_hp"):
		var cur2 := float(_boss.call("get_hp"))
		var max2 := float(_boss.call("get_max_hp"))
		_boss_hud.call("set_health", cur2, max2)
		return

	# Try properties
	var candidates: Array[PackedStringArray] = [
		PackedStringArray(["health", "max_health"]),
		PackedStringArray(["hp", "max_hp"]),
		PackedStringArray(["current_hp", "max_hp"]),
		PackedStringArray(["current_health", "max_health"])
	]

	for pair: PackedStringArray in candidates:
		var a: String = pair[0]
		var b: String = pair[1]
		var curv: Variant = _boss.get(a)
		var maxv2: Variant = _boss.get(b)
		if curv != null and maxv2 != null:
			_boss_hud.call("set_health", float(curv), float(maxv2))
			return


# -----------------------------
# Boss cast signals -> BossHUDTop
# -----------------------------
func _on_boss_cast_started(spell_name: String, cast_time: float) -> void:
	if _boss_hud == null or not is_instance_valid(_boss_hud):
		return
	if _boss_hud.has_method("start_cast"):
		_boss_hud.call("start_cast", spell_name, cast_time)


func _on_boss_cast_ended(_spell_name: String) -> void:
	if _boss_hud == null or not is_instance_valid(_boss_hud):
		return
	if _boss_hud.has_method("stop_cast"):
		_boss_hud.call("stop_cast")


# -----------------------------
# Label helpers
# -----------------------------
func _set_encounter_label_text(s: String) -> void:
	if _encounter_label_node == null:
		return

	if _encounter_label_node is RichTextLabel:
		var rtl := _encounter_label_node as RichTextLabel
		rtl.bbcode_enabled = true
		rtl.scroll_active = false
		rtl.scroll_following = false
		rtl.fit_content = true
		rtl.clear()
		rtl.parse_bbcode(s)
		return

	if _encounter_label_node is Label:
		(_encounter_label_node as Label).text = s


func _set_control_visible(c: Control, v: bool) -> void:
	if c == null:
		return
	c.visible = v


func _get_node_as_control(p: NodePath) -> Control:
	if p == NodePath():
		return null
	var n: Node = get_node_or_null(p)
	if n == null:
		return null
	if n is Control:
		return n as Control
	return null


# -----------------------------
# Find helpers (LAST resort)
# -----------------------------
func _find_first_encounter(n: Node) -> EncounterController:
	var ec: EncounterController = n as EncounterController
	if ec != null:
		return ec
	for child: Node in n.get_children():
		var found: EncounterController = _find_first_encounter(child)
		if found != null:
			return found
	return null


func _find_first_floors(n: Node) -> FloorProgressionController:
	var fp: FloorProgressionController = n as FloorProgressionController
	if fp != null:
		return fp
	for child: Node in n.get_children():
		var found: FloorProgressionController = _find_first_floors(child)
		if found != null:
			return found
	return null


func _find_first_control_named(n: Node, name_to_find: String) -> Control:
	if n is Control and n.name == name_to_find:
		return n as Control
	for child: Node in n.get_children():
		var found: Control = _find_first_control_named(child, name_to_find)
		if found != null:
			return found
	return null


func _find_first_label_named(n: Node, name_to_find: String) -> Label:
	if n is Label and n.name == name_to_find:
		return n as Label
	for child: Node in n.get_children():
		var found: Label = _find_first_label_named(child, name_to_find)
		if found != null:
			return found
	return null
