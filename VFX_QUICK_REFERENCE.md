# 🎨 VFX Quick Reference

## Active VFX Systems

| VFX Name | Trigger | Location | Signal | Status |
|----------|---------|----------|--------|--------|
| **Landing VFX** | Player lands | Player feet | `landed(was_double_jump, facing_direction)` | ✅ Active (Directional) |
| **Defensive VFX** | Defensive ability used | Player feet | `defensive_activated(character_name, facing_direction)` | ✅ Active (Directional) |
| **Rogue Defensive Smoke VFX** | Rogue defensive ability | Player center (on top) | `defensive_activated(character_name, facing_direction)` | ✅ Active (Rogue only, z_index=10, one-shot) |
| **Rogue Defensive Aura VFX** | Rogue defensive buff duration | Follows player | `defensive_activated(character_name, facing_direction)` | ✅ Active (Rogue only, looping, 10s, opacity=0.35) |
| **Roll VFX** | Player rolls/dodges | Behind player | `roll_started(character_name, facing_direction)` | ✅ Active (Rogue only, z_index=-1, behind player) |
| **Fire Explosion VFX** | Hit by SkeletonMage fireball | Player center | `damage_applied(damage, source)` | ✅ Active (Universal, z_index=10) |
| **Blood Explosion VFX** | Hit by Necromancer blood projectile | Player center | `damage_applied(damage, source)` | ✅ Active (Universal, z_index=10) |
| **Heavy Attack VFX** | Rogue heavy attack | Player center | `heavy_attack_started(character_name, facing_direction)` | ✅ Active (Rogue only, Directional) |
| **Knight Heavy Attack VFX** | Knight heavy attack (AOE spin) | Player center | `heavy_attack_started(character_name, facing_direction)` | ✅ Active (Knight only, Blue spin slash) |
| **Knight Light Attack VFX** | Knight light attack combo | Player center | `light_attack_started(character_name, combo_step, facing_direction)` | ✅ Active (Knight only, Blue flurry slash, Directional) |
| **Light Attack VFX** | Rogue light attack combo | Player center | `light_attack_started(character_name, combo_step, facing_direction)` | ✅ Active (Rogue only, Directional) |
| **Ultimate Attack VFX** | Rogue ultimate hits enemy | Enemy position | `ultimate_attack_hit(character_name, enemy_position, facing_direction)` | ✅ Active (Rogue only, Directional) |
| **Knight Ultimate VFX** | Knight ultimate wave attack | Player center + in front + enemy positions | `knight_ultimate_started(facing_direction)` + `knight_ultimate_hit(enemy_position)` | ✅ Active (Knight only, Sequential Triple VFX: charge/wave/enemy hits, Rotated 90°) |
| **Enemy Hit VFX** | Enemy/boss takes damage | Enemy position | Auto-spawned in `take_damage()` | ✅ Active (Universal) |
| **Dash VFX** | Player dashes/sprints (ground) | Player feet (Y +50) | `dash_started(facing_direction, is_airborne)` + continuous during sprint | ✅ Active (Directional, ground only, continuous while sprinting) |
| **Air Dash VFX** | Player dashes (air) | Player center | `dash_started(facing_direction, is_airborne)` | ✅ Active (Directional, air only) |
| **Jump VFX** | Player jumps (regular) | Player feet | `jump_started(is_double_jump, facing_direction)` | ✅ Active (Directional, regular jumps only) |
| **Double Jump VFX** | Player double jumps | Player feet | `jump_started(is_double_jump, facing_direction)` | ✅ Active (Directional, Rotated 270°) |
| **Perfect Dodge VFX** | Perfect dodge | Above player | `perfect_dodge` | ✅ Active (Toast) |

---

## Quick Add Checklist

When adding new VFX, follow these steps:

### 1️⃣ Create VFX Scene (`scenes/vfx/YourVFX.tscn`)
- Root: `Node2D` with embedded script
- Child: `AnimatedSprite2D` with SpriteFrames
- **Animation name must match script** (e.g., `"your_anim"`)
- **Set `loop: false`** for one-shot VFX
- Set FPS (24-60 typical)
- **⚠️ ALWAYS add `set_facing(direction: int)` method** (standard pattern)

### 2️⃣ Create Manager Script (`scripts/player/YourVFX.gd`)
- Extend `Node`, set `class_name YourVFX`
- Export: `vfx_scene: PackedScene`
- Export: `debug_logs: bool = true` (for testing)
- Connect to signal in `_ready()`
- Spawn VFX in signal handler

### 3️⃣ Add Signal to Source
```gdscript
# In source script (e.g., PlayerControllerV3.gd)
# ⚠️ ALWAYS include facing_direction parameter
signal your_event_name(facing_direction: int, other_params)

# Where event happens:
print("[SourceScript] 📍 Emitting signal (facing=%d)" % _facing_direction)
your_event_name.emit(_facing_direction, other_params)
```

### 4️⃣ **⚠️ Add Manager to player.tscn**
```gdscript
# In player.tscn ext_resource section:
[ext_resource type="Script" path="res://scripts/player/YourVFX.gd" id="XX"]
[ext_resource type="PackedScene" path="res://scenes/vfx/YourVFX.tscn" id="YY"]
# NOTE: Use path-only for new scenes (no UID) until Godot registers them

# In node tree:
[node name="YourVFX" type="Node" parent="."]
script = ExtResource("XX")
vfx_scene = ExtResource("YY")
feet_offset_y = 75.0
debug_logs = true
```

**👉 This is the step most often forgotten!**

**⚠️ UID Tip:** For newly created VFX scenes, use path-only references (no `uid="..."`) in `player.tscn` to avoid "Unrecognized UID" errors. Godot will generate UIDs automatically when scenes are opened/saved.

---

## Common Sprite Sheets

| Name | Frames | Grid | Use Case |
|------|--------|------|----------|
| Land_Wind_White_v1_A | 62 | 8x8 | Landing, ground impact |
| Stab_Hand Drawn_v1_Ground Wind | 16 | 8x2 | Defensive, abilities (feet) |
| Smoke_Burst_White_v7_C | 16 | 4x4 | Rogue defensive burst (center, z_index=10) |
| Smoke_Burst_Loop_White_v7 | 16 | 4x4 | Rogue defensive aura (looping, opacity=0.35) |
| Smoke_Burst_Loop_White_v1 | 16 | 4x4 | Roll/dodge smoke trail (behind player, z_index=-1) |
| Fire_Burst_v5 | 16 | 4x4 | Fire explosion (fireball hit, z_index=10) |
| Blood_Impact_Burst_v2_A | 16 | 4x4 | Blood explosion (blood projectile hit, z_index=10) |
| Blue Lightning Strike v3_B | 16 | 4x4 | Knight ultimate (on player, z_index=10) |
| Blue Lightning Strike v3_D_Bolts Thick | 16 | 4x4 | Knight ultimate wave (in front, rotated 90°) |
| Stab_Hand Drawn_v1 | 16 | 8x2 | Heavy attacks, stabs |
| Lightning Slash v1 - Flurry_A | 56 | 8x7 | Light attack combo (Rogue) |
| Impact_Cut_V2 | 16 | 8x2 | Enemy hit impact |
| Impact_Cut_V4 | 16 | 4x4 | Ultimate attack VFX (Rogue) |
| Fireball_v7 | 16 | 8x2 | SkeletonMage projectile |
| Blood_Projectile_v4_B | 16 | 8x2 | Necromancer projectile |
| Wind_Ground_Alpha_Left_0.5_Burst_A | 14 | 8x2 | Ground dash (directional) |
| Dash_Wind_White_v3 | 16 | 8x2 | Air dash (directional) |
| Dash_Wind_White_v6 | 16 | 8x2 | Regular jump VFX |
| Dash_Wind_White_v7 | 16 | 8x2 | Double jump VFX (rotated 270°) |
| Star_Sparkle_Aura_v1_Loop | ? | ? | Buffs, status effects |

---

## Standard Settings

| Setting | Value | Notes |
|---------|-------|-------|
| **feet_offset_y** | 75.0 | Distance below player center to feet |
| **cooldown** | 0.2-0.5 | Prevent spam |
| **FPS** | 24-60 | Higher = faster animation |
| **Loop** | false | For one-shot effects |
| **debug_logs** | true | Enable during development |
| **flip_h** | true/false | For directional VFX (dash, attacks) |

---

## Debugging

### Expected Console Output:
```
[YourVFX] _ready() called
[YourVFX] ✅ Connected to signal
[SourceScript] 📍 Emitting signal
[YourVFX] 🎯 Signal received!
[YourVFX] ✨ Spawned VFX at (x, y)
```

### If No VFX:
1. ❌ No `_ready()` logs → Manager not in player.tscn
2. ❌ No "Connected" log → Signal name mismatch
3. ❌ No "Emitting" log → Event not triggering
4. ❌ No "Spawned" log → Check VFX scene assignment

---

## File Structure

```
📁 Aleatoris The Twentyfold Edict/
├── 📁 scenes/
│   ├── 📁 player/
│   │   └── player.tscn          ← Add manager nodes here!
│   └── 📁 vfx/
│       ├── LandingVFX.tscn      ← VFX scene
│       ├── DefensiveVFX.tscn    ← VFX scene
│       ├── HeavyAttackVFX.tscn  ← VFX scene
│       ├── LightAttackVFX.tscn  ← VFX scene
│       ├── UltimateAttackVFX.tscn ← VFX scene
│       ├── RogueDefensiveSmokeVFX.tscn ← VFX scene (burst)
│       ├── RogueDefensiveAuraVFX.tscn ← VFX scene (continuous)
│       ├── RollVFX.tscn         ← VFX scene (roll smoke trail)
│       ├── FireExplosionVFX.tscn ← VFX scene (fireball hit)
│       ├── BloodExplosionVFX.tscn ← VFX scene (blood hit)
│       ├── KnightUltimatePlayerVFX.tscn ← VFX scene (Knight ultimate)
│       ├── KnightUltimateWaveVFX.tscn ← VFX scene (Knight wave)
│       ├── KnightUltimateEnemyHitVFX.tscn ← VFX scene (Knight enemy hit)
│       ├── DashVFX.tscn         ← VFX scene
│       ├── AirDashVFX.tscn      ← VFX scene
│       ├── JumpVFX.tscn         ← VFX scene
│       ├── DoubleJumpVFX.tscn   ← VFX scene
│       └── EnemyHitVFX.tscn     ← VFX scene
├── 📁 enemies/
│   ├── SkeletonMageProjectile.tscn  ← Enemy projectile
│   └── NecromancerProjectile.tscn   ← Enemy projectile
├── 📁 scripts/
│   └── 📁 player/
│       ├── PlayerControllerV3.gd ← Add signals here
│       ├── LandingVFX.gd         ← Manager script
│       ├── DefensiveVFX.gd       ← Manager script
│       ├── HeavyAttackVFX.gd     ← Manager script
│       ├── LightAttackVFX.gd     ← Manager script
│       ├── UltimateAttackVFX.gd  ← Manager script
│       ├── RogueDefensiveSmokeVFX.gd ← Manager script (burst)
│       ├── RogueDefensiveAuraVFX.gd ← Manager script (continuous)
│       ├── RollVFX.gd            ← Manager script (roll smoke)
│       ├── ProjectileHitVFX.gd   ← Manager script (projectile explosions)
│       ├── KnightUltimateVFX.gd  ← Manager script (Knight ultimate triple VFX)
│       ├── DashVFX.gd            ← Manager script
│       ├── AirDashVFX.gd         ← Manager script
│       ├── JumpVFX.gd            ← Manager script
│       └── DoubleJumpVFX.gd      ← Manager script
└── 📁 assets/
    └── 📁 VFX/
        └── [Sprite sheets]
```

---

## See Also

- **Full Guide**: `VFX_SETUP_GUIDE.md`
- **Example Systems**: `scripts/player/LandingVFX.gd`, `DefensiveVFX.gd`
