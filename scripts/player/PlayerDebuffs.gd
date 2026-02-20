extends Node
class_name PlayerDebuffs

signal debuff_changed(id: StringName, active: bool, time_left: float)

var _timers: Dictionary[StringName, float] = {}

func _process(delta: float) -> void:
	if _timers.is_empty():
		return

	var to_clear: Array[StringName] = []
	for k: StringName in _timers.keys():
		var t: float = float(_timers[k])
		t = maxf(t - delta, 0.0)
		_timers[k] = t
		if t <= 0.0:
			to_clear.append(k)

	for k2: StringName in to_clear:
		_timers.erase(k2)
		debuff_changed.emit(k2, false, 0.0)

func apply_debuff(id: StringName, duration: float) -> void:
	if duration <= 0.0:
		return
	_timers[id] = duration
	debuff_changed.emit(id, true, duration)

func has_debuff(id: StringName) -> bool:
	return _timers.has(id)

func time_left(id: StringName) -> float:
	if not _timers.has(id):
		return 0.0
	return float(_timers[id])
