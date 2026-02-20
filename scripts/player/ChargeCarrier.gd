extends Node
class_name ChargeCarrier

signal carrying_changed(is_carrying: bool)

enum DropReason { MANUAL, FORCED_BY_DAMAGE }

@export var player_health_path: NodePath
@export var interact_area_path: NodePath
@export var debuffs_path: NodePath
@export var hold_point_path: NodePath = ^"../Visual/HoldPoint"

@export var carry_offset: Vector2 = Vector2(0, -24)
@export var drop_offset: Vector2 = Vector2.ZERO

@export var manual_drop_damage: int = 10
@export var forced_drop_damage: int = 0
@export var drop_damage_ignores_invuln: bool = true

@export var drop_volatility_duration: float = 2.5
@export var drop_on_damage: bool = false

@export var pickup_radius_fallback: float = 40.0
@export var pickup_mask_fallback: int = 1

var carried_charge: AscensionCharge = null

@onready var _health: PlayerHealth = get_node_or_null(player_health_path) as PlayerHealth
@onready var _player: Node2D = get_parent() as Node2D
@onready var _interact_area: Area2D = get_node_or_null(interact_area_path) as Area2D
@onready var _debuffs: PlayerDebuffs = get_node_or_null(debuffs_path) as PlayerDebuffs
@onready var _hold_point: Marker2D = get_node_or_null(hold_point_path) as Marker2D

var _pickup_radius: float = 40.0
var _pickup_mask: int = 1

func _ready() -> void:
	if _health == null:
		push_error("ChargeCarrier: player_health_path must point to PlayerHealth.")
		return
	if _player == null:
		push_error("ChargeCarrier: parent must be a Node2D (Player).")
		return
	if _debuffs == null:
		push_error("ChargeCarrier: debuffs_path must point to PlayerDebuffs (e.g. ../Debuffs).")
		return

	_health.damage_applied.connect(_on_damage_applied)

	_pickup_radius = pickup_radius_fallback
	_pickup_mask = pickup_mask_fallback

	if _interact_area != null:
		_pickup_mask = _interact_area.collision_mask

		var cs: CollisionShape2D = _interact_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs != null and cs.shape != null:
			if cs.shape is CircleShape2D:
				_pickup_radius = (cs.shape as CircleShape2D).radius
			elif cs.shape is RectangleShape2D:
				var ext: Vector2 = (cs.shape as RectangleShape2D).extents
				_pickup_radius = maxf(ext.x, ext.y)
			elif cs.shape is CapsuleShape2D:
				var cap: CapsuleShape2D = cs.shape as CapsuleShape2D
				_pickup_radius = maxf(cap.radius, cap.height * 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_handle_interact()

func is_carrying() -> bool:
	return carried_charge != null and is_instance_valid(carried_charge)

func _handle_interact() -> void:
	if is_carrying():
		_drop_current(DropReason.MANUAL)
		return

	if _debuffs.has_debuff(&"volatile"):
		return

	var target: AscensionCharge = _find_charge_in_radius()
	if target != null:
		_pickup(target)

func _find_charge_in_radius() -> AscensionCharge:
	var space_state: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = _pickup_radius

	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, _player.global_position)
	params.collision_mask = _pickup_mask
	params.collide_with_areas = true
	params.collide_with_bodies = false

	if _interact_area != null:
		params.exclude = [_interact_area.get_rid()]

	var hits: Array[Dictionary] = space_state.intersect_shape(params, 16)

	var best: AscensionCharge = null
	var best_d2: float = INF

	for h: Dictionary in hits:
		var collider_v: Variant = h.get("collider")
		var area: Area2D = collider_v as Area2D
		if area == null:
			continue

		var charge: AscensionCharge = area as AscensionCharge
		if charge == null:
			continue
		if not charge.can_be_picked_up():
			continue

		var d2: float = _player.global_position.distance_squared_to(charge.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = charge

	return best

func _pickup(charge: AscensionCharge) -> void:
	if is_carrying():
		return
	if charge == null or not is_instance_valid(charge):
		return
	if not charge.can_be_picked_up():
		return

	if _hold_point == null:
		_hold_point = get_node_or_null(hold_point_path) as Marker2D

	carried_charge = charge

	# ✅ IMPORTANT: listen for consume so we can clear carry state
	if not carried_charge.consumed.is_connected(_on_carried_charge_consumed):
		carried_charge.consumed.connect(_on_carried_charge_consumed)

	var use_offset: Vector2 = carry_offset
	if _hold_point != null and is_instance_valid(_hold_point):
		use_offset = _hold_point.global_position - _player.global_position

	charge.pickup_to(_player, use_offset)

	carrying_changed.emit(true)

func _drop_current(reason: DropReason) -> void:
	if not is_carrying():
		return

	var charge: AscensionCharge = carried_charge
	carried_charge = null

	# Disconnect consume handler from the old charge
	if charge != null and is_instance_valid(charge):
		if charge.consumed.is_connected(_on_carried_charge_consumed):
			charge.consumed.disconnect(_on_carried_charge_consumed)

	var world_parent: Node = get_tree().current_scene
	var drop_pos: Vector2 = _player.global_position + drop_offset
	charge.drop_into_world(world_parent, drop_pos)

	carrying_changed.emit(false)

	_apply_drop_penalty(reason)

func _apply_drop_penalty(reason: DropReason) -> void:
	var dmg: int = 0
	match reason:
		DropReason.MANUAL:
			dmg = manual_drop_damage
		DropReason.FORCED_BY_DAMAGE:
			dmg = forced_drop_damage

	if dmg > 0:
		_health.take_damage(dmg, self, drop_damage_ignores_invuln)

	if drop_volatility_duration > 0.0:
		_debuffs.apply_debuff(&"volatile", drop_volatility_duration)

func _on_damage_applied(final_damage: int, _source: Node) -> void:
	if final_damage <= 0:
		return
	if not drop_on_damage:
		return
	if is_carrying():
		_drop_current(DropReason.FORCED_BY_DAMAGE)

func _physics_process(_delta: float) -> void:
	if not is_carrying():
		return

	if _hold_point == null:
		_hold_point = get_node_or_null(hold_point_path) as Marker2D
		if _hold_point == null:
			return

	if not is_instance_valid(_hold_point) or not is_instance_valid(carried_charge):
		return

	var n2d: Node2D = carried_charge as Node2D
	if n2d != null:
		n2d.global_position = _hold_point.global_position

# ✅ NEW: if the charge is socketed/consumed while carried, clear carry state
func _on_carried_charge_consumed() -> void:
	# carried_charge may already be queued_free by the time this runs; treat as not carrying.
	carried_charge = null
	carrying_changed.emit(false)
