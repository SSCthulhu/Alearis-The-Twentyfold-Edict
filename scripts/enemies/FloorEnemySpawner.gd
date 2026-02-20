# res://scripts/FloorEnemySpawner.gd
extends Node
class_name FloorEnemySpawner

# ✅ NEW: Support multiple enemy types for randomization
@export var enemy_scenes: Array[PackedScene] = []    # Add multiple enemy types here
@export var enemy_scene: PackedScene                 # Legacy: single enemy (for backward compatibility)

# ✅ Elite spawning (Golem replacement)
@export var golem_scene: PackedScene                 # Skeleton Golem scene for elite spawns

@export var spawns_root_path: NodePath = ^"../Arena/Spawns"

# How many enemies to spawn per floor (floors 1-4)
@export var enemies_per_floor: Array[int] = [2, 3, 4, 5]

# Groups must match FloorProgressionController
@export var floor_enemy_groups: Array[StringName] = [
	&"floor1_enemies",
	&"floor2_enemies",
	&"floor3_enemies",
	&"floor4_enemies",
]

@export var spawn_all_on_ready: bool = false  # ✅ CHANGED: Must be false for elite spawning to work
@export var debug_spawning: bool = false  # ✅ NEW: Enable debug logs for spawning

# Optional: parent node to hold spawned enemies (keeps tree tidy)
@export var enemy_parent_path: NodePath = ^"../Arena"

# Floor activation mode (must match world type)
@export_enum("Vertical (Y-axis)", "Horizontal (X-axis)") var floor_activation_mode: int = 0  # 0 = vertical (World1/World2), 1 = horizontal (World3)

# Enable strict ledge guarding (prevents enemies from jumping off ledges)
@export var enable_strict_ledge_guard: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawned_floors: Array[bool] = [false, false, false, false]  # ✅ Track which floors have spawned

func _ready() -> void:
	_rng.randomize()

	# ✅ Floor 1 always spawns on ready (no modifier chosen yet)
	if spawn_all_on_ready:
		call_deferred("_spawn_all_floors_deferred")
	else:
		# Spawn only Floor 1 initially
		call_deferred("_spawn_floor_deferred", 0)

func _spawn_all_floors_deferred() -> void:
	spawn_all_floors()

func _spawn_floor_deferred(floor_index: int) -> void:
	spawn_floor(floor_index)

func spawn_all_floors() -> void:
	for floor_index in range(min(4, floor_enemy_groups.size())):
		spawn_floor(floor_index)

# ✅ NEW: Called by FloorProgressionController when modifier is chosen
func spawn_next_floor(current_floor_index: int) -> void:
	var next_floor: int = current_floor_index + 1
	if next_floor < 4 and not _spawned_floors[next_floor]:
		if debug_spawning:
			pass
		spawn_floor(next_floor)

func spawn_floor(floor_index: int) -> void:
	# ✅ Prevent double-spawning
	if _spawned_floors[floor_index]:
		if debug_spawning:
			pass
		return
	
	_spawned_floors[floor_index] = true
	
	if debug_spawning:
		pass
	
	# ✅ Build enemy pool from either enemy_scenes array or legacy enemy_scene
	var enemy_pool: Array[PackedScene] = []
	if not enemy_scenes.is_empty():
		enemy_pool = enemy_scenes
	elif enemy_scene != null:
		enemy_pool = [enemy_scene]
	
	if enemy_pool.is_empty():
		push_warning("[Spawner] No enemy scenes assigned. Set Enemy Scenes array in inspector.")
		return

	var spawns_root: Node = get_node_or_null(spawns_root_path)
	if spawns_root == null:
		push_warning("[Spawner] Spawns root NOT found at path: %s (Spawner node: %s)" % [str(spawns_root_path), get_path()])
		push_warning("[Spawner] Fix: set Spawns Root Path using the NodePath picker (likely ../Arena/Spawns).")
		return

	var floor_node_name := "Floor%s" % str(floor_index + 1)
	var floor_node: Node = spawns_root.get_node_or_null(floor_node_name)
	if floor_node == null:
		push_warning("[Spawner] Missing spawn folder: %s (expected under %s)" % [floor_node_name, spawns_root.get_path()])
		return

	# Collect Marker2D spawn points (exclude player/special spawns)
	var points: Array[Marker2D] = []
	var excluded_names: Array[String] = ["PlayerSpawn", "OrbFinishMarker"]
	for child in floor_node.get_children():
		var m := child as Marker2D
		if m != null and not excluded_names.has(m.name):
			points.append(m)

	if points.is_empty():
		push_warning("[Spawner] No Marker2D spawn points under: %s" % floor_node.get_path())
		return

	points.shuffle()

	var desired: int = 1
	if floor_index < enemies_per_floor.size():
		desired = max(1, enemies_per_floor[floor_index])

	var count_to_spawn: int = min(desired, points.size())
	var group_name: StringName = floor_enemy_groups[floor_index]

	var enemy_parent: Node = get_node_or_null(enemy_parent_path)
	if enemy_parent == null:
		enemy_parent = get_tree().current_scene

	# ✅ Elite spawning: Check if modifier requires Golem replacement
	var elites_to_spawn: int = 0
	if RunStateSingleton != null and "elites_to_spawn_bonus" in RunStateSingleton:
		elites_to_spawn = int(RunStateSingleton.elites_to_spawn_bonus)
		if debug_spawning:
			pass
	else:
		if debug_spawning:
			pass
	
	# Clamp elites to not exceed total spawn count
	elites_to_spawn = mini(elites_to_spawn, count_to_spawn)
	
	if debug_spawning:
		pass
	
	# Randomly select which spawn indices will be Golems
	var golem_indices: Array[int] = []
	if elites_to_spawn > 0 and golem_scene != null:
		var available_indices: Array[int] = []
		for i in range(count_to_spawn):
			available_indices.append(i)
		available_indices.shuffle()
		
		for i in range(elites_to_spawn):
			golem_indices.append(available_indices[i])
		
		if debug_spawning:
			pass
	elif elites_to_spawn > 0 and golem_scene == null:
		if debug_spawning:
			pass
	
	# Spawn enemies (some will be Golems if elites_to_spawn > 0)
	for i in range(count_to_spawn):
		var spawn_pos: Vector2 = points[i].global_position
		
		if golem_indices.has(i):
			# Spawn Golem at this position
			_spawn_golem_now(enemy_parent, spawn_pos, group_name)
		else:
			# Spawn regular enemy
			_spawn_enemy_now(enemy_parent, spawn_pos, group_name, enemy_pool)
	
	# ✅ Consume elite modifier after spawning
	if elites_to_spawn > 0 and RunStateSingleton != null:
		RunStateSingleton.elites_to_spawn_bonus = 0
		if debug_spawning:
			pass
	
	var _regular_count: int = count_to_spawn - elites_to_spawn
	if debug_spawning:
		pass

func _spawn_enemy_now(parent: Node, spawn_pos: Vector2, group_name: StringName, enemy_pool: Array[PackedScene]) -> void:
	if parent == null or enemy_pool.is_empty():
		return

	# ✅ Randomly pick an enemy type from the pool
	var random_scene: PackedScene = enemy_pool[_rng.randi_range(0, enemy_pool.size() - 1)]
	if random_scene == null:
		push_warning("[Spawner] Null enemy scene in pool, skipping spawn.")
		return
	
	var enemy_node: Node = random_scene.instantiate()
	var enemy_2d: Node2D = enemy_node as Node2D
	if enemy_2d == null:
		push_warning("[Spawner] Enemy scene root must be Node2D/CharacterBody2D. Got: %s" % enemy_node.get_class())
		enemy_node.queue_free()
		return

	# IMPORTANT:
	# Add child + set position immediately so EnemyKnightAdd._ready() sees the correct global_position
	parent.add_child(enemy_2d)
	enemy_2d.global_position = spawn_pos
	enemy_2d.add_to_group(group_name)

	# -----------------------------
	# Floor activation setup
	# -----------------------------
	enemy_2d.set("use_floor_activation", true)
	enemy_2d.set("floor_activation_mode", floor_activation_mode)
	
	# Enable strict ledge guarding if configured (applies to all worlds)
	if enable_strict_ledge_guard:
		enemy_2d.set("strict_ledge_guard", true)
		if debug_spawning:
			pass
	
	if floor_activation_mode == 1:  # Horizontal (X-axis) mode for World3
		var activation_x: float = -999999.0  # floor 1 default (always active)
		match group_name:
			&"floor2_enemies":
				activation_x = 3500.0  # Start of Floor 2
			&"floor3_enemies":
				activation_x = 9300.0  # Start of Floor 3
			&"floor4_enemies":
				activation_x = 16300.0  # Start of Floor 4
		enemy_2d.set("floor_activation_x", activation_x)
		
		# World3 specific: Apply skeleton_texture_B variant
		if enemy_2d.has_node("Enemy3DView"):
			var view_3d = enemy_2d.get_node("Enemy3DView")
			if view_3d != null and view_3d.has_method("set_model_texture"):
				view_3d.call_deferred("set_model_texture", "res://assets/textures/skeleton_texture_B.png")
				if debug_spawning:
					pass
	else:  # Vertical (Y-axis) mode for World1/World2
		var activation_y: float = 999999.0  # floor 1 default (always active)
		match group_name:
			&"floor2_enemies":
				activation_y = 200.0
			&"floor3_enemies":
				activation_y = -900.0
			&"floor4_enemies":
				activation_y = -1925.0
		enemy_2d.set("floor_activation_y", activation_y)

# ✅ Spawn a Golem at the specified position
func _spawn_golem_now(parent: Node, spawn_pos: Vector2, group_name: StringName) -> void:
	if parent == null:
		return
	if golem_scene == null:
		push_warning("[Spawner] Golem scene not assigned. Cannot spawn elite.")
		return
	
	var golem_node: Node = golem_scene.instantiate()
	var golem_2d: Node2D = golem_node as Node2D
	if golem_2d == null:
		push_warning("[Spawner] Golem scene root must be Node2D/CharacterBody2D. Got: %s" % golem_node.get_class())
		golem_node.queue_free()
		return
	
	# Add child + set position immediately
	parent.add_child(golem_2d)
	golem_2d.global_position = spawn_pos
	golem_2d.add_to_group(group_name)
	golem_2d.add_to_group(&"elites")  # Mark as elite for future use (e.g., UI indicators)
	
	# Floor activation setup
	golem_2d.set("use_floor_activation", true)
	golem_2d.set("floor_activation_mode", floor_activation_mode)
	
	# Enable strict ledge guarding if configured
	if enable_strict_ledge_guard:
		golem_2d.set("strict_ledge_guard", true)
		if debug_spawning:
			pass
	
	if floor_activation_mode == 1:  # Horizontal (X-axis) mode for World3
		var activation_x: float = -999999.0  # floor 1 default (always active)
		match group_name:
			&"floor2_enemies":
				activation_x = 3500.0  # Start of Floor 2
			&"floor3_enemies":
				activation_x = 9300.0  # Start of Floor 3
			&"floor4_enemies":
				activation_x = 16300.0  # Start of Floor 4
		golem_2d.set("floor_activation_x", activation_x)
		
		# World3 specific: Apply skeleton_texture_B variant
		if golem_2d.has_node("Enemy3DView"):
			var view_3d = golem_2d.get_node("Enemy3DView")
			if view_3d != null and view_3d.has_method("set_model_texture"):
				view_3d.call_deferred("set_model_texture", "res://assets/textures/skeleton_texture_B.png")
				if debug_spawning:
					pass
	else:  # Vertical (Y-axis) mode for World1/World2
		var activation_y: float = 999999.0  # floor 1 default (always active)
		match group_name:
			&"floor2_enemies":
				activation_y = 200.0
			&"floor3_enemies":
				activation_y = -900.0
			&"floor4_enemies":
				activation_y = -1925.0
		golem_2d.set("floor_activation_y", activation_y)
	
	pass
