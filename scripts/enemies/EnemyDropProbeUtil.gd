extends RefCounted
class_name EnemyDropProbeUtil

static func raycast_landing_below(
	space_state: PhysicsDirectSpaceState2D,
	owner: CollisionObject2D,
	world_mask: int,
	from: Vector2,
	max_distance: float,
	exclude_collider: Variant = null
) -> Dictionary:
	var to: Vector2 = from + Vector2(0.0, maxf(max_distance, 1.0))
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [owner]
	if exclude_collider is CollisionObject2D:
		params.exclude.append(exclude_collider)
	params.collision_mask = world_mask
	return space_state.intersect_ray(params)

static func is_drop_distance_safe(
	drop_distance: float,
	min_drop_distance: float,
	max_drop_distance: float,
	max_safe_landing_delta: float
) -> bool:
	if drop_distance < min_drop_distance:
		return false
	if drop_distance > max_drop_distance:
		return false
	if drop_distance > maxf(max_safe_landing_delta, 24.0):
		return false
	return true
