extends Area2D
class_name ChargeStation

@export var charge_rate: float = 1.0
@export var debug_station: bool = false

@export var visual_path: NodePath = ^"AnimatedSprite2D"
@export var base_modulate: Color = Color(1, 1, 1, 1)
@export var hint_modulate: Color = Color(1.35, 1.35, 1.35, 1)

var _active: bool = false
var _hint_enabled: bool = true
var _tracked: Array[AscensionCharge] = []

@onready var _visual: CanvasItem = get_node_or_null(visual_path) as CanvasItem

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)

	# Keep station visible always; only modulate changes
	if _visual != null:
		_visual.visible = true

	# Important: do NOT stomp _active here. EncounterController controls it.
	# Apply whatever the current state is.
	_apply_visual()

func set_active(v: bool) -> void:
	_active = v

	# ✅ CRITICAL: cannot toggle monitoring/monitorable during overlap callbacks
	# Use deferred property set.
	set_deferred("monitoring", _active)
	set_deferred("monitorable", true)

	# Optional: clear tracked when turning off
	if not _active:
		_tracked.clear()

	_apply_visual()

	if debug_station:
		pass

func is_active() -> bool:
	return _active

func set_hint_enabled(v: bool) -> void:
	_hint_enabled = v
	_apply_visual()

func is_hint_enabled() -> bool:
	return _hint_enabled

func _get_effective_charge_rate() -> float:
	var mult: float = 1.0
	if RunStateSingleton != null and ("orb_charge_mult" in RunStateSingleton):
		mult = float(RunStateSingleton.orb_charge_mult)
	return maxf(0.0, charge_rate * mult)

func _process(delta: float) -> void:
	if not _active:
		return
	if _tracked.is_empty():
		return

	for c in _tracked.duplicate():
		if c == null or not is_instance_valid(c):
			_tracked.erase(c)
			continue
		if c.is_consumed:
			_tracked.erase(c)
			continue
		if not c.is_carried:
			continue

		c.add_charge_seconds(_get_effective_charge_rate() * delta)

func _on_area_entered(area: Area2D) -> void:
	# Only track if active
	if not _active:
		return

	var c := area as AscensionCharge
	if c == null:
		var p := area.get_parent()
		if p != null:
			c = p as AscensionCharge
	if c == null:
		return

	if not _tracked.has(c):
		_tracked.append(c)
		if debug_station:
			pass

	if debug_station:
		pass

func _on_area_exited(area: Area2D) -> void:
	var c := area as AscensionCharge
	if c == null:
		var p := area.get_parent()
		if p != null:
			c = p as AscensionCharge
	if c == null:
		return

	_tracked.erase(c)

	if debug_station:
		pass

func _apply_visual() -> void:
	if _visual == null:
		return
	_visual.visible = true
	_visual.modulate = hint_modulate if (_active and _hint_enabled) else base_modulate
