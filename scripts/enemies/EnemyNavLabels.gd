extends RefCounted
class_name EnemyNavLabels

static func nav_state_name(state: int) -> String:
	match state:
		0:
			return "HOLD"
		1:
			return "CHASE"
		2:
			return "RETREAT"
		3:
			return "ASCEND"
		4:
			return "DESCEND"
	return "UNKNOWN"

static func vertical_action_name(action: int) -> String:
	match action:
		0:
			return "NONE"
		1:
			return "JUMP_UP"
		2:
			return "DROP_THROUGH"
		3:
			return "EDGE_DROP"
	return "UNKNOWN"
