extends "res://scripts/systems/EncounterController.gd"
class_name World1EncounterController
const World1FrozenOrbScript := preload("res://scripts/boss/World1FrozenOrb.gd")

signal world1_phase_changed(new_phase: int)

enum World1Phase {
	PHASE_1,
	PHASE_2,
	PHASE_3,
	DEFEATED
}

@export_group("World1 Frost Golem Phase Gates")
@export_range(0.05, 0.95, 0.01) var phase_2_hp_threshold: float = 0.70
@export_range(0.05, 0.95, 0.01) var phase_3_hp_threshold: float = 0.35

@export_group("World1 Encounter Targets")
@export_range(30.0, 300.0, 1.0) var target_fight_duration_seconds: float = 120.0
@export_range(60.0, 360.0, 1.0) var hard_fight_duration_cap_seconds: float = 210.0

@export_group("World1 Frozen Orb Tuning")
@export_range(0.01, 0.30, 0.01) var frozen_orb_hp_ratio: float = 0.05
@export_range(0.0, 0.9, 0.05) var boss_attack_pressure_reduction_while_orbs_alive: float = 0.25

@export_group("World1 Absolute Zero Tuning")
@export_range(1, 10, 1) var absolute_zero_tick_damage: int = 1
@export_range(0.10, 3.0, 0.05) var absolute_zero_tick_interval: float = 0.50
@export_range(0.0, 3.0, 0.05) var absolute_zero_grace_seconds: float = 0.60

@export_group("World1 Ice Drift Tuning")
@export_range(0.01, 1.50, 0.01) var ice_floor_decel_multiplier: float = 0.55
@export_range(0.01, 1.50, 0.01) var ice_floor_accel_multiplier: float = 0.72
@export_range(0.05, 1.00, 0.05) var ice_turn_control_multiplier: float = 0.60
@export_range(0.0, 1.0, 0.05) var max_drift_velocity_ratio: float = 0.80
@export var platform_traction_areas_group: StringName = &"world1_safe_platforms"

@export_group("World1 Phase 1 - Core Attacks")
@export var enable_phase1_core_attacks: bool = true
@export_range(0.25, 6.0, 0.05) var phase1_attack_interval_min: float = 1.80
@export_range(0.25, 8.0, 0.05) var phase1_attack_interval_max: float = 3.00
@export_range(1, 50, 1) var phase1_hit_damage: int = 3

@export_subgroup("Frost Slam")
@export_range(1, 8, 1) var frost_slam_spikes_per_side: int = 3
@export_range(16.0, 400.0, 1.0) var frost_slam_spike_spacing: float = 128.0
@export_range(0.05, 2.0, 0.01) var frost_slam_spike_step_delay: float = 0.10
@export_range(0.05, 3.0, 0.01) var frost_slam_telegraph_time: float = 0.45
@export var frost_slam_hitbox_size: Vector2 = Vector2(120.0, 88.0)
@export_range(256.0, 8000.0, 16.0) var frost_slam_lane_reach_distance: float = 2800.0
@export var frost_slam_floor_y_offset: float = 0.0
@export var frost_slam_animation_name: StringName = &"KAnim/Melee_Unarmed_Smash"
@export_range(0.1, 10.0, 0.05) var frost_slam_animation_speed: float = 1.8

@export_subgroup("Glacial Breath")
@export_range(0.05, 3.0, 0.01) var glacial_breath_telegraph_time: float = 0.60
@export var glacial_breath_size: Vector2 = Vector2(1200.0, 210.0)
@export var glacial_breath_x_offset: float = 210.0
@export var glacial_breath_y_offset: float = -320.0

@export_subgroup("Ice Comets")
@export_range(1, 10, 1) var ice_comets_count: int = 4
@export_range(16.0, 1200.0, 1.0) var ice_comet_spread_x: float = 420.0
@export_range(0.05, 3.0, 0.01) var ice_comet_telegraph_time: float = 0.70
@export_range(8.0, 320.0, 1.0) var ice_comet_radius: float = 92.0
@export_range(0.0, 1.0, 0.01) var ice_comet_stagger: float = 0.08

@export_group("World1 Phase 2 - Arena + Frozen Orbs")
@export var enable_phase2_arena_changes: bool = true
@export var phase2_destroy_platform_paths: Array[NodePath] = []
@export var phase2_tilemap_platform_layer_path: NodePath = ^"../Arena/Geometry/Platforms"
@export var phase2_hide_entire_tilemap_platform_layer: bool = false
@export var phase2_tilemap_destroy_regions: Array[Rect2i] = []
@export_range(1, 8, 1) var phase2_frozen_orb_count: int = 3
@export_range(64.0, 1800.0, 1.0) var phase2_orb_spawn_radius_x: float = 520.0
@export_range(16.0, 900.0, 1.0) var phase2_orb_spawn_radius_y: float = 160.0
@export_range(0.0, 600.0, 1.0) var phase2_orb_spawn_jitter_x: float = 70.0
@export_range(0.0, 400.0, 1.0) var phase2_orb_spawn_jitter_y: float = 45.0
@export_range(100.0, 3000.0, 1.0) var phase2_orb_spawn_arena_half_width: float = 980.0
@export var phase2_orb_spawn_min_y_offset_from_boss: float = -140.0
@export var phase2_orb_spawn_max_y_offset_from_boss: float = 180.0
@export_range(0.20, 8.0, 0.05) var phase2_orb_shard_interval_min: float = 1.10
@export_range(0.20, 8.0, 0.05) var phase2_orb_shard_interval_max: float = 1.80
@export_range(16.0, 3000.0, 1.0) var phase2_orb_shard_range: float = 900.0
@export_range(8.0, 300.0, 1.0) var phase2_orb_shard_width: float = 92.0
@export_range(0.05, 2.0, 0.01) var phase2_orb_shard_telegraph_time: float = 0.35
@export_range(1, 50, 1) var phase2_orb_shard_damage: int = 2

@export_group("World1 Phase 3 - Absolute Zero")
@export var enable_phase3_absolute_zero: bool = true
@export var phase3_safe_platform_path: NodePath = NodePath("")
@export var phase3_safe_zone_size: Vector2 = Vector2(460.0, 120.0)
@export_range(16.0, 3000.0, 1.0) var phase3_safe_zone_half_travel_x: float = 760.0
@export_range(10.0, 1000.0, 1.0) var phase3_safe_zone_move_speed: float = 220.0
@export var phase3_safe_zone_floor_y_offset: float = 0.0
@export var phase3_safe_zone_color: Color = Color(0.25, 0.95, 1.0, 0.24)
@export var phase3_enable_outside_darkness: bool = true
@export var phase3_outside_darkness_color: Color = Color(0.02, 0.04, 0.08, 0.62)
@export_range(200.0, 6000.0, 10.0) var phase3_darkness_padding_x: float = 1800.0
@export_range(200.0, 4000.0, 10.0) var phase3_darkness_padding_y: float = 1200.0

@export_group("World1 Debug")
@export var world1_debug_logs: bool = false

var world1_phase: int = -1
var _phase_gates_armed: bool = false
var _boss_max_hp_cached: float = -1.0
var _phase1_attack_timer: float = 0.0
var _phase2_initialized: bool = false
var _phase2_orbs: Array[Node] = []
var _phase3_initialized: bool = false
var _phase3_center_x: float = 0.0
var _phase3_move_dir: float = 1.0
var _phase3_outside_time: float = 0.0
var _phase3_dot_tick_timer: float = 0.0
var _phase3_safe_zone_root: Node2D = null
var _phase3_safe_zone_poly: Polygon2D = null
var _phase3_dark_top: Polygon2D = null
var _phase3_dark_bottom: Polygon2D = null
var _phase3_dark_left: Polygon2D = null
var _phase3_dark_right: Polygon2D = null
var _phase3_safe_platform_node: Node2D = null

const _PHASE1_ATTACK_FROST_SLAM: int = 0
const _PHASE1_ATTACK_GLACIAL_BREATH: int = 1
const _PHASE1_ATTACK_ICE_COMETS: int = 2


func begin_boss_encounter() -> void:
	super.begin_boss_encounter()
	_set_world1_ice_profile_enabled(true)
	_arm_world1_phase_gates()
	_phase2_initialized = false
	_clear_phase2_orbs()
	_phase3_initialized = false
	_phase3_outside_time = 0.0
	_phase3_dot_tick_timer = 0.0
	_clear_phase3_safe_zone_visual()
	_phase3_safe_platform_node = null
	_reset_phase1_attack_timer()
	_set_world1_phase(World1Phase.PHASE_1)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_world1_phase_gates()
	_process_phase1_core_attacks(delta)
	_process_phase3_absolute_zero(delta)


func _on_boss_died() -> void:
	_set_world1_phase(World1Phase.DEFEATED)
	_set_world1_ice_profile_enabled(false)
	_clear_phase2_orbs()
	_clear_phase3_safe_zone_visual()
	super._on_boss_died()


func set_combat_paused(p: bool) -> void:
	# Exposed for external encounter-level pause control during migration.
	if _boss != null and _boss.has_method("set_combat_paused"):
		_boss.call("set_combat_paused", p)


func _on_tree_exiting() -> void:
	_set_world1_ice_profile_enabled(false)
	_clear_phase2_orbs()
	_clear_phase3_safe_zone_visual()
	super._on_tree_exiting()


func _arm_world1_phase_gates() -> void:
	_phase_gates_armed = true
	_boss_max_hp_cached = _resolve_boss_max_hp()


func _update_world1_phase_gates() -> void:
	if not _phase_gates_armed:
		return
	if _boss == null or not is_instance_valid(_boss):
		return

	var current_hp: float = _resolve_boss_current_hp()
	var max_hp: float = _resolve_boss_max_hp()
	if max_hp <= 0.0:
		return

	var hp_ratio: float = current_hp / max_hp

	if world1_phase == World1Phase.PHASE_1 and hp_ratio <= phase_2_hp_threshold:
		_set_world1_phase(World1Phase.PHASE_2)
	elif world1_phase == World1Phase.PHASE_2 and hp_ratio <= phase_3_hp_threshold:
		_set_world1_phase(World1Phase.PHASE_3)


func _set_world1_phase(new_phase: int) -> void:
	if world1_phase == new_phase:
		return
	world1_phase = new_phase
	if world1_phase == World1Phase.PHASE_1:
		_reset_phase1_attack_timer()
	if world1_phase == World1Phase.PHASE_2:
		_enter_phase2()
	if world1_phase == World1Phase.PHASE_3:
		_phase2_initialized = true
		_enter_phase3()
	world1_phase_changed.emit(world1_phase)
	if world1_debug_logs:
		print("[World1Encounter] Phase -> %s" % _world1_phase_name(world1_phase))


func _resolve_boss_current_hp() -> float:
	if _boss == null:
		return 0.0
	if _boss.has_method("get_health"):
		return float(_boss.call("get_health"))
	if _boss.has_method("get_hp"):
		return float(_boss.call("get_hp"))
	var hp_variant: Variant = _boss.get("hp")
	if hp_variant != null:
		return float(hp_variant)
	var health_variant: Variant = _boss.get("health")
	if health_variant != null:
		return float(health_variant)
	return 0.0


func _resolve_boss_max_hp() -> float:
	if _boss == null:
		return maxf(_boss_max_hp_cached, 1.0)
	if _boss.has_method("get_max_health"):
		return maxf(float(_boss.call("get_max_health")), 1.0)
	if _boss.has_method("get_max_hp"):
		return maxf(float(_boss.call("get_max_hp")), 1.0)
	var max_hp_variant: Variant = _boss.get("max_hp")
	if max_hp_variant != null:
		return maxf(float(max_hp_variant), 1.0)
	var max_health_variant: Variant = _boss.get("max_health")
	if max_health_variant != null:
		return maxf(float(max_health_variant), 1.0)
	return maxf(_boss_max_hp_cached, 1.0)


func _world1_phase_name(p: int) -> String:
	match p:
		World1Phase.PHASE_1:
			return "PHASE_1"
		World1Phase.PHASE_2:
			return "PHASE_2"
		World1Phase.PHASE_3:
			return "PHASE_3"
		World1Phase.DEFEATED:
			return "DEFEATED"
		_:
			return "UNKNOWN"


func _set_world1_ice_profile_enabled(enabled: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return
	if player.has_method("set_world1_ice_profile"):
		player.call(
			"set_world1_ice_profile",
			enabled,
			ice_floor_decel_multiplier,
			ice_floor_accel_multiplier,
			ice_turn_control_multiplier,
			max_drift_velocity_ratio,
			platform_traction_areas_group
		)
		if world1_debug_logs:
			print("[World1Encounter] Ice profile %s" % ("enabled" if enabled else "disabled"))


func _process_phase1_core_attacks(delta: float) -> void:
	if not enable_phase1_core_attacks:
		return
	if not encounter_active:
		return
	if world1_phase != World1Phase.PHASE_1 and world1_phase != World1Phase.PHASE_2 and world1_phase != World1Phase.PHASE_3:
		return
	if _boss == null or not is_instance_valid(_boss):
		return

	# During migration, keep old bullet scheduler disabled and allow direct pressure in Phase 1.
	if _boss.has_method("set_attacks_enabled"):
		_boss.call("set_attacks_enabled", false)
	if _boss.has_method("set_vulnerable"):
		var should_be_vulnerable: bool = (
			world1_phase == World1Phase.PHASE_1
			or world1_phase == World1Phase.PHASE_3
			or (world1_phase == World1Phase.PHASE_2 and not _are_phase2_orbs_alive())
		)
		_boss.call("set_vulnerable", should_be_vulnerable)

	_phase1_attack_timer -= delta
	if _phase1_attack_timer > 0.0:
		return

	_execute_phase1_attack()
	var interval_scale: float = 1.0
	if _are_phase2_orbs_alive():
		interval_scale = maxf(1.0 + clampf(boss_attack_pressure_reduction_while_orbs_alive, 0.0, 0.9), 1.0)
	_reset_phase1_attack_timer(interval_scale)


func _execute_phase1_attack() -> void:
	var attack_roll: int = _rng.randi_range(0, 2)
	match attack_roll:
		_PHASE1_ATTACK_FROST_SLAM:
			_run_frost_slam()
		_PHASE1_ATTACK_GLACIAL_BREATH:
			_run_glacial_breath()
		_PHASE1_ATTACK_ICE_COMETS:
			_run_ice_comets()
		_:
			_run_frost_slam()


func _run_frost_slam() -> void:
	if _boss != null and _boss.has_method("play_attack_animation"):
		_boss.call("play_attack_animation", String(frost_slam_animation_name), frost_slam_animation_speed, false)
	var origin: Vector2 = _get_boss_origin()
	# Deterministic absolute Y placement by design.
	# frost_slam_floor_y_offset is treated as world-space Y.
	var lane_floor_y: float = frost_slam_floor_y_offset
	var spacing: float = maxf(frost_slam_spike_spacing, 8.0)
	var coverage_spikes: int = int(ceil(maxf(frost_slam_lane_reach_distance, 0.0) / spacing))
	var spikes_per_side: int = maxi(maxi(frost_slam_spikes_per_side, coverage_spikes), 1)
	for i: int in range(spikes_per_side):
		var idx: float = float(i + 1)
		var x_offset: float = idx * spacing
		var step_delay: float = float(i) * maxf(frost_slam_spike_step_delay, 0.0)
		_schedule_slam_spike(Vector2(origin.x - x_offset, lane_floor_y), step_delay)
		_schedule_slam_spike(Vector2(origin.x + x_offset, lane_floor_y), step_delay)


func _schedule_slam_spike(hit_center: Vector2, delay_s: float) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	scene_tree.create_timer(maxf(delay_s, 0.0)).timeout.connect(func() -> void:
		_spawn_rect_telegraph(hit_center, frost_slam_hitbox_size, 0.0, frost_slam_telegraph_time, Color(0.45, 0.85, 1.0, 0.28))
		var tree2: SceneTree = get_tree()
		if tree2 == null:
			return
		tree2.create_timer(maxf(frost_slam_telegraph_time, 0.01)).timeout.connect(func() -> void:
			_apply_rect_damage_to_player(hit_center, frost_slam_hitbox_size, 0.0, phase1_hit_damage)
		)
	)


func _run_glacial_breath() -> void:
	var boss_origin: Vector2 = _get_boss_origin()
	var player_pos: Vector2 = _get_player_position()
	var dir: float = 1.0 if player_pos.x >= boss_origin.x else -1.0
	var origin: Vector2 = boss_origin + Vector2(dir * absf(glacial_breath_x_offset), glacial_breath_y_offset)
	var size: Vector2 = glacial_breath_size
	var center: Vector2 = origin + Vector2(dir * (size.x * 0.5), 0.0)
	_spawn_rect_telegraph(center, size, 0.0, glacial_breath_telegraph_time, Color(0.35, 0.70, 1.0, 0.22))
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	scene_tree.create_timer(maxf(glacial_breath_telegraph_time, 0.01)).timeout.connect(func() -> void:
		_apply_rect_damage_to_player(center, size, 0.0, phase1_hit_damage)
	)


func _run_ice_comets() -> void:
	var player_pos: Vector2 = _get_player_position()
	var count: int = maxi(ice_comets_count, 1)
	for i: int in range(count):
		var spread: float = _rng.randf_range(-ice_comet_spread_x, ice_comet_spread_x)
		var target: Vector2 = player_pos + Vector2(spread, 0.0)
		var delay_s: float = float(i) * maxf(ice_comet_stagger, 0.0)
		_schedule_comet_impact(target, delay_s)


func _schedule_comet_impact(target: Vector2, delay_s: float) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	scene_tree.create_timer(maxf(delay_s, 0.0)).timeout.connect(func() -> void:
		_spawn_circle_telegraph(target, ice_comet_radius, ice_comet_telegraph_time, Color(0.70, 0.88, 1.0, 0.24))
		var tree2: SceneTree = get_tree()
		if tree2 == null:
			return
		tree2.create_timer(maxf(ice_comet_telegraph_time, 0.01)).timeout.connect(func() -> void:
			_apply_circle_damage_to_player(target, ice_comet_radius, phase1_hit_damage)
		)
	)


func _enter_phase2() -> void:
	if _phase2_initialized:
		return
	_phase2_initialized = true
	if not enable_phase2_arena_changes:
		return
	_destroy_phase2_platforms()
	_spawn_phase2_frozen_orbs()


func _destroy_phase2_platforms() -> void:
	_destroy_phase2_tilemap_regions()
	for p: NodePath in phase2_destroy_platform_paths:
		if p == NodePath():
			continue
		var n: Node = get_node_or_null(p)
		if n == null:
			if world1_debug_logs:
				print("[World1Encounter] Missing phase2 platform path: %s" % String(p))
			continue
		_set_platform_node_enabled(n, false)


func _set_platform_node_enabled(platform: Node, enabled: bool) -> void:
	if platform == null or not is_instance_valid(platform):
		return
	if platform is CanvasItem:
		(platform as CanvasItem).visible = enabled
	if platform is CollisionObject2D:
		var co := platform as CollisionObject2D
		if enabled:
			co.collision_layer = max(co.collision_layer, 1)
		else:
			co.collision_layer = 0
			co.collision_mask = 0
	for c: Node in platform.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = enabled
		if c is CollisionObject2D:
			var co2 := c as CollisionObject2D
			if enabled:
				co2.collision_layer = max(co2.collision_layer, 1)
			else:
				co2.collision_layer = 0
				co2.collision_mask = 0
		var cs: CollisionShape2D = c as CollisionShape2D
		if cs != null:
			cs.set_deferred("disabled", not enabled)


func _destroy_phase2_tilemap_regions() -> void:
	if phase2_tilemap_platform_layer_path == NodePath():
		return
	var layer: Node = get_node_or_null(phase2_tilemap_platform_layer_path)
	if layer == null:
		if world1_debug_logs:
			print("[World1Encounter] TileMapLayer not found: %s" % String(phase2_tilemap_platform_layer_path))
		return

	if phase2_hide_entire_tilemap_platform_layer:
		if layer is CanvasItem:
			(layer as CanvasItem).visible = false
		if "collision_enabled" in layer:
			layer.set("collision_enabled", false)
		return

	if phase2_tilemap_destroy_regions.is_empty():
		if world1_debug_logs:
			print("[World1Encounter] No tilemap destroy regions configured; skipping tile erasure.")
		return
	if not layer.has_method("erase_cell"):
		push_warning("[World1Encounter] TileMapLayer missing erase_cell(): %s" % String(phase2_tilemap_platform_layer_path))
		return

	for rect: Rect2i in phase2_tilemap_destroy_regions:
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		for y: int in range(rect.position.y, rect.position.y + rect.size.y):
			for x: int in range(rect.position.x, rect.position.x + rect.size.x):
				layer.call("erase_cell", Vector2i(x, y))


func _spawn_phase2_frozen_orbs() -> void:
	_clear_phase2_orbs()
	var boss_pos: Vector2 = _get_boss_origin()
	var max_hp: int = int(round(_resolve_boss_max_hp()))
	var orb_hp: int = maxi(int(round(float(max_hp) * frozen_orb_hp_ratio)), 1)
	var count: int = maxi(phase2_frozen_orb_count, 1)
	var arena_half_width: float = maxf(phase2_orb_spawn_arena_half_width, 100.0)
	var min_x: float = boss_pos.x - arena_half_width
	var max_x: float = boss_pos.x + arena_half_width
	var min_y_offset: float = minf(phase2_orb_spawn_min_y_offset_from_boss, phase2_orb_spawn_max_y_offset_from_boss)
	var max_y_offset: float = maxf(phase2_orb_spawn_min_y_offset_from_boss, phase2_orb_spawn_max_y_offset_from_boss)
	var min_y: float = boss_pos.y + min_y_offset
	var max_y: float = boss_pos.y + max_y_offset
	for i: int in range(count):
		var orb: Node = World1FrozenOrbScript.new()
		var angle: float = (TAU * float(i) / float(count)) + _rng.randf_range(-0.2, 0.2)
		var x: float = cos(angle) * phase2_orb_spawn_radius_x
		var y: float = sin(angle) * phase2_orb_spawn_radius_y
		x += _rng.randf_range(-phase2_orb_spawn_jitter_x, phase2_orb_spawn_jitter_x)
		y += _rng.randf_range(-phase2_orb_spawn_jitter_y, phase2_orb_spawn_jitter_y)
		var spawn_pos: Vector2 = boss_pos + Vector2(x, y)
		spawn_pos.x = clampf(spawn_pos.x, min_x, max_x)
		spawn_pos.y = clampf(spawn_pos.y, min_y, max_y)
		if orb is Node2D:
			(orb as Node2D).global_position = spawn_pos
		var seed_val: int = _rng.randi()
		if orb.has_method("configure"):
			orb.call("configure", seed_val, orb_hp, phase2_orb_shard_interval_min, phase2_orb_shard_interval_max)
		if orb.has_signal("shard_fired"):
			orb.connect("shard_fired", Callable(self, "_on_phase2_orb_shard_fired"))
		if orb.has_signal("died"):
			orb.connect("died", Callable(self, "_on_phase2_orb_died"))
		get_tree().current_scene.add_child(orb)
		_phase2_orbs.append(orb)


func _on_phase2_orb_shard_fired(origin: Vector2, direction: Vector2) -> void:
	var dir: Vector2 = direction.normalized()
	if dir.length() <= 0.001:
		return
	var shard_len: float = maxf(phase2_orb_shard_range, 16.0)
	var width: float = maxf(phase2_orb_shard_width, 8.0)
	var center: Vector2 = origin + (dir * (shard_len * 0.5))
	var rotation: float = dir.angle()
	var size: Vector2 = Vector2(shard_len, width)
	_spawn_rect_telegraph(center, size, rotation, phase2_orb_shard_telegraph_time, Color(0.55, 0.90, 1.0, 0.24))
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	scene_tree.create_timer(maxf(phase2_orb_shard_telegraph_time, 0.01)).timeout.connect(func() -> void:
		_apply_rect_damage_to_player(center, size, rotation, phase2_orb_shard_damage)
	)


func _on_phase2_orb_died(orb: Node) -> void:
	var idx: int = _phase2_orbs.find(orb)
	if idx >= 0:
		_phase2_orbs.remove_at(idx)


func _clear_phase2_orbs() -> void:
	for orb: Node in _phase2_orbs:
		if orb != null and is_instance_valid(orb):
			orb.queue_free()
	_phase2_orbs.clear()


func _are_phase2_orbs_alive() -> bool:
	for orb: Node in _phase2_orbs:
		if orb != null and is_instance_valid(orb):
			return true
	return false


func _enter_phase3() -> void:
	if _phase3_initialized:
		return
	_phase3_initialized = true
	_phase3_outside_time = 0.0
	_phase3_dot_tick_timer = 0.0
	_phase3_safe_platform_node = get_node_or_null(phase3_safe_platform_path) as Node2D
	_phase3_center_x = _get_boss_origin().x
	_phase3_move_dir = 1.0
	_create_phase3_safe_zone_visual()
	# Ensure leftover orbs never block vulnerability once phase 3 begins.
	_clear_phase2_orbs()


func _process_phase3_absolute_zero(delta: float) -> void:
	if not enable_phase3_absolute_zero:
		return
	if not _phase3_initialized:
		return
	if world1_phase != World1Phase.PHASE_3:
		return

	var origin_x: float = _get_boss_origin().x
	var left_bound: float = origin_x - maxf(phase3_safe_zone_half_travel_x, 0.0)
	var right_bound: float = origin_x + maxf(phase3_safe_zone_half_travel_x, 0.0)
	_phase3_center_x += _phase3_move_dir * maxf(phase3_safe_zone_move_speed, 0.0) * delta
	if _phase3_center_x >= right_bound:
		_phase3_center_x = right_bound
		_phase3_move_dir = -1.0
	elif _phase3_center_x <= left_bound:
		_phase3_center_x = left_bound
		_phase3_move_dir = 1.0

	# Deterministic absolute Y placement by design.
	# phase3_safe_zone_floor_y_offset is treated as world-space Y.
	var safe_center: Vector2 = Vector2(_phase3_center_x, phase3_safe_zone_floor_y_offset)
	_update_phase3_safe_zone_visual(safe_center)
	_move_phase3_safe_platform(safe_center)
	_tick_phase3_outside_damage(delta, safe_center)


func _tick_phase3_outside_damage(delta: float, safe_center: Vector2) -> void:
	var player_pos: Vector2 = _get_player_position()
	var half: Vector2 = phase3_safe_zone_size * 0.5
	var in_safe_zone: bool = (
		absf(player_pos.x - safe_center.x) <= half.x
		and absf(player_pos.y - safe_center.y) <= half.y
	)
	if in_safe_zone:
		_phase3_outside_time = 0.0
		_phase3_dot_tick_timer = 0.0
		return

	_phase3_outside_time += delta
	if _phase3_outside_time < maxf(absolute_zero_grace_seconds, 0.0):
		return

	_phase3_dot_tick_timer += delta
	var tick_interval: float = maxf(absolute_zero_tick_interval, 0.05)
	if _phase3_dot_tick_timer < tick_interval:
		return
	_phase3_dot_tick_timer -= tick_interval
	_apply_damage_to_player(maxi(absolute_zero_tick_damage, 1))


func _create_phase3_safe_zone_visual() -> void:
	_clear_phase3_safe_zone_visual()
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	_phase3_safe_zone_root = Node2D.new()
	_phase3_safe_zone_root.z_index = 240

	if phase3_enable_outside_darkness:
		_phase3_dark_top = Polygon2D.new()
		_phase3_dark_bottom = Polygon2D.new()
		_phase3_dark_left = Polygon2D.new()
		_phase3_dark_right = Polygon2D.new()
		_phase3_dark_top.color = phase3_outside_darkness_color
		_phase3_dark_bottom.color = phase3_outside_darkness_color
		_phase3_dark_left.color = phase3_outside_darkness_color
		_phase3_dark_right.color = phase3_outside_darkness_color
		_phase3_dark_top.z_index = 238
		_phase3_dark_bottom.z_index = 238
		_phase3_dark_left.z_index = 238
		_phase3_dark_right.z_index = 238
		_phase3_safe_zone_root.add_child(_phase3_dark_top)
		_phase3_safe_zone_root.add_child(_phase3_dark_bottom)
		_phase3_safe_zone_root.add_child(_phase3_dark_left)
		_phase3_safe_zone_root.add_child(_phase3_dark_right)

	_phase3_safe_zone_poly = Polygon2D.new()
	_phase3_safe_zone_poly.color = phase3_safe_zone_color
	_phase3_safe_zone_poly.z_index = 240
	_phase3_safe_zone_root.add_child(_phase3_safe_zone_poly)
	tree.current_scene.add_child(_phase3_safe_zone_root)


func _update_phase3_safe_zone_visual(center: Vector2) -> void:
	if _phase3_safe_zone_root == null or not is_instance_valid(_phase3_safe_zone_root):
		return
	_phase3_safe_zone_root.global_position = center
	var half: Vector2 = Vector2(maxf(phase3_safe_zone_size.x * 0.5, 8.0), maxf(phase3_safe_zone_size.y * 0.5, 8.0))
	if _phase3_safe_zone_poly != null and is_instance_valid(_phase3_safe_zone_poly):
		_phase3_safe_zone_poly.color = phase3_safe_zone_color
		_set_rect_polygon(_phase3_safe_zone_poly, -half.x, -half.y, half.x, half.y)
	_update_phase3_darkness_polygons(half)


func _update_phase3_darkness_polygons(half: Vector2) -> void:
	if not phase3_enable_outside_darkness:
		return
	if _phase3_dark_top == null or not is_instance_valid(_phase3_dark_top):
		return
	var ext_x: float = maxf(phase3_safe_zone_half_travel_x + phase3_darkness_padding_x, half.x + 32.0)
	var ext_y: float = maxf(phase3_darkness_padding_y, half.y + 32.0)
	var left: float = -ext_x
	var right: float = ext_x
	var top: float = -ext_y
	var bottom: float = ext_y
	var inner_left: float = -half.x
	var inner_right: float = half.x
	var inner_top: float = -half.y
	var inner_bottom: float = half.y
	_phase3_dark_top.color = phase3_outside_darkness_color
	_phase3_dark_bottom.color = phase3_outside_darkness_color
	_phase3_dark_left.color = phase3_outside_darkness_color
	_phase3_dark_right.color = phase3_outside_darkness_color
	_set_rect_polygon(_phase3_dark_top, left, top, right, inner_top)
	_set_rect_polygon(_phase3_dark_bottom, left, inner_bottom, right, bottom)
	_set_rect_polygon(_phase3_dark_left, left, inner_top, inner_left, inner_bottom)
	_set_rect_polygon(_phase3_dark_right, inner_right, inner_top, right, inner_bottom)


func _set_rect_polygon(poly: Polygon2D, x0: float, y0: float, x1: float, y1: float) -> void:
	if poly == null or not is_instance_valid(poly):
		return
	poly.polygon = PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1)
	])


func _clear_phase3_safe_zone_visual() -> void:
	if _phase3_safe_zone_root != null and is_instance_valid(_phase3_safe_zone_root):
		_phase3_safe_zone_root.queue_free()
	_phase3_safe_zone_root = null
	_phase3_safe_zone_poly = null
	_phase3_dark_top = null
	_phase3_dark_bottom = null
	_phase3_dark_left = null
	_phase3_dark_right = null


func _move_phase3_safe_platform(center: Vector2) -> void:
	if _phase3_safe_platform_node == null or not is_instance_valid(_phase3_safe_platform_node):
		return
	var p: Vector2 = _phase3_safe_platform_node.global_position
	p.x = center.x
	p.y = center.y
	_phase3_safe_platform_node.global_position = p


func _reset_phase1_attack_timer(scale: float = 1.0) -> void:
	_phase1_attack_timer = _rng.randf_range(
		maxf(phase1_attack_interval_min, 0.25),
		maxf(phase1_attack_interval_max, phase1_attack_interval_min)
	) * maxf(scale, 0.1)


func _spawn_rect_telegraph(center: Vector2, size: Vector2, rotation_radians: float, duration: float, color: Color) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null or scene_tree.current_scene == null:
		return
	var n: Node2D = Node2D.new()
	n.global_position = center
	n.global_rotation = rotation_radians
	n.z_index = 230

	var poly: Polygon2D = Polygon2D.new()
	poly.color = color
	var half: Vector2 = size * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	n.add_child(poly)
	scene_tree.current_scene.add_child(n)

	var tween: Tween = n.create_tween()
	tween.tween_interval(maxf(duration, 0.01))
	tween.tween_property(poly, "modulate:a", 0.0, 0.08)
	tween.finished.connect(func() -> void:
		if n != null and is_instance_valid(n):
			n.queue_free()
	)


func _spawn_circle_telegraph(center: Vector2, radius: float, duration: float, color: Color) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null or scene_tree.current_scene == null:
		return
	var n: Node2D = Node2D.new()
	n.global_position = center
	n.z_index = 230

	var poly: Polygon2D = Polygon2D.new()
	poly.color = color
	var points: PackedVector2Array = PackedVector2Array()
	var r: float = maxf(radius, 4.0)
	var segments: int = 24
	for i: int in range(segments):
		var t: float = TAU * (float(i) / float(segments))
		points.append(Vector2(cos(t), sin(t)) * r)
	poly.polygon = points
	n.add_child(poly)
	scene_tree.current_scene.add_child(n)

	var tween: Tween = n.create_tween()
	tween.tween_interval(maxf(duration, 0.01))
	tween.tween_property(poly, "modulate:a", 0.0, 0.08)
	tween.finished.connect(func() -> void:
		if n != null and is_instance_valid(n):
			n.queue_free()
	)


func _apply_rect_damage_to_player(center: Vector2, size: Vector2, rotation_radians: float, damage: int) -> void:
	if not _is_player_overlapping_rect(center, size, rotation_radians):
		return
	_apply_damage_to_player(damage)


func _apply_circle_damage_to_player(center: Vector2, radius: float, damage: int) -> void:
	var player_pos: Vector2 = _get_player_position()
	if player_pos.distance_to(center) > maxf(radius, 0.0):
		return
	_apply_damage_to_player(damage)


func _point_in_oriented_rect(point: Vector2, center: Vector2, size: Vector2, rotation_radians: float) -> bool:
	var local: Vector2 = (point - center).rotated(-rotation_radians)
	var half: Vector2 = size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y


func _is_player_overlapping_rect(center: Vector2, size: Vector2, rotation_radians: float) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var player: Node2D = tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return false

	# Primary path: use physics shape overlap so it matches engine collision behavior.
	var world_2d_ref: World2D = player.get_world_2d()
	if world_2d_ref != null:
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
		var q: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		q.shape = rect_shape
		q.transform = Transform2D(rotation_radians, center)
		q.collide_with_areas = false
		q.collide_with_bodies = true
		# Player root body is on layer 2 in this project.
		q.collision_mask = 2
		var hits: Array[Dictionary] = world_2d_ref.direct_space_state.intersect_shape(q, 32)
		for h: Dictionary in hits:
			var collider: Variant = h.get("collider", null)
			if collider == player:
				return true
			if collider is Node:
				var n: Node = collider as Node
				if n == player or n.get_parent() == player:
					return true

	# Fallback path: sampled points around player body.
	var points: Array[Vector2] = [player.global_position]
	var cs: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null and cs.shape != null:
		var center_p: Vector2 = cs.global_position
		var ext_x: float = 18.0
		var ext_y: float = 30.0
		var shape: Shape2D = cs.shape
		var sx: float = absf(cs.global_scale.x)
		var sy: float = absf(cs.global_scale.y)
		if shape is CapsuleShape2D:
			var cap: CapsuleShape2D = shape as CapsuleShape2D
			ext_x = maxf(ext_x, cap.radius * sx)
			ext_y = maxf(ext_y, (cap.height * 0.5 + cap.radius) * sy)
		elif shape is RectangleShape2D:
			var rect: RectangleShape2D = shape as RectangleShape2D
			ext_x = maxf(ext_x, rect.size.x * 0.5 * sx)
			ext_y = maxf(ext_y, rect.size.y * 0.5 * sy)
		points = [
			center_p,
			center_p + Vector2(ext_x, 0.0),
			center_p + Vector2(-ext_x, 0.0),
			center_p + Vector2(0.0, ext_y),
			center_p + Vector2(0.0, -ext_y),
			center_p + Vector2(ext_x, ext_y),
			center_p + Vector2(-ext_x, ext_y),
			center_p + Vector2(ext_x, -ext_y),
			center_p + Vector2(-ext_x, -ext_y)
		]

	for p: Vector2 in points:
		if _point_in_oriented_rect(p, center, size, rotation_radians):
			return true
	return false


func _apply_damage_to_player(amount: int) -> void:
	if amount <= 0:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return
	var health: Node = player.get_node_or_null("Health")
	if health == null:
		return
	if health.has_method("take_damage"):
		health.call("take_damage", amount, self, false)


func _get_player_position() -> Vector2:
	var tree: SceneTree = get_tree()
	if tree == null:
		return Vector2.ZERO
	var player: Node2D = tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO
	return player.global_position


func _get_boss_origin() -> Vector2:
	if _boss is Node2D:
		return (_boss as Node2D).global_position
	return Vector2.ZERO
