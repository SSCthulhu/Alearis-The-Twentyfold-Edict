extends Area2D
class_name RisingHazard

@export var bottom_marker_path: NodePath
@export var ceiling_marker_path: NodePath # OPTIONAL. Leave empty if you drive via rise_to_ceiling_y()

@export var rise_speed: float = 140.0
@export var retract_speed: float = 220.0

@export var damage_per_second: float = 2.0

# Prevent “teleport” on big delta when unpausing
@export var max_motion_dt: float = 0.05

# Debug logging
@export var debug_logging: bool = false

var _bottom_y: float = 0.0
var _ceiling_y: float = 0.0

var _rising: bool = false
var _retracting: bool = false
var _damage_enabled: bool = false

# Gate: freeze & block starting until UI selection is made
var _paused_by_system: bool = false

# Queue “start rising” requests while paused
var _queued_start_rising: bool = false
var _queued_rise_to: bool = false
var _queued_target_y: float = 0.0
var _queued_enable_damage: bool = true

var _tracked: Array[Node] = []
var _damage_accum: Dictionary = {}

@onready var _bottom_marker: Node2D = get_node_or_null(bottom_marker_path) as Node2D
@onready var _ceiling_marker: Node2D = get_node_or_null(ceiling_marker_path) as Node2D

@onready var _visual: CanvasItem = get_node_or_null(^"Visual") as CanvasItem

func _ready() -> void:
	if _bottom_marker == null:
		# Only warn if bottom_marker_path was set but not found
		if bottom_marker_path != NodePath():
			push_warning("[Hazard] bottom_marker not found. Set bottom_marker_path.")
	else:
		_bottom_y = _bottom_marker.global_position.y

	# Ceiling marker is OPTIONAL
	if _ceiling_marker != null:
		_ceiling_y = _ceiling_marker.global_position.y

	# Start at bottom if you want (your older behavior)
	# If you don’t want this, comment this line out.
	if _bottom_marker != null:
		global_position.y = _bottom_y

	if _visual != null:
		_visual.visible = false

	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_set_damage_enabled(false)
	set_process(true)

func _process(delta: float) -> void:
	# Freeze completely while modifier UI is open
	if _paused_by_system:
		return

	var dt: float = minf(delta, max_motion_dt)

	# Movement
	if _rising:
		_move_up(dt)
	elif _retracting:
		_move_down(dt)

	# Damage uses real delta so DPS stays correct
	if _damage_enabled and damage_per_second > 0.0:
		_apply_below_line_damage(delta)

# ---------------------------
# UI gate control
# ---------------------------
func set_paused_by_system(paused: bool) -> void:
	_paused_by_system = paused

	if paused:
		# Freeze in place. Do not move. Do not damage.
		_rising = false
		_retracting = false
		_set_damage_enabled(false)
		if debug_logging: print("[Hazard] Paused by system (waiting for selection)")
		return
	
	if debug_logging: print("[Hazard] Unpaused by system")

	# Execute anything that tried to start while we were paused
	if _queued_rise_to:
		var ty: float = _queued_target_y
		var ed: bool = _queued_enable_damage
		_queued_rise_to = false
		_queued_start_rising = false
		_rise_to_now(ty, ed)
		return

	if _queued_start_rising:
		_queued_start_rising = false
		_start_rising_now()
		if debug_logging: print("[Hazard] Rising started. Effective rise speed=", _get_rise_speed_effective())


# ---------------------------
# External API (called by your floor controller)
# ---------------------------
func start_rising() -> void:
	if _paused_by_system:
		_queued_start_rising = true
		_queued_rise_to = false
		if debug_logging: print("[Hazard] start_rising queued until selection")
		return
	_start_rising_now()

func rise_to_ceiling_y(target_y: float, enable_damage: bool = true) -> void:
	_ceiling_y = target_y

	if _paused_by_system:
		_queued_rise_to = true
		_queued_start_rising = false
		_queued_target_y = target_y
		_queued_enable_damage = enable_damage
		if debug_logging: print("[Hazard] rise_to_ceiling_y queued until selection. Target Y=", target_y)
		return

	_rise_to_now(target_y, enable_damage)

func pause_rising() -> void:
	_rising = false
	if debug_logging: print("[Hazard] Rising paused")

func enter_dps() -> void:
	# Freeze motion only — KEEP damage enabled so standing in hazard still hurts.
	_rising = false
	_retracting = false

	# ✅ Do NOT disable damage here.
	# _set_damage_enabled(false)

	if debug_logging: print("[Hazard] DPS: frozen (damage stays on)")


func retract_to_bottom() -> void:
	_rising = false
	_retracting = true
	_set_damage_enabled(false)

	if _visual != null:
		_visual.visible = true

	if debug_logging: print("[Hazard] Retracting to bottom")

# ---------------------------
# Internals
# ---------------------------
func _start_rising_now() -> void:
	_retracting = false
	_rising = true
	_set_damage_enabled(true)

	if _visual != null:
		_visual.visible = true

	if debug_logging: print("[Hazard] Rising started")

func _rise_to_now(target_y: float, enable_damage: bool) -> void:
	_ceiling_y = target_y
	_retracting = false
	_rising = true
	_set_damage_enabled(enable_damage)

	if _visual != null:
		_visual.visible = true

	if debug_logging: print("[Hazard] Rising to target Y=", _ceiling_y)

func _move_up(dt: float) -> void:
	# If a ceiling marker exists, it can override the target (OPTIONAL behavior)
	if _ceiling_marker != null:
		_ceiling_y = _ceiling_marker.global_position.y

	var y: float = global_position.y
	y -= _get_rise_speed_effective() * dt

	if y < _ceiling_y:
		y = _ceiling_y
		_rising = false
		pass

	global_position.y = y

func _move_down(dt: float) -> void:
	if _bottom_marker != null:
		_bottom_y = _bottom_marker.global_position.y

	var y: float = global_position.y
	y += _get_retract_speed_effective() * dt

	if y > _bottom_y:
		y = _bottom_y
		_retracting = false
		if _visual != null:
			_visual.visible = false
		pass

	global_position.y = y

func _get_rise_speed_effective() -> float:
	var mult: float = 1.0
	if RunStateSingleton != null and ("hazard_rise_mult" in RunStateSingleton):
		mult = float(RunStateSingleton.hazard_rise_mult)
	return maxf(1.0, rise_speed * mult)

func _get_retract_speed_effective() -> float:
	# Usually retract should NOT scale with danger (feels unfair).
	# Keep it constant for readability and pacing.
	return maxf(1.0, retract_speed)

# ---------------------------
# Tracking + damage
# ---------------------------
func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if _tracked.has(body):
		return
	_tracked.append(body)
	_damage_accum[body] = 0.0

func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	_tracked.erase(body)
	_damage_accum.erase(body)

func _set_damage_enabled(enabled: bool) -> void:
	_damage_enabled = enabled
	for k in _damage_accum.keys():
		_damage_accum[k] = 0.0

func _apply_below_line_damage(delta: float) -> void:
	var hazard_y: float = global_position.y

	var bodies := _tracked.duplicate()
	for b in bodies:
		if b == null or not is_instance_valid(b):
			_tracked.erase(b)
			_damage_accum.erase(b)
			continue

		var body_y: float = (b as Node2D).global_position.y if (b is Node2D) else hazard_y

		if body_y > hazard_y:
			var acc: float = float(_damage_accum.get(b, 0.0))
			acc += damage_per_second * delta

			var dmg_int: int = int(floor(acc))
			if dmg_int >= 1:
				_deal_damage(b, dmg_int)
				acc -= float(dmg_int)

			_damage_accum[b] = acc
		else:
			_damage_accum[b] = 0.0

func _deal_damage(body: Node, amount: int) -> void:
	if amount <= 0:
		return

	if body.has_node("Health"):
		var h := body.get_node("Health")
		if h != null and h.has_method("take_damage"):
			h.take_damage(amount, self, true)
			return

	if body.has_method("take_damage"):
		body.call("take_damage", amount, self, true)
