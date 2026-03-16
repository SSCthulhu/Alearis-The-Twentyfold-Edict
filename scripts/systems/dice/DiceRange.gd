extends RefCounted
class_name DiceRange

var min_roll: int = 1
var max_roll: int = 20

func _init(min_roll_value: int = 1, max_roll_value: int = 20) -> void:
	min_roll = clampi(mini(min_roll_value, max_roll_value), 1, 20)
	max_roll = clampi(maxi(min_roll_value, max_roll_value), 1, 20)

func width() -> int:
	return max_roll - min_roll

func midpoint() -> float:
	return (float(min_roll) + float(max_roll)) * 0.5

func is_valid() -> bool:
	return min_roll >= 1 and max_roll <= 20 and min_roll <= max_roll
