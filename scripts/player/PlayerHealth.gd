extends Node
class_name PlayerHealth

signal health_changed(current: int, max_value: int)
signal damage_applied(final_damage: int, source: Node) # emitted ONLY when HP is reduced (includes source for VFX)
signal damage_blocked(attempted_damage: int, source: Node) # emitted when hit is prevented by invuln
signal guarded
signal died

# -----------------------------
# Shield / Barrier (temporary HP)
# -----------------------------
signal shield_changed(current: int, max_value: int)
signal shield_absorbed(absorbed: int, attempted_damage: int, source: Node)

# Base designer max HP (this is your "true" stat before buffs)
@export var base_max_hp: int = 100

@export var invuln_time: float = 0.35
@export var god_mode: bool = false

@export var defend_damage_multiplier: float = 1.0 # 1.0 = no change; 0.8 = -20%; 0.0 = negate
@export var buffs_path: NodePath = ^"../Buffs"

# Debug toggle (prints sources + invuln state)
@export var debug_damage: bool = false

# Healing VFX
const HEALING_VFX_SCENE: PackedScene = preload("res://scenes/vfx/HealingVFX.tscn")

# Current HP and computed max HP
var hp: int = 0
var max_hp: int = 1

# Shield state
var shield: int = 0
var shield_max: int = 0
var _shield_timer: float = 0.0

var _invuln_timer: float = 0.0
var _is_dead: bool = false
var _invuln_source: String = ""  # Track what granted invuln: "roll", "hit", "other"
var _is_initialized: bool = false  # Track if initial setup is complete
var _healing_vfx_suppressed_until_sec: float = 0.0

const STAT_MAX_HP_MULT: StringName = &"max_hp_mult"

@onready var _buffs: PlayerBuffs = get_node_or_null(buffs_path) as PlayerBuffs

func _ready() -> void:
	_is_dead = false
	_invuln_timer = 0.0
	_is_initialized = false  # Mark as not initialized yet

	# Listen for any buff stat changes (Vital Thread / future relics)
	if _buffs != null:
		if not _buffs.stats_changed.is_connected(_on_stats_changed):
			_buffs.stats_changed.connect(_on_stats_changed)

	# Compute max hp from buffs and start full
	recompute_max_hp(true)

	# Ensure shield signals are initialized
	_emit_shield_changed()

	# Mark as initialized after initial setup
	_is_initialized = true

	#print("Player HP:", hp)

func _process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(_invuln_timer - delta, 0.0)
		if _invuln_timer <= 0.0:
			_invuln_source = ""  # Clear source when invuln expires

	# Shield duration countdown
	if _shield_timer > 0.0:
		_shield_timer = maxf(_shield_timer - delta, 0.0)
		if _shield_timer <= 0.0:
			_clear_shield_internal(true)

func _on_stats_changed() -> void:
	# Recompute max HP without fully healing; preserve current HP percent.
	recompute_max_hp(false)

# -----------------------------
# Max HP recompute (Vital Thread support)
# -----------------------------
func recompute_max_hp(do_full_heal: bool = false) -> void:
	var old_max: int = maxi(max_hp, 1)
	var old_hp: int = clampi(hp, 0, old_max)

	var mult: float = 1.0
	if _buffs != null:
		mult = _buffs.get_mult(STAT_MAX_HP_MULT, 1.0)

	var new_max: int = int(round(float(maxi(base_max_hp, 1)) * mult))
	new_max = maxi(new_max, 1)

	max_hp = new_max

	if do_full_heal:
		hp = max_hp
	else:
		# Preserve HP ratio when max changes
		var ratio: float = 1.0
		if old_max > 0:
			ratio = float(old_hp) / float(old_max)
		hp = clampi(int(round(ratio * float(max_hp))), 0, max_hp)

	# Shield does not auto-scale, but must remain clamped
	if shield_max > 0:
		shield = clampi(shield, 0, shield_max)
	else:
		shield = 0
		_shield_timer = 0.0

	health_changed.emit(hp, max_hp)
	_emit_shield_changed()
	
	# Spawn VFX if health actually increased (but not during initial setup)
	if _is_initialized and hp > old_hp:
		_spawn_healing_vfx()

# -----------------------------
# Utility APIs
# -----------------------------
func full_heal() -> void:
	_is_dead = false
	var before: int = hp
	hp = max_hp
	health_changed.emit(hp, max_hp)
	pass
	
	# Spawn VFX if health actually increased (but not during initial setup)
	if _is_initialized and hp > before:
		_spawn_healing_vfx()

func set_max_and_full_heal(new_max: int) -> void:
	# This changes BASE max HP (designer max), then recomputes with buffs.
	base_max_hp = maxi(new_max, 1)
	_is_dead = false
	recompute_max_hp(true)
	pass

func _get_heal_mult() -> float:
	if RunStateSingleton != null and ("healing_mult" in RunStateSingleton):
		return clampf(float(RunStateSingleton.healing_mult), 0.05, 10.0)
	return 1.0

func heal(amount: int) -> int:
	if _is_dead:
		return 0
	if amount <= 0:
		return 0

	var mult := _get_heal_mult()
	var final_amt: int = int(round(float(amount) * mult))
	final_amt = maxi(final_amt, 1)

	var before: int = hp
	hp = clampi(hp + final_amt, 0, max_hp)

	var gained: int = hp - before
	if gained != 0:
		health_changed.emit(hp, max_hp)
		# Only spawn VFX if initialized (prevents VFX on spawn)
		if _is_initialized:
			_spawn_healing_vfx()
	return gained

func heal_percent(pct: float) -> int:
	if pct <= 0.0:
		return 0
	var base: int = int(round(float(max_hp) * pct))
	return heal(base)

# -----------------------------
# Shield / Barrier API
# -----------------------------
func has_shield() -> bool:
	return shield > 0

func get_shield() -> int:
	return shield

func get_shield_max() -> int:
	return shield_max

func get_shield_time_left() -> float:
	return maxf(_shield_timer, 0.0)

func clear_shield() -> void:
	_clear_shield_internal(true)

func add_shield(amount: int, duration: float, max_cap: int, refresh_duration: bool = true) -> int:
	# Returns actual amount gained (after cap/clamp).
	if _is_dead:
		return 0
	if amount <= 0:
		return 0

	var cap: int = maxi(max_cap, 0)
	if cap <= 0:
		return 0

	var before: int = shield

	# Update cap first (stable max for UI + clamping)
	shield_max = cap

	# Apply gain then clamp
	shield = clampi(shield + amount, 0, shield_max)

	# Duration handling
	var dur: float = maxf(duration, 0.0)
	if refresh_duration:
		_shield_timer = dur
	else:
		_shield_timer = maxf(_shield_timer, dur)

	var gained: int = shield - before
	if gained != 0 or before != shield:
		_emit_shield_changed()

	return gained

func set_shield(current_value: int, max_value: int, duration: float) -> void:
	var cap: int = maxi(max_value, 0)
	shield_max = cap

	if shield_max <= 0:
		_clear_shield_internal(true)
		return

	shield = clampi(current_value, 0, shield_max)
	_shield_timer = maxf(duration, 0.0)
	_emit_shield_changed()

func _emit_shield_changed() -> void:
	shield_changed.emit(shield, shield_max)

func _clear_shield_internal(emit_changes: bool) -> void:
	if shield == 0 and shield_max == 0 and _shield_timer == 0.0:
		return
	shield = 0
	shield_max = 0
	_shield_timer = 0.0
	if emit_changes:
		_emit_shield_changed()

# -----------------------------
# I-frames API (public + safe)
# -----------------------------
func grant_invuln(seconds: float, source: String = "other") -> void:
	if seconds <= 0.0:
		return
	_invuln_timer = maxf(_invuln_timer, seconds)
	_invuln_source = source  # Track what granted invuln

func is_invulnerable() -> bool:
	return _invuln_timer > 0.0

func get_invuln_time_left() -> float:
	return maxf(_invuln_timer, 0.0)

func get_invuln_source() -> String:
	return _invuln_source if is_invulnerable() else ""

# -----------------------------
# Damage intake
# -----------------------------
func take_damage(amount: int, source: Node = null, ignore_invuln: bool = false) -> void:
	if _is_dead:
		return
	if amount <= 0:
		return
	if god_mode:
		return

	var _src_name: String = "NULL"
	var _src_class: String = "NULL"
	if source != null:
		_src_name = String(source.name)
		_src_class = String(source.get_class())
	
	# Check for Rogue defensive dodge chance FIRST (before invuln)
	if _buffs != null and not ignore_invuln:
		var dodge_chance: float = _buffs.get_add(&"dodge_chance_add", 0.0)
		if dodge_chance > 0.0:
			var roll: float = randf()
			if roll < dodge_chance:
				# Rogue dodge successful!
				pass
				# NOTE: Don't emit damage_blocked signal here - this is RNG dodge, not invuln-based
				# Emitting it confuses PerfectDodgeDetector which expects invuln state
				return

	# Invuln gate
	if (not ignore_invuln) and _invuln_timer > 0.0:
		damage_blocked.emit(amount, source)

		if debug_damage:
			pass
			#print("[PlayerHealth] BLOCKED dmg=", amount,
				#" source=", _src_name, " class=", _src_class,
				#" invuln_left=", _invuln_timer,
				#" ignore_invuln=", ignore_invuln
			#)
		return

	# GLOBAL: 50% damage reduction from ALL sources (enemies, bosses, hazards, projectiles)
	var final_amount: int = int(round(float(amount) * 0.5))

	# 1) Buffs-based damage taken multiplier (Glass Pact, Defend buff, etc.)
	var dmg_mult: float = 1.0
	if _buffs != null:
		dmg_mult = _buffs.get_mult(&"damage_taken_mult", 1.0)
	final_amount = int(round(float(final_amount) * dmg_mult))
	
	# Log damage for defensive ability testing
	if dmg_mult != 1.0:
		var _reduction_pct: float = (1.0 - dmg_mult) * 100.0
		pass
	else:
		pass

	# 2) OPTIONAL legacy defend multiplier via Combat
	var player: Node = get_parent()
	if player != null and player.has_node("Combat"):
		var combat: Node = player.get_node("Combat")
		if combat != null and combat.has_method("is_defending") and bool(combat.call("is_defending")):
			final_amount = int(round(float(final_amount) * defend_damage_multiplier))

	if debug_damage:
		pass
		#print("[PlayerHealth] APPLY dmg=", final_amount, " (raw=", amount, ")",
			#" source=", _src_name, " class=", _src_class,
			#" invuln_left=", _invuln_timer,
			#" ignore_invuln=", ignore_invuln,
			#" dmg_mult=", dmg_mult,
			#" shield=", shield, "/", shield_max, " shield_left=", _shield_timer
		#)

	# If fully negated by multipliers/guard
	if final_amount <= 0:
		guarded.emit()
		pass
		if not ignore_invuln:
			_invuln_timer = invuln_time
			_invuln_source = "guard"  # Guard invuln, not from roll
		return

	# -----------------------------
	# Shield absorbs damage first
	# -----------------------------
	var absorbed: int = 0
	if shield > 0:
		absorbed = mini(shield, final_amount)
		if absorbed > 0:
			shield = maxi(shield - absorbed, 0)
			final_amount = maxi(final_amount - absorbed, 0)

			shield_absorbed.emit(absorbed, absorbed + final_amount, source)
			_emit_shield_changed()

			# If shield is now empty, clear cap/timer (avoids stale UI later)
			if shield <= 0:
				_clear_shield_internal(true)

	# Apply remaining to HP
	if final_amount > 0:
		hp = maxi(hp - final_amount, 0)
		health_changed.emit(hp, max_hp)

		# IMPORTANT: emit ONLY when HP is reduced (keeps your damage numbers sane)
		damage_applied.emit(final_amount, source)

		#print("Player took ", final_amount, " damage. HP now: ", hp)
	else:
		# Fully absorbed by shield — do NOT emit damage_applied.
		if debug_damage:
			pass

	if not ignore_invuln:
		_invuln_timer = invuln_time
		_invuln_source = "hit"  # Post-hit invuln, not from roll

	if hp <= 0 and not _is_dead:
		_is_dead = true
		pass
		died.emit()

func revive_full() -> void:
	_is_dead = false
	_invuln_timer = 0.0
	var missing: int = max_hp - hp
	if missing > 0:
		heal(missing)
	else:
		health_changed.emit(hp, max_hp)

func suppress_healing_vfx_for(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	_healing_vfx_suppressed_until_sec = maxf(_healing_vfx_suppressed_until_sec, now_sec + seconds)

func _is_healing_vfx_suppressed() -> bool:
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	return now_sec < _healing_vfx_suppressed_until_sec

func _spawn_healing_vfx() -> void:
	"""Spawns healing VFX that follows the player"""
	if _is_healing_vfx_suppressed():
		return
	if HEALING_VFX_SCENE == null:
		return
	
	var player: Node = get_parent()
	if player == null:
		return
	
	# Instantiate VFX
	var vfx: Node2D = HEALING_VFX_SCENE.instantiate()
	if vfx == null:
		return
	
	# Set position and scale before adding
	vfx.position = Vector2.ZERO
	vfx.scale = Vector2(1.0, 1.0)  # Explicitly set scale to 1.0
	
	# Also set scale on the AnimatedSprite2D child if it exists
	if vfx.has_node("AnimatedSprite2D"):
		var sprite: AnimatedSprite2D = vfx.get_node("AnimatedSprite2D")
		if sprite != null:
			sprite.scale = Vector2(1.0, 1.0)
	
	# Add as child of player so it follows them (deferred to avoid blocking)
	player.add_child.call_deferred(vfx)
	pass
