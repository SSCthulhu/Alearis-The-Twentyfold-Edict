# res://scripts/EnemyStatusEffects.gd
extends Node
class_name EnemyStatusEffects

@export var debug_logs: bool = false

# Receiver that takes damage (EnemyHealth, BossHealth, etc.)
var _receiver: Node = null

# ---- Bleed state (refresh-only) ----
var _bleed_time_left: float = 0.0
var _bleed_tick_timer: float = 0.0
var _bleed_tick_interval: float = 0.5
var _bleed_base_tick_damage: int = 1

# ---- Stun state ----
var _stun_time_left: float = 0.0

# Damage tags (for colored damage numbers)
const TAG_BLEED: StringName = &"bleed"

func set_receiver(receiver: Node) -> void:
	_receiver = receiver

func clear_receiver() -> void:
	_receiver = null

func has_bleed() -> bool:
	return _bleed_time_left > 0.0

func has_stun() -> bool:
	return _stun_time_left > 0.0

func is_stunned() -> bool:
	return _stun_time_left > 0.0

func apply_stun(duration: float) -> void:
	"""Apply stun effect for given duration"""
	_stun_time_left = maxf(duration, 0.0)
	if debug_logs:
		pass

func apply_bleed_refresh(base_tick_damage: int, duration: float, tick_interval: float) -> void:
	_bleed_base_tick_damage = maxi(base_tick_damage, 1)
	_bleed_time_left = maxf(duration, 0.01)
	_bleed_tick_interval = maxf(tick_interval, 0.01)

	# Refresh-only: reset tick cadence for readability
	_bleed_tick_timer = 0.0

	if debug_logs:
		pass

func _process(delta: float) -> void:
	# Update stun timer
	if _stun_time_left > 0.0:
		_stun_time_left = maxf(_stun_time_left - delta, 0.0)
		if _stun_time_left <= 0.0 and debug_logs:
			pass
	
	# Update bleed
	if _bleed_time_left <= 0.0:
		return

	_bleed_time_left = maxf(_bleed_time_left - delta, 0.0)

	_bleed_tick_timer += delta
	while _bleed_tick_timer >= _bleed_tick_interval and _bleed_time_left > 0.0:
		_bleed_tick_timer -= _bleed_tick_interval
		_tick_bleed()

	if _bleed_time_left <= 0.0:
		_bleed_time_left = 0.0
		_bleed_tick_timer = 0.0

func _tick_bleed() -> void:
	if _receiver == null or not is_instance_valid(_receiver):
		if debug_logs:
			pass
		return
	if not _receiver.has_method("take_damage"):
		if debug_logs:
			pass
		return

	# Relic scaling (C6 Bleedstone)
	var mult: float = 1.0
	if RunStateSingleton != null and ("relic_bleed_damage_mult" in RunStateSingleton):
		mult = clampf(float(RunStateSingleton.relic_bleed_damage_mult), 0.0, 999.0)

	var dmg_f: float = float(_bleed_base_tick_damage) * mult
	var dmg: int = maxi(int(round(dmg_f)), 1)

	# ✅ Pass tag if receiver supports it (EnemyHealth: take_damage(amount, source, tag))
	# Fallback safely for BossHealth or older signatures.
	var argc: int = _receiver.get_method_argument_count("take_damage")
	if argc >= 3:
		_receiver.call("take_damage", dmg, null, TAG_BLEED)
	elif argc >= 2:
		_receiver.call("take_damage", dmg, null)
	else:
		_receiver.call("take_damage", dmg)

	if debug_logs:
		pass
