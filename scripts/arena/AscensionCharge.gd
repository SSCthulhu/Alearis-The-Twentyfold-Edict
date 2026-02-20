# res://scripts/AscensionCharge.gd
extends Area2D
class_name AscensionCharge

signal picked_up(carrier: Node2D)
signal dropped
signal consumed

@export var pickup_lockout_seconds: float = 0.75

@export var ready_ring_path: NodePath = ^"ReadyRing"
@export var ready_ring_alpha: float = 0.75
@export var ready_ring_scale: float = 1.2
@onready var _ready_ring: Sprite2D = get_node_or_null(ready_ring_path) as Sprite2D

var is_carried: bool = false
var is_consumed: bool = false
var pickup_locked: bool = false

var _lockout_timer: Timer
var _encounter: EncounterController = null

signal charge_progress(seconds_charged: float, seconds_required: float)
signal fully_charged

@export var charge_required_seconds: float = 10.0
var charged_seconds: float = 0.0
var _did_emit_full: bool = false

# -------------------------
# NEW: Drop gravity settings
# -------------------------
@export var drop_gravity: float = 1250.0
@export var drop_max_fall_speed: float = 900.0

# How far below the orb we consider "ground contact" snapping (pixels)
@export var drop_ground_snap: float = 8.0

# How far above the hit point we place the orb (so it doesn't visually sink into ground).
# Tune this based on your sprite pivot/collision shape.
@export var drop_ground_clearance: float = 10.0

var _fall_velocity_y: float = 0.0

# -------------------------
# NEW: Group name for reliable lookup (reparents between player/world)
# -------------------------
const GROUP_ASCENSION_CHARGE: StringName = &"ascension_charge"


func _ready() -> void:
	# Ensure we can be found even as we reparent.
	add_to_group(GROUP_ASCENSION_CHARGE)

	# HARD SAFETY: ensure we never auto-pickup via old body_entered connections.
	if body_entered.get_connections().size() > 0:
		for c in body_entered.get_connections():
			var callable: Callable = c["callable"]
			if body_entered.is_connected(callable):
				body_entered.disconnect(callable)

	_lockout_timer = Timer.new()
	_lockout_timer.one_shot = true
	add_child(_lockout_timer)
	_lockout_timer.timeout.connect(_on_lockout_timeout)

	# ✅ IMPORTANT:
	# Charge should usually NOT "monitor" (we don't need it to detect others),
	# but it MUST be "monitorable" so stations/sockets can detect it.
	monitoring = false
	monitorable = true


	if _ready_ring != null:
		_ready_ring.visible = false
		_ready_ring.modulate.a = ready_ring_alpha
		_ready_ring.scale = Vector2.ONE * ready_ring_scale
	else:
		push_warning("[Charge] ReadyRing not found. Add Sprite2D child 'ReadyRing' or set ready_ring_path.")

	if not fully_charged.is_connected(_on_fully_charged):
		fully_charged.connect(_on_fully_charged)
	if not charge_progress.is_connected(_on_charge_progress):
		charge_progress.connect(_on_charge_progress)

	_emit_charge_progress()


# -------------------------
# NEW: Drop falling loop
# -------------------------
func _physics_process(delta: float) -> void:
	if is_consumed:
		return
	if is_carried:
		return

	# If we're not carried, we should fall until we hit WORLD (Layer 1).
	_apply_drop_gravity(delta)


func _apply_drop_gravity(delta: float) -> void:
	# Integrate velocity
	_fall_velocity_y = minf(_fall_velocity_y + drop_gravity * delta, drop_max_fall_speed)

	# How far we intend to move down this frame
	var step: float = _fall_velocity_y * delta
	if step <= 0.0:
		return

	var from_pos: Vector2 = global_position
	var to_pos: Vector2 = from_pos + Vector2(0.0, step + drop_ground_snap)

	# Raycast against WORLD layer only (Layer 1 => bit 0 => mask 1)
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1)
	params.exclude = [self]

	var hit: Dictionary = space_state.intersect_ray(params)

	if hit.is_empty():
		# No ground hit, keep falling
		global_position = from_pos + Vector2(0.0, step)
		return

	# Ground hit: snap to just above surface and stop falling
	var hit_pos: Vector2 = hit["position"]
	global_position = Vector2(from_pos.x, hit_pos.y - drop_ground_clearance)
	_fall_velocity_y = 0.0


func set_encounter(encounter: EncounterController) -> void:
	_encounter = encounter

func is_fully_charged() -> bool:
	return charged_seconds >= charge_required_seconds

func is_ready_for_socket() -> bool:
	return is_fully_charged()

func add_charge_seconds(amount: float) -> void:
	if is_consumed:
		return
	if amount <= 0.0:
		return

	charged_seconds = clampf(charged_seconds + amount, 0.0, charge_required_seconds)
	_emit_charge_progress()

	if is_fully_charged() and not _did_emit_full:
		_did_emit_full = true
		fully_charged.emit()

func set_forge_progress(progress: float) -> void:
	"""Update charge progress from 0.0 to 1.0 (used during forging)"""
	if is_consumed:
		return
	var new_seconds := progress * charge_required_seconds
	charged_seconds = clampf(new_seconds, 0.0, charge_required_seconds)
	_emit_charge_progress()
	
	if is_fully_charged() and not _did_emit_full:
		_did_emit_full = true
		fully_charged.emit()

func reset_charge() -> void:
	charged_seconds = 0.0
	_did_emit_full = false
	_emit_charge_progress()
	_set_ready_ring(false)

func _emit_charge_progress() -> void:
	charge_progress.emit(charged_seconds, charge_required_seconds)

func can_be_picked_up() -> bool:
	return (not is_consumed) and (not is_carried) and (not pickup_locked)

func pickup_to(carrier: Node2D, local_offset: Vector2) -> void:
	if not can_be_picked_up():
		return

	is_carried = true
	pickup_locked = true

	# NEW: stop any fall momentum immediately
	_fall_velocity_y = 0.0

	# ✅ KEY CHANGE: keep monitorable true so stations/sockets can detect the charge while carried
	monitoring = false
	monitorable = true

	if get_parent() != carrier:
		reparent(carrier)

	position = local_offset

	_start_lockout(pickup_lockout_seconds)
	picked_up.emit(carrier)

	# Don't reset charge - keep progress when picked up after dropping
	# reset_charge()

	if _encounter != null and _encounter.has_method("notify_charge_picked_up"):
		_encounter.notify_charge_picked_up(self)

func drop_into_world(world_parent: Node, world_position: Vector2) -> void:
	if is_consumed:
		return

	is_carried = false

	if get_parent() != world_parent:
		reparent(world_parent)

	global_position = world_position

	# ✅ KEY CHANGE: still monitorable so stations/sockets can detect it while dropped
	monitoring = false
	monitorable = true

	# NEW: reset fall velocity so the drop starts clean
	_fall_velocity_y = 0.0

	pickup_locked = true
	_start_lockout(pickup_lockout_seconds)

	dropped.emit()

	if _encounter != null and _encounter.has_method("notify_charge_dropped"):
		_encounter.call("notify_charge_dropped", self)

func consume() -> void:
	call_deferred("_consume_deferred")

func _consume_deferred() -> void:
	if is_consumed:
		return

	is_consumed = true
	is_carried = false

	# NEW: stop falling
	_fall_velocity_y = 0.0

	# ✅ Deferred-safe
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	consumed.emit()

	if _encounter != null and _encounter.has_method("notify_charge_consumed"):
		_encounter.call("notify_charge_consumed", self)

	queue_free()

func reset_to_spawn(world_parent: Node, spawn_pos: Vector2) -> void:
	if is_consumed:
		return

	is_carried = false

	if get_parent() != world_parent:
		reparent(world_parent)

	global_position = spawn_pos

	# NEW: stop falling
	_fall_velocity_y = 0.0

	pickup_locked = false
	_lockout_timer.stop()

	monitoring = false
	monitorable = true

	reset_charge()

func _start_lockout(seconds: float) -> void:
	if seconds <= 0.0:
		_on_lockout_timeout()
		return
	_lockout_timer.start(seconds)

func _on_lockout_timeout() -> void:
	pickup_locked = false

func _on_fully_charged() -> void:
	_set_ready_ring(true)

func _on_charge_progress(seconds_charged: float, seconds_required: float) -> void:
	_set_ready_ring(seconds_charged >= seconds_required)

func _set_ready_ring(on: bool) -> void:
	if _ready_ring == null:
		return
	_ready_ring.visible = on
