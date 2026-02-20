extends Node
class_name PlayerBuffs

signal buff_added(id: StringName, duration: float)
signal buff_removed(id: StringName)
signal stats_changed

# Each buff has: time_left, and a stats dictionary of modifiers.
# stats keys are StringName; values are float.
# Example keys:
#  - &"defend_cooldown_mult": 0.8
#  - &"defend_duration_mult": 1.5
#  - &"defend_allowed_while_carrying": 1.0
var _buffs: Dictionary[StringName, Dictionary] = {}

func _process(delta: float) -> void:
	if _buffs.is_empty():
		return

	var expired: Array[StringName] = []
	for id: StringName in _buffs.keys():
		var data: Dictionary = _buffs[id]
		var t: float = float(data.get("time_left", 0.0))
		t = maxf(t - delta, 0.0)
		data["time_left"] = t
		_buffs[id] = data
		if t <= 0.0:
			expired.append(id)

	if not expired.is_empty():
		for id2: StringName in expired:
			_buffs.erase(id2)
			buff_removed.emit(id2)
		stats_changed.emit()

func add_buff(id: StringName, duration: float, stats: Dictionary[StringName, float]) -> void:
	if duration <= 0.0:
		return

	var data: Dictionary = {
		"time_left": duration,
		"stats": stats
	}
	_buffs[id] = data
	buff_added.emit(id, duration)
	stats_changed.emit()

func remove_buff(id: StringName) -> void:
	if _buffs.erase(id):
		buff_removed.emit(id)
		stats_changed.emit()

func has_buff(id: StringName) -> bool:
	return _buffs.has(id)

func time_left(id: StringName) -> float:
	if not _buffs.has(id):
		return 0.0
	return float(_buffs[id].get("time_left", 0.0))

# ---- Stat query helpers ----
# Multipliers: default 1.0, multiply across buffs.
func get_mult(stat: StringName, default_value: float = 1.0) -> float:
	var mult: float = default_value
	for id: StringName in _buffs.keys():
		var data: Dictionary = _buffs[id]
		var stats: Dictionary = data.get("stats", {})
		if stats.has(stat):
			mult *= float(stats[stat])
	return mult

# Adders: default 0.0, sum across buffs.
func get_add(stat: StringName, default_value: float = 0.0) -> float:
	var add: float = default_value
	for id: StringName in _buffs.keys():
		var data: Dictionary = _buffs[id]
		var stats: Dictionary = data.get("stats", {})
		if stats.has(stat):
			add += float(stats[stat])
	return add

# Boolean-ish: returns true if ANY buff sets it to >= 1.0
func get_flag(stat: StringName) -> bool:
	for id: StringName in _buffs.keys():
		var data: Dictionary = _buffs[id]
		var stats: Dictionary = data.get("stats", {})
		if stats.has(stat) and float(stats[stat]) >= 1.0:
			return true
	return false
