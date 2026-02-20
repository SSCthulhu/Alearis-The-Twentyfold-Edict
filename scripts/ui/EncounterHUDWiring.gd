extends Node
class_name EncounterHUDWiring

@export var floor_controller_path: NodePath = ^"../../FloorProgressionController"
@export var floor_status_hud_path: NodePath = ^"../TopRight/Pad/StatusPanel"

# If you still want it hidden AFTER the boss (optional), keep this.
# For now we DO NOT hide on boss floor so "Defeat Boss" can show.
@export var hide_floor_chip_on_floor: int = 999

@export var floor_poll_interval: float = 0.25
@export var boss_floor: int = 5

@export var boss_path: NodePath = ^"../../Boss"
@export var boss_hud_root_path: NodePath = ^"../TopCenter"
@export var boss_hp_poll_interval: float = 0.10

@export var total_floors: int = 5

var _last_floor_num: int = -1
var _last_enemies_total: int = 0

var _floors: FloorProgressionController = null
var _floor_status_hud: Node = null
var _floor_poll_t: float = 0.0

var _boss: Node = null
var _boss_hud: Node = null
var _boss_hp_poll_t: float = 0.0


func _ready() -> void:
	_floors = _resolve_floors()
	if _floors == null:
		# Only warn in main world scenes (sub-arenas and FinalWorld don't have FloorProgressionController)
		var scene_name: String = ""
		if get_tree().current_scene:
			scene_name = String(get_tree().current_scene.name)
		if not ("SubArena" in scene_name or "FinalWorld" in scene_name):
			push_warning("[UI] FloorProgressionController not found (floor UI will not update).")

	_floor_status_hud = get_node_or_null(floor_status_hud_path)
	if _floor_status_hud == null:
		push_warning("[UI] FloorStatusHUD not found. Check floor_status_hud_path.")

	_boss = _resolve_boss()
	if _boss == null:
		# Only warn in main world scenes (sub-arenas and FinalWorld don't have bosses)
		var scene_name: String = ""
		if get_tree().current_scene:
			scene_name = String(get_tree().current_scene.name)
		if not ("SubArena" in scene_name or "FinalWorld" in scene_name):
			push_warning("[UI] Boss not found. Set boss_path OR add boss to group 'boss'.")
	else:
		_connect_boss_cast_signals(_boss)

	_boss_hud = _resolve_boss_hud()
	if _boss_hud == null:
		push_warning("[UI] BossHUDTop not found. Check boss_hud_root_path.")
	else:
		# Hide boss HUD if no boss present (sub-arenas)
		if _boss == null:
			_boss_hud.visible = false
		else:
			_boss_hud.visible = true
			if is_instance_valid(_boss) and _boss_hud.has_method("set_boss_name"):
				_boss_hud.call("set_boss_name", _get_boss_display_name(_boss))

	_floor_poll_t = 0.0
	_boss_hp_poll_t = 0.0
	_update_floor_chip()
	_poll_boss_health_into_hud()

	set_process(true)


func refresh_boss_connection() -> void:
	"""Public method to refresh boss connection after dynamic boss replacement"""
	# Disconnect old boss signals
	if _boss != null and is_instance_valid(_boss):
		if _boss.has_signal("cast_started") and _boss.is_connected("cast_started", Callable(self, "_on_boss_cast_started")):
			_boss.disconnect("cast_started", Callable(self, "_on_boss_cast_started"))
		if _boss.has_signal("cast_ended") and _boss.is_connected("cast_ended", Callable(self, "_on_boss_cast_ended")):
			_boss.disconnect("cast_ended", Callable(self, "_on_boss_cast_ended"))
	
	# Re-resolve boss
	_boss = _resolve_boss()
	if _boss == null:
		push_warning("[UI] Boss not found after refresh. Set boss_path OR add boss to group 'boss'.")
		if _boss_hud != null:
			_boss_hud.visible = false
		return
	
	# Connect new boss signals
	_connect_boss_cast_signals(_boss)
	
	# Update boss HUD with new boss name
	if _boss_hud != null and is_instance_valid(_boss_hud):
		_boss_hud.visible = true
		if _boss_hud.has_method("set_boss_name"):
			var new_name := _get_boss_display_name(_boss)
			_boss_hud.call("set_boss_name", new_name)
			pass
	
	# Force immediate health poll
	_poll_boss_health_into_hud()


func _exit_tree() -> void:
	if _boss != null and is_instance_valid(_boss):
		if _boss.has_signal("cast_started") and _boss.is_connected("cast_started", Callable(self, "_on_boss_cast_started")):
			_boss.disconnect("cast_started", Callable(self, "_on_boss_cast_started"))
		if _boss.has_signal("cast_ended") and _boss.is_connected("cast_ended", Callable(self, "_on_boss_cast_ended")):
			_boss.disconnect("cast_ended", Callable(self, "_on_boss_cast_ended"))


func _process(delta: float) -> void:
	_floor_poll_t += delta
	if _floor_poll_t >= floor_poll_interval:
		_floor_poll_t = 0.0
		_update_floor_chip()

	_boss_hp_poll_t += delta
	if _boss_hp_poll_t >= boss_hp_poll_interval:
		_boss_hp_poll_t = 0.0
		_poll_boss_health_into_hud()


func _update_floor_chip() -> void:
	if _floor_status_hud == null or not is_instance_valid(_floor_status_hud):
		return

	var floor_num: int = _get_floor_num()
	var is_boss: bool = floor_num >= boss_floor

	# Show chip on boss floor so it can display "Defeat Boss"
	var should_show: bool = (floor_num < hide_floor_chip_on_floor) or is_boss
	_floor_status_hud.visible = should_show

	if not should_show:
		return

	if _floors == null or not is_instance_valid(_floors):
		_floor_status_hud.visible = false
		return

	var enemies_left: int = _floors.get_enemies_left_current_floor()
	var complete: bool = _floors.is_current_floor_complete()

	# Detect floor change -> snapshot total enemies for this floor
	if floor_num != _last_floor_num:
		_last_floor_num = floor_num
		_last_enemies_total = enemies_left

	if _floor_status_hud.has_method("set_floor"):
		_floor_status_hud.call("set_floor", floor_num)
	if _floor_status_hud.has_method("set_floor_total"):
		_floor_status_hud.call("set_floor_total", total_floors)

	if _floor_status_hud.has_method("set_is_boss_floor"):
		_floor_status_hud.call("set_is_boss_floor", is_boss)

	# Only feed dots if not boss (view will ignore anyway, but this keeps it clean)
	if _floor_status_hud.has_method("set_enemies_total"):
		_floor_status_hud.call("set_enemies_total", _last_enemies_total)
	if _floor_status_hud.has_method("set_enemies_left"):
		_floor_status_hud.call("set_enemies_left", enemies_left)

	if _floor_status_hud.has_method("set_floor_complete"):
		_floor_status_hud.call("set_floor_complete", complete)
	
	# ✅ NEW: Count elites on current floor
	if _floor_status_hud.has_method("set_elites_count"):
		var elite_count: int = _count_elites_on_floor(floor_num)
		_floor_status_hud.call("set_elites_count", elite_count)


func _get_floor_num() -> int:
	if _floors == null or not is_instance_valid(_floors):
		return 1
	return _floors.get_current_floor_number()


func _resolve_floors() -> FloorProgressionController:
	var fp: FloorProgressionController = null
	fp = get_tree().get_first_node_in_group("floors") as FloorProgressionController
	if fp != null:
		return fp
	if floor_controller_path != NodePath():
		fp = get_node_or_null(floor_controller_path) as FloorProgressionController
		if fp != null:
			return fp
	if get_tree().current_scene != null:
		fp = _find_first_floors(get_tree().current_scene)
	return fp


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


func _resolve_boss_hud() -> Node:
	var root: Node = get_node_or_null(boss_hud_root_path)
	if root == null:
		return null
	if root.has_method("set_health") or root.has_method("start_cast") or root.has_method("set_boss_name"):
		return root
	var found := _find_first_node_with_methods(root, ["set_health", "start_cast"])
	if found != null:
		return found
	return null


func _poll_boss_health_into_hud() -> void:
	if _boss_hud == null or not is_instance_valid(_boss_hud):
		return
	if _boss == null or not is_instance_valid(_boss):
		return
	if not _boss_hud.has_method("set_health"):
		return

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


func _connect_boss_cast_signals(boss: Node) -> void:
	if boss == null:
		return
	if boss.has_signal("cast_started"):
		if not boss.is_connected("cast_started", Callable(self, "_on_boss_cast_started")):
			boss.connect("cast_started", Callable(self, "_on_boss_cast_started"))
	if boss.has_signal("cast_ended"):
		if not boss.is_connected("cast_ended", Callable(self, "_on_boss_cast_ended")):
			boss.connect("cast_ended", Callable(self, "_on_boss_cast_ended"))


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


func _get_boss_display_name(boss: Node) -> String:
	if boss == null:
		return "BOSS"
	if boss.has_method("get_boss_name"):
		return String(boss.call("get_boss_name"))
	var v: Variant = boss.get("boss_name")
	if v is String:
		return String(v)
	return boss.name


func _find_first_floors(n: Node) -> FloorProgressionController:
	var fp: FloorProgressionController = n as FloorProgressionController
	if fp != null:
		return fp
	for child: Node in n.get_children():
		var found: FloorProgressionController = _find_first_floors(child)
		if found != null:
			return found
	return null


func _find_first_node_with_methods(n: Node, methods: Array[String]) -> Node:
	var ok := true
	for m in methods:
		if not n.has_method(m):
			ok = false
			break
	if ok:
		return n
	for child: Node in n.get_children():
		var found := _find_first_node_with_methods(child, methods)
		if found != null:
			return found
	return null

# ✅ NEW: Count elites on current floor
func _count_elites_on_floor(floor_num: int) -> int:
	# Check if any enemies in the elite group exist
	var elites: Array[Node] = get_tree().get_nodes_in_group(&"elites")
	
	# Filter to only elites on the current floor
	# Floor groups: floor1_enemies, floor2_enemies, floor5_enemies, etc.
	var floor_group: StringName = &"floor%d_enemies" % floor_num
	
	var count: int = 0
	for elite in elites:
		if elite != null and is_instance_valid(elite):
			if elite.is_in_group(floor_group):
				count += 1
	
	return count
