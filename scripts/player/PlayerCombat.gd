# res://scripts/PlayerCombat.gd
extends Node
class_name PlayerCombat

signal attack_started(kind: StringName, windup: float, total_time: float)
signal attack_ended(kind: StringName)

# Existing signal (keep)
signal attack_hit(kind: StringName, target: Node, dealt_damage: int)

# NEW: detailed hit info (for crit-based relics)
signal attack_hit_detailed(kind: StringName, target: Node, dealt_damage: int, was_crit: bool)

@export var hitbox_scene: PackedScene
@export var buffs_path: NodePath = ^"../Buffs"

# Timings (seconds)
@export var light_windup: float = 0.03
@export var light_recovery: float = 0.50
@export var heavy_windup: float = 0.10
@export var heavy_recovery: float = 1.00
@export var ultimate_windup: float = 0.15
@export var ultimate_recovery: float = 0.35
@export var BIGD_windup: float = 0.03
@export var BIGD_recovery: float = 0.01

# Damage
@export var light_damage: int = 6
@export var heavy_damage: int = 14
@export var ultimate_damage: int = 45
@export var BIGD_damage: int = 99999999

# Cooldowns (seconds)
@export var heavy_cooldown: float = 3.0
@export var ultimate_cooldown: float = 60.0

# Defend-as-buff (character-specific)
@export var defend_cooldown: float = 60.0
@export var defend_buff_duration: float = 10.0  # Increased from 5.0 to 10.0
@export var knight_damage_reduction: float = 0.20  # Knight: 20% damage reduction
@export var rogue_dodge_chance: float = 0.20  # Rogue: 20% chance to avoid damage

# Hitbox placement (position)
@export var hitbox_offset: Vector2 = Vector2(28, 0)  # Slightly reduced for tighter range

# Single shared hitbox size for ALL attacks
@export var hitbox_size_mult: float = 1.2  # Modest boost from 1.0

# Animation names
@export var anim_light: StringName = &"light_attack"
@export var anim_heavy: StringName = &"heavy_attack"
@export var anim_ultimate: StringName = &"ultimate"

# -----------------------------
# Crit tuning (R3 needs this)
# -----------------------------
@export var crit_chance: float = 0.10 # 10% default; set to 0.0 if you want no crits
@export var crit_mult: float = 1.50   # 1.5x damage on crit

const DEFEND_BUFF_ID_KNIGHT: StringName = &"knight_damage_reduction"
const DEFEND_BUFF_ID_ROGUE: StringName = &"rogue_dodge_chance"

# Incoming damage modifier
const STAT_DAMAGE_TAKEN_MULT: StringName = &"damage_taken_mult"
const STAT_DODGE_CHANCE_ADD: StringName = &"dodge_chance_add"  # For Rogue defensive

# Outgoing damage modifier (relics)
const STAT_DAMAGE_DEALT_MULT: StringName = &"damage_dealt_mult"

# C10 Quickstep Wraps support (light-only outgoing)
const STAT_LIGHT_DAMAGE_DEALT_MULT: StringName = &"light_damage_dealt_mult"
const BUFF_QUICKSTEP_WRAPS: StringName = &"relic_quickstep_wraps"

# OPTIONAL: if you ever want to force a tag for certain attacks
const TAG_NONE: StringName = &""

var _player: CharacterBody2D = null
var _buffs: PlayerBuffs = null

var _facing: int = 1
var _busy: bool = false

# ✅ Cancellation token for timers/hitbox spawns.
var _attack_seq: int = 0
var _current_attack_kind: StringName = &""

# ✅ Track active hitboxes so we can hard-cancel and ensure nothing lingers.
var _active_hitboxes: Array[Node] = []

var _ultimate_ready_time: float = 0.0
var _defend_ready_time: float = 0.0
var _light_ready_time: float = 0.0
var _heavy_ready_time: float = 0.0
var _BIGD_ready_time: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		push_error("PlayerCombat must be a child of the Player (CharacterBody2D).")
		return

	_buffs = get_node_or_null(buffs_path) as PlayerBuffs
	if _buffs == null:
		push_error("PlayerCombat: Buffs not found. Add a Buffs node (PlayerBuffs.gd) and set buffs_path.")
		return

	if hitbox_scene == null:
		push_warning("PlayerCombat: hitbox_scene is not assigned. Set it in the Inspector.")

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _cd_mult() -> float:
	if RunStateSingleton != null and ("cooldown_mult" in RunStateSingleton):
		return clampf(float(RunStateSingleton.cooldown_mult), 0.25, 2.5)
	return 1.0

func _get_ultimate_cd_mult_from_relics() -> float:
	if RunStateSingleton != null and ("relic_ultimate_gain_mult" in RunStateSingleton):
		return clampf(float(RunStateSingleton.relic_ultimate_gain_mult), 0.10, 10.0)
	return 1.0

func _get_player_can_attack() -> bool:
	if _player == null:
		return false
	var v: Variant = _player.get("can_attack")
	if v is bool:
		return bool(v)
	return true

func _get_player_carried_charge() -> Node:
	if _player == null:
		return null
	var v: Variant = _player.get("carried_charge")
	if v is Node:
		return v as Node
	return null

func _carry_locked() -> bool:
	if _player == null:
		return true
	if _get_player_carried_charge() != null:
		return true
	if not _get_player_can_attack():
		return true
	return false

func _get_anim_duration_seconds(anim_name: StringName) -> float:
	if _player == null:
		return 0.0
	var anim_node := _player.get_node_or_null("Visual/BodyVisual") as AnimatedSprite2D
	if anim_node == null or anim_node.sprite_frames == null:
		return 0.0

	var a: String = String(anim_name)
	if not anim_node.sprite_frames.has_animation(a):
		return 0.0

	var frames: int = anim_node.sprite_frames.get_frame_count(a)
	var fps: float = anim_node.sprite_frames.get_animation_speed(a)
	if fps <= 0.0:
		return 0.0
	return float(frames) / fps

func is_defending() -> bool:
	if _buffs == null:
		return false
	return _buffs.has_buff(DEFEND_BUFF_ID_KNIGHT) or _buffs.has_buff(DEFEND_BUFF_ID_ROGUE)

# ------------------------------------------------------------
# Public API: hard cancel for dodge / hit / cutscene etc.
# ------------------------------------------------------------
func cancel_all_attacks(_reason: StringName = &"") -> void:
	# Invalidate any pending timers/spawns.
	_attack_seq += 1

	# Remove any active hitboxes.
	_clear_active_hitboxes()

	var had_kind: bool = (_current_attack_kind != &"")
	var ended_kind: StringName = _current_attack_kind

	_busy = false
	_current_attack_kind = &""

	# If something was active, emit attack_ended so PlayerController can clear its state.
	if had_kind:
		attack_ended.emit(ended_kind)

func _clear_active_hitboxes() -> void:
	if _active_hitboxes.is_empty():
		return

	# Copy then clear to avoid mutation while iterating.
	var to_clear: Array[Node] = _active_hitboxes.duplicate()
	_active_hitboxes.clear()

	for hb: Node in to_clear:
		if hb == null:
			continue
		if not is_instance_valid(hb):
			continue

		# Prefer a dedicated cancel/force_end if your hitbox supports it.
		if hb.has_method("cancel"):
			hb.call("cancel")
		elif hb.has_method("force_end"):
			hb.call("force_end")
		else:
			hb.queue_free()

func _process(_delta: float) -> void:
	if _player == null:
		return

	# Get facing direction from PlayerController if available
	if _player.has_method("get_facing_direction"):
		_facing = int(_player.call("get_facing_direction"))
	elif absf(_player.velocity.x) > 1.0:
		_facing = 1 if _player.velocity.x > 0.0 else -1

	# Defend input is now handled by PlayerControllerV3 state machine
	# Removed from here to prevent double-triggering

	if _carry_locked():
		return

	# ✅ Check for Rogue combo input BEFORE _busy check (combo needs to accept input during window)
	if Input.is_action_just_pressed("attack_light") and _is_rogue_combo_active():
		_handle_rogue_combo_input()
		return

	if _busy:
		return

	# REMOVED: PlayerControllerV3 now handles ALL attack inputs
	# This prevents race conditions and ensures cooldown checks are enforced
	# Light/Heavy/Ultimate attacks are now triggered via PlayerControllerV3 -> _start_attack()
	
	# REMOVED: BIGD is now handled in PlayerControllerV3 with inspector toggle control
	# This prevents the input from being triggered when disabled for demo release
	# PlayerControllerV3's _handle_debug_inputs() now controls this

func get_cooldown_left(ability_id: StringName) -> float:
	var now: float = _now()
	match ability_id:
		&"light":
			return maxf(_light_ready_time - now, 0.0)
		&"heavy":
			return maxf(_heavy_ready_time - now, 0.0)
		&"ultimate":
			return maxf(_ultimate_ready_time - now, 0.0)
		&"BIGD":
			return maxf(_BIGD_ready_time - now, 0.0)
		&"defend":
			return maxf(_defend_ready_time - now, 0.0)
		_:
			return 0.0

func is_ability_ready(ability_id: StringName) -> bool:
	return get_cooldown_left(ability_id) <= 0.0

func _get_defend_duration_seconds() -> float:
	var dur: float = defend_buff_duration
	if RunStateSingleton != null and ("relic_defend_duration_bonus" in RunStateSingleton):
		dur += float(RunStateSingleton.relic_defend_duration_bonus)
	return maxf(dur, 0.01)

func _try_defend() -> void:
	var now: float = _now()
	if now < _defend_ready_time:
		return
	if _carry_locked():
		return
	if _busy:
		return
	
	# Get character type
	var character_name: String = ""
	if _player != null:
		var char_data = _player.get("character_data")
		if char_data != null and char_data is Resource:
			# CharacterData is a Resource with a character_name property
			if "character_name" in char_data:
				character_name = str(char_data.character_name)
	
	if character_name == "":
		push_warning("[PlayerCombat] Cannot use defensive ability: no character selected")
		return
	
	# Set cooldown
	_defend_ready_time = now + defend_cooldown * _cd_mult()
	
	# Note: Animation is played by PlayerControllerV3._start_defend()
	# PlayerCombat only handles the buff application
	
	# Character-specific buff
	var stats: Dictionary[StringName, float] = {}
	var buff_id: StringName = &""
	var duration: float = _get_defend_duration_seconds()
	
	match character_name:
		"Knight":
			# Knight: Damage reduction buff
			var mult: float = clampf(1.0 - knight_damage_reduction, 0.0, 1.0)
			stats[STAT_DAMAGE_TAKEN_MULT] = mult
			buff_id = DEFEND_BUFF_ID_KNIGHT
			pass
		
		"Rogue":
			# Rogue: Dodge chance buff
			stats[STAT_DODGE_CHANCE_ADD] = rogue_dodge_chance
			buff_id = DEFEND_BUFF_ID_ROGUE
			pass
		
		_:
			push_warning("[PlayerCombat] Unknown character: %s" % character_name)
			return
	
	if _buffs != null:
		_buffs.add_buff(buff_id, duration, stats)

func _apply_run_damage_multiplier(base_dmg: int) -> int:
	var dmg: int = base_dmg
	if RunStateSingleton != null and ("player_damage_mult" in RunStateSingleton):
		var mult: float = float(RunStateSingleton.player_damage_mult)
		if mult != 1.0:
			dmg = int(round(float(dmg) * mult))
	return max(dmg, 1)

func _apply_buffs_outgoing_multiplier(base_dmg: int) -> int:
	var dmg: int = base_dmg
	if _buffs == null:
		return dmg
	var mult: float = _buffs.get_mult(STAT_DAMAGE_DEALT_MULT, 1.0)
	if mult != 1.0:
		dmg = int(round(float(dmg) * mult))
	return max(dmg, 1)

func _apply_light_only_multiplier(base_dmg: int) -> int:
	var dmg: int = base_dmg
	if _buffs == null:
		return dmg
	var mult: float = _buffs.get_mult(STAT_LIGHT_DAMAGE_DEALT_MULT, 1.0)
	if mult != 1.0:
		dmg = int(round(float(dmg) * mult))
	return max(dmg, 1)

func _roll_crit() -> bool:
	var c: float = clampf(crit_chance, 0.0, 1.0)
	if c <= 0.0:
		return false
	return randf() < c

func _apply_crit_if_any(dmg: int, was_crit: bool) -> int:
	if not was_crit:
		return dmg
	var m: float = maxf(crit_mult, 1.0)
	return max(int(round(float(dmg) * m)), 1)

func _start_attack(kind: StringName) -> void:
	if _carry_locked():
		return

	var now: float = _now()

	match kind:
		&"light":
			if now < _light_ready_time:
				return
		&"heavy":
			if now < _heavy_ready_time:
				var _cd_left: float = _heavy_ready_time - now
				pass
				return
		&"ultimate":
			if now < _ultimate_ready_time:
				return
		&"BIGD":
			if now < _BIGD_ready_time:
				return
		_:
			return

	var windup: float = 0.0
	var recovery: float = 0.0
	var dmg: int = 0
	var lifetime: float = 0.0
	var anim_name: StringName = &""

	match kind:
		&"light":
			windup = light_windup
			recovery = light_recovery
			dmg = light_damage
			lifetime = 0.08
			anim_name = anim_light
			_light_ready_time = now + (windup + recovery)

		&"heavy":
			windup = heavy_windup
			recovery = heavy_recovery
			dmg = heavy_damage
			lifetime = 0.10
			anim_name = anim_heavy
			_heavy_ready_time = now + maxf(heavy_cooldown, 0.0) * _cd_mult()

		&"ultimate":
			windup = ultimate_windup
			recovery = ultimate_recovery
			dmg = ultimate_damage
			lifetime = 0.14
			anim_name = anim_ultimate

			var ult_cd_mult: float = _get_ultimate_cd_mult_from_relics()
			_ultimate_ready_time = now + ultimate_cooldown * _cd_mult() * ult_cd_mult

		&"BIGD":
			windup = BIGD_windup
			recovery = BIGD_recovery
			dmg = BIGD_damage
			lifetime = 0.08
			_BIGD_ready_time = now + (windup + recovery)

		_:
			return

	_busy = true
	_current_attack_kind = kind

	# New attack seq; invalidates prior timers if any.
	_attack_seq += 1
	var my_seq: int = _attack_seq

	var base_total: float = windup + recovery
	var anim_len: float = _get_anim_duration_seconds(anim_name)
	var total_time: float = maxf(base_total, anim_len)

	attack_started.emit(kind, windup, total_time)

	dmg = _apply_run_damage_multiplier(dmg)
	dmg = _apply_buffs_outgoing_multiplier(dmg)

	# C10: only modifies LIGHT, and consumes the one-shot buff immediately
	if kind == &"light":
		dmg = _apply_light_only_multiplier(dmg)
		if _buffs != null and _buffs.has_buff(BUFF_QUICKSTEP_WRAPS):
			_buffs.remove_buff(BUFF_QUICKSTEP_WRAPS)

	# Crit roll (per swing / hitbox)
	var was_crit: bool = _roll_crit()
	dmg = _apply_crit_if_any(dmg, was_crit)

	_schedule_hit(kind, windup, dmg, lifetime, was_crit, my_seq)
	_end_busy_after(kind, total_time, my_seq)

func _schedule_hit(kind: StringName, delay: float, dmg: int, lifetime: float, was_crit: bool, seq: int) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		# Cancel-safe: do nothing if attack changed/cancelled.
		if seq != _attack_seq:
			return
		if not _busy:
			return
		if _current_attack_kind != kind:
			return
		if _carry_locked():
			return
		_spawn_hitbox(kind, dmg, lifetime, was_crit)
	)

func _end_busy_after(kind: StringName, t: float, seq: int) -> void:
	get_tree().create_timer(t).timeout.connect(func() -> void:
		# Cancel-safe: do nothing if attack changed/cancelled.
		if seq != _attack_seq:
			return
		if not _busy:
			return
		if _current_attack_kind != kind:
			return

		_busy = false
		_current_attack_kind = &""
		attack_ended.emit(kind)
	)

func _spawn_hitbox(kind: StringName, dmg: int, lifetime: float, was_crit: bool) -> void:
	if _carry_locked():
		return
	if hitbox_scene == null or _player == null:
		return

	# ✅ Knight heavy attack: spawn AOE hitboxes (front AND back)
	var selected_character: String = CharacterDatabase.get_selected_character()
	var is_knight_heavy: bool = (kind == &"heavy" and selected_character == "Knight")
	
	if is_knight_heavy:
		# Spawn two hitboxes: one in front, one behind
		_spawn_single_hitbox(1, dmg, lifetime, was_crit, kind, false)   # Front (normal forward bias)
		_spawn_single_hitbox(-1, dmg, lifetime, was_crit, kind, true)  # Back (disable forward bias)
	else:
		# Normal attack: single hitbox in facing direction
		_spawn_single_hitbox(_facing, dmg, lifetime, was_crit, kind, false)

func _spawn_single_hitbox(direction: int, dmg: int, lifetime: float, was_crit: bool, kind: StringName, disable_forward_bias: bool) -> void:
	"""Helper to spawn a single hitbox in a specific direction"""
	if hitbox_scene == null or _player == null:
		return

	var hb: Node = hitbox_scene.instantiate()
	var parent: Node = _player.get_tree().current_scene
	if parent == null:
		return
	parent.add_child(hb)

	# Track for cancellation cleanup.
	_active_hitboxes.append(hb)
	if not hb.tree_exited.is_connected(_on_hitbox_tree_exited):
		hb.tree_exited.connect(_on_hitbox_tree_exited.bind(hb))

	var offset: Vector2 = hitbox_offset
	offset.x *= float(direction)

	var hb2d: Node2D = hb as Node2D
	if hb2d != null:
		hb2d.global_position = _player.global_position + offset

	var size_mult: float = maxf(hitbox_size_mult, 0.01)

	# ✅ Disable forward_only for back hitbox (Knight heavy AOE)
	if disable_forward_bias and hb.has_method("set"):
		hb.set("forward_only", false)

	# IMPORTANT: connect per-instance with a per-instance bound callable
	if hb.has_signal("hit_landed"):
		var cb := Callable(self, "_on_hitbox_hit_landed").bind(was_crit)
		if not hb.hit_landed.is_connected(cb):
			hb.hit_landed.connect(cb)

	# IMPORTANT: push crit/tag into the hitbox so Hurtbox + DamageNumberEmitter can see it
	var tag: StringName = TAG_NONE
	if hb.has_method("configure"):
		# configure(owner, damage, lifetime, knockback, size_mult, mode, kind, tag, is_crit)
		hb.call("configure", _player, dmg, lifetime, 0.0, size_mult, &"", kind, tag, was_crit)

func _on_hitbox_tree_exited(hb: Node) -> void:
	# Remove from tracking when it leaves tree (freed naturally or cancelled).
	var idx: int = _active_hitboxes.find(hb)
	if idx >= 0:
		_active_hitboxes.remove_at(idx)

func _on_hitbox_hit_landed(kind: StringName, target: Object, dmg: int, _source: Object, was_crit: bool) -> void:
	var n: Node = target as Node
	if n == null:
		return

	attack_hit.emit(kind, n, dmg)
	attack_hit_detailed.emit(kind, n, dmg, was_crit)

# ✅ Rogue combo system helpers
func _is_rogue_combo_active() -> bool:
	"""Check if player is Rogue and should use combo system"""
	return CharacterDatabase.get_selected_character() == "Rogue"

func _handle_rogue_combo_input() -> void:
	"""Route light attack input to Rogue combo system"""
	if not is_instance_valid(_player):
		return
	if not _player.has_method("try_rogue_combo_attack"):
		return
	
	_player.call("try_rogue_combo_attack")

func start_rogue_combo_hit(_step: int, damage: int) -> void:
	"""Called by PlayerController to spawn hitbox for a specific combo hit"""
	_busy = true  # Block other attacks (heavy/ultimate) during combo
	_current_attack_kind = &"light"
	
	# New attack seq
	_attack_seq += 1
	
	# Emit attack_started signal for relics (like Shock Charm) to hook into
	var combo_hitbox_lifetime: float = 0.08
	attack_started.emit(&"light", 0.0, combo_hitbox_lifetime)
	
	# Apply damage multipliers (same as normal light attack)
	var final_damage: int = damage
	final_damage = _apply_run_damage_multiplier(final_damage)
	final_damage = _apply_buffs_outgoing_multiplier(final_damage)
	
	# Apply light-only multiplier (C10 Quickstep Wraps support)
	final_damage = _apply_light_only_multiplier(final_damage)
	if _buffs != null and _buffs.has_buff(BUFF_QUICKSTEP_WRAPS):
		_buffs.remove_buff(BUFF_QUICKSTEP_WRAPS)
	
	# Roll for crit
	var was_crit: bool = _roll_crit()
	final_damage = _apply_crit_if_any(final_damage, was_crit)
	
	# Spawn hitbox immediately (no windup for combo hits)
	_spawn_hitbox(&"light", final_damage, 0.08, was_crit)
	
	# No recovery timer - combo system handles timing
	var _char_name: String = CharacterDatabase.get_selected_character()
	pass
