# Enemy Systems Documentation

**Last Updated:** 2026-02-09 (Phase 3 Optimization)
**Status:** Production-Ready, Well-Structured

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Health System](#health-system)
3. [Projectile System](#projectile-system)
4. [3D View System](#3d-view-system)
5. [Enemy AI Hierarchy](#enemy-ai-hierarchy)
6. [Adding New Enemies](#adding-new-enemies)

---

## System Overview

The enemy system is built with a clean inheritance hierarchy and modular components:

```
Enemy Components:
├─ Health (EnemyHealth.gd / GolemHealth.gd)
├─ 3D Visual (Enemy3DView.gd + Enemy3DStage.tscn)
├─ AI (EnemyKnightAdd.gd + specializations)
├─ Projectiles (EnemyProjectile.gd - unified)
└─ Status Effects (EnemyStatusEffects.gd)
```

---

## Health System

### Architecture

```
EnemyHealth.gd (base class)
  └─ GolemHealth.gd (adds ranged immunity)
```

### EnemyHealth.gd

**Purpose:** Standard enemy health with damage tracking and crit support

**Key Features:**
- Max HP and current HP
- Damage signals (legacy, tagged, crit-aware)
- Death signal
- Full heal method

**Signals:**
```gdscript
signal damaged(amount: int)                                   # Legacy
signal damaged_tagged(amount: int, tag: StringName)           # Preferred
signal damaged_tagged_crit(amount: int, tag: StringName, is_crit: bool) # Crit-aware
signal died
```

**Usage:**
```gdscript
# Standard setup
@onready var health: EnemyHealth = $Health
health.died.connect(_on_died)
health.damaged_tagged_crit.connect(_on_damaged)

# Taking damage
health.take_damage(amount, source, tag, is_crit)
```

---

### GolemHealth.gd

**Purpose:** Tank enemy with ranged damage immunity

**Inherits:** EnemyHealth

**Additional Features:**
- Ranged immunity (player must be within melee range)
- Distance-based damage filtering
- Configurable melee range

**Exports:**
```gdscript
@export var melee_damage_range: float = 100.0  # Player distance threshold
```

**How It Works:**
1. Checks if damage source is player or player hitbox
2. Calculates distance between golem and player
3. If distance > `melee_damage_range`, damage is ignored
4. Otherwise, calls `super.take_damage()` normally

**Usage:**
```gdscript
# Setup in Golem scene
@onready var health: GolemHealth = $Health
health.melee_damage_range = 120.0  # Customize range
```

---

## Projectile System

### Architecture (Post-Phase 3 Consolidation)

**Unified System:** All enemy projectiles use `EnemyProjectile.gd`

Previously had duplication:
- ~~NecromancerProjectile.gd~~ (REMOVED in Phase 3)
- EnemyProjectile.gd (UNIFIED)

**Boss projectiles** (`BossProjectile.gd`) remain separate due to complexity.

---

### EnemyProjectile.gd

**Purpose:** Generic enemy projectile with configurable behavior

**Exports:**
```gdscript
@export var speed: float = 600.0
@export var lifetime: float = 5.0
@export var rotate_to_direction: bool = true  # Optional rotation
```

**Key Features:**
- Linear movement
- Multi-hit prevention
- Auto-destroy after lifetime
- Targets player group only
- Configurable rotation

**Initialization:**
```gdscript
func initialize(direction: Vector2, damage: int) -> void
```

**Usage Example (in enemy script):**
```gdscript
# Spawn projectile
var proj: Area2D = projectile_scene.instantiate()
get_tree().current_scene.add_child(proj)
proj.global_position = global_position
if proj.has_method("initialize"):
    proj.call("initialize", direction_to_player, ranged_damage)
```

**Scene Setup:**
```
NecromancerProjectile.tscn (shared by Necromancer & Skeleton Mage)
├─ Area2D (collision_layer: 0, collision_mask: 2)
│   └─ script: EnemyProjectile.gd
├─ CollisionShape2D (RectangleShape2D 24x24)
└─ Visual (ColorRect, purple)
```

---

## 3D View System

### Architecture

```
Enemy3DView.gd (script)
  └─ Manages: SubViewport, 3D model, Camera, Sprite2D output
  
Enemy3DStage.tscn (template)
  ├─ Node3D (root)
  ├─ FacingPivot (Node3D)
  │   └─ [3D Model Instance] (e.g., Skeleton_Warrior)
  ├─ Camera3D (orthographic)
  └─ DirectionalLight3D
```

### Rig Sizes

**Two skeleton rigs:**

1. **Rig_Medium** - Standard size
   - Used by: Skeleton Warrior, Necromancer, Rogue, Mage, Knight (player)
   
2. **Rig_Large** - Large size
   - Used by: Skeleton Golem

### Enemy3DView.gd

**Purpose:** Manages 3D model rendering to 2D sprite via SubViewport

**Key Features:**
- Animation playback (idle, walk, attack, hit, death, etc.)
- Player-facing logic
- SubViewport to Sprite2D pipeline
- Animation looping and one-shots
- Root motion stripping

**Node References:**
```gdscript
@export var sub_vp_path: NodePath = ^"SubViewport"
@export var stage_path: NodePath = ^"SubViewport/Enemy3DStage"
@export var sprite_path: NodePath = ^"Sprite2D"
@export var stage_animation_player_path: NodePath  # Path to model's AnimationPlayer
```

**Animation System:**
```gdscript
# Play looping animation
play_loop(anim_name: StringName)

# Play one-shot animation
play_one_shot(anim_name: StringName, speed_mult: float = 1.0)

# Update facing direction
set_facing_right(is_right: bool)
```

### Adding New Enemy 3D Model

**Step 1:** Duplicate `Enemy3DStage.tscn`
```
scenes/enemies/Enemy3DStage.tscn
  → scenes/enemies/YourEnemy3DStage.tscn
```

**Step 2:** Replace model in FacingPivot
- Delete old Skeleton_Warrior
- Instance your new model (must use Rig_Medium or Rig_Large)

**Step 3:** Create Enemy3DView instance
```
scenes/enemies/YourEnemy3DView.tscn (instance of Enemy3DView.tscn)
├─ Set stage_path to your custom 3DStage
├─ Set stage_animation_player_path to model's AnimationPlayer
└─ Configure viewport size if needed
```

**Step 4:** Reference in enemy scene
```gdscript
@export var visual_3d_path: NodePath = ^"YourEnemy3DView"
```

---

## Enemy AI Hierarchy

### Class Structure

```
CharacterBody2D
  └─ EnemyKnightAdd.gd (base enemy AI)
      ├─ EnemyNecromancer.gd (ranged caster + summoning)
      ├─ EnemyRogueSkeleton.gd (ranged crossbow sniper)
      ├─ EnemySkeletonMage.gd (ranged caster)
      ├─ EnemySkeletonGolem.gd (melee tank)
      └─ EnemyMinionSkeleton.gd (simple melee)
```

---

### EnemyKnightAdd.gd (Base Class)

**Purpose:** Core enemy AI with movement, combat, and patrol

**Key Features:**
- Movement (walking, acceleration, friction)
- Gravity and jumping
- Melee attacks
- Aggro and chase logic
- Patrol behavior
- Edge detection and ledge safety
- Floor activation gating
- Platform awareness
- Contact damage

**Exports (Selected):**
```gdscript
# Movement
@export var move_speed: float = 140.0
@export var accel: float = 1800.0
@export var friction: float = 2200.0

# Combat
@export var attack_cooldown: float = 1.25
@export var attack_damage: int = 12
@export var contact_damage: int = 10

# Behavior
@export var aggro_range: float = 1360.0
@export var patrol_enabled: bool = true
@export var prevent_falling_off_ledges: bool = true
```

**State Machine:**
- Idle → Patrol → Chase → Attack → Return

**Animation Hooks:**
```gdscript
@export var anim_attack: StringName
@export var anim_dead: StringName
@export var anim_hit: StringName
@export var anim_idle: StringName
@export var anim_walk: StringName
# ... etc
```

---

### EnemyNecromancer.gd

**Extends:** EnemyKnightAdd

**Specialization:** Ranged caster with minion summoning

**Additional Features:**
- Summon minions (configurable max count)
- Ranged projectile attacks
- Distance keeping (maintain range from player)
- Cast bar UI
- Dual cast types (summon vs ranged)

**Exports:**
```gdscript
# Summoning
@export var minion_scene: PackedScene
@export var summon_cast_time: float = 3.0
@export var max_minions: int = 1

# Ranged
@export var projectile_scene: PackedScene
@export var ranged_cast_time: float = 2.0
@export var ranged_damage: int = 15

# Distance
@export var preferred_distance: float = 250.0
@export var min_distance: float = 180.0
@export var max_distance: float = 350.0
```

**Behavior:**
1. Spawns with immediate minion summon
2. Maintains distance from player
3. Alternates between summoning and ranged attacks
4. Uses cast bar for telegraphing

---

### EnemyRogueSkeleton.gd

**Extends:** EnemyKnightAdd

**Specialization:** Ranged crossbow sniper

**Additional Features:**
- Aim → Shoot → Reload state machine
- Long-range attacks (900px)
- Distance keeping (sniper behavior)
- No melee attacks

**Exports:**
```gdscript
# Ranged
@export var projectile_scene: PackedScene
@export var aim_time: float = 1.0
@export var reload_time: float = 1.5
@export var ranged_damage: int = 20
@export var ranged_range: float = 900.0

# Sniper distance
@export var preferred_distance: float = 600.0
@export var min_distance: float = 400.0
@export var max_distance: float = 800.0
```

**Behavior:**
1. Maintains long distance from player
2. Aims (plays aim animation)
3. Shoots projectile
4. Reloads (plays reload animation)
5. Cooldown → repeat

---

### EnemySkeletonGolem.gd

**Extends:** EnemyKnightAdd

**Specialization:** Melee tank with high HP and ranged immunity

**Uses:** GolemHealth instead of EnemyHealth

**Key Features:**
- High HP pool
- Slow movement
- Heavy melee damage
- Immune to ranged damage (see GolemHealth)

---

### EnemyMinionSkeleton.gd

**Extends:** EnemyKnightAdd

**Specialization:** Simple melee enemy, summoned by Necromancer

**Key Features:**
- Low HP
- Basic melee attacks
- No special abilities

---

## Adding New Enemies

### Quick Start Checklist

**1. Choose Base Class:**
- Melee enemy? Extend `EnemyKnightAdd`
- Need ranged attacks? Reference `EnemyNecromancer` or `EnemyRogueSkeleton`
- Need special health logic? Extend `EnemyHealth` (see `GolemHealth` example)

**2. Create 3D View:**
- Duplicate `Enemy3DStage.tscn`
- Replace model (respect Rig_Medium or Rig_Large)
- Create `YourEnemy3DView.tscn`
- Set `stage_animation_player_path`

**3. Create Enemy Script:**
```gdscript
extends EnemyKnightAdd
class_name EnemyYourEnemy

# Override animations
func _ready() -> void:
    anim_idle = &"YourRig/YourIdleAnim"
    anim_walk = &"YourRig/YourWalkAnim"
    # ... etc
    super._ready()

# Add custom behavior
func _physics_process(delta: float) -> void:
    # Your logic here
    super._physics_process(delta)
```

**4. Create Enemy Scene:**
```
EnemyYourEnemy.tscn
├─ CharacterBody2D (script: EnemyYourEnemy.gd)
├─ CollisionShape2D
├─ Health (EnemyHealth or GolemHealth)
├─ YourEnemy3DView
├─ Hurtbox (Area2D)
├─ DamageNumberEmitter
└─ EnemyRunScaler
```

**5. Test:**
- Spawn in test scene
- Verify movement, combat, animations
- Test aggro/patrol behavior

---

## Best Practices

### Health System
✅ **Use EnemyHealth** for standard enemies
✅ **Extend EnemyHealth** for special damage logic (see GolemHealth)
❌ **Don't duplicate** EnemyHealth - use inheritance

### Projectiles
✅ **Use EnemyProjectile** for all enemy projectiles
✅ **Set rotate_to_direction** based on your visual needs
❌ **Don't create** new projectile classes - configure existing one

### 3D View
✅ **Duplicate Enemy3DStage.tscn** for new models
✅ **Respect rig sizes** (Rig_Medium vs Rig_Large)
✅ **Set stage_animation_player_path** correctly
❌ **Don't modify** Enemy3DView.gd - it's generic

### AI
✅ **Extend EnemyKnightAdd** for new enemy types
✅ **Override animations** in _ready()
✅ **Call super methods** to preserve base behavior
❌ **Don't duplicate** movement/jump/patrol logic

---

## Performance Notes

- **Enemy3DView:** Uses SubViewport per enemy (moderate cost)
- **Projectiles:** Lightweight, auto-destroy after lifetime
- **Health:** No physics, minimal overhead
- **AI:** CharacterBody2D with physics, most expensive component

**Optimization Tips:**
- Limit active enemies on screen
- Use floor activation gating for distant enemies
- Reduce SubViewport resolution if needed
- Pool projectiles if spawning many simultaneously

---

## Changelog

### Phase 3 (2026-02-09)
- **UNIFIED** projectile system (removed NecromancerProjectile.gd duplication)
- **ADDED** `rotate_to_direction` export to EnemyProjectile
- **DOCUMENTED** all enemy systems comprehensively

### Pre-Phase 3
- Initial enemy system implementation
- Health hierarchy (EnemyHealth ← GolemHealth)
- 3D view system with rig support
- AI inheritance (EnemyKnightAdd + specializations)
