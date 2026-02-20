# Boss Bullet Hell System Documentation

## Overview

A modular projectile attack system for boss fights that allows creating wave-based, pattern-driven attacks.

## Components

### 1. **BossProjectile.gd** - The Projectile
Base projectile with multiple movement types:
- **Straight**: Standard linear movement
- **Homing**: Tracks player for a duration
- **Sine Wave**: Wavy serpentine movement
- **Spiral**: Spirals outward from spawn point

**Exports:**
- `speed`: Movement speed (px/s)
- `lifetime`: How long before auto-destroy (seconds)
- `damage`: Damage dealt to player
- `pierce_count`: 0 = destroy on hit, -1 = infinite pierce
- `movement_type`: Choose from enum

### 2. **BossProjectilePattern.gd** - Pattern Resource
Defines how projectiles spawn in formations.

**Pattern Types:**
- `HORIZONTAL_LINE`: Straight line of projectiles
- `RADIAL_BURST`: Circle spreading outward
- `CONE`: Aimed cone toward player
- `SPIRAL`: Rotating spiral
- `WAVE`: Multiple sequential waves
- `ARC`: Arc-shaped spread
- `CROSS`: X-pattern (8 directions)
- `RANDOM_SCATTER`: Random directions
- `CUSTOM`: Specific angles array

**Key Exports:**
- `pattern_name`: Identifier
- `pattern_type`: Choose from enum
- `projectile_count`: Number of projectiles
- `projectile_speed/damage`: Per-projectile stats
- Pattern-specific parameters (spread angles, wave delays, etc.)

### 3. **BossProjectileAttack.gd** - Attack Manager
Manages spawning patterns and timing.

**Usage:**
```gdscript
# Add to boss scene as child node
var attack_manager: BossProjectileAttack

# Execute by pattern index
attack_manager.execute_attack(0, "Melee_2H_Attack")

# Execute by name
attack_manager.execute_attack_by_name("Spiral Tempest", "Melee_Dualwield_Slash")

# Random attack
attack_manager.execute_random_attack("Melee_2H_Slam")
```

## Setup Instructions

### For World 1 Boss:
1. Open `Boss.tscn` (World 1)
2. Add `BossProjectileAttack` node as child
3. Configure exports:
   - `Boss Path`: `..` (parent)
   - `Projectile Scene`: `res://scenes/boss/BossProjectile.tscn`
   - `Spawn Point Path`: Create a Node2D child for spawn position
   - `Boss Visual Path`: `../BlackKnight3DView`
4. Add pattern resources to `Attack Patterns` array:
   - `world1_horizontal_wave.tres`
   - `world1_radial_burst.tres`

### For World 2 Boss:
1. Same setup as World 1
2. Use more complex patterns:
   - `world2_spiral_attack.tres`
   - `world2_cross_slash.tres`
   - Mix multiple patterns per attack

### Calling from BossController:
```gdscript
# In BossController.gd, add reference
@export var projectile_attack_path: NodePath = ^"BossProjectileAttack"
var _projectile_attack: BossProjectileAttack = null

func _ready():
	_projectile_attack = get_node_or_null(projectile_attack_path)

# Call during attacks
func cast_blade_tempest():
	if _projectile_attack != null:
		_projectile_attack.execute_attack_by_name("Radial Burst", "Melee_2H_Attack")
```

## Creating Custom Patterns

1. Right-click in FileSystem → New Resource
2. Search for `BossProjectilePattern`
3. Configure parameters in Inspector
4. Save in `resources/boss/`
5. Add to boss's `BossProjectileAttack.attack_patterns` array

## Animation Integration

Patterns can trigger animations on the boss 3D model:
- Pass animation name from `large_rig` animations
- Example: `Melee_1H_Slash`, `Melee_2H_Slam`, `Melee_Dualwield_SlashCombo`
- Animation plays when pattern spawns

## Differentiation: World 1 vs World 2

### World 1 (Easier):
- 5-8 projectiles per pattern
- Speed: 300-350 px/s
- Simple patterns (horizontal, radial)
- Clear timing windows
- Damage: 12-15

### World 2 (Harder):
- 16-24 projectiles per pattern
- Speed: 450-500 px/s
- Complex patterns (spiral, cross, waves)
- Overlapping attacks
- Damage: 18-20

## Tips

- Use `spawn_delay` for telegraphing
- Use `sequential_delay` for staggered spawns
- Combine multiple patterns for combos
- Test projectile speeds in-game for balance
- Adjust `collision_mask` if projectiles hit wrong things

## Future Enhancements

- Add visual trails for projectiles
- Projectile explosion effects
- Sound integration
- Screen shake on pattern spawn
- Boss telegraphs (animation signals)
