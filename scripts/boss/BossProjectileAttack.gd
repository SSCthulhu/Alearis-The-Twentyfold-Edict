extends Node
class_name BossProjectileAttack

## Manages boss projectile attacks
## Spawns projectiles based on patterns and links to animations

signal attack_started(attack_name: String)
signal attack_completed(attack_name: String)
signal pattern_spawned(pattern_name: String, projectile_count: int)

@export var boss_path: NodePath = ^".."
@export var projectile_scene: PackedScene
@export var spawn_point_path: NodePath = ^"../ProjectileSpawnPoint"

# Attack configuration
@export var attack_enabled: bool = true
@export var attack_patterns: Array[BossProjectilePattern] = []

# Visual integration
@export var boss_visual_path: NodePath = ^"../BlackKnight3DView"
@export var play_animation_on_attack: bool = true

var _boss: Node2D = null
var _spawn_point: Node2D = null
var _boss_visual: Node = null
var _attack_in_progress: bool = false

func _ready() -> void:
	_boss = get_node_or_null(boss_path) as Node2D
	if _boss == null:
		push_error("[BossProjectileAttack] Boss node not found at: %s" % boss_path)
		return
	
	_spawn_point = get_node_or_null(spawn_point_path) as Node2D
	if _spawn_point == null:
		# Use boss position as fallback
		_spawn_point = _boss
		push_warning("[BossProjectileAttack] Spawn point not found, using boss position")
	
	_boss_visual = get_node_or_null(boss_visual_path)
	if _boss_visual == null and play_animation_on_attack:
		push_warning("[BossProjectileAttack] Boss visual not found for animations")

## Execute a projectile attack by pattern index
func execute_attack(pattern_index: int, animation_name: String = "") -> bool:
	if not attack_enabled:
		return false
	if _attack_in_progress:
		return false
	if pattern_index < 0 or pattern_index >= attack_patterns.size():
		push_error("[BossProjectileAttack] Invalid pattern index: %d" % pattern_index)
		return false
	
	var pattern: BossProjectilePattern = attack_patterns[pattern_index]
	if pattern == null:
		push_error("[BossProjectileAttack] Pattern at index %d is null" % pattern_index)
		return false
	
	_execute_pattern(pattern, animation_name)
	return true

## Execute attack by pattern name
func execute_attack_by_name(pattern_name: String, animation_name: String = "") -> bool:
	for i in range(attack_patterns.size()):
		var pattern: BossProjectilePattern = attack_patterns[i]
		if pattern != null and pattern.pattern_name == pattern_name:
			return execute_attack(i, animation_name)
	
	push_warning("[BossProjectileAttack] Pattern not found: %s" % pattern_name)
	return false

## Execute a random pattern
func execute_random_attack(animation_name: String = "") -> bool:
	if attack_patterns.size() == 0:
		return false
	
	var random_index: int = randi() % attack_patterns.size()
	return execute_attack(random_index, animation_name)

func _execute_pattern(pattern: BossProjectilePattern, animation_name: String) -> void:
	_attack_in_progress = true
	attack_started.emit(pattern.pattern_name)
	
	# Use pattern's animation if none explicitly provided
	var anim_to_play: String = animation_name if animation_name != "" else pattern.animation_name
	
	# Get spawn data
	var player: Node2D = _get_player()
	var target_pos: Vector2 = player.global_position if player != null else Vector2.ZERO
	var origin: Vector2 = _spawn_point.global_position if _spawn_point != null else _boss.global_position
	
	var spawn_data: Array = pattern.get_spawn_data(origin, target_pos)
	
	pass
	
	# Determine if we should play animation per projectile (for patterns with sequential spawns)
	var play_per_projectile: bool = pattern.sequential_delay > 0.0 and pattern.pattern_name == "Horizontal Wave"
	
	# Enable manual facing control for directional attacks
	if play_per_projectile and _boss != null and _boss.has_method("set_manual_facing_control"):
		_boss.call("set_manual_facing_control", true)
	
	# Play animation once if not playing per projectile
	if not play_per_projectile and play_animation_on_attack and anim_to_play != "" and _boss_visual != null:
		_play_boss_animation(anim_to_play, 1.0)
	
	# Schedule projectile spawns
	for data in spawn_data:
		var spawn_info: Dictionary = data as Dictionary
		if spawn_info.has("delay") and spawn_info["delay"] > 0.0:
			# Delayed spawn
			get_tree().create_timer(spawn_info["delay"]).timeout.connect(
				func() -> void:
					# Set boss facing based on projectile direction
					if _boss_visual != null and _boss_visual.has_method("set_facing"):
						var dir_x: int = 1 if spawn_info["direction"].x >= 0 else -1
						_boss_visual.call("set_facing", dir_x)
					
					# Play animation per projectile if configured
					if play_per_projectile and play_animation_on_attack and anim_to_play != "" and _boss_visual != null:
						_play_boss_animation(anim_to_play, 8.0)  # Speed up to 8x for snappy punches
					_spawn_projectile(
						spawn_info["direction"],
						spawn_info.get("offset", Vector2.ZERO),
						pattern.projectile_speed,
						pattern.projectile_damage,
						pattern.projectile_color
					)
			)
		else:
			# Immediate spawn
			# Set boss facing based on projectile direction
			if _boss_visual != null and _boss_visual.has_method("set_facing"):
				var dir_x: int = 1 if spawn_info["direction"].x >= 0 else -1
				_boss_visual.call("set_facing", dir_x)
			
			if play_per_projectile and play_animation_on_attack and anim_to_play != "" and _boss_visual != null:
				_play_boss_animation(anim_to_play, 8.0)  # Speed up to 8x for snappy punches
			_spawn_projectile(
				spawn_info["direction"],
				spawn_info.get("offset", Vector2.ZERO),
				pattern.projectile_speed,
				pattern.projectile_damage,
				pattern.projectile_color
			)
	
	pattern_spawned.emit(pattern.pattern_name, spawn_data.size())
	
	# Calculate total attack duration and schedule completion
	var max_delay: float = 0.0
	for data in spawn_data:
		var spawn_info: Dictionary = data as Dictionary
		if spawn_info.has("delay"):
			max_delay = maxf(max_delay, spawn_info["delay"])
	
	get_tree().create_timer(max_delay + 0.5).timeout.connect(
		func() -> void:
			_attack_in_progress = false
			attack_completed.emit(pattern.pattern_name)
			pass
			
			# Re-enable automatic facing after attack completes
			if _boss != null and _boss.has_method("set_manual_facing_control"):
				_boss.call("set_manual_facing_control", false)
	)

func _spawn_projectile(direction: Vector2, offset: Vector2, speed: float, damage: int, color: Color = Color(1.0, 0.2, 0.2, 1.0)) -> void:
	if projectile_scene == null:
		push_error("[BossProjectileAttack] No projectile scene assigned!")
		return
	
	var projectile: Node = projectile_scene.instantiate()
	if projectile == null:
		push_error("[BossProjectileAttack] Failed to instantiate projectile")
		return
	
	# Add to scene
	get_tree().current_scene.add_child(projectile)
	
	# Position projectile with random scatter
	var spawn_pos: Vector2 = _spawn_point.global_position if _spawn_point != null else _boss.global_position
	
	# Add random scatter perpendicular to direction (creates "lane" scatter)
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)  # 90 degree rotation
	var scatter_amount: float = randf_range(-80.0, 80.0)  # Random offset within lane
	var scatter_offset: Vector2 = perpendicular * scatter_amount
	
	projectile.global_position = spawn_pos + offset + scatter_offset
	
	# Initialize projectile
	if projectile.has_method("initialize"):
		projectile.call("initialize", direction, damage, speed)
	
	# Set projectile color
	if projectile.has_method("set_color"):
		projectile.call("set_color", color)
	
	# Set player as homing target if projectile supports it
	var player: Node2D = _get_player()
	if player != null and projectile.has_method("set_target"):
		projectile.call("set_target", player)

func _play_boss_animation(anim_name: String, speed: float = 1.0) -> void:
	if _boss_visual == null:
		push_warning("[BossProjectileAttack] Boss visual is null, can't play animation: %s" % anim_name)
		return
	
	pass
	
	# Try to find and play animation
	if _boss_visual.has_method("play_one_shot"):
		_boss_visual.call("play_one_shot", anim_name, true, speed)
		pass
	elif _boss_visual.has_method("play_animation"):
		_boss_visual.call("play_animation", anim_name)
		pass
	else:
		push_warning("[BossProjectileAttack] Boss visual doesn't support animation playback")

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

## Clear all active projectile timers (for boss death/phase transition)
func cancel_all_attacks() -> void:
	_attack_in_progress = false
	# Note: Can't cancel already-scheduled timers, but new attacks won't start
	pass
