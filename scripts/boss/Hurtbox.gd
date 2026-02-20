# res://scripts/Hurtbox.gd
extends Area2D
class_name Hurtbox

@export var boss_path: NodePath = ^".."
@export var receiver_path: NodePath = NodePath("") # set to ../Health for enemies
@export var require_group: StringName = &"player_hitbox"
@export var invulnerable: bool = false

@export var debug_damage: bool = false

# -----------------------------
# Bleed baseline tuning (v1)
# -----------------------------
@export var enable_heavy_bleed: bool = true
@export var bleed_duration: float = 4.0
@export var bleed_tick_interval: float = 0.5
@export var bleed_base_tick_damage: int = 2

# Optional: where to look for an EnemyStatusEffects node
@export var status_effects_path: NodePath = ^"../StatusEffects"

const ATTACK_KIND_HEAVY: StringName = &"heavy"
const GROUP_HURTBOX: StringName = &"hurtbox"

# Damage tags
const TAG_BLEED: StringName = &"bleed"

# Boss group (BossController adds itself to this)
const GROUP_BOSS: StringName = &"boss"

func _ready() -> void:
	monitoring = true
	monitorable = true
	if not is_in_group(GROUP_HURTBOX):
		add_to_group(GROUP_HURTBOX)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(hit_area: Area2D) -> void:
	apply_hit_from_area(hit_area)

func apply_hit_from_area(hit_area: Area2D) -> void:
	if invulnerable:
		if debug_damage:
			pass
		return
	if hit_area == null:
		return

	# Group filter
	if require_group != &"" and not hit_area.is_in_group(require_group):
		if debug_damage:
			pass
		return

	var dmg: int = 0
	if hit_area.has_meta("damage"):
		dmg = int(hit_area.get_meta("damage"))
	elif hit_area.has_method("get_damage"):
		dmg = int(hit_area.call("get_damage"))

	if dmg <= 0:
		if debug_damage:
			pass
		return

	var src: Node = _resolve_source(hit_area)

	# Attack kind
	var attack_kind: StringName = &""
	if hit_area.has_meta("kind"):
		var k: Variant = hit_area.get_meta("kind")
		if k is StringName:
			attack_kind = k
		elif k is String:
			attack_kind = StringName(String(k))

	# Tag + crit (if provided by the hitbox)
	var tag: StringName = &""
	if hit_area.has_meta("tag"):
		var t: Variant = hit_area.get_meta("tag")
		if t is StringName:
			tag = t
		elif t is String:
			tag = StringName(String(t))

	var is_crit: bool = false
	if hit_area.has_meta("is_crit"):
		is_crit = bool(hit_area.get_meta("is_crit"))

	if debug_damage:
		pass

	# Forward the hit (tag/crit supported)
	var receiver: Node = _forward_damage(dmg, src, tag, is_crit)

	# Heavy → apply/refresh bleed
	if enable_heavy_bleed and attack_kind == ATTACK_KIND_HEAVY:
		_apply_bleed_refresh(receiver, src)

func take_damage(amount: int, source: Node = null) -> void:
	# Back-compat entry point
	if invulnerable or amount <= 0:
		return
	_forward_damage(amount, _resolve_source(source), &"", false)

func take_damage_tagged(amount: int, source: Node = null, tag: StringName = &"", is_crit: bool = false) -> void:
	# Optional public API (tag + crit)
	if invulnerable or amount <= 0:
		return
	_forward_damage(amount, _resolve_source(source), tag, is_crit)

# -----------------------------
# Internals
# -----------------------------
func _forward_damage(amount: int, source: Node, tag: StringName, is_crit: bool) -> Node:
	pass
	pass
	
	# 0) Boss-first routing:
	# If boss_path points to a node in group "boss", ALWAYS route damage there so boss HP/UI/death logic works.
	var boss: Node = get_node_or_null(boss_path)
	pass
	if boss != null:
		pass
	
	if boss != null and is_instance_valid(boss) and boss.is_in_group(GROUP_BOSS) and boss.has_method("take_damage"):
		pass
		_call_take_damage(boss, amount, source, tag, is_crit)
		return boss

	# 1) Prefer explicit receiver (enemies: ../Health)
	if receiver_path != NodePath(""):
		var receiver: Node = get_node_or_null(receiver_path)
		pass
		if receiver != null:
			pass
		if receiver != null and receiver.has_method("take_damage"):
			pass
			_call_take_damage(receiver, amount, source, tag, is_crit)
			return receiver
		else:
			pass

	# 2) Non-boss parent forwarding (if it has take_damage)
	if boss != null and boss.has_method("take_damage"):
		_call_take_damage(boss, amount, source, tag, is_crit)
		return boss
	elif debug_damage:
		pass

	# 3) BossHealth fallback (legacy)
	var bh: Node = get_node_or_null(^"../BossHealth")
	if bh != null and bh.has_method("take_damage"):
		if debug_damage:
			pass
		_call_take_damage(bh, amount, source, tag, is_crit)
		return bh

	if debug_damage:
		pass

	return null

func _call_take_damage(receiver: Node, amount: int, source: Node, tag: StringName, is_crit: bool) -> void:
	# Godot 4: method overloads don’t exist; inspect arg count.
	var argc: int = receiver.get_method_argument_count("take_damage")
	pass

	# Prefer (amount, source, tag, is_crit)
	if argc >= 4:
		pass
		receiver.call("take_damage", amount, source, tag, is_crit)
		return

	# Next: (amount, source, tag) only if tag non-empty
	if argc >= 3 and tag != &"":
		receiver.call("take_damage", amount, source, tag)
		return

	# Next: (amount, source)
	if argc >= 2:
		receiver.call("take_damage", amount, source)
		return

	# Fallback: (amount)
	receiver.call("take_damage", amount)

func _apply_bleed_refresh(receiver: Node, source: Node) -> void:
	if receiver == null or not is_instance_valid(receiver):
		return

	var dur: float = maxf(bleed_duration, 0.01)
	var tick: float = maxf(bleed_tick_interval, 0.01)
	var base_tick: int = maxi(bleed_base_tick_damage, 1)

	var se: EnemyStatusEffects = null

	# Try explicit path first
	var se_node: Node = null
	if status_effects_path != NodePath(""):
		se_node = get_node_or_null(status_effects_path)
	se = se_node as EnemyStatusEffects

	# If not found, create it on the receiver parent
	if se == null:
		var parent_node: Node = receiver.get_parent()
		if parent_node == null:
			parent_node = get_parent()

		if parent_node != null:
			se = parent_node.get_node_or_null("StatusEffects") as EnemyStatusEffects
			if se == null:
				se = EnemyStatusEffects.new()
				se.name = "StatusEffects"
				parent_node.add_child(se)

	if se == null:
		if debug_damage:
			pass
		return

	se.set_receiver(receiver)
	if se.has_method("set_source"):
		se.call("set_source", source)

	se.apply_bleed_refresh(base_tick, dur, tick)

	if debug_damage:
		pass

func _resolve_source(source: Node) -> Node:
	if source is Area2D:
		var a: Area2D = source as Area2D
		if a.has_meta("source"):
			var meta_node: Node = a.get_meta("source") as Node
			if meta_node != null:
				return meta_node
	return source
