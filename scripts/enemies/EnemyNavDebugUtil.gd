extends RefCounted
class_name EnemyNavDebugUtil

static func append_positions(base_line: String, include_positions: bool, enemy_pos: Vector2, target_pos: Vector2) -> String:
	if not include_positions:
		return base_line
	return base_line + " ex=%.1f ey=%.1f px=%.1f py=%.1f" % [
		enemy_pos.x,
		enemy_pos.y,
		target_pos.x,
		target_pos.y
	]

static func format_nav_print(enemy_name: StringName, line: String) -> String:
	return "[EnemyNav:%s] %s" % [String(enemy_name), line]
