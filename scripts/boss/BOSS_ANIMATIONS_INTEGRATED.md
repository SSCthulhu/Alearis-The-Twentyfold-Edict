# Boss Animation Integration - Projectile Attacks

## Overview
Integrated BlackKnight boss animations to play during projectile attacks, making the boss visually respond to each attack pattern.

## Available BlackKnight Animations

### Combat Animations (Used for Projectile Attacks)
- `KAnim/Melee_2H_Slash` (1.57s) - Fast slashing attack
- `KAnim/Melee_2H_Attack` (1.33s) - Sweeping attack motion
- `KAnim/Melee_2H_Slam` (2.83s) - Heavy overhead slam
- `KAnim/Melee_1H_Slash` (1.57s) - One-handed slash
- `KAnim/Melee_1H_Stab` (1.40s) - Stabbing motion

### Other Available Animations
- `KAnim/Idle_A` (1.97s) - Standard idle pose
- `KAnim/Idle_B` (6.00s) - Alternate idle
- `KAnim/Melee_2H_Idle` (1.57s) - Ready stance with weapon
- `KAnim/Hit_A` (0.70s) - Taking damage
- `KAnim/Death_A` (1.67s) - Death animation
- `KAnim/Dodge_Backwards/Forward/Left/Right` (0.33s each)
- `KAnim/Melee_Block` (1.07s) - Blocking pose
- `KAnim/Running_A` (1.07s) - Running animation
- `KAnim/Walking_A` (1.07s) - Walking animation

## Changes Made

### 1. Added Animation Support to BossProjectilePattern
**BossProjectilePattern.gd:**
```gdscript
@export var animation_name: String = ""  // Boss animation to play during this attack
```

Each pattern resource can now specify which animation to play.

### 2. Updated BossProjectileAttack to Use Pattern Animations
**BossProjectileAttack.gd → _execute_pattern():**
```gdscript
# Use pattern's animation if none explicitly provided
var anim_to_play: String = animation_name if animation_name != "" else pattern.animation_name

# Play animation if configured
if play_animation_on_attack and anim_to_play != "" and _boss_visual != null:
    _play_boss_animation(anim_to_play)
```

**Logic:**
1. Check if animation_name was explicitly passed to execute_attack()
2. If not, use the pattern's animation_name
3. Play animation on boss visual (BlackKnight3DView)

### 3. Configured World 2 Attack Patterns

**Spiral Tempest (Purple):**
```gdresource
animation_name = "KAnim/Melee_2H_Attack"
```
- Uses sweeping 2H attack animation (1.33s)
- Matches the spinning nature of the spiral pattern
- Boss swings weapon in circular motion as projectiles spiral out

**Cross Slash (Orange):**
```gdresource
animation_name = "KAnim/Melee_2H_Slash"
```
- Uses slashing 2H attack animation (1.57s)
- Matches the directional cross pattern
- Boss performs horizontal/vertical slash as projectiles fire

### 4. Fixed World2.tscn BossProjectileAttack Configuration
**Added missing paths:**
```gdscene
boss_path = NodePath("..")
spawn_point_path = NodePath("../ProjectileSpawnPoint")
boss_visual_path = NodePath("../BlackKnight3DView")
```

**Why needed:**
- `boss_path`: Reference to Boss node for position/state
- `spawn_point_path`: Where projectiles spawn from
- `boss_visual_path`: **Critical** - points to BlackKnight3DView for animation playback

## How It Works

### Execution Flow
1. **BossController** triggers projectile attack via scheduler
2. **BossProjectileAttack.execute_attack()** called with pattern index
3. **_execute_pattern()** checks for animation:
   - Uses pattern.animation_name if no override provided
   - Calls _play_boss_animation() with animation name
4. **_play_boss_animation()** calls BlackKnight3DView.play_one_shot()
5. **BlackKnight3DView** plays animation on 3D model's AnimationPlayer
6. Projectiles spawn while animation plays

### Animation System Architecture
```
BossController (2D StaticBody2D)
├─ BossProjectileAttack (Node)
│  └─ _play_boss_animation(anim_name)
│     └─ Calls boss_visual.play_one_shot()
│
└─ BlackKnight3DView (Enemy3DView / Node2D)
   ├─ SubViewport (contains 3D scene)
   │  └─ BlackKnight3DStage
   │     └─ FacingPivot
   │        └─ BlackKnight
   │           └─ AnimationPlayer (actual animations)
   └─ play_one_shot(anim)
      └─ Plays animation on AnimationPlayer
```

## Pattern-Specific Behavior

### Spiral Tempest (Purple)
**Animation:** `KAnim/Melee_2H_Attack` (1.33s)
**Visual:** Boss performs sweeping circular attack
**Projectiles:** 12 purple slashes spiral outward
**Timing:** Animation duration matches spiral spawn time

**Feel:** Boss spins weapon, releasing energy in spiral pattern

### Cross Slash (Orange)
**Animation:** `KAnim/Melee_2H_Slash` (1.57s)
**Visual:** Boss performs powerful horizontal slash
**Projectiles:** 8 orange slashes fire in cross pattern
**Timing:** Animation duration matches cross spawn time

**Feel:** Boss slashes weapon, releasing energy waves in X formation

## Enemy3DView Integration

### Key Methods Used
**play_one_shot(anim: StringName, restart: bool = true, speed: float = 1.0):**
- Plays animation once, doesn't loop
- Automatically returns to previous animation when done
- Perfect for attack animations that should play then return to idle

**play_loop(anim: StringName, restart: bool = false):**
- Plays animation on loop
- Used for idle/walking animations
- Not used for projectile attacks

### Animation Validation
Enemy3DView includes validation:
```gdscript
func _has_anim_name(a: String) -> bool:
    if _anim_player == null:
        return false
    if _anim_player.has_animation(a):
        return true
    if debug_print_missing_anims:
        push_warning("Enemy3DView: Missing animation: '%s'" % a)
    return false
```

If an invalid animation name is provided, you'll see a warning in console.

## Testing

### How to Test
1. Load World 2
2. Reach boss encounter (Floor 5)
3. Watch boss during projectile attacks:
   - **Purple spiral** → Boss should play sweeping attack animation
   - **Orange cross** → Boss should play slashing attack animation

### Debug Tips
If animations don't play:
1. Check console for warnings: `"Enemy3DView: Missing animation: 'KAnim/...'"
2. Verify `boss_visual_path` is set in World2.tscn
3. Check `play_animation_on_attack` is true (default)
4. Confirm animation names match exactly (case-sensitive)

## Future Enhancements

### Add More Attack Animations
To add new attack patterns with animations:

1. **Create pattern resource:**
```gdscript
// In resources/boss/world2_new_attack.tres
animation_name = "KAnim/Melee_2H_Slam"
```

2. **Add to World2.tscn:**
```gdscene
attack_patterns = Array[Resource]([
    ExtResource("30_spiral"), 
    ExtResource("31_cross"),
    ExtResource("32_new_attack")  // Add here
])
```

### Animation Suggestions by Pattern Type
- **Radial Burst:** `KAnim/Melee_2H_Slam` (overhead smash, energy radiates)
- **Cone:** `KAnim/Melee_1H_Slash` (directional slash forward)
- **Wave:** `KAnim/Melee_Dualwield_SlashCombo` (multiple slashes, waves)
- **Spiral:** `KAnim/Melee_2H_Attack` ✓ (already using)
- **Cross:** `KAnim/Melee_2H_Slash` ✓ (already using)

### Idle Animation Transition
Could add idle animation that plays between attacks:
```gdscript
func _after_attack_complete():
    if _boss_visual != null:
        _boss_visual.play_loop("KAnim/Melee_2H_Idle")
```

## Files Modified
1. `scripts/boss/BossProjectilePattern.gd`
   - Added `animation_name` export property

2. `scripts/boss/BossProjectileAttack.gd`
   - Modified `_execute_pattern()` to use pattern's animation_name
   - Falls back to passed animation_name if provided

3. `resources/boss/world2_spiral_attack.tres`
   - Added `animation_name = "KAnim/Melee_2H_Attack"`

4. `resources/boss/world2_cross_slash.tres`
   - Added `animation_name = "KAnim/Melee_2H_Slash"`

5. `scenes/world/World2.tscn`
   - Fixed BossProjectileAttack node paths
   - Added `boss_visual_path = NodePath("../BlackKnight3DView")`

6. `scripts/boss/BOSS_ANIMATIONS_INTEGRATED.md` (this file)

## Status
✅ Animation system integrated into pattern resources
✅ BossProjectileAttack plays pattern animations automatically
✅ Spiral Tempest uses sweeping attack animation
✅ Cross Slash uses slashing attack animation
✅ Boss visual paths configured in World2.tscn
✅ Compatible with Enemy3DView animation system
✅ Ready for testing

## Notes
- Animations play via `play_one_shot()` so they return to idle when done
- Animation timing roughly matches projectile spawn duration
- System is fully modular - easy to add new animations for new patterns
- All BlackKnight animations are available for use
