extends Node

func _ready() -> void:
	add_to_group(&"floors")

func get_current_floor_number() -> int:
	return 1

func get_enemies_left_current_floor() -> int:
	return 0

func is_current_floor_complete() -> bool:
	return true

func get_current_floor_fast_clear_time_left() -> float:
	return 0.0

func is_current_floor_fast_clear_active() -> bool:
	return false
