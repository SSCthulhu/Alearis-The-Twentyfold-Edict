extends Area2D
class_name AscensionSocket

signal charge_socketed(consumed_charge: AscensionCharge)

@export var debug_socket: bool = false
@export var visual_path: NodePath = ^"AnimatedSprite2D"
@onready var _visual: CanvasItem = get_node_or_null(visual_path) as CanvasItem

var _enabled: bool = false  # Start hidden until charge is forged
var _pending_consume: bool = false

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	_apply_enabled_state()

func set_enabled(v: bool) -> void:
	_enabled = v
	_apply_enabled_state()

func is_enabled() -> bool:
	return _enabled

func _apply_enabled_state() -> void:
	# ✅ Deferred to avoid "blocked during in/out signal"
	set_deferred("monitoring", _enabled)
	set_deferred("monitorable", _enabled)

	if _visual != null:
		_visual.visible = _enabled
		pass

func _on_area_entered(area: Area2D) -> void:
	if not _enabled:
		return
	if _pending_consume:
		return
	if area == null or not is_instance_valid(area):
		return

	var charge: AscensionCharge = _extract_charge(area)
	if charge == null:
		return
	if charge.is_consumed or charge.is_queued_for_deletion():
		return

	# Gate: must be ready
	var ok: bool = false
	if charge.has_method("is_ready_for_socket"):
		ok = bool(charge.call("is_ready_for_socket"))
	else:
		ok = (charge.charged_seconds >= charge.charge_required_seconds)

	if not ok:
		if debug_socket:
			pass
		return

	# ✅ Defer the actual consume/disable work to next frame
	_pending_consume = true
	call_deferred("_consume_charge_deferred", charge)

func _consume_charge_deferred(charge: AscensionCharge) -> void:
	_pending_consume = false

	if not _enabled:
		return
	if charge == null or not is_instance_valid(charge):
		return
	if charge.is_consumed or charge.is_queued_for_deletion():
		return

	if debug_socket:
		pass

	# Emit first so EncounterController can switch phases
	charge_socketed.emit(charge)

	# Consume last (also safe-deferred in AscensionCharge below)
	charge.consume()

func _extract_charge(area: Area2D) -> AscensionCharge:
	var c := area as AscensionCharge
	if c != null:
		return c

	var p := area.get_parent()
	if p != null:
		c = p as AscensionCharge
		if c != null:
			return c

	return null
