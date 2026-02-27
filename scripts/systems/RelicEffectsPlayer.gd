# res://scripts/RelicEffectsPlayer.gd
extends Node
class_name RelicEffectsPlayer

# -----------------------------
# Relic IDs (must match .tres id fields)
# -----------------------------
const RELIC_OATH_OF_MOMENTUM: StringName = &"c1_oath_of_momentum"
const RELIC_SIPHON_EDGE: StringName = &"c2_siphon_edge"
const RELIC_RUNNERS_SIGIL: StringName = &"c3_runners_sigil"
const RELIC_TEMPERED_GUARD: StringName = &"c4_tempered_guard"
const RELIC_ARC_BATTERY: StringName = &"c5_arc_battery"

const RELIC_BLEEDSTONE: StringName = &"c6_bleedstone"
const RELIC_SHOCK_CHARM: StringName = &"c7_shock_charm" # ✅ (C7 floor pulse)

const RELIC_SURGE_CAPACITOR: StringName = &"c8_surge_capacitor"
const RELIC_ORB_CONDUCTOR: StringName = &"c9_orb_conductor"
const RELIC_QUICKSTEP_WRAPS: StringName = &"c10_quickstep_wraps"
const RELIC_VITAL_THREAD: StringName = &"c11_vital_thread"
const RELIC_HAZARD_BOOTS: StringName = &"c12_hazard_boots"

const RELIC_GLASS_PACT: StringName = &"r1_glass_pact"

# -----------------------------
# R2 Time Slip
# -----------------------------
const RELIC_TIME_SLIP: StringName = &"r2_time_slip"

@export var time_slip_duration: float = 2.00
@export var time_slip_cooldown: float = 6.0
@export var time_slip_debug: bool = true

var _time_slip_cd_left: float = 0.0
var _time_slip_active: bool = false
var _time_slip_restore: Dictionary = {} # Node -> { "proc": bool, "phys": bool }

# -----------------------------
# R3 Execution Loop
# -----------------------------
const RELIC_EXECUTION_LOOP: StringName = &"r3_execution_loop"

@export var execution_loop_roll_recharge_cut: float = 0.40 # reduce remaining recharge by 40%
@export var execution_loop_cooldown: float = 8.0
@export var execution_loop_debug: bool = true

var _execution_loop_cd_left: float = 0.0

# -----------------------------
# R4 Sanctified Barrier (NEW)
# -----------------------------
const RELIC_SANCTIFIED_BARRIER: StringName = &"r4_sanctified_barrier"

@export var sanctified_barrier_shield_pct_max_hp: float = 0.12 # 12% of max HP
@export var sanctified_barrier_duration: float = 6.0
@export var sanctified_barrier_cooldown: float = 10.0
@export var sanctified_barrier_cap_pct_max_hp: float = 0.12 # cap equal to grant by default
@export var sanctified_barrier_debug: bool = true

var _sanctified_barrier_cd_left: float = 0.0

# -----------------------------
# R5 Blood Price (NEW)
# -----------------------------
const RELIC_BLOOD_PRICE: StringName = &"r5_blood_price"

@export var blood_price_threshold_on: float = 0.40  # turns ON below this
@export var blood_price_threshold_off: float = 0.42 # turns OFF above this (hysteresis)
@export var blood_price_damage_dealt_mult: float = 1.25
@export var blood_price_debug: bool = false

var _blood_price_active: bool = false

# -----------------------------
# R6 Orb Surge
# -----------------------------
const RELIC_ORB_SURGE: StringName = &"r6_orb_surge"

@export var orb_surge_attack_speed_mult: float = 1.20 # +20% attack speed while boss vulnerable
@export var orb_surge_debug: bool = true

const BUFF_ORB_SURGE: StringName = &"relic_orb_surge"
const STAT_ATTACK_SPEED_MULT: StringName = &"attack_speed_mult"

var _boss_vulnerable: bool = false
var _orb_surge_applied: bool = false

# -----------------------------
# E2 Ascendant Core
# -----------------------------
const RELIC_ASCENDANT_CORE: StringName = &"e2_ascendant_core"

@export var ascendant_core_extend_seconds: float = 4.0
@export var ascendant_core_debug: bool = true

# -----------------------------
# Buff IDs (owned by this script)
# -----------------------------
const BUFF_OATH_MOMENTUM: StringName = &"relic_oath_momentum"
const BUFF_RUNNERS_SIGIL: StringName = &"relic_runners_sigil"
const BUFF_GLASS_PACT: StringName = &"relic_glass_pact"
const BUFF_VITAL_THREAD: StringName = &"relic_vital_thread"
const BUFF_QUICKSTEP_WRAPS: StringName = &"relic_quickstep_wraps"
const BUFF_SURGE_CAPACITOR: StringName = &"relic_surge_capacitor"
const BUFF_BLOOD_PRICE: StringName = &"relic_blood_price"

# -----------------------------
# Stat keys
# -----------------------------
const STAT_DAMAGE_DEALT_MULT: StringName = &"damage_dealt_mult"
const STAT_DAMAGE_TAKEN_MULT: StringName = &"damage_taken_mult"
const STAT_MAX_HP_MULT: StringName = &"max_hp_mult"
const STAT_DODGE_COOLDOWN_MULT: StringName = &"dodge_cooldown_mult"
const STAT_LIGHT_DAMAGE_DEALT_MULT: StringName = &"light_damage_dealt_mult"

# -----------------------------
# Damage tags (for DamageNumber coloring)
# -----------------------------
const DAMAGE_TAG_SHOCK: StringName = &"shock"

# -----------------------------
# Oath of Momentum tuning
# -----------------------------
@export var oath_bonus_mult: float = 1.12
@export var oath_duration: float = 4.0

# -----------------------------
# Siphon Edge tuning (C2)
# -----------------------------
@export var siphon_edge_heal_pct: float = 0.01 # 1% max HP
@export var siphon_edge_cooldown: float = 1.0  # seconds

# -----------------------------
# Runner’s Sigil tuning (C3)
# -----------------------------
@export var runners_sigil_dodge_cooldown_mult: float = 0.80

# -----------------------------
# Tempered Guard tuning (C4)
# -----------------------------
@export var tempered_guard_duration_bonus: float = 2.0 # +2s Bulwark duration

# -----------------------------
# Arc Battery tuning (C5)
# -----------------------------
@export var arc_battery_ultimate_cd_mult: float = 0.85 # 0.85 = 15% faster ultimate cooldown

# -----------------------------
# Bleedstone tuning (C6)
# -----------------------------
@export var bleedstone_bleed_damage_mult: float = 1.35 # +35% bleed damage

# -----------------------------
# Shock Charm tuning (C7) ✅ floor pulse, flat dmg
# -----------------------------
@export var shock_charm_cooldown: float = 8.0          # seconds
@export var shock_charm_splash_damage: int = 2         # flat damage to OTHER enemies on same floor
@export var shock_charm_debug: bool = false

# -----------------------------
# Surge Capacitor tuning (C8)
# -----------------------------
@export var surge_capacitor_damage_mult: float = 1.12
@export var surge_capacitor_duration: float = 4.0
@export var surge_capacitor_cooldown: float = 6.0

# -----------------------------
# Orb Conductor tuning (C9)
# -----------------------------
@export var orb_conductor_orb_charge_mult: float = 1.20

# -----------------------------
# Quickstep Wraps tuning (C10)
# -----------------------------
@export var quickstep_light_damage_mult: float = 1.25
@export var quickstep_window: float = 2.0

# -----------------------------
# Vital Thread tuning
# -----------------------------
@export var vital_thread_max_hp_mult: float = 1.12

# -----------------------------
# Glass Pact tuning
# -----------------------------
@export var glass_pact_damage_dealt_mult: float = 1.22
@export var glass_pact_damage_taken_mult: float = 1.12

# -----------------------------
# Hazard Boots tuning (C12)
# -----------------------------
@export var hazard_boots_hazard_rise_mult: float = 0.90

# -----------------------------
# Debug
# -----------------------------
@export var debug_logs: bool = false
@export var debug_force_all_relics_enabled: bool = false
@export var debug_force_relic_ids: Array[StringName] = []
@export var debug_force_grants_to_runstate: bool = true # <-- add this toggle
# -----------------------------
# Node paths
# -----------------------------
@export var buffs_path: NodePath = ^"../Buffs"
@export var perfect_dodge_detector_path: NodePath = ^"../PerfectDodgeDetector"
@export var health_path: NodePath = ^"../Health"
@export var combat_path: NodePath = ^"../Combat"

var _buffs: PlayerBuffs = null
var _pdd: PerfectDodgeDetector = null
var _health: PlayerHealth = null
var _combat: Node = null
var _player: Node = null

var _charge: AscensionCharge = null

const PERMA_DURATION: float = 999999.0

# Siphon Edge internal cooldown
var _siphon_cd_left: float = 0.0

# Surge Capacitor internal cooldown
var _surge_cd_left: float = 0.0

# Shock Charm internal cooldown + per-swing gate
var _shock_cd_left: float = 0.0
var _shock_armed_for_this_light: bool = false

# Group used by AscensionCharge (must match AscensionCharge.gd)
const GROUP_ASCENSION_CHARGE: StringName = &"ascension_charge"

func _ready() -> void:
	_player = get_parent()

	_buffs = get_node_or_null(buffs_path) as PlayerBuffs
	_pdd = get_node_or_null(perfect_dodge_detector_path) as PerfectDodgeDetector
	_health = get_node_or_null(health_path) as PlayerHealth
	_combat = get_node_or_null(combat_path)
	_debug_apply_forced_relics_to_runstate()
	
	if _buffs == null:
		push_warning("[RelicEffectsPlayer] Buffs node not found at: %s" % String(buffs_path))
		return

	# Hook perfect dodge for Oath / R2 / R4
	if _pdd == null:
		push_warning("[RelicEffectsPlayer] PerfectDodgeDetector not found at: %s" % String(perfect_dodge_detector_path))
	else:
		if not _pdd.perfect_dodge.is_connected(_on_perfect_dodge):
			_pdd.perfect_dodge.connect(_on_perfect_dodge)
		if debug_logs:
			pass
			#print("[RelicEffectsPlayer] PerfectDodgeDetector hooked: node=", _pdd.name)

	# Hook combat hits + attack lifecycle (needed for C7 gating)
	if _combat == null:
		push_warning("[RelicEffectsPlayer] Combat not found at: %s" % String(combat_path))
	else:
		if _combat.has_signal("attack_hit"):
			if not _combat.attack_hit.is_connected(_on_attack_hit):
				_combat.attack_hit.connect(_on_attack_hit)
		else:
			push_warning("[RelicEffectsPlayer] Combat is missing signal attack_hit (needed for relics).")

		if _combat.has_signal("attack_started"):
			if not _combat.attack_started.is_connected(_on_attack_started):
				_combat.attack_started.connect(_on_attack_started)
		else:
			push_warning("[RelicEffectsPlayer] Combat is missing signal attack_started (C7 gate wants this).")

		if _combat.has_signal("attack_ended"):
			if not _combat.attack_ended.is_connected(_on_attack_ended):
				_combat.attack_ended.connect(_on_attack_ended)

		# R3 wants crit info (preferred: attack_hit_detailed)
		if _combat != null and _combat.has_signal("attack_hit_detailed"):
			if not _combat.attack_hit_detailed.is_connected(_on_attack_hit_detailed):
				_combat.attack_hit_detailed.connect(_on_attack_hit_detailed)

	# Hook roll_started for Quickstep Wraps (C10)
	if _player != null and _player.has_signal("roll_started"):
		if not _player.roll_started.is_connected(_on_roll_started):
			_player.roll_started.connect(_on_roll_started)
	else:
		push_warning("[RelicEffectsPlayer] Parent player missing signal roll_started (C10 won't work).")

	# C8 robust hook: detect AscensionCharge whenever it appears
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)

	_try_hook_existing_charge()

	_rebuild_passive_relic_buffs()
	_refresh_shock_charm_state()

	if RunStateSingleton != null and RunStateSingleton.has_signal("relics_changed"):
		if not RunStateSingleton.relics_changed.is_connected(_on_relics_changed):
			RunStateSingleton.relics_changed.connect(_on_relics_changed)
	else:
		if debug_logs:
			pass
			#print("[RelicEffectsPlayer] NOTE: RunStateSingleton missing signal relics_changed (passives won't hot-rebuild).")

	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Ready. debug_force_all=", debug_force_all_relics_enabled,
			#" debug_force_ids=", debug_force_relic_ids)

func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	_unhook_charge()

func _process(delta: float) -> void:
	if _siphon_cd_left > 0.0:
		_siphon_cd_left = maxf(_siphon_cd_left - delta, 0.0)
	if _surge_cd_left > 0.0:
		_surge_cd_left = maxf(_surge_cd_left - delta, 0.0)
	if _shock_cd_left > 0.0:
		_shock_cd_left = maxf(_shock_cd_left - delta, 0.0)
	if _time_slip_cd_left > 0.0:
		_time_slip_cd_left = maxf(_time_slip_cd_left - delta, 0.0)
	if _execution_loop_cd_left > 0.0:
		_execution_loop_cd_left = maxf(_execution_loop_cd_left - delta, 0.0)
	if _sanctified_barrier_cd_left > 0.0:
		_sanctified_barrier_cd_left = maxf(_sanctified_barrier_cd_left - delta, 0.0)

	# R5: evaluate every frame (super cheap) so we don't depend on unknown health signal names.
	_update_blood_price_state()

func _on_relics_changed() -> void:
	_rebuild_passive_relic_buffs()
	_refresh_shock_charm_state()
	_refresh_orb_surge_state()


func _refresh_shock_charm_state() -> void:
	if not _owns_relic(RELIC_SHOCK_CHARM):
		_shock_cd_left = 0.0
		_shock_armed_for_this_light = false
		return

	# Feel-good: if off cooldown, next LIGHT can proc.
	if _shock_cd_left <= 0.0:
		_shock_armed_for_this_light = false

# -----------------------------
# Ownership helper
# -----------------------------
func _owns_relic(id: StringName) -> bool:
	if debug_force_all_relics_enabled:
		return true
	if not debug_force_relic_ids.is_empty():
		return debug_force_relic_ids.has(id)
	if RunStateSingleton == null:
		return false
	if not RunStateSingleton.has_method("has_relic"):
		return false
	return bool(RunStateSingleton.call("has_relic", id))

# -----------------------------
# R5 Blood Price
# -----------------------------
func _get_health_ratio_safe() -> float:
	# Returns 0..1 if possible, else 1.0 (safe "not low hp")
	if _health == null or not is_instance_valid(_health):
		return 1.0

	# Prefer common property names via Object.get() (returns null if missing)
	var cur_v: Variant = _health.get("current_hp")
	if cur_v == null:
		cur_v = _health.get("hp")
	var max_v: Variant = _health.get("max_hp")

	var cur: float = 0.0
	var mx: float = 0.0

	if cur_v != null:
		cur = float(cur_v)
	if max_v != null:
		mx = float(max_v)

	if mx <= 0.0:
		return 1.0

	return clampf(cur / mx, 0.0, 1.0)

func _update_blood_price_state() -> void:
	if _buffs == null:
		return

	if not _owns_relic(RELIC_BLOOD_PRICE):
		if _blood_price_active:
			_blood_price_active = false
			_buffs.remove_buff(BUFF_BLOOD_PRICE)
		return

	var ratio: float = _get_health_ratio_safe()

	var on_t: float = clampf(blood_price_threshold_on, 0.0, 1.0)
	var off_t: float = clampf(blood_price_threshold_off, 0.0, 1.0)
	if off_t < on_t:
		off_t = on_t

	if (not _blood_price_active) and ratio < on_t:
		_blood_price_active = true

		var mult: float = maxf(blood_price_damage_dealt_mult, 1.0)
		var stats: Dictionary[StringName, float] = {}
		stats[STAT_DAMAGE_DEALT_MULT] = mult
		_buffs.add_buff(BUFF_BLOOD_PRICE, PERMA_DURATION, stats)

		if blood_price_debug or debug_logs:
			pass
			#print("[RelicEffectsPlayer] R5 Blood Price ON: hp_ratio=", ratio, " damage_dealt x", mult)

	elif _blood_price_active and ratio > off_t:
		_blood_price_active = false
		_buffs.remove_buff(BUFF_BLOOD_PRICE)

		if blood_price_debug or debug_logs:
			pass
			#print("[RelicEffectsPlayer] R5 Blood Price OFF: hp_ratio=", ratio, " (off_t=", off_t, ")")

# -----------------------------
# AscensionCharge hook (C8)
# -----------------------------
func _on_tree_node_added(n: Node) -> void:
	var charge: AscensionCharge = n as AscensionCharge
	if charge == null:
		return
	_hook_charge(charge)

func _try_hook_existing_charge() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(GROUP_ASCENSION_CHARGE)
	if not nodes.is_empty():
		var c: AscensionCharge = nodes[0] as AscensionCharge
		if c != null and is_instance_valid(c):
			_hook_charge(c)
			return

	var root: Node = get_tree().current_scene
	if root == null:
		return
	var found: AscensionCharge = _find_first_charge(root)
	if found != null:
		_hook_charge(found)

func _find_first_charge(root: Node) -> AscensionCharge:
	for child in root.get_children():
		var c: AscensionCharge = child as AscensionCharge
		if c != null:
			return c
		var deep: AscensionCharge = _find_first_charge(child)
		if deep != null:
			return deep
	return null

func _unhook_charge() -> void:
	if _charge == null or not is_instance_valid(_charge):
		_charge = null
		return
	if _charge.dropped.is_connected(_on_charge_dropped):
		_charge.dropped.disconnect(_on_charge_dropped)
	if _charge.tree_exiting.is_connected(_on_charge_tree_exiting):
		_charge.tree_exiting.disconnect(_on_charge_tree_exiting)
	_charge = null

func _hook_charge(charge: AscensionCharge) -> void:
	if charge == null or not is_instance_valid(charge):
		return
	if _charge == charge:
		return

	_unhook_charge()
	_charge = charge

	if not _charge.dropped.is_connected(_on_charge_dropped):
		_charge.dropped.connect(_on_charge_dropped)
	if not _charge.tree_exiting.is_connected(_on_charge_tree_exiting):
		_charge.tree_exiting.connect(_on_charge_tree_exiting)

	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Hooked AscensionCharge for C8. node=", _charge.name)

func _on_charge_tree_exiting() -> void:
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] AscensionCharge exiting tree; unhooking C8.")
	_unhook_charge()

func _on_charge_dropped() -> void:
	if not _owns_relic(RELIC_SURGE_CAPACITOR):
		return
	if _buffs == null:
		return
	if _surge_cd_left > 0.0:
		if debug_logs:
			pass
			#print("[RelicEffectsPlayer] C8 drop ignored (ICD): ", _surge_cd_left)
		return

	_surge_cd_left = maxf(surge_capacitor_cooldown, 0.0)
	_apply_surge_capacitor()

func _apply_surge_capacitor() -> void:
	var mult: float = maxf(surge_capacitor_damage_mult, 1.0)
	var dur: float = maxf(surge_capacitor_duration, 0.01)

	var stats: Dictionary[StringName, float] = {}
	stats[STAT_DAMAGE_DEALT_MULT] = mult
	_buffs.add_buff(BUFF_SURGE_CAPACITOR, dur, stats)

	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Surge Capacitor proc: damage_dealt x", mult, " for ", dur, "s (ICD=", _surge_cd_left, ")")

# -----------------------------
# Passive rebuild pipeline
# -----------------------------
func _rebuild_passive_relic_buffs() -> void:
	if _buffs == null:
		return

	_reset_runstate_relic_knobs_and_world_multipliers()

	_buffs.remove_buff(BUFF_RUNNERS_SIGIL)
	_buffs.remove_buff(BUFF_GLASS_PACT)
	_buffs.remove_buff(BUFF_VITAL_THREAD)
	_buffs.remove_buff(BUFF_BLOOD_PRICE)
	_buffs.remove_buff(BUFF_ORB_SURGE)
	_orb_surge_applied = false
	_blood_price_active = false

	# Reset C7 proc state safely
	_shock_armed_for_this_light = false
	_shock_cd_left = 0.0

	if _owns_relic(RELIC_RUNNERS_SIGIL):
		_apply_runners_sigil()
	if _owns_relic(RELIC_GLASS_PACT):
		_apply_glass_pact()
	if _owns_relic(RELIC_VITAL_THREAD):
		_apply_vital_thread()

	if _owns_relic(RELIC_TEMPERED_GUARD):
		_apply_tempered_guard()
	if _owns_relic(RELIC_ARC_BATTERY):
		_apply_arc_battery()
	if _owns_relic(RELIC_BLEEDSTONE):
		_apply_bleedstone()

	if _owns_relic(RELIC_ORB_CONDUCTOR):
		_apply_orb_conductor()
	if _owns_relic(RELIC_HAZARD_BOOTS):
		_apply_hazard_boots()

	if _health != null and is_instance_valid(_health):
		if _health.has_method("recompute_max_hp"):
			_health.call("recompute_max_hp")

	# If we own Shock Charm, start off cooldown (so the very next LIGHT can proc)
	if _owns_relic(RELIC_SHOCK_CHARM):
		_shock_cd_left = 0.0
		_shock_armed_for_this_light = false

	# Evaluate Blood Price immediately after rebuild (so UI/tests feel instant)
	_update_blood_price_state()

	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Passive rebuild complete.",
			#" runners=", _owns_relic(RELIC_RUNNERS_SIGIL),
			#" glass=", _owns_relic(RELIC_GLASS_PACT),
			#" vital=", _owns_relic(RELIC_VITAL_THREAD),
			#" tempered_guard=", _owns_relic(RELIC_TEMPERED_GUARD),
			#" arc_battery=", _owns_relic(RELIC_ARC_BATTERY),
			#" c6_bleedstone=", _owns_relic(RELIC_BLEEDSTONE),
			#" c7_shock=", _owns_relic(RELIC_SHOCK_CHARM),
			#" c8_surge=", _owns_relic(RELIC_SURGE_CAPACITOR),
			#" quickstep=", _owns_relic(RELIC_QUICKSTEP_WRAPS),
			#" orb=", _owns_relic(RELIC_ORB_CONDUCTOR),
			#" hazard=", _owns_relic(RELIC_HAZARD_BOOTS),
			#" r4_sanctified=", _owns_relic(RELIC_SANCTIFIED_BARRIER),
			#" r5_blood_price=", _owns_relic(RELIC_BLOOD_PRICE)
		#)

func _reset_runstate_relic_knobs_and_world_multipliers() -> void:
	if RunStateSingleton == null:
		return

	# World multipliers you already drive from relics
	if "orb_charge_mult" in RunStateSingleton:
		RunStateSingleton.orb_charge_mult = 1.0
	if "hazard_rise_mult" in RunStateSingleton:
		RunStateSingleton.hazard_rise_mult = 1.0

	# Relic knobs (run-long) – reset before re-applying owned relics
	if "relic_defend_duration_bonus" in RunStateSingleton:
		RunStateSingleton.relic_defend_duration_bonus = 0.0
	if "relic_ultimate_gain_mult" in RunStateSingleton:
		RunStateSingleton.relic_ultimate_gain_mult = 1.0
	if "relic_bleed_damage_mult" in RunStateSingleton:
		RunStateSingleton.relic_bleed_damage_mult = 1.0

# -----------------------------
# Event relics + C7 gating
# -----------------------------
func _on_attack_started(kind: StringName, _windup: float, _total_time: float) -> void:
	# Gate: only ONE proc per LIGHT attack
	if kind == &"light" and _owns_relic(RELIC_SHOCK_CHARM) and _shock_cd_left <= 0.0:
		_shock_armed_for_this_light = true
		if debug_logs or shock_charm_debug:
			pass
			#print("[RelicEffectsPlayer] C7 Shock Charm armed for this LIGHT (off CD).")
	else:
		_shock_armed_for_this_light = false

func _on_attack_ended(kind: StringName) -> void:
	# If the light swing ends without hitting anything, clear arming so it doesn't carry to next light.
	if kind == &"light":
		_shock_armed_for_this_light = false

func _on_perfect_dodge(trigger_source: Node, _attempted_damage: int) -> void:
	if debug_logs:
		var _src := "NULL" if trigger_source == null else String(trigger_source.name)
		#print("[RelicEffectsPlayer] perfect_dodge RECEIVED. source=", _src)

	# R4 Sanctified Barrier
	if _owns_relic(RELIC_SANCTIFIED_BARRIER):
		_try_proc_sanctified_barrier()

	# R2 Time Slip
	if _owns_relic(RELIC_TIME_SLIP):
		_try_proc_time_slip()

	# Oath
	if _owns_relic(RELIC_OATH_OF_MOMENTUM):
		_apply_oath_of_momentum("perfect_dodge")

func _try_proc_sanctified_barrier() -> void:
	if _health == null or not is_instance_valid(_health):
		return
	if _sanctified_barrier_cd_left > 0.0:
		return

	var pct: float = clampf(sanctified_barrier_shield_pct_max_hp, 0.0, 2.0)
	var cap_pct: float = clampf(sanctified_barrier_cap_pct_max_hp, 0.0, 2.0)
	var dur: float = maxf(sanctified_barrier_duration, 0.01)

	var maxhp: int = maxi(_health.max_hp, 1)
	var grant: int = int(round(float(maxhp) * pct))
	grant = maxi(grant, 1)

	var cap: int = int(round(float(maxhp) * cap_pct))
	cap = maxi(cap, grant)

	_sanctified_barrier_cd_left = maxf(sanctified_barrier_cooldown, 0.01)

	var _gained: int = _health.add_shield(grant, dur, cap, true)

	if sanctified_barrier_debug or debug_logs:
		pass
		#print("[RelicEffectsPlayer] R4 Sanctified Barrier PROC: +", _gained, " shield (grant=", grant,
			#" cap=", cap, ") for ", dur, "s (CD=", _sanctified_barrier_cd_left, ")")

func _on_roll_started(_character_name: String, _facing_direction: int) -> void:
	if not _owns_relic(RELIC_QUICKSTEP_WRAPS):
		return
	_apply_quickstep_wraps()

func _on_attack_hit(kind: StringName, target: Node, _dealt_damage: int) -> void:
	# ---- C2 Siphon Edge ----
	if kind == &"heavy":
		if _owns_relic(RELIC_SIPHON_EDGE) and _health != null and is_instance_valid(_health) and _siphon_cd_left <= 0.0:
			_siphon_cd_left = maxf(siphon_edge_cooldown, 0.0)
			var pct: float = clampf(siphon_edge_heal_pct, 0.0, 1.0)
			if pct > 0.0:
				_health.heal_percent(pct)
			if debug_logs:
				pass
				#print("[RelicEffectsPlayer] Siphon Edge proc: heal_pct=", pct, " cd=", _siphon_cd_left)

	# ---- C7 Shock Charm: floor pulse ----
	if kind != &"light":
		return
	if not _owns_relic(RELIC_SHOCK_CHARM):
		return
	if not _shock_armed_for_this_light:
		return
	if _shock_cd_left > 0.0:
		return

	var hb: Hurtbox = target as Hurtbox
	if hb == null:
		return

	_shock_armed_for_this_light = false
	_shock_cd_left = maxf(shock_charm_cooldown, 0.01)

	var _hit_count: int = _shock_pulse_floor_from_hurtbox(hb)

	if debug_logs or shock_charm_debug:
		pass
		#print("[RelicEffectsPlayer] C7 Shock Charm proc: floor_pulse targets_hit=", _hit_count, " splash=", shock_charm_splash_damage, " cd=", _shock_cd_left)

func _shock_pulse_floor_from_hurtbox(primary_hurtbox: Hurtbox) -> int:
	if primary_hurtbox == null or not is_instance_valid(primary_hurtbox):
		return 0

	var splash: int = maxi(shock_charm_splash_damage, 1)

	# Find enemy root that belongs to a floor group (floorX_enemies)
	var enemy_root: Node = primary_hurtbox.get_parent()
	for _i in 3:
		if enemy_root == null:
			break
		if _get_floor_group(enemy_root) != &"":
			break
		enemy_root = enemy_root.get_parent()

	if enemy_root == null:
		return 0

	var floor_group: StringName = _get_floor_group(enemy_root)
	if floor_group == &"":
		return 0
	if shock_charm_debug:
		pass

	var nodes: Array[Node] = get_tree().get_nodes_in_group(floor_group)
	var hit_count: int = 0

	for n in nodes:
		if n == null or not is_instance_valid(n):
			continue
		if n == enemy_root:
			continue
		if _deal_damage_to_enemy_root(n, splash, DAMAGE_TAG_SHOCK):
			hit_count += 1
		if shock_charm_debug:
			pass

	return hit_count

func _get_floor_group(n: Node) -> StringName:
	if n == null:
		return &""
	for g in n.get_groups():
		var s: String = String(g)
		if s.begins_with("floor") and s.ends_with("_enemies"):
			return StringName(s)
	return &""

func _call_take_damage_tagged(receiver: Node, amount: int, source: Node, tag: StringName) -> bool:
	if receiver == null or not is_instance_valid(receiver):
		return false
	if not receiver.has_method("take_damage"):
		return false

	var argc: int = receiver.get_method_argument_count("take_damage")
	if argc >= 3:
		receiver.call("take_damage", amount, source, tag)
		return true
	if argc >= 2:
		receiver.call("take_damage", amount, source)
		return true
	if argc >= 1:
		receiver.call("take_damage", amount)
		return true
	return false

func _deal_damage_to_enemy_root(enemy_root: Node, amount: int, tag: StringName) -> bool:
	if enemy_root == null or amount <= 0:
		return false

	# Preferred: Health child
	var h: Node = enemy_root.get_node_or_null("Health")
	if h != null:
		if _call_take_damage_tagged(h, amount, _player, tag):
			return true

	# Next: Hurtbox child (will forward) — tag only if Hurtbox supports 3 args (yours doesn't, so it will safely fall back)
	var hb: Node = enemy_root.get_node_or_null("Hurtbox")
	if hb != null:
		if _call_take_damage_tagged(hb, amount, _player, tag):
			return true

	# Fallback: direct (enemy_root itself)
	if _call_take_damage_tagged(enemy_root, amount, _player, tag):
		return true

	return false

# -----------------------------
# Buff-based relics
# -----------------------------
func _apply_oath_of_momentum(_reason: String) -> void:
	var mult: float = maxf(oath_bonus_mult, 1.0)
	var dur: float = maxf(oath_duration, 0.01)

	var stats: Dictionary[StringName, float] = {}
	stats[STAT_DAMAGE_DEALT_MULT] = mult
	_buffs.add_buff(BUFF_OATH_MOMENTUM, dur, stats)

	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Oath applied (", _reason, "): x", mult, " for ", dur, "s")

func _apply_runners_sigil() -> void:
	var cd_mult: float = clampf(runners_sigil_dodge_cooldown_mult, 0.10, 1.0)
	var stats: Dictionary[StringName, float] = {}
	stats[STAT_DODGE_COOLDOWN_MULT] = cd_mult
	_buffs.add_buff(BUFF_RUNNERS_SIGIL, PERMA_DURATION, stats)
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Runner's Sigil applied: dodge_cooldown_mult x", cd_mult)
		#print("[RelicEffectsPlayer] Runner’s Sigil applied: dodge_cooldown_mult x", cd_mult)

func _apply_glass_pact() -> void:
	var dealt: float = maxf(glass_pact_damage_dealt_mult, 1.0)
	var taken: float = maxf(glass_pact_damage_taken_mult, 1.0)
	var stats: Dictionary[StringName, float] = {}
	stats[STAT_DAMAGE_DEALT_MULT] = dealt
	stats[STAT_DAMAGE_TAKEN_MULT] = taken
	_buffs.add_buff(BUFF_GLASS_PACT, PERMA_DURATION, stats)
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Glass Pact applied: dealt x", dealt, " taken x", taken)

func _apply_vital_thread() -> void:
	var mult: float = maxf(vital_thread_max_hp_mult, 1.0)
	var stats: Dictionary[StringName, float] = {}
	stats[STAT_MAX_HP_MULT] = mult
	_buffs.add_buff(BUFF_VITAL_THREAD, PERMA_DURATION, stats)
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Vital Thread applied: max_hp x", mult)

func _apply_quickstep_wraps() -> void:
	var mult: float = maxf(quickstep_light_damage_mult, 1.0)
	var dur: float = maxf(quickstep_window, 0.01)
	var stats: Dictionary[StringName, float] = {}
	stats[STAT_LIGHT_DAMAGE_DEALT_MULT] = mult
	_buffs.add_buff(BUFF_QUICKSTEP_WRAPS, dur, stats)
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Quickstep Wraps armed: next LIGHT x", mult, " for ", dur, "s")

func _on_attack_hit_detailed(kind: StringName, target: Node, _dealt_damage: int, was_crit: bool) -> void:
	if kind != &"heavy":
		return
	if not was_crit:
		return
	if not _owns_relic(RELIC_EXECUTION_LOOP):
		return
	if _execution_loop_cd_left > 0.0:
		return

	# ✅ Only proc on actual enemy hurtboxes (prevents InteractArea collisions)
	var hb: Hurtbox = target as Hurtbox
	if hb == null:
		return

	_execution_loop_cd_left = maxf(execution_loop_cooldown, 0.01)

	var pc: Node = _player
	var _before: float = 0.0
	var _after: float = 0.0

	if pc != null and pc.has_method("get_roll_next_charge_time_left"):
		_before = float(pc.call("get_roll_next_charge_time_left"))

	var _applied: bool = false
	if pc != null and pc.has_method("reduce_roll_recharge_remaining"):
		_applied = bool(pc.call("reduce_roll_recharge_remaining", clampf(execution_loop_roll_recharge_cut, 0.0, 0.95)))

	if pc != null and pc.has_method("get_roll_next_charge_time_left"):
		_after = float(pc.call("get_roll_next_charge_time_left"))

	if execution_loop_debug or debug_logs:
		pass
		#print("[RelicEffectsPlayer] R3 Execution Loop PROC: heavy_crit -> reduce roll recharge by ",
			#execution_loop_roll_recharge_cut * 100.0, "% applied=", _applied,
			#" next_charge_left ", _before, " -> ", _after,
			#" (CD=", _execution_loop_cd_left, ")")

# -----------------------------
# RunState-driven relics
# -----------------------------
func _apply_tempered_guard() -> void:
	if RunStateSingleton == null:
		return
	if not ("relic_defend_duration_bonus" in RunStateSingleton):
		return
	var bonus: float = maxf(tempered_guard_duration_bonus, 0.0)
	RunStateSingleton.relic_defend_duration_bonus = bonus
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Tempered Guard applied: defend_duration_bonus +", bonus, "s")

func _apply_arc_battery() -> void:
	if RunStateSingleton == null:
		return
	if not ("relic_ultimate_gain_mult" in RunStateSingleton):
		return
	var mult: float = clampf(arc_battery_ultimate_cd_mult, 0.10, 10.0)
	RunStateSingleton.relic_ultimate_gain_mult = mult
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Arc Battery applied: ultimate_cd_mult x", mult)

func _apply_bleedstone() -> void:
	if RunStateSingleton == null:
		return
	if not ("relic_bleed_damage_mult" in RunStateSingleton):
		return
	var mult: float = clampf(bleedstone_bleed_damage_mult, 0.0, 10.0)
	RunStateSingleton.relic_bleed_damage_mult = mult
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Bleedstone applied: relic_bleed_damage_mult x", mult)

func _apply_orb_conductor() -> void:
	if RunStateSingleton == null:
		return
	var mult: float = clampf(orb_conductor_orb_charge_mult, 0.10, 10.0)
	RunStateSingleton.orb_charge_mult = mult
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Orb Conductor applied: orb_charge_mult x", mult)

func _apply_hazard_boots() -> void:
	if RunStateSingleton == null:
		return
	var mult: float = clampf(hazard_boots_hazard_rise_mult, 0.10, 10.0)
	RunStateSingleton.hazard_rise_mult = mult
	if debug_logs:
		pass
		#print("[RelicEffectsPlayer] Hazard Boots applied: hazard_rise_mult x", mult)

func _try_proc_time_slip() -> void:
	if _time_slip_active:
		return
	if _time_slip_cd_left > 0.0:
		return

	_time_slip_cd_left = maxf(time_slip_cooldown, 0.01)
	_apply_time_slip()

func _apply_time_slip() -> void:
	var dur: float = maxf(time_slip_duration, 0.01)

	_time_slip_active = true
	_time_slip_restore.clear()

	var _affected: int = 0
	for n in _get_time_slip_targets():
		if n == null or not is_instance_valid(n):
			continue

		# Don’t freeze the player if they accidentally share a group
		if n.is_in_group(&"player"):
			continue

		# Save previous processing flags
		_time_slip_restore[n] = {
			"proc": n.is_processing(),
			"phys": n.is_physics_processing()
		}

		# Freeze AI/behavior
		n.set_process(false)
		n.set_physics_process(false)

		# If it’s a CharacterBody2D, also zero velocity to stop drift
		if n is CharacterBody2D:
			(n as CharacterBody2D).velocity = Vector2.ZERO

		_affected += 1

	if time_slip_debug:
		pass
		#print("[RelicEffectsPlayer] R2 Time Slip PROC: froze ", _affected, " enemies for ", dur, "s (CD=", _time_slip_cd_left, ")")

	# ✅ FIX: no standalone lambda (prevents the spam error you hit)
	var t := get_tree().create_timer(dur)
	t.timeout.connect(_restore_time_slip_targets)

func _restore_time_slip_targets() -> void:
	for n in _time_slip_restore.keys():
		if n == null or not is_instance_valid(n):
			continue
		var data: Dictionary = _time_slip_restore[n]
		n.set_process(bool(data.get("proc", true)))
		n.set_physics_process(bool(data.get("phys", true)))

	_time_slip_restore.clear()
	_time_slip_active = false

func _get_time_slip_targets() -> Array[Node]:
	# We’ll target the same floor grouping scheme you use elsewhere.
	var groups: Array[StringName] = [
		&"floor1_enemies",
		&"floor2_enemies",
		&"floor3_enemies",
		&"floor4_enemies",
		&"floor5_enemies",
		&"enemies",
		&"enemy"
	]

	var out: Array[Node] = []
	var seen: Dictionary = {}

	for g in groups:
		var nodes: Array[Node] = get_tree().get_nodes_in_group(g)
		for n in nodes:
			if n == null or not is_instance_valid(n):
				continue
			if seen.has(n):
				continue
			seen[n] = true
			out.append(n)

	return out
	
# -----------------------------
# Boss vulnerable hook (R6)
# Call this from your boss/encounter controller whenever vulnerability toggles.
# -----------------------------
func set_boss_vulnerable(v: bool) -> void:
	_boss_vulnerable = v
	_refresh_orb_surge_state()

func _refresh_orb_surge_state() -> void:
	if _buffs == null:
		return

	# If we don't own the relic, ensure it's off.
	if not _owns_relic(RELIC_ORB_SURGE):
		if _orb_surge_applied:
			_buffs.remove_buff(BUFF_ORB_SURGE)
			_orb_surge_applied = false
		return

	# Owned: apply while vulnerable, remove otherwise
	if _boss_vulnerable:
		if not _orb_surge_applied:
			var mult: float = maxf(orb_surge_attack_speed_mult, 0.05)
			var stats: Dictionary[StringName, float] = {}
			stats[STAT_ATTACK_SPEED_MULT] = mult
			_buffs.add_buff(BUFF_ORB_SURGE, PERMA_DURATION, stats)
			_orb_surge_applied = true

			if orb_surge_debug or debug_logs:
				pass
				#print("[RelicEffectsPlayer] R6 Orb Surge ON: attack_speed x", mult)
	else:
		if _orb_surge_applied:
			_buffs.remove_buff(BUFF_ORB_SURGE)
			_orb_surge_applied = false

			if orb_surge_debug or debug_logs:
				pass
				#print("[RelicEffectsPlayer] R6 Orb Surge OFF")

# -----------------------------
# Orb socket hook (E2)
# Called by EncounterController right after DPS starts.
# -----------------------------
func on_orb_socketed(encounter: Node) -> void:
	if not _owns_relic(RELIC_ASCENDANT_CORE):
		return
	if encounter == null or not is_instance_valid(encounter):
		return
	if not encounter.has_method("extend_dps_window"):
		return

	var extra: float = maxf(ascendant_core_extend_seconds, 0.0)
	if extra <= 0.0:
		return

	var applied: bool = bool(encounter.call("extend_dps_window", extra, "E2 Ascendant Core"))
	if applied and (ascendant_core_debug or debug_logs):
		pass
		#print("[RelicEffectsPlayer] E2 Ascendant Core PROC: +", extra, "s DPS window")
		
func _debug_apply_forced_relics_to_runstate() -> void:
	if not debug_force_grants_to_runstate:
		return
	if debug_force_relic_ids.is_empty():
		return
	if RunStateSingleton == null:
		push_warning("[RelicEffectsPlayer] RunStateSingleton NULL; cannot debug-grant relics.")
		return
	if not RunStateSingleton.has_method("add_relic"):
		push_warning("[RelicEffectsPlayer] RunState missing add_relic; cannot debug-grant relics.")
		return

	for id in debug_force_relic_ids:
		if id == &"":
			continue
		# Avoid spam / duplicates
		if RunStateSingleton.has_method("has_relic") and bool(RunStateSingleton.call("has_relic", id)):
			continue
		var ok: bool = bool(RunStateSingleton.call("add_relic", id))
		if ok:
			pass
			#print("[RelicEffectsPlayer] DEBUG granted relic into RunState: ", id)
