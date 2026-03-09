extends Area2D
class_name World1FrozenOrb

signal died(orb: Node)
signal shard_fired(origin: Vector2, direction: Vector2)

const DAMAGE_NUMBER_SCENE_DEFAULT: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")
const HIT_VFX_SCENE_DEFAULT: PackedScene = preload("res://scenes/vfx/EnemyHitVFX.tscn")
const CRIT_VFX_SCENE_DEFAULT: PackedScene = preload("res://scenes/vfx/EnemyCritVFX.tscn")
const ORB_SPRITESHEET_DEFAULT: Texture2D = preload("res://art/charge/pipo-gate01b.png")

@export_range(1, 10000, 1) var max_hp: int = 50
@export_range(0.20, 10.0, 0.05) var shard_interval_min: float = 1.4
@export_range(0.20, 10.0, 0.05) var shard_interval_max: float = 2.2
@export_range(8.0, 256.0, 1.0) var collision_radius: float = 42.0
@export var debug_logs: bool = false
@export var damage_number_scene: PackedScene = DAMAGE_NUMBER_SCENE_DEFAULT
@export var hit_vfx_scene: PackedScene = HIT_VFX_SCENE_DEFAULT
@export var crit_vfx_scene: PackedScene = CRIT_VFX_SCENE_DEFAULT
@export var damage_number_offset: Vector2 = Vector2(0.0, -24.0)
@export var orb_spritesheet: Texture2D = ORB_SPRITESHEET_DEFAULT
@export_range(1, 16, 1) var orb_sheet_columns: int = 5
@export_range(1, 16, 1) var orb_sheet_rows: int = 3
@export_range(1.0, 30.0, 0.5) var orb_anim_fps: float = 12.0
@export var orb_sprite_scale: Vector2 = Vector2(0.72, 0.72)

var hp: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fire_timer: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"floor5_enemies")
	# Match enemy hurtbox interaction behavior for player hitboxes.
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	_build_runtime_visuals()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	hp = max_hp
	_schedule_next_shard()
	set_process(true)


func configure(seed_value: int, hp_value: int, interval_min: float, interval_max: float) -> void:
	max_hp = maxi(hp_value, 1)
	hp = max_hp
	shard_interval_min = maxf(interval_min, 0.2)
	shard_interval_max = maxf(interval_max, shard_interval_min)
	_rng.seed = int(seed_value)
	_schedule_next_shard()


func _process(delta: float) -> void:
	if hp <= 0:
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	var dir: Vector2 = _get_shard_direction()
	shard_fired.emit(global_position, dir)
	_schedule_next_shard()


func apply_hit_from_area(hit_area: Area2D) -> void:
	if hit_area == null:
		return
	if not hit_area.is_in_group(&"player_hitbox"):
		return
	var dmg: int = 0
	var tag: StringName = &""
	var is_crit: bool = false
	if hit_area.has_meta("damage"):
		dmg = int(hit_area.get_meta("damage"))
	elif hit_area.has_method("get_damage"):
		dmg = int(hit_area.call("get_damage"))
	if hit_area.has_meta("tag"):
		var t: Variant = hit_area.get_meta("tag")
		if t is StringName:
			tag = t
		elif t is String:
			tag = StringName(String(t))
	if hit_area.has_meta("is_crit"):
		is_crit = bool(hit_area.get_meta("is_crit"))
	if dmg <= 0:
		return
	take_damage(dmg, hit_area, tag, is_crit)


func _on_area_entered(area: Area2D) -> void:
	# Fallback so orb can still receive damage if hitbox-side routing misses.
	apply_hit_from_area(area)


func take_damage(amount: int, _source: Node = null, tag: StringName = &"", is_crit: bool = false) -> void:
	if amount <= 0 or hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	_spawn_damage_number(amount, tag, is_crit)
	_spawn_hit_vfx(is_crit)
	if hp <= 0:
		set_process(false)
		died.emit(self)
		queue_free()


func _schedule_next_shard() -> void:
	_fire_timer = _rng.randf_range(maxf(shard_interval_min, 0.2), maxf(shard_interval_max, shard_interval_min))


func _get_shard_direction() -> Vector2:
	if _player != null and is_instance_valid(_player):
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() > 0.001:
			return to_player.normalized()
	var angle: float = _rng.randf_range(0.0, TAU)
	return Vector2(cos(angle), sin(angle))


func _build_runtime_visuals() -> void:
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = maxf(collision_radius, 8.0)
	cs.shape = shape
	add_child(cs)

	if orb_spritesheet != null:
		var sprite_frames: SpriteFrames = SpriteFrames.new()
		var cols: int = maxi(orb_sheet_columns, 1)
		var rows: int = maxi(orb_sheet_rows, 1)
		var tex_size: Vector2i = orb_spritesheet.get_size()
		var frame_w: float = floor(float(tex_size.x) / float(cols))
		var frame_h: float = floor(float(tex_size.y) / float(rows))
		if frame_w >= 1.0 and frame_h >= 1.0:
			for y: int in range(rows):
				for x: int in range(cols):
					var atlas: AtlasTexture = AtlasTexture.new()
					atlas.atlas = orb_spritesheet
					atlas.region = Rect2(float(x) * frame_w, float(y) * frame_h, frame_w, frame_h)
					sprite_frames.add_frame(&"default", atlas, 1.0)
			sprite_frames.set_animation_loop(&"default", true)
			sprite_frames.set_animation_speed(&"default", maxf(orb_anim_fps, 1.0))
			var animated: AnimatedSprite2D = AnimatedSprite2D.new()
			animated.sprite_frames = sprite_frames
			animated.animation = &"default"
			animated.z_index = 3
			animated.scale = orb_sprite_scale
			add_child(animated)
			animated.play()
			return

	# Fallback visual in case sheet slicing is invalid.
	var poly: Polygon2D = Polygon2D.new()
	poly.color = Color(0.62, 0.90, 1.0, 0.75)
	var pts: PackedVector2Array = PackedVector2Array()
	var r: float = maxf(collision_radius * 0.95, 6.0)
	var segments: int = 18
	for i: int in range(segments):
		var t: float = TAU * (float(i) / float(segments))
		pts.append(Vector2(cos(t), sin(t)) * r)
	poly.polygon = pts
	poly.z_index = 3
	add_child(poly)


func _spawn_damage_number(amount: int, tag: StringName, is_crit: bool) -> void:
	if damage_number_scene == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var dn: Node = damage_number_scene.instantiate()
	var dn2d: Node2D = dn as Node2D
	if dn2d != null:
		dn2d.global_position = global_position + damage_number_offset
	tree.current_scene.add_child(dn)
	if dn.has_method("setup_damage"):
		dn.call("setup_damage", amount, tag, is_crit)
		return
	if dn.has_method("setup_amount_tagged"):
		var argc: int = dn.get_method_argument_count("setup_amount_tagged")
		if argc >= 3:
			dn.call("setup_amount_tagged", amount, tag, is_crit)
		else:
			dn.call("setup_amount_tagged", amount, tag)
		return
	if dn.has_method("setup"):
		dn.call("setup", amount)


func _spawn_hit_vfx(is_crit: bool) -> void:
	var scene_to_use: PackedScene = null
	if is_crit and crit_vfx_scene != null:
		scene_to_use = crit_vfx_scene
	elif hit_vfx_scene != null:
		scene_to_use = hit_vfx_scene
	if scene_to_use == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var vfx_node: Node = scene_to_use.instantiate()
	var vfx_2d: Node2D = vfx_node as Node2D
	if vfx_2d == null:
		vfx_node.queue_free()
		return
	tree.current_scene.add_child(vfx_2d)
	vfx_2d.global_position = global_position
