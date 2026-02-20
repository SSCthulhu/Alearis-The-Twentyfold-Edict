# 🎨 VFX Setup Guide

This document explains how to add VFX to the game, using the Landing VFX as a reference example.

## ✅ Fixed Issues & Key Learnings

### Issue #1: Animation Name Mismatch
- **Problem**: Script tried to play `"land"` but SpriteFrames had `"default"`
- **Fix**: Renamed animation in SpriteFrames to `"land"`
- **Lesson**: Animation names must match between SpriteFrames and code

### Issue #2: Loop Setting
- **Problem**: Animation had `loop: true` preventing `animation_finished` signal
- **Fix**: Changed to `loop: false` for one-shot VFX
- **Lesson**: One-shot VFX should have loop disabled

### Issue #3: Insufficient Debug Logging
- **Problem**: No logs to diagnose connection issues
- **Fix**: Added comprehensive debug logging at every step
- **Lesson**: Always add debug logs for initialization and signal handling

### Issue #4: Manager Not Added to Scene
- **Problem**: VFX scene created but manager node never added to `player.tscn`
- **Fix**: Added manager node to player scene with proper configuration
- **Lesson**: Most common mistake! Always add manager node to player.tscn

### Issue #5: Inverted Flip Direction
- **Problem**: Dash VFX flipped backwards (sprite named "Left" but faces RIGHT)
- **Fix**: Changed `sprite.flip_h = (direction > 0)` to `sprite.flip_h = (direction < 0)`
- **Lesson**: **Always test sprite sheet's default facing** before setting flip logic
- **Standard Pattern**: Most sprite sheets face RIGHT, so use `flip_h = (direction < 0)` to flip for LEFT

### Issue #6: No Directional Support on All VFX
- **Problem**: Only Dash VFX had directional flipping initially
- **Fix**: Added `set_facing()` method and facing_direction parameters to ALL VFX
- **Lesson**: **Directional support should be standard** for consistency, even if sprite appears symmetrical

---

## 📋 Standard VFX Setup Checklist

Use this checklist for every new VFX you add:

### 1. **Create VFX Scene** (`scenes/vfx/YourVFX.tscn`)

```gdscript
# Root: Node2D with embedded script
extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if sprite != null:
		sprite.play(&"your_animation_name")  # ⚠️ Must match SpriteFrames name
		sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	queue_free()  # Auto-destroy when done

func set_facing(direction: int) -> void:
	"""Set facing direction: -1=left, 1=right"""
	if sprite != null:
		# ⚠️ STANDARD PATTERN: sprite.flip_h = (direction < 0)
		# This assumes sprite sheet faces RIGHT by default
		# If your sprite faces LEFT, use: sprite.flip_h = (direction > 0)
		sprite.flip_h = (direction < 0)
```

**⚠️ IMPORTANT:** All VFX should include `set_facing()` method for consistency, even if the sprite sheet appears symmetrical.

**Scene Structure:**
```
Node2D (root with script above)
└── AnimatedSprite2D
    ├── sprite_frames: (assign SpriteFrames resource)
    ├── animation: "your_animation_name"  # ⚠️ Must match script
    └── autoplay: "" (leave empty, script handles playback)
```

**SpriteFrames Setup:**
1. Create new SpriteFrames resource
2. Add animation named exactly as in script (e.g., `"land"`)
3. Import sprite sheet → Add frames
4. Set FPS (24-60 typical)
5. **Set `loop: false`** for one-shot VFX
6. **Set `loop: true`** for looping VFX

---

### 2. **Create Manager Script** (`scripts/player/YourVFX.gd`)

```gdscript
extends Node
class_name YourVFX

@export var target_node_path: NodePath = ^".."  # Path to node with signal
@export var vfx_scene: PackedScene

@export var debug_logs: bool = false
@export var cooldown: float = 0.2

var _target_node: Node = null
var _cooldown_left: float = 0.0

func _ready() -> void:
	if debug_logs:
		print("[YourVFX] _ready() called")
		print("[YourVFX] VFX scene assigned: ", vfx_scene != null)
	
	_target_node = get_node_or_null(target_node_path)
	
	if vfx_scene == null:
		push_warning("[YourVFX] vfx_scene not assigned.")
		return
	
	if _target_node == null:
		push_warning("[YourVFX] Target node not found at: %s" % String(target_node_path))
		return
	
	# Connect to signal
	if _target_node.has_signal("your_signal_name"):
		if not _target_node.your_signal_name.is_connected(_on_signal_triggered):
			_target_node.your_signal_name.connect(_on_signal_triggered)
			print("[YourVFX] ✅ Connected to signal")
	else:
		push_warning("[YourVFX] Target missing signal: your_signal_name")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func _on_signal_triggered(facing_direction: int) -> void:  # ⚠️ Always accept facing_direction
	if debug_logs:
		print("[YourVFX] 🎯 Signal received! facing=%d" % facing_direction)
	
	if _cooldown_left > 0.0:
		if debug_logs:
			print("[YourVFX] ⏸️ Skipped - cooldown active")
		return
	
	_cooldown_left = maxf(cooldown, 0.0)
	_spawn_vfx(facing_direction)  # ⚠️ Pass facing to spawn function

func _spawn_vfx(facing_direction: int) -> void:  # ⚠️ Always accept facing_direction
	if vfx_scene == null:
		return
	
	# Get parent/world position
	var parent_node: Node2D = get_parent() as Node2D
	if parent_node == null:
		return
	
	# Instantiate VFX
	var vfx: Node2D = vfx_scene.instantiate() as Node2D
	if vfx == null:
		push_warning("[YourVFX] VFX scene root must be Node2D")
		return
	
	# Add to world (not as child of moving object)
	var world_parent: Node = parent_node.get_parent()
	if world_parent != null:
		world_parent.add_child(vfx)
		
		# Position VFX
		vfx.global_position = parent_node.global_position
		# Add offsets as needed
		
		# ⚠️ ALWAYS SET FACING (standard pattern)
		if vfx.has_method("set_facing"):
			vfx.call("set_facing", facing_direction)
			if debug_logs:
				var dir_name: String = "LEFT" if facing_direction < 0 else "RIGHT"
				print("[YourVFX] Set VFX facing: %s" % dir_name)
		
		print("[YourVFX] ✨ Spawned VFX at ", vfx.global_position, " facing ", facing_direction)
	else:
		vfx.queue_free()
		push_warning("[YourVFX] Could not find world parent")
```

---

### 3. **Add Signal to Source** (e.g., `PlayerControllerV3.gd`)

```gdscript
# At top of script
# ⚠️ ALWAYS include facing_direction parameter
signal your_signal_name(facing_direction: int, other_params: Type)

# Where event happens
func some_function() -> void:
	# ... your code ...
	print("[SourceScript] 📍 Emitting your_signal_name (facing=%d)" % _facing_direction)
	your_signal_name.emit(_facing_direction, other_params)
```

**⚠️ STANDARD PATTERN:** All VFX signals should include `facing_direction: int` parameter for directional support.

---

### 4. **Add to Player Scene** (`scenes/player/player.tscn`)

⚠️ **CRITICAL STEP** - This is often forgotten!

**Option A: In Godot Editor (Recommended for first time)**
1. Open `scenes/player/player.tscn`
2. Right-click **Player** root → **Add Child Node** → **Node** → Add
3. Rename to `"YourVFX"`
4. In Inspector → **Script** → Attach `scripts/player/YourVFX.gd`
5. **Configure exports in Inspector:**
   - `target_node_path`: `..` (or path to signal source)
   - `vfx_scene`: Drag `scenes/vfx/YourVFX.tscn`
   - `debug_logs`: ✅ **Enable for testing**
   - `cooldown`: Adjust as needed
6. **Save scene** (Ctrl+S)

**Option B: Direct .tscn Edit (Advanced)**
```gdscript
# Add to ext_resource section:
[ext_resource type="Script" path="res://scripts/player/YourVFX.gd" id="XX_your_vfx"]
[ext_resource type="PackedScene" uid="uid://..." path="res://scenes/vfx/YourVFX.tscn" id="YY_your_vfx"]

# Add before closing node (find good insertion point):
[node name="YourVFX" type="Node" parent="."]
script = ExtResource("XX_your_vfx")
vfx_scene = ExtResource("YY_your_vfx")
feet_offset_y = 75.0
debug_logs = true
```

**⚠️ Common Mistake:** Creating the VFX scene but forgetting to add the manager node to player.tscn!

---

## 🐛 Debugging VFX

### Expected Console Output (with `debug_logs: true`):

```
[YourVFX] _ready() called
[YourVFX] VFX scene assigned: true
[YourVFX] Found target node: [Node...]
[YourVFX] ✅ Connected to signal

[When event triggers...]
[SourceScript] 📍 Emitting your_signal_name
[YourVFX] 🎯 Signal received!
[YourVFX] 🎬 Instantiating VFX scene...
[YourVFX] ✨ Spawned VFX at (x, y)
```

### Common Issues:

| Problem | Check |
|---------|-------|
| No `_ready()` logs | Manager script not attached or not in scene tree |
| "Signal not found" warning | Signal name typo or not declared in source |
| "VFX scene not assigned" | Forgot to drag scene to export property |
| "Target node not found" | Wrong `NodePath` or node renamed |
| Signal not triggering | Event not happening, or signal not being emitted |
| VFX instantiates but not visible | Wrong parent, wrong position, or sprite setup issue |
| Animation doesn't play | Animation name mismatch, or sprite_frames not assigned |
| Animation doesn't end | `loop: true` instead of `false` for one-shot VFX |
| **Invalid UID warning** | **Wrong UID in .tscn file - check sprite sheet's .import file for correct UID** |

#### Fixing UID Issues:

**Sprite Sheet UID Warning:**
When you see: `WARNING: ext_resource, invalid UID: uid://xxxxx - using text path instead`

1. Find the correct UID in the sprite sheet's `.import` file
2. Example: `assets/VFX/YourSprite.png.import` → Look for `uid="uid://xxxxxx"`
3. Update the UID in your VFX scene's `.tscn` file

**Scene UID Error:**
When you see: `ERROR: Unrecognized UID: "uid://xxxxx"`

1. **Option A (Recommended):** Use path-only reference in `player.tscn`:
   ```gdscript
   [ext_resource type="PackedScene" path="res://scenes/vfx/YourVFX.tscn" id="XX"]
   ```
2. **Option B:** Open the VFX scene in Godot, save it, then copy the UID from the saved file

**Why this happens:** When creating .tscn files programmatically, Godot hasn't registered the UID yet. Using path references is more reliable until Godot generates/caches the UID.

---

## 📝 Naming Conventions

| Type | Example | Location |
|------|---------|----------|
| VFX Scene | `LandingVFX.tscn` | `scenes/vfx/` |
| Manager Script | `LandingVFX.gd` | `scripts/player/` or `scripts/vfx/` |
| Signal | `landed`, `attack_hit`, `ability_used` | Source script |
| Animation | `"land"`, `"hit"`, `"explode"` | SpriteFrames |
| Manager Node | `"LandingVFX"` | Player scene |

---

## 🎯 Testing Workflow

1. **Enable debug logs** on manager
2. **Run game**
3. **Check console** for initialization logs
4. **Trigger event** (jump, attack, etc.)
5. **Verify** signal emission and VFX spawn logs
6. **Adjust** positioning/timing/cooldown as needed
7. **Disable debug logs** when working

---

## 📚 Reference: VFX Implementations

### Landing VFX (Directional)
- **VFX Scene**: `scenes/vfx/LandingVFX.tscn`
- **Manager**: `scripts/player/LandingVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `landed(was_double_jump: bool, facing_direction: int)`
- **Sprite Sheet**: `Land_Wind_White_v1_A_spritesheet.png`
- **Frames**: 62 frames, 8x8 grid, 512x512 per frame
- **FPS**: 60
- **Loop**: false
- **Position**: Player feet + 50px Y offset
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Trigger**: When player lands from jump/double jump

### Defensive VFX (Directional)
- **VFX Scene**: `scenes/vfx/DefensiveVFX.tscn`
- **Manager**: `scripts/player/DefensiveVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `defensive_activated(character_name: String, facing_direction: int)`
- **Sprite Sheet**: `Stab_Hand Drawn_v1_Ground Wind_Only_spritesheet.png`
- **Frames**: 16 frames, 8x2 grid, 512x512 per frame
- **FPS**: 30
- **Loop**: false
- **Position**: Player feet + 75px Y offset
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Trigger**: When player activates defensive ability (Knight or Rogue)

### Rogue Defensive Smoke VFX (Rogue Only, Layered, One-Shot)
- **VFX Scene**: `scenes/vfx/RogueDefensiveSmokeVFX.tscn`
- **Manager**: `scripts/player/RogueDefensiveSmokeVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `defensive_activated(character_name: String, facing_direction: int)`
- **Sprite Sheet**: `Smoke_Burst_White_v7_C_spritesheet.png`
- **Frames**: 16 frames, 4x4 grid, 512x512 per frame
- **FPS**: 45
- **Loop**: false
- **Position**: Player center (no offset) - spawns on top of player
- **Character Filter**: Rogue only (set `target_character = "Rogue"`)
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Z-Index**: 10 (renders in front of player)
- **Trigger**: When Rogue activates defensive ability
- **Special**: 
  - Works alongside the standard Defensive VFX (plays both simultaneously)
  - Uses `z_index = 10` in scene to render in front of player sprite
  - Positioned at player center rather than feet for "on top of player" effect
  - Only spawns for Rogue (Knight gets only the standard feet VFX)
  - One-shot effect that plays once and disappears

### Rogue Defensive Aura VFX (Rogue Only, Continuous, Follows Player)
- **VFX Scene**: `scenes/vfx/RogueDefensiveAuraVFX.tscn`
- **Manager**: `scripts/player/RogueDefensiveAuraVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `defensive_activated(character_name: String, facing_direction: int)`
- **Sprite Sheet**: `Smoke_Burst_Loop_White_v7_spritesheet.png`
- **Frames**: 16 frames, 4x4 grid, 512x512 per frame
- **FPS**: 30
- **Loop**: true (continuous animation)
- **Position**: Attached as child of player (follows player movement)
- **Character Filter**: Rogue only (set `target_character = "Rogue"`)
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Z-Index**: 5 (renders behind player for subtle effect)
- **Opacity**: 0.35 (35% opacity via `modulate = Color(1, 1, 1, 0.35)`)
- **Duration**: 10 seconds (auto-destroys via Timer node)
- **Trigger**: When Rogue activates defensive ability
- **Special**: 
  - **Continuous looping smoke** that stays active for the full buff duration
  - **Follows player** because it's spawned as a child node (not in world space)
  - **Reduced opacity** (35%) allows player character to be visible through the smoke
  - **Auto-destroys** after 10 seconds using a Timer node
  - Only spawns for Rogue (Knight gets only the standard feet VFX)
  - Works alongside both the standard Defensive VFX (feet) and Smoke Burst VFX (one-shot)

### Roll VFX (Rogue Only, Directional, Behind Player)
- **VFX Scene**: `scenes/vfx/RollVFX.tscn`
- **Manager**: `scripts/player/RollVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `roll_started(character_name: String, facing_direction: int)`
- **Sprite Sheet**: `Smoke_Burst_Loop_White_v1_spritesheet.png`
- **Frames**: 16 frames, 4x4 grid, 512x512 per frame
- **FPS**: 45
- **Loop**: false
- **Position**: Behind player (opposite direction of roll)
- **Character Filter**: Rogue only (set `target_character = "Rogue"`)
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Z-Index**: -1 (renders behind player)
- **Behind Offset**: 100 pixels behind player based on facing direction
- **Trigger**: When Rogue rolls/dodges
- **Special**: 
  - Spawns **behind the player** to create a trailing smoke effect
  - Positioning logic: `vfx_position.x -= facing_direction * behind_offset`
    - If rolling right (+1): spawns left of player (behind)
    - If rolling left (-1): spawns right of player (behind)
  - Uses `z_index = -1` to render behind player sprite
  - Creates a smoke trail effect showing where the player rolled from
  - Only triggers for Rogue (Knight uses block, which is stationary)

### Heavy Attack VFX (Rogue Only, Directional)
- **VFX Scene**: `scenes/vfx/HeavyAttackVFX.tscn`
- **Manager**: `scripts/player/HeavyAttackVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `heavy_attack_started(character_name: String, facing_direction: int)`
- **Sprite Sheet**: `Stab_Hand Drawn_v1_spritesheet.png`
- **Frames**: 16 frames, 8x2 grid, 512x512 per frame
- **FPS**: 30
- **Loop**: false
- **Position**: Player center (no offset)
- **Character Filter**: Rogue only (set `target_character = "Rogue"`)
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Trigger**: When Rogue performs heavy attack

### Light Attack VFX (Rogue Only, Directional)
- **VFX Scene**: `scenes/vfx/LightAttackVFX.tscn`
- **Manager**: `scripts/player/LightAttackVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `light_attack_started(character_name: String, combo_step: int, facing_direction: int)`
- **Sprite Sheet**: `Lightning Slash v1 - Flurry_A_spritesheet.png`
- **Frames**: 56 frames, 8x7 grid, 512x512 per frame
- **FPS**: 60
- **Loop**: false
- **Position**: Player center (no offset)
- **Character Filter**: Rogue only (set `target_character = "Rogue"`)
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Trigger**: When Rogue performs light attack combo (any step 1-3)
- **Special**: Includes `combo_step` parameter to track which combo attack is being performed

### Ultimate Attack VFX (Rogue Only, Directional)
- **VFX Scene**: `scenes/vfx/UltimateAttackVFX.tscn`
- **Manager**: `scripts/player/UltimateAttackVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `ultimate_attack_hit(character_name: String, enemy_position: Vector2, facing_direction: int)`
- **Sprite Sheet**: `Impact_Cut_V4_spritesheet.png`
- **Frames**: 16 frames, 4x4 grid, 512x512 per frame
- **FPS**: 60
- **Loop**: false
- **Position**: Enemy position (spawns at enemy's global position, not player's)
- **Character Filter**: Rogue only (set `target_character = "Rogue"`)
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Trigger**: Each time Rogue's ultimate attack hits an enemy (teleport + strike sequence)
- **Special**: 
  - Spawns at **enemy's position** (passed via signal parameter), not player's position
  - Plays once for **each enemy hit** during ultimate sequence
  - Emitted after damage is dealt in `_ultimate_rogue_teleport_attack()`

### Knight Ultimate VFX (Knight Only, Triple VFX, Rotated)
- **VFX Scenes**: 
  - `scenes/vfx/KnightUltimatePlayerVFX.tscn` (on player)
  - `scenes/vfx/KnightUltimateWaveVFX.tscn` (wave in front)
  - `scenes/vfx/KnightUltimateEnemyHitVFX.tscn` (on each enemy hit)
- **Manager**: `scripts/player/KnightUltimateVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signals**: 
  - `knight_ultimate_started(facing_direction: int)` - triggers player & wave VFX
  - `knight_ultimate_hit(enemy_position: Vector2)` - triggers per-enemy hit VFX
- **Sprite Sheets**: 
  - Player: `Blue Lightning Strike v3_B_spritesheet.png`
  - Wave: `Blue Lightning Strike v3_D_Bolts Thick_spritesheet.png`
  - Enemy Hit: `Blue Lightning Strike v3_D_Bolts Thick_spritesheet.png`
- **Frames**: 16 frames each, 4x4 grid, 512x512 per frame
- **FPS**: 60
- **Loop**: false
- **Position**: 
  - Player VFX: Spawns at player center
  - Wave VFX: Spawns in front of player based on facing direction (distance configurable via `wave_forward_offset`)
  - Enemy Hit VFX: Spawns at each enemy's position that gets hit
- **Directional**: Wave VFX flips horizontally based on facing direction
- **Rotation**: Wave VFX and Enemy Hit VFX rotated 90 degrees (`rotation = 1.5708`) for vertical lightning
- **Z-Index**: Player VFX = 10 (front), Wave VFX = 5 (mid), Enemy Hit VFX = 10 (front)
- **Trigger**: When Knight activates ultimate wave attack (hits all enemies in front)
- **Special**: 
  - **Sequential Triple VFX system** - spawns THREE types of effects from two signals
  - **Phase 1 (immediate)**: Player VFX plays on Knight (charge-up lightning, sword lighting up)
  - **Phase 2 (after `wave_delay`)**: Wave VFX spawns in front (sword slam, wave shoots out)
  - **Phase 3 (after `enemy_hit_delay`)**: Enemy Hit VFX spawns on each enemy that gets hit (visual confirmation)
  - Use `wave_delay` export to sync with animation timing (default 0.3s, adjust to match charge-up duration)
  - Use `enemy_hit_delay` export to sync with wave impact timing (default 1.3s, adjust to match wave travel)
  - Wave VFX plays in front to visualize the directional attack
  - Enemy Hit VFX spawns at each enemy's position for visual feedback of damage
  - All VFX play once and auto-destroy when animation completes
  - Only triggers for Knight's ultimate (stationary wave attack hitting all enemies in front)
  - Debug logs show "[PHASE 1]", "[PHASE 2]", and "[PHASE 3]" to help sync timing with animation

### Dash VFX (Directional, Ground Only, Continuous During Sprint)
- **VFX Scene**: `scenes/vfx/DashVFX.tscn`
- **Manager**: `scripts/player/DashVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `dash_started(facing_direction: int, is_airborne: bool)`
- **Sprite Sheet**: `Wind_Ground_Alpha_Left_0.5_Burst_A_spritesheet.png` (despite name, faces RIGHT by default)
- **Frames**: 14 frames, 8x2 grid (first 14), 512x512 per frame
- **FPS**: 30
- **Loop**: false
- **Position**: Player feet + 50px Y offset
- **Directional**: Flips horizontally for LEFT dashes (`sprite.flip_h = (direction < 0)`)
- **Trigger**: 
  - When player dashes on ground (filters for `is_airborne == false`)
  - **Continuously spawns VFX while sprinting** (every 0.15s by default, configurable via `sprint_vfx_interval`)
- **Special**: Uses `get_current_state()` to detect SPRINT state and spawn VFX periodically

### Air Dash VFX (Directional, Air Only)
- **VFX Scene**: `scenes/vfx/AirDashVFX.tscn`
- **Manager**: `scripts/player/AirDashVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `dash_started(facing_direction: int, is_airborne: bool)`
- **Sprite Sheet**: `Dash_Wind_White_v3_spritesheet.png`
- **Frames**: 16 frames, 8x2 grid, 512x512 per frame
- **FPS**: 30
- **Loop**: false
- **Position**: Player center (no offset)
- **Directional**: Flips horizontally for LEFT dashes (`sprite.flip_h = (direction < 0)`)
- **Trigger**: When player dashes in air (filters for `is_airborne == true`)

### Jump VFX (Directional, Regular Jumps Only)
- **VFX Scene**: `scenes/vfx/JumpVFX.tscn`
- **Manager**: `scripts/player/JumpVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `jump_started(is_double_jump: bool, facing_direction: int)`
- **Sprite Sheet**: `Dash_Wind_White_v6_spritesheet.png`
- **Frames**: 16 frames, 8x2 grid, 512x512 per frame
- **FPS**: 30
- **Loop**: false
- **Position**: Player feet (Y offset varies)
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Trigger**: When player performs regular jump (filters out `is_double_jump == true`)

### Double Jump VFX (Directional + Rotated 270°)
- **VFX Scene**: `scenes/vfx/DoubleJumpVFX.tscn`
- **Manager**: `scripts/player/DoubleJumpVFX.gd`
- **Signal Source**: `scripts/player/PlayerControllerV3.gd`
- **Signal**: `jump_started(is_double_jump: bool, facing_direction: int)`
- **Sprite Sheet**: `Dash_Wind_White_v7_spritesheet.png`
- **Frames**: 16 frames, 8x2 grid, 512x512 per frame
- **FPS**: 30
- **Loop**: false
- **Position**: Player feet + 30px Y offset
- **Rotation**: 270° (4.71239 radians) for downward burst effect
- **Directional**: Flips horizontally based on player facing (`sprite.flip_h = (direction < 0)`)
- **Trigger**: When player performs double jump (filters for `is_double_jump == true`)

### Enemy Hit VFX (Universal)
- **VFX Scene**: `scenes/vfx/EnemyHitVFX.tscn`
- **Integration**: Built into `EnemyHealth.gd` and `BossHealth.gd` scripts
- **Sprite Sheet**: `Impact_Cut_V2_spritesheet.png`
- **Frames**: 16 frames, 8x2 grid, 512x512 per frame
- **FPS**: 45
- **Loop**: false
- **Position**: Enemy/boss global position (centered on enemy)
- **Trigger**: Automatically spawns when `take_damage()` is called
- **Setup**: Assign `hit_vfx_scene` property in enemy/boss inspector to `res://scenes/vfx/EnemyHitVFX.tscn`

### Enemy Projectile VFX

**SkeletonMage Projectile:**
- **Scene**: `scenes/enemies/SkeletonMageProjectile.tscn`
- **Sprite Sheet**: `Fireball_v7_spritesheet.png`
- **Frames**: 16 frames, 8x2 grid, 512x512 per frame
- **FPS**: 30
- **Loop**: true (continuous while traveling)
- **Collision**: 24x24 rectangle
- **Visual**: Animated fireball effect

**Necromancer Projectile:**
- **Scene**: `scenes/enemies/NecromancerProjectile.tscn`
- **Sprite Sheet**: `Blood_Projectile_v4_B_spritesheet.png`
- **Frames**: 16 frames, 8x2 grid, 512x512 per frame
- **FPS**: 30
- **Loop**: true (continuous while traveling)
- **Collision**: 24x24 rectangle
- **Visual**: Animated blood projectile effect

**Note:** All VFX now support directional flipping as standard pattern. Signals pass `facing_direction`, and VFX scenes include `set_facing()` method.

---

## 🎯 Character-Specific VFX

Some VFX should only trigger for specific characters (e.g., Rogue heavy attack vs Knight heavy attack).

### Implementation:

```gdscript
# In manager script
@export var target_character: String = "Rogue"  # Only trigger for this character

func _on_signal_received(character_name: String) -> void:
	# Filter by character
	if character_name != target_character:
		if debug_logs:
			print("[VFX] ⏭️ Skipped - wrong character")
		return
	
	# Spawn VFX only for target character
	_spawn_vfx()
```

**Example:** `HeavyAttackVFX.gd` only spawns for Rogue heavy attacks, not Knight

---

## 🌍 Context-Specific VFX

Some VFX should only trigger in specific contexts (e.g., ground dash vs air dash, regular jump vs double jump).

### Implementation Pattern:

```gdscript
# In manager script
func _on_signal_received(param1: int, context_flag: bool) -> void:
	# Filter by context
	if not context_flag:  # or if context_flag, depending on what you want
		if debug_logs:
			print("[VFX] ⏭️ Skipped - wrong context")
		return
	
	# Spawn VFX only for matching context
	_spawn_vfx()
```

### Examples:

**Ground vs Air Dashes:**
- Signal: `dash_started(facing_direction: int, is_airborne: bool)`
- `DashVFX.gd` filters for `is_airborne == false` (ground dashes only)
- `AirDashVFX.gd` filters for `is_airborne == true` (air dashes only)

**Regular vs Double Jumps:**
- Signal: `jump_started(is_double_jump: bool, facing_direction: int)`
- `JumpVFX.gd` filters for `is_double_jump == false` (regular jumps only)
- `DoubleJumpVFX.gd` filters for `is_double_jump == true` (double jumps only)

**Benefits:**
- Both VFX systems listen to the same signal
- Filtering logic keeps systems independent and clean
- Easy to add more context-specific VFX variants

---

## 🔄 Directional VFX

Some VFX need to face the direction the player is moving/attacking (e.g., dash burst, attack swipes).

### VFX Scene Setup (with direction support):

```gdscript
# Embedded in VFX scene .tscn
extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if sprite != null:
		sprite.play(&"animation_name")
		sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	queue_free()

func set_facing(direction: int) -> void:
	"""Set facing direction: -1=left, 1=right"""
	if sprite != null:
		# ⚠️ Check your sprite sheet's default orientation first!
		# If sprite faces RIGHT by default: flip when direction < 0 (left)
		# If sprite faces LEFT by default: flip when direction > 0 (right)
		sprite.flip_h = (direction < 0)  # Example: sprite defaults to right
```

**⚠️ Important:** Test the sprite sheet's default facing direction first, then adjust the flip logic accordingly!

### Manager Script Pattern:

```gdscript
func _spawn_vfx(facing_direction: int) -> void:
	var vfx: Node2D = vfx_scene.instantiate() as Node2D
	# ... position VFX ...
	world_parent.add_child(vfx)
	
	# Apply facing AFTER adding to tree
	if vfx.has_method("set_facing"):
		vfx.call("set_facing", facing_direction)
		if debug_logs:
			print("[VFX] Set facing: %s" % ("LEFT" if facing_direction < 0 else "RIGHT"))
```

### Signal Pattern:

```gdscript
# Emit with facing direction parameter
signal dash_started(facing_direction: int)

# When emitting:
dash_started.emit(_facing_direction)  # -1 for left, 1 for right
```

**Example:** `DashVFX.gd` flips the wind burst based on dash direction

---

## 🔄 Rotated VFX

Some VFX need to be rotated to match the direction of movement (e.g., vertical dash effects for jumps).

### VFX Scene Setup (with rotation):

In the `.tscn` file, set the root node's rotation property:

```gdscript
[node name="JumpVFX" type="Node2D"]
script = SubResource("GDScript_jump")
rotation = 1.5708  # 90 degrees in radians (π/2)

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
# Animation frames...
```

**Common Rotations:**
- 0 radians = 0° (horizontal right)
- 1.5708 radians = 90° (vertical up)
- 3.14159 radians = 180° (horizontal left)
- 4.71239 radians = 270° (vertical down)

**⚠️ Important:** Rotation is applied to the root `Node2D`, so the sprite and any flipping will be relative to this rotation.

### Combining Rotation + Flip:

```gdscript
# Scene has rotation = 1.5708 (90°)
# Flip logic still works normally in set_facing()
func set_facing(direction: int) -> void:
	if sprite != null:
		sprite.flip_h = (direction < 0)
```

**Examples:** 
- `JumpVFX.gd` uses horizontal dash sprite (no rotation) for regular jump
- `DoubleJumpVFX.gd` uses horizontal dash sprite rotated 270° to create downward burst effect

---

## ✨ Tips

- **World vs Local**: Spawn VFX in world parent (not as child of moving player) to avoid drift
- **Cooldown**: Prevents spam when events fire rapidly (0.1-0.3s typical)
- **Debug First**: Always test with debug logs before disabling
- **Positioning**: Use offsets to fine-tune VFX placement
- **Performance**: Ensure VFX auto-destroys (use `queue_free()` on animation end)
- **Character Filtering**: Use `target_character` export to limit VFX to specific characters
