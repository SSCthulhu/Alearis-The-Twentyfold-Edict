extends RefCounted
class_name EnemyTraversalScoring

static func choose_action(
	score_jump_up: float,
	score_drop_through: float,
	score_edge_drop: float,
	jump_up_action: int,
	drop_through_action: int,
	edge_drop_action: int,
	reason_code: String
) -> Dictionary:
	var result: Dictionary = {
		"action": 0,
		"reason": reason_code
	}

	if score_jump_up >= score_drop_through and score_jump_up >= score_edge_drop and score_jump_up > 0.0:
		result["action"] = jump_up_action
		result["reason"] = "jump_up"
		return result
	if score_drop_through >= score_edge_drop and score_drop_through > 0.0:
		result["action"] = drop_through_action
		result["reason"] = "drop_through"
		return result
	if score_edge_drop > 0.0:
		result["action"] = edge_drop_action
		result["reason"] = "edge_drop"
		return result

	return result
