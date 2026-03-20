extends Node
class_name ReflectionSummonHealth

signal health_changed(current_hp: int, max_hp: int)
signal died

var max_hp: int = 1
var hp: int = 1

func set_max_and_full_heal(new_max: int) -> void:
	max_hp = maxi(new_max, 1)
	hp = max_hp
	health_changed.emit(hp, max_hp)

func take_damage(amount: int, _source: Node = null, _ignore_invuln: bool = false) -> void:
	if amount <= 0 or hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
