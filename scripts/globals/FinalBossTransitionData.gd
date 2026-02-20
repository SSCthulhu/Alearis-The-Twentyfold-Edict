extends Node

# Global singleton to store final boss selection across scene changes
# This persists when changing from World3 to FinalWorld

var dice_result: int = -1
var has_data: bool = false

# Boss scene mapping based on dice result
var boss_scene_map: Dictionary = {
	1: "res://scenes/boss/FinalBoss_A.tscn",
	2: "res://scenes/boss/FinalBoss_B.tscn",
	3: "res://scenes/boss/FinalBoss_B.tscn",
	4: "res://scenes/boss/FinalBoss_B.tscn",
	5: "res://scenes/boss/FinalBoss_B.tscn",
	6: "res://scenes/boss/FinalBoss_B.tscn",
	7: "res://scenes/boss/FinalBoss_B.tscn",
	8: "res://scenes/boss/FinalBoss_C.tscn",
	9: "res://scenes/boss/FinalBoss_C.tscn",
	10: "res://scenes/boss/FinalBoss_C.tscn",
	11: "res://scenes/boss/FinalBoss_C.tscn",
	12: "res://scenes/boss/FinalBoss_C.tscn",
	13: "res://scenes/boss/FinalBoss_C.tscn",
	14: "res://scenes/boss/FinalBoss_D.tscn",
	15: "res://scenes/boss/FinalBoss_D.tscn",
	16: "res://scenes/boss/FinalBoss_D.tscn",
	17: "res://scenes/boss/FinalBoss_D.tscn",
	18: "res://scenes/boss/FinalBoss_D.tscn",
	19: "res://scenes/boss/FinalBoss_D.tscn",
	20: "res://scenes/boss/FinalBoss_E.tscn"
}

func set_boss_selection(result: int) -> void:
	"""Store dice result before transitioning to FinalWorld"""
	dice_result = result
	has_data = true
	pass

func get_boss_scene_path(result: int = -1) -> String:
	"""Get the boss scene path for a dice result"""
	var r := result if result >= 0 else dice_result
	
	if boss_scene_map.has(r):
		return boss_scene_map[r]
	
	# Fallback
	push_warning("[FinalBossTransitionData] No boss mapping for result %d, defaulting to FinalBoss_B" % r)
	return "res://scenes/boss/FinalBoss_B.tscn"

func clear_data() -> void:
	"""Clear transition data after use"""
	dice_result = -1
	has_data = false
	pass
