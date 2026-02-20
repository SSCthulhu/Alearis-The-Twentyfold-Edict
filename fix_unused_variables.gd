@tool
extends EditorScript

## EditorScript to fix unused variable/parameter warnings
## - Removes unused local variables
## - Prefixes unused parameters with underscore
## 
## HOW TO USE:
## 1. Open this script in Godot Editor
## 2. Click "File" → "Run" (or press Ctrl+Shift+X)
## 3. Check the Output panel for results

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("Starting Unused Variable Cleanup Tool")
	print("=".repeat(60) + "\n")
	
	# Variables to remove (local variables only used in prints)
	var variables_to_remove := [
		# VictoryHUD
		{"file": "res://scripts/ui/VictoryHUD.gd", "line": 182, "var_name": "forced_reward_roll"},
		
		# VFX direction_name variables (used in removed prints)
		{"file": "res://scripts/player/RollVFX.gd", "line": 85, "var_name": "direction_name"},
		{"file": "res://scripts/player/RogueDefensiveSmokeVFX.gd", "line": 80, "var_name": "direction_name"},
		{"file": "res://scripts/player/RogueDefensiveAuraVFX.gd", "line": 91, "var_name": "direction_name"},
		{"file": "res://scripts/player/LightAttackVFX.gd", "line": 119, "var_name": "direction_name"},
		{"file": "res://scripts/player/LightAttackVFX.gd", "line": 57, "var_name": "direction_name"},
		{"file": "res://scripts/player/LandingVFX.gd", "line": 106, "var_name": "direction_name"},
		{"file": "res://scripts/player/JumpVFX.gd", "line": 110, "var_name": "direction_name"},
		{"file": "res://scripts/player/HeavyAttackVFX.gd", "line": 113, "var_name": "direction_name"},
		{"file": "res://scripts/player/DoubleJumpVFX.gd", "line": 110, "var_name": "direction_name"},
		{"file": "res://scripts/player/DefensiveVFX.gd", "line": 105, "var_name": "direction_name"},
		{"file": "res://scripts/player/DashVFX.gd", "line": 135, "var_name": "direction_name"},
		{"file": "res://scripts/player/DashVFX.gd", "line": 77, "var_name": "direction_name"},
		{"file": "res://scripts/player/AirDashVFX.gd", "line": 114, "var_name": "direction_name"},
		{"file": "res://scripts/player/AirDashVFX.gd", "line": 53, "var_name": "direction_name"},
		{"file": "res://scripts/player/KnightLightAttackVFX.gd", "line": 79, "var_name": "direction_name"},
		
		# Jump/location type variables
		{"file": "res://scripts/player/LandingVFX.gd", "line": 109, "var_name": "jump_type"},
		{"file": "res://scripts/player/JumpVFX.gd", "line": 113, "var_name": "jump_type"},
		{"file": "res://scripts/player/JumpVFX.gd", "line": 53, "var_name": "jump_type"},
		{"file": "res://scripts/player/DoubleJumpVFX.gd", "line": 53, "var_name": "jump_type"},
		{"file": "res://scripts/player/DashVFX.gd", "line": 78, "var_name": "location"},
		{"file": "res://scripts/player/AirDashVFX.gd", "line": 54, "var_name": "location"},
		
		# PlayerCombat
		{"file": "res://scripts/player/PlayerCombat.gd", "line": 599, "var_name": "char_name"},
		{"file": "res://scripts/player/PlayerCombat.gd", "line": 373, "var_name": "cd_left"},
		
		# PlayerControllerV3
		{"file": "res://scripts/player/PlayerControllerV3.gd", "line": 1737, "var_name": "char_name"},
		{"file": "res://scripts/player/PlayerControllerV3.gd", "line": 1431, "var_name": "enemies_hit"},
		{"file": "res://scripts/player/PlayerControllerV3.gd", "line": 1397, "var_name": "animation_duration"},
		{"file": "res://scripts/player/PlayerControllerV3.gd", "line": 814, "var_name": "cooldown_left"},
		{"file": "res://scripts/player/PlayerControllerV3.gd", "line": 380, "var_name": "char_name"},
		{"file": "res://scripts/player/PlayerControllerV3.gd", "line": 365, "var_name": "char_name"},
		
		# Other scripts
		{"file": "res://scripts/player/PerfectDodgeDetector.gd", "line": 76, "var_name": "src_name"},
		{"file": "res://scripts/player/PerfectDodgeDetector.gd", "line": 58, "var_name": "source"},
		{"file": "res://scripts/player/PlayerHealth.gd", "line": 322, "var_name": "reduction_pct"},
		{"file": "res://scripts/player/OrbFlightController.gd", "line": 790, "var_name": "avg_fps"},
		{"file": "res://scripts/ui/InteractionPrompt.gd", "line": 180, "var_name": "parent_debug_name"},
		{"file": "res://scripts/ui/InteractionPrompt.gd", "line": 95, "var_name": "parent_groups"},
		{"file": "res://scripts/ui/InteractionPrompt.gd", "line": 94, "var_name": "parent_name"},
		{"file": "res://scripts/ui/DamageNumberEmitter.gd", "line": 120, "var_name": "pos_str"},
		{"file": "res://scripts/enemies/EnemyKnightAdd.gd", "line": 961, "var_name": "hit_distance"},
		{"file": "res://scripts/enemies/EnemyKnightAdd.gd", "line": 804, "var_name": "hitbox_spawn_time"},
		{"file": "res://scripts/enemies/EnemyKnightAdd.gd", "line": 771, "var_name": "attack_start_time"},
		{"file": "res://scripts/enemies/EnemyMeleeHitbox.gd", "line": 172, "var_name": "collision_time"},
		{"file": "res://scripts/enemies/EnemyMeleeHitbox.gd", "line": 140, "var_name": "target_pos"},
		{"file": "res://scripts/enemies/EnemyMeleeHitbox.gd", "line": 139, "var_name": "damage_time"},
		{"file": "res://scripts/enemies/FloorEnemySpawner.gd", "line": 178, "var_name": "regular_count"},
		{"file": "res://scripts/systems/EncounterController.gd", "line": 587, "var_name": "active_name"},
		{"file": "res://scripts/systems/EncounterController.gd", "line": 303, "var_name": "why"},
		{"file": "res://scripts/systems/EncounterController.gd", "line": 297, "var_name": "before"},
		{"file": "res://scripts/hazard/OrbFallingRock.gd", "line": 215, "var_name": "orb_ref"},
		{"file": "res://scripts/player/KnightUltimateVFX.gd", "line": 107, "var_name": "enemy_name"},
	]
	
	# Parameters to prefix with underscore (must keep parameters)
	var parameters_to_prefix := [
		{"file": "res://scripts/player/LightAttackVFX.gd", "line": 55, "param": "combo_step"},
		{"file": "res://scripts/player/KnightLightAttackVFX.gd", "line": 32, "param": "combo_step"},
		{"file": "res://scripts/player/KnightUltimateVFX.gd", "line": 48, "param": "facing_direction"},
		{"file": "res://scripts/player/HeavyAttackVFX.gd", "line": 73, "param": "character_name"},
		{"file": "res://scripts/player/DefensiveVFX.gd", "line": 65, "param": "character_name"},
		{"file": "res://scripts/player/PlayerCombat.gd", "line": 573, "param": "step"},
		{"file": "res://scripts/systems/EncounterController.gd", "line": 964, "param": "idx"},
	]
	
	var total_vars_removed := 0
	var total_params_prefixed := 0
	var files_modified := {}
	
	# Remove unused variables
	for fix in variables_to_remove:
		var result := _remove_variable_line(fix.file, fix.line, fix.var_name)
		if result:
			total_vars_removed += 1
			if not files_modified.has(fix.file):
				files_modified[fix.file] = []
			files_modified[fix.file].append("removed var " + fix.var_name)
	
	# Prefix unused parameters
	for fix in parameters_to_prefix:
		var result := _prefix_parameter(fix.file, fix.line, fix.param)
		if result:
			total_params_prefixed += 1
			if not files_modified.has(fix.file):
				files_modified[fix.file] = []
			files_modified[fix.file].append("prefixed param _" + fix.param)
	
	print("\n" + "=".repeat(60))
	print("SUMMARY:")
	print("  Variables removed: %d" % total_vars_removed)
	print("  Parameters prefixed: %d" % total_params_prefixed)
	print("  Files modified: %d" % files_modified.size())
	print("=".repeat(60))
	
	for file_path in files_modified.keys():
		var changes: Array = files_modified[file_path]
		print("✓ %s: %s" % [file_path.replace("res://scripts/", ""), ", ".join(changes)])
	
	print("\n✅ Complete! Unused variable warnings should be resolved.")

func _remove_variable_line(file_path: String, line_number: int, var_name: String) -> bool:
	"""Remove a specific variable declaration line from a file"""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: %s" % file_path)
		return false
	
	var lines: Array[String] = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	# Remove trailing empty line
	if lines.size() > 0 and lines[-1] == "":
		lines.pop_back()
	
	# Check if the line contains the variable declaration
	if line_number <= lines.size():
		var target_line := lines[line_number - 1]  # Convert to 0-indexed
		
		# Check if this line declares the variable
		if ("var " + var_name) in target_line or ("const " + var_name) in target_line:
			lines.remove_at(line_number - 1)
			
			# Write back
			var write_file := FileAccess.open(file_path, FileAccess.WRITE)
			if write_file == null:
				push_error("Failed to write file: %s" % file_path)
				return false
			
			for i in range(lines.size()):
				write_file.store_line(lines[i])
			write_file.close()
			
			return true
	
	return false

func _prefix_parameter(file_path: String, line_number: int, param_name: String) -> bool:
	"""Prefix a parameter name with underscore to mark it as intentionally unused"""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: %s" % file_path)
		return false
	
	var lines: Array[String] = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	# Remove trailing empty line
	if lines.size() > 0 and lines[-1] == "":
		lines.pop_back()
	
	# Find and replace the parameter in the function signature
	if line_number <= lines.size():
		var target_line := lines[line_number - 1]
		
		# Replace parameter name with underscored version
		# Match patterns like "param_name:" or "param_name," or "param_name)"
		var new_line := target_line.replace(param_name + ":", "_" + param_name + ":")
		new_line = new_line.replace(param_name + ",", "_" + param_name + ",")
		new_line = new_line.replace(param_name + ")", "_" + param_name + ")")
		
		if new_line != target_line:
			lines[line_number - 1] = new_line
			
			# Write back
			var write_file := FileAccess.open(file_path, FileAccess.WRITE)
			if write_file == null:
				push_error("Failed to write file: %s" % file_path)
				return false
			
			for i in range(lines.size()):
				write_file.store_line(lines[i])
			write_file.close()
			
			return true
	
	return false
