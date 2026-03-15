extends "res://scripts/enemies/EnemyKnightAdd.gd"
class_name EnemyRangedBase

# Shared ranged retreat/cast hysteresis.
@export var retreat_cast_buffer: float = 24.0
@export var retreat_pressure_extra: float = 32.0

var _retreat_mode: bool = false

func _ranged_attack_window_open(distance_to_target: float, max_range: float, preferred_dist: float) -> bool:
	if _retreat_mode:
		return false
	if distance_to_target > max_range:
		return false
	if distance_to_target < (preferred_dist + maxf(retreat_cast_buffer, 0.0)):
		return false
	return true

func _ranged_chase_desired_velocity(min_dist: float, preferred_dist: float, max_dist: float, retreat_deadzone: float) -> float:
	if _target == null:
		return 0.0
	if _drop_through_timer > 0.0:
		# While dropping, avoid horizontal churn from kiting logic.
		return 0.0

	var desired_vx: float = _distance_keeping_velocity(_target.global_position, min_dist, preferred_dist, max_dist)
	var dx: float = _target.global_position.x - global_position.x
	var dist: float = absf(dx)
	var pressure_dist: float = maxf(min_dist, preferred_dist + maxf(retreat_pressure_extra, 0.0))
	var retreat_exit_dist: float = pressure_dist + maxf(retreat_deadzone, 24.0)

	if _retreat_mode:
		if dist >= retreat_exit_dist:
			_retreat_mode = false
	else:
		if dist <= pressure_dist:
			_retreat_mode = true

	if _retreat_mode:
		var retreat_dir: float = float(_stable_retreat_dir(dx, 0.24, retreat_deadzone))
		return retreat_dir * move_speed

	# Do not force move-toward for LOS recovery; stop/cast, then retreat again.
	return desired_vx
