extends Node
class_name PerfectDodgeDetector

# Fires when a blocked hit happened within the perfect timing window.
signal perfect_dodge(trigger_source: Node, attempted_damage: int)

@export var health_path: NodePath = ^"../Health"

# Perfect timing window measured from the moment invulnerability STARTS.
@export var perfect_window: float = 0.25

# Prevents spamming perfect-dodge triggers from multiple blocked hits in the same moment.
@export var rearm_cooldown: float = 0.10

@export var debug_prints: bool = true

var _rearm_left: float = 0.0

var _health: PlayerHealth = null

# --- Robust timing: track invuln rising-edge ---
var _was_invuln: bool = false
var _invuln_start_time: float = -1.0 # < 0 means "haven't started / not currently tracking"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT

	_health = get_node_or_null(health_path) as PlayerHealth
	if _health == null:
		push_warning("[PerfectDodgeDetector] Health not found at path: %s" % String(health_path))
		return

	if debug_prints:
		pass

	# PlayerHealth must emit: damage_blocked(attempted_damage, source)
	if not _health.damage_blocked.is_connected(_on_damage_blocked):
		_health.damage_blocked.connect(_on_damage_blocked)

	# Initialize invuln state
	_was_invuln = _health.is_invulnerable()
	if _was_invuln:
		_invuln_start_time = _now()
		if debug_prints:
			pass

func _process(delta: float) -> void:
	if _rearm_left > 0.0:
		_rearm_left = maxf(_rearm_left - delta, 0.0)

	if _health == null or not is_instance_valid(_health):
		return

	# Track the exact moment invulnerability begins (false -> true)
	var inv: bool = _health.is_invulnerable()
	if inv and not _was_invuln:
		_invuln_start_time = _now()
		var _source: String = ""
		if _health.has_method("get_invuln_source"):
			_source = _health.get_invuln_source()
		if debug_prints:
			pass

	# If invuln ends, stop tracking (optional, but keeps logs clean)
	if (not inv) and _was_invuln:
		_invuln_start_time = -1.0
		if debug_prints:
			pass

	_was_invuln = inv

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _on_damage_blocked(attempted_damage: int, source: Node) -> void:
	var _src_name: String = "NULL"
	if source != null:
		_src_name = String(source.name)

	# How long since invuln began?
	var since_invuln: float = -1.0
	if _invuln_start_time >= 0.0:
		since_invuln = _now() - _invuln_start_time
	
	# Check invuln source - only allow perfect dodge from rolls, not post-hit invuln
	var invuln_source: String = ""
	if _health != null and _health.has_method("get_invuln_source"):
		invuln_source = _health.get_invuln_source()

	if debug_prints:
		pass

	# CRITICAL: Only allow perfect dodge from roll invuln, not post-hit invuln
	if invuln_source != "roll":
		if debug_prints:
			pass
		return

	# Rearm cooldown gate
	if _rearm_left > 0.0:
		if debug_prints:
			pass
		return

	# Must be inside the window measured from invuln start
	var win: float = maxf(perfect_window, 0.01)
	if since_invuln < 0.0 or since_invuln > win:
		if debug_prints:
			pass
		return

	# Trigger
	_rearm_left = maxf(rearm_cooldown, 0.0)

	if debug_prints:
		pass

	perfect_dodge.emit(source, attempted_damage)
	
