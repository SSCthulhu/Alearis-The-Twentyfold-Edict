extends Area2D
class_name AttackHitbox

# Legacy signal (do not break existing connections)
signal hit_landed(kind: StringName, target: Object, damage: int, source: Object)

# NEW: extended signal that includes the hitbox instance
signal hit_landed_ex(hitbox: AttackHitbox, kind: StringName, target: Object, damage: int, source: Object)

@export var damage: int = 5
@export var lifetime: float = 0.08
@export var knockback: float = 0.0

# What attack spawned this hitbox (light/heavy/ultimate/etc.)
var attack_kind: StringName = &""

# NEW: hit metadata used by Hurtbox -> Health -> DamageNumberEmitter
var hit_tag: StringName = &""       # e.g. &"shock", &"bleed"
var is_crit: bool = false           # crit styling + forwarding

# Forward-bias options
@export var forward_only: bool = true
@export var forward_bias_px: float = 28.0
@export var facing_from_owner_velocity: bool = true
@export var facing_from_owner_flip_h: bool = true

@export var debug_hits: bool = false  # ✅ DISABLED for clean logs (AttackHitbox spams console)

# Rectangle presets (full size, not extents)
@export var size_horizontal: Vector2 = Vector2(80.0, 34.0)
@export var size_vertical: Vector2 = Vector2(44.0, 86.0)
@export var size_thrust: Vector2 = Vector2(92.0, 26.0)

@export var default_mode: StringName = &"horizontal" # "horizontal", "vertical", "thrust"

@onready var _col: CollisionShape2D = $CollisionShape2D

var owner_node: Node = null
var _hit_targets: Dictionary = {}
var _timer_started: bool = false

func configure(
	p_owner: Node,
	p_damage: int,
	p_lifetime: float,
	p_knockback: float = 0.0,
	size_mult: float = 1.0,
	mode: StringName = &"",
	p_kind: StringName = &"",          # existing optional
	p_tag: StringName = &"",           # NEW optional (back-compat)
	p_is_crit: bool = false            # NEW optional (back-compat)
) -> void:
	owner_node = p_owner
	damage = p_damage
	lifetime = p_lifetime
	knockback = p_knockback

	attack_kind = p_kind
	hit_tag = p_tag
	is_crit = p_is_crit

	if not is_in_group("player_hitbox"):
		add_to_group("player_hitbox")

	# Metadata for other systems (Hurtbox reads these)
	set_meta("damage", damage)
	set_meta("source", owner_node)
	set_meta("kind", attack_kind)
	set_meta("tag", hit_tag)
	set_meta("is_crit", is_crit)

	if mode == &"":
		mode = default_mode

	_apply_rect_size(size_mult, mode)
	_apply_forward_bias()
	_start_timer_if_needed()

	if debug_hits:
		pass

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_start_timer_if_needed()

	if debug_hits:
		pass

func _start_timer_if_needed() -> void:
	if _timer_started:
		return
	_timer_started = true
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _get_facing() -> int:
	var facing: int = 1

	# A) infer from owner velocity
	if facing_from_owner_velocity and owner_node is CharacterBody2D:
		var cb: CharacterBody2D = owner_node as CharacterBody2D
		if absf(cb.velocity.x) > 1.0:
			facing = 1 if cb.velocity.x > 0.0 else -1

	# B) infer from AnimatedSprite2D flip_h
	if facing_from_owner_flip_h and owner_node != null:
		var vis := owner_node.get_node_or_null("Visual/BodyVisual") as AnimatedSprite2D
		if vis != null:
			facing = -1 if vis.flip_h else 1

	# C) explicit owner property "facing"
	if owner_node != null:
		var v: Variant = owner_node.get("facing")
		if v is int:
			facing = int(v)

	return facing

func _apply_forward_bias() -> void:
	if not forward_only:
		return
	if _col == null:
		return

	var facing: int = _get_facing()
	var p: Vector2 = _col.position
	p.x = absf(forward_bias_px) * float(facing)
	_col.position = p

func _apply_rect_size(mult: float, mode: StringName) -> void:
	if _col == null or _col.shape == null:
		if debug_hits:
			pass
		return

	var rect: RectangleShape2D = _col.shape as RectangleShape2D
	if rect == null:
		if debug_hits:
			pass
		return

	mult = maxf(mult, 0.01)

	var base: Vector2 = size_horizontal
	match mode:
		&"vertical":
			base = size_vertical
		&"thrust":
			base = size_thrust
		_:
			base = size_horizontal

	rect.size = base * mult

func _mark_hit(target: Object) -> bool:
	if target == null:
		return false
	if _hit_targets.has(target):
		return false
	_hit_targets[target] = true
	return true

func set_crit(v: bool) -> void:
	is_crit = v
	set_meta("is_crit", is_crit)

func set_tag(t: StringName) -> void:
	hit_tag = t
	set_meta("tag", hit_tag)

func _emit_hit(target: Object) -> void:
	# Legacy + extended signals (extended is what RelicEffectsPlayer should use)
	hit_landed.emit(attack_kind, target, damage, owner_node)
	hit_landed_ex.emit(self, attack_kind, target, damage, owner_node)

	if debug_hits:
		pass

func _on_area_entered(area: Area2D) -> void:
	if not _mark_hit(area):
		return

	_emit_hit(area)

	if debug_hits:
		pass

	# IMPORTANT: RelicEffectsPlayer can mark crit/tag synchronously via hit_landed_ex
	# before we call apply_hit_from_area below.

	if area.has_method("apply_hit_from_area"):
		area.call("apply_hit_from_area", self)
		if debug_hits:
			pass
		return

	# Fallback: if target directly implements take_damage, we can pass only legacy args here.
	# (Most of your damage routing should go through Hurtbox.apply_hit_from_area anyway.)
	if area.has_method("take_damage"):
		area.call("take_damage", damage, owner_node)
		if debug_hits:
			pass

func _on_body_entered(body: Node) -> void:
	if not _mark_hit(body):
		return

	_emit_hit(body)

	if debug_hits:
		pass

	if body.has_method("take_damage"):
		body.call("take_damage", damage, owner_node)
		if debug_hits:
			pass
