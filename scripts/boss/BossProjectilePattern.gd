extends Resource
class_name BossProjectilePattern

## Defines a pattern for spawning boss projectiles
## Can be configured in the Inspector and reused across attacks

enum PatternType {
	HORIZONTAL_LINE,   # Straight line of projectiles
	RADIAL_BURST,      # Circle of projectiles radiating outward
	CONE,              # Cone-shaped spread toward target
	SPIRAL,            # Rotating spiral pattern
	WAVE,              # Sequential waves
	ARC,               # Arc pattern
	CROSS,             # X-shaped pattern
	RANDOM_SCATTER,    # Random directions
	CUSTOM             # Custom angles array
}

@export var pattern_name: String = "Unnamed Pattern"
@export var pattern_type: PatternType = PatternType.RADIAL_BURST
@export var animation_name: String = ""  # Boss animation to play during this attack

# Projectile configuration
@export var projectile_count: int = 8
@export var projectile_speed: float = 400.0
@export var projectile_damage: int = 15
@export var projectile_color: Color = Color(1.0, 0.2, 0.2, 1.0)  # Visual color for this pattern

# Pattern-specific parameters
@export_group("Radial Burst")
@export var radial_full_circle: bool = true
@export var radial_start_angle: float = 0.0  # Degrees
@export var radial_arc_size: float = 360.0   # Degrees

@export_group("Cone")
@export var cone_spread_angle: float = 60.0  # Total spread in degrees
@export var cone_aim_at_player: bool = true

@export_group("Spiral")
@export var spiral_rotations: float = 2.0
@export var spiral_duration: float = 1.0  # Time to complete spiral

@export_group("Wave")
@export var wave_count: int = 3
@export var wave_delay: float = 0.3  # Seconds between waves

@export_group("Arc")
@export var arc_height: float = 200.0
@export var arc_span: float = 180.0  # Degrees

@export_group("Custom")
@export var custom_angles: Array[float] = []  # Specific angles in degrees

@export_group("Timing")
@export var spawn_delay: float = 0.0  # Delay before spawning starts
@export var sequential_delay: float = 0.0  # Delay between each projectile

## Get projectile spawn data for this pattern
## Returns Array of Dictionaries: [{direction: Vector2, delay: float}, ...]
func get_spawn_data(origin: Vector2, target_position: Vector2 = Vector2.ZERO) -> Array:
	var spawns: Array = []
	
	match pattern_type:
		PatternType.HORIZONTAL_LINE:
			spawns = _generate_horizontal_line(origin)
		PatternType.RADIAL_BURST:
			spawns = _generate_radial_burst(origin)
		PatternType.CONE:
			spawns = _generate_cone(origin, target_position)
		PatternType.SPIRAL:
			spawns = _generate_spiral(origin)
		PatternType.WAVE:
			spawns = _generate_wave(origin, target_position)
		PatternType.ARC:
			spawns = _generate_arc(origin, target_position)
		PatternType.CROSS:
			spawns = _generate_cross(origin)
		PatternType.RANDOM_SCATTER:
			spawns = _generate_random_scatter(origin)
		PatternType.CUSTOM:
			spawns = _generate_custom(origin)
	
	return spawns

func _generate_horizontal_line(_origin: Vector2) -> Array:
	var spawns: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(projectile_count):
		# Randomly fire left or right
		var direction: Vector2 = Vector2.LEFT if rng.randf() < 0.5 else Vector2.RIGHT
		# Randomize vertical offset within a range
		var random_y_offset: float = rng.randf_range(-150.0, 150.0)
		
		spawns.append({
			"direction": direction,
			"delay": spawn_delay + (i * sequential_delay),
			"offset": Vector2(0, random_y_offset)
		})
	
	return spawns

func _generate_radial_burst(_origin: Vector2) -> Array:
	var spawns: Array = []
	var angle_step: float = radial_arc_size / projectile_count
	
	for i in range(projectile_count):
		var angle_deg: float = radial_start_angle + (i * angle_step)
		var angle_rad: float = deg_to_rad(angle_deg)
		var direction: Vector2 = Vector2(cos(angle_rad), sin(angle_rad))
		
		spawns.append({
			"direction": direction,
			"delay": spawn_delay + (i * sequential_delay),
			"offset": Vector2.ZERO
		})
	
	return spawns

func _generate_cone(_origin: Vector2, target_position: Vector2) -> Array:
	var spawns: Array = []
	
	# Calculate base direction
	var base_direction: Vector2 = Vector2.RIGHT
	if cone_aim_at_player and target_position != Vector2.ZERO:
		base_direction = (target_position - _origin).normalized()
	
	var base_angle: float = base_direction.angle()
	var half_spread: float = deg_to_rad(cone_spread_angle / 2.0)
	var angle_step: float = deg_to_rad(cone_spread_angle) / max(projectile_count - 1, 1)
	
	for i in range(projectile_count):
		var offset_angle: float = -half_spread + (i * angle_step)
		var final_angle: float = base_angle + offset_angle
		var direction: Vector2 = Vector2(cos(final_angle), sin(final_angle))
		
		spawns.append({
			"direction": direction,
			"delay": spawn_delay + (i * sequential_delay),
			"offset": Vector2.ZERO
		})
	
	return spawns

func _generate_spiral(_origin: Vector2) -> Array:
	var spawns: Array = []
	var total_angle: float = spiral_rotations * TAU
	var angle_step: float = total_angle / projectile_count
	var time_step: float = spiral_duration / projectile_count
	
	for i in range(projectile_count):
		var angle: float = i * angle_step
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		
		spawns.append({
			"direction": direction,
			"delay": spawn_delay + (i * time_step),
			"offset": Vector2.ZERO
		})
	
	return spawns

func _generate_wave(_origin: Vector2, _target_position: Vector2) -> Array:
	var spawns: Array = []
	var projectiles_per_wave: int = int(projectile_count / float(wave_count))
	
	for wave_idx in range(wave_count):
		var wave_delay_offset: float = wave_idx * wave_delay
		
		for proj_idx in range(projectiles_per_wave):
			var angle_step: float = 360.0 / projectiles_per_wave
			var angle_deg: float = proj_idx * angle_step
			var angle_rad: float = deg_to_rad(angle_deg)
			var direction: Vector2 = Vector2(cos(angle_rad), sin(angle_rad))
			
			spawns.append({
				"direction": direction,
				"delay": spawn_delay + wave_delay_offset + (proj_idx * sequential_delay),
				"offset": Vector2.ZERO
			})
	
	return spawns

func _generate_arc(_origin: Vector2, target_position: Vector2) -> Array:
	var spawns: Array = []
	
	# Calculate direction to target
	var base_direction: Vector2 = Vector2.RIGHT
	if target_position != Vector2.ZERO:
		base_direction = (target_position - _origin).normalized()
	
	var base_angle: float = base_direction.angle()
	var half_span: float = deg_to_rad(arc_span / 2.0)
	var angle_step: float = deg_to_rad(arc_span) / max(projectile_count - 1, 1)
	
	for i in range(projectile_count):
		var offset_angle: float = -half_span + (i * angle_step)
		var final_angle: float = base_angle + offset_angle
		var direction: Vector2 = Vector2(cos(final_angle), sin(final_angle))
		
		spawns.append({
			"direction": direction,
			"delay": spawn_delay + (i * sequential_delay),
			"offset": Vector2.ZERO
		})
	
	return spawns

func _generate_cross(_origin: Vector2) -> Array:
	var spawns: Array = []
	var directions: Array[Vector2] = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()
	]
	
	var count_per_direction: int = int(max(projectile_count / 8.0, 1.0))
	
	for dir in directions:
		for i in range(count_per_direction):
			spawns.append({
				"direction": dir,
				"delay": spawn_delay + (spawns.size() * sequential_delay),
				"offset": Vector2.ZERO
			})
	
	return spawns

func _generate_random_scatter(_origin: Vector2) -> Array:
	var spawns: Array = []
	
	for i in range(projectile_count):
		var random_angle: float = randf() * TAU
		var direction: Vector2 = Vector2(cos(random_angle), sin(random_angle))
		
		spawns.append({
			"direction": direction,
			"delay": spawn_delay + (i * sequential_delay),
			"offset": Vector2.ZERO
		})
	
	return spawns

func _generate_custom(_origin: Vector2) -> Array:
	var spawns: Array = []
	
	for angle_deg in custom_angles:
		var angle_rad: float = deg_to_rad(angle_deg)
		var direction: Vector2 = Vector2(cos(angle_rad), sin(angle_rad))
		
		spawns.append({
			"direction": direction,
			"delay": spawn_delay + (spawns.size() * sequential_delay),
			"offset": Vector2.ZERO
		})
	
	return spawns
