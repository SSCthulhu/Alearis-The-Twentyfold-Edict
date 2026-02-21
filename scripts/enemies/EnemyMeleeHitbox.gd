extends Node2D
class_name EnemyMeleeHitbox

signal damage_confirmed(target: Node, hit_position: Vector2, facing: int)

@export var active_time: float = 0.16
@export var damage: int = 5
@export var target_group: StringName = &"player"

# Facing: 1 right, -1 left
@export var face_dir: int = 1

# ---- Range tuning (match Player AttackHitbox feel) ----
@export var forward_only: bool = true
@export var forward_bias_px: float = 70.0

# Default mode (keep simple: one rectangle)
@export var size_horizontal: Vector2 = Vector2(170.0, 64.0)

# NEW: prevents multi-hit spam across multiple spawned hitboxes
# If your enemy spawns multiple melee hitboxes rapidly, this is the safety net.
@export var target_hit_cooldown: float = 0.60

@export var debug_logs: bool = false

@onready var hurt_area: Area2D = $HurtArea
@onready var col_shape: CollisionShape2D = $HurtArea/CollisionShape2D

var _active: bool = false
var _hit_once: Dictionary = {}

# Global (shared) cooldown across all EnemyMeleeHitbox instances.
# Key: target instance_id -> next allowed time (seconds)
static var _global_next_hit_time: Dictionary = {}

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _scaled_enemy_damage(base: int) -> int:
	var v := base
	if RunStateSingleton != null and ("enemy_damage_mult" in RunStateSingleton):
		v = int(round(float(v) * float(RunStateSingleton.enemy_damage_mult)))
	return max(1, v)

func _is_valid_target(node: Node) -> bool:
	if node == null:
		return false
	if target_group == &"":
		return true
	return node.is_in_group(target_group)

func _cooldown_allows(target: Object) -> bool:
	if target_hit_cooldown <= 0.0:
		return true
	if target == null:
		return false

	var id: int = int(target.get_instance_id())
	var now: float = _now()

	if _global_next_hit_time.has(id):
		var next_time: float = float(_global_next_hit_time[id])
		if now < next_time:
			return false

	_global_next_hit_time[id] = now + maxf(target_hit_cooldown, 0.0)
	return true

func _ready() -> void:
	_active = true
	_hit_once.clear()


	if hurt_area == null or col_shape == null:
		push_error("[EnemyMeleeHitbox] Missing HurtArea or HurtArea/CollisionShape2D")
		queue_free()
		return

	# Ensure rectangle shape exists
	var rect: RectangleShape2D = col_shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		col_shape.shape = rect

	# Apply size (RectangleShape2D uses EXTENTS not full size)
	rect.extents = size_horizontal * 0.5

	# Apply forward bias (local position)
	# forward_only means always offset in facing direction (never centered)
	var dir: int = -1 if face_dir < 0 else 1
	var offset_x: float = forward_bias_px * float(dir)
	col_shape.position = Vector2(offset_x, 0.0)

	# Hook collisions
	hurt_area.monitoring = true
	hurt_area.monitorable = true

	if not hurt_area.body_entered.is_connected(_on_body_entered):
		hurt_area.body_entered.connect(_on_body_entered)

	# Optional: support Area2D receivers too (future-proof)
	if not hurt_area.area_entered.is_connected(_on_area_entered):
		hurt_area.area_entered.connect(_on_area_entered)

	if debug_logs:
		pass

	# Auto-expire
	get_tree().create_timer(active_time).timeout.connect(func() -> void:
		if debug_logs:
			pass
		queue_free()
	)

func _try_apply_damage(target: Node) -> void:
	if not _active:
		return
	if target == null:
		return
	if not _is_valid_target(target):
		return

	# Per-instance safety (still useful)
	if _hit_once.has(target):
		if debug_logs:
			pass
		return

	# Global safety across instances (this is the big fix)
	if not _cooldown_allows(target):
		if debug_logs:
			pass
		return

	_hit_once[target] = true

	var final_dmg: int = _scaled_enemy_damage(damage)
	var hp_holder: Node = target
	if target.has_node("Health"):
		hp_holder = target.get_node("Health")
	var hp_before: int = int(hp_holder.get("hp")) if (hp_holder != null and ("hp" in hp_holder)) else -1

	# ✅ TIMING DEBUG: Mark damage application
	if debug_logs:
		pass

	var attempted_damage: bool = false

	# Preferred: Health node
	if target.has_node("Health"):
		var h: Node = target.get_node("Health")
		if h != null and h.has_method("take_damage"):
			# Your PlayerHealth signature: take_damage(amount, source, ignore_invuln)
			var argc: int = h.get_method_argument_count("take_damage")
			if argc >= 3:
				h.call("take_damage", final_dmg, self, false)
			elif argc >= 2:
				h.call("take_damage", final_dmg, self)
			else:
				h.call("take_damage", final_dmg)
			attempted_damage = true

	# Fallback: direct take_damage
	if (not attempted_damage) and target.has_method("take_damage"):
		var argc2: int = target.get_method_argument_count("take_damage")
		if argc2 >= 3:
			target.call("take_damage", final_dmg, self, false)
		elif argc2 >= 2:
			target.call("take_damage", final_dmg, self)
		else:
			target.call("take_damage", final_dmg)
		attempted_damage = true

	if attempted_damage and hp_before >= 0:
		var hp_after: int = int(hp_holder.get("hp")) if (hp_holder != null and ("hp" in hp_holder)) else hp_before
		if hp_after < hp_before:
			var hit_position: Vector2 = target.global_position if (target is Node2D) else global_position
			damage_confirmed.emit(target, hit_position, face_dir)

func _on_body_entered(body: Node) -> void:
	# ✅ TIMING DEBUG: Mark collision detection
	if debug_logs:
		pass
	_try_apply_damage(body)

func _on_area_entered(area: Area2D) -> void:
	# Some setups put the player's hurt receiver as an Area2D.
	# Try the area itself, then its parent.
	_try_apply_damage(area)
	if area != null and area.get_parent() != null:
		_try_apply_damage(area.get_parent())
