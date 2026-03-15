extends RefCounted
class_name EnemyFloorQueryUtil

static func floor_delta_from_hits(my_floor_hit: Dictionary, target_floor_hit: Dictionary) -> Dictionary:
	if my_floor_hit.is_empty() or target_floor_hit.is_empty():
		return {"valid": false, "delta": 0.0}
	var my_floor_y: float = (my_floor_hit["position"] as Vector2).y
	var target_floor_y: float = (target_floor_hit["position"] as Vector2).y
	return {"valid": true, "delta": target_floor_y - my_floor_y}

static func has_min_delta_below(my_floor_hit: Dictionary, target_floor_hit: Dictionary, min_delta: float) -> bool:
	var info: Dictionary = floor_delta_from_hits(my_floor_hit, target_floor_hit)
	if not bool(info.get("valid", false)):
		return false
	return float(info.get("delta", 0.0)) >= min_delta

static func has_min_delta_above(my_floor_hit: Dictionary, target_floor_hit: Dictionary, min_delta: float) -> bool:
	var info: Dictionary = floor_delta_from_hits(my_floor_hit, target_floor_hit)
	if not bool(info.get("valid", false)):
		return false
	return -float(info.get("delta", 0.0)) >= min_delta

static func is_small_step_between_hits(
	my_floor_hit: Dictionary,
	target_floor_hit: Dictionary,
	min_height: float,
	max_height: float
) -> bool:
	var info: Dictionary = floor_delta_from_hits(my_floor_hit, target_floor_hit)
	if not bool(info.get("valid", false)):
		return false
	var floor_delta_abs: float = absf(float(info.get("delta", 0.0)))
	return floor_delta_abs >= maxf(min_height, 6.0) and floor_delta_abs <= maxf(max_height, min_height)
