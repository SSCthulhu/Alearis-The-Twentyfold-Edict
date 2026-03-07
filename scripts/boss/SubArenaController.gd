extends Node
class_name SubArenaController

# Controls sub-arena (wrong or right portal)
# Wrong portal: 3 enemies → uncharged orb → 10% debuff on pickup → return
# Right portal: Fully charged orb → return

@export var player_path: NodePath = ^"../Player"
@export var debug_logs: bool = false
@export var settle_timeout_seconds: float = 2.2
@export var settle_timeout_fallback_seconds: float = 1.0
@export var settle_min_stable_time_before_accept: float = 0.28
@export var lock_charge_drop_until_socketed: bool = true
@export var enemy_wake_delay_after_fade_in: float = 1.0

# Enemy spawning (for WRONG portal only)
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_spawn_positions: Array[Vector2] = [
	Vector2(-300, 0),
	Vector2(0, 0),
	Vector2(300, 0)
]

# Orb spawning
@export var orb_scene: PackedScene  # AscensionCharge scene
@export var orb_spawn_position: Vector2 = Vector2(0, -100)

var _player: Node2D = null
var _is_correct_portal: bool = false
var _return_position: Vector2 = Vector2.ZERO
var _source_scene_path: String = ""
var _boss_phase_saved: int = 1  # Save boss state from portal entry
var _boss_hp_saved: int = 2000

var _active_enemies: Array[Node] = []
var _active_orb: AscensionCharge = null
var _orb_spawned: bool = false  # Prevent duplicate orb spawns
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _entry_fade_overlay: ColorRect = null
var _entry_fade_canvas: CanvasLayer = null

func _enter_tree() -> void:
	# Keep screen black from scene load until spawn/drop settling completes.
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1000

	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(overlay)
	get_tree().current_scene.call_deferred("add_child", canvas_layer)

	_entry_fade_overlay = overlay
	_entry_fade_canvas = canvas_layer

func _ready() -> void:
	# Wait a frame for scene to fully load
	await get_tree().process_frame
	
	# Find player
	_player = get_node_or_null(player_path)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	
	if _player == null:
		push_error("[SubArenaController] Player not found!")
		# Try again after another frame
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group("player")
		
		if _player == null:
			push_error("[SubArenaController] Player STILL not found after waiting!")
			if _entry_fade_canvas != null and is_instance_valid(_entry_fade_canvas):
				_entry_fade_canvas.queue_free()
			return

	# Ensure gravity/physics can run while hidden in sub-arena entry.
	if _player.has_method("set_input_locked"):
		_player.set_input_locked(false)
	if _player.has_method("set_cutscene_lock"):
		_player.set_cutscene_lock(false)
	
	# Read portal data from global singleton
	var portal_data = get_node_or_null("/root/PortalTransitionData")
	if portal_data == null:
		push_error("[SubArenaController] PortalTransitionData autoload not found! Did you restart Godot?")
		return
	
	if not portal_data.has_data:
		push_error("[SubArenaController] No portal transition data available!")
		return
	
	_is_correct_portal = portal_data.is_correct_portal
	_return_position = portal_data.return_position
	_source_scene_path = portal_data.source_scene_path
	_boss_phase_saved = portal_data.boss_phase
	_boss_hp_saved = portal_data.boss_hp
	_seed_rng_for_sub_arena()
	
	# Restore player HP immediately
	var player_health = _player.get_node_or_null("Health")
	if player_health != null:
		if player_health.has_method("set_hp"):
			player_health.call("set_hp", portal_data.player_hp, portal_data.player_max_hp)
		elif "hp" in player_health and "max_hp" in player_health:
			player_health.hp = portal_data.player_hp
			player_health.max_hp = portal_data.player_max_hp
			# Emit health changed signal if it exists
			if player_health.has_signal("health_changed"):
				player_health.health_changed.emit(player_health.hp, player_health.max_hp)
		
		if debug_logs:
			pass
	
	# Restore player cooldowns immediately
	var player_combat = _player.get_node_or_null("Combat")
	if player_combat != null and not portal_data.player_cooldowns.is_empty():
		# Add cooldowns to the current time
		var now = Time.get_ticks_msec() / 1000.0
		for ability_id in portal_data.player_cooldowns.keys():
			var cd_left = portal_data.player_cooldowns[ability_id]
			if cd_left > 0.0:
				var ready_time = now + cd_left
				match ability_id:
					"light":
						if "_light_ready_time" in player_combat:
							player_combat._light_ready_time = ready_time
					"heavy":
						if "_heavy_ready_time" in player_combat:
							player_combat._heavy_ready_time = ready_time
					"ultimate":
						if "_ultimate_ready_time" in player_combat:
							player_combat._ultimate_ready_time = ready_time
					"defend":
						if "_defend_ready_time" in player_combat:
							player_combat._defend_ready_time = ready_time
					"BIGD":
						if "_BIGD_ready_time" in player_combat:
							player_combat._BIGD_ready_time = ready_time
		
		if debug_logs:
			pass
	
	# Restore dodge charges immediately
	if "_roll_charges" in _player:
		_player._roll_charges = portal_data.player_dodge_charges
	if "_roll_recharge_accum" in _player:
		_player._roll_recharge_accum = portal_data.player_dodge_recharge_accum
	
	if debug_logs:
		pass
	
	if debug_logs:
		pass
		pass
		pass
		pass
	
	# Clear the global data (consumed)
	portal_data.clear_data()
	
	# Teleport player to spawn position
	var player_spawn = get_node_or_null("PlayerSpawn")
	if player_spawn:
		_player.global_position = player_spawn.global_position
		if debug_logs:
			pass
	# Let one physics tick happen after teleport so floor state updates cleanly.
	await get_tree().physics_frame
	
	# Start appropriate sequence
	if _is_correct_portal:
		_start_correct_portal_sequence()
	else:
		_start_wrong_portal_sequence()
	var settle_groups: Array[StringName] = []
	if not _is_correct_portal:
		settle_groups = [&"subarena_enemies"]
	if debug_logs:
		print("[SubArenaController] Begin settle wait. portal=", "RIGHT" if _is_correct_portal else "WRONG", " player=", _describe_node_settle(_player))
	var settled: bool = await _wait_for_settle_hidden([_player], settle_groups, settle_timeout_seconds)
	if not settled and debug_logs:
		print("[SubArenaController] Settle timeout (primary) before fade-in. Trying fallback wait.")
	if not settled:
		settled = await _wait_for_settle_hidden([_player], settle_groups, settle_timeout_fallback_seconds)
	if not settled and debug_logs:
		_log_unsettled_targets([_player], settle_groups)
	if not _is_correct_portal:
		# Wrong arena only: freeze enemies during reveal, then release 1s later.
		_set_subarena_enemy_physics_enabled(false)
	if _entry_fade_overlay != null and is_instance_valid(_entry_fade_overlay):
		await _fade_screen(_entry_fade_overlay, 1.0, 0.0, 1.2)
	if _entry_fade_canvas != null and is_instance_valid(_entry_fade_canvas):
		_entry_fade_canvas.queue_free()
	if not _is_correct_portal:
		if enemy_wake_delay_after_fade_in > 0.0:
			await get_tree().create_timer(enemy_wake_delay_after_fade_in).timeout
		_set_subarena_enemy_physics_enabled(true)

func _seed_rng_for_sub_arena() -> void:
	if RunStateSingleton != null and RunStateSingleton.has_method("make_rng_for_domain"):
		var extra: int = int(hash(_source_scene_path))
		if _is_correct_portal:
			extra += 1
		var seeded_rng: RandomNumberGenerator = RunStateSingleton.call("make_rng_for_domain", &"sub_arena_controller", extra) as RandomNumberGenerator
		if seeded_rng != null:
			_rng.seed = seeded_rng.seed
			return
	_rng.randomize()

func _start_correct_portal_sequence() -> void:
	if debug_logs:
		pass
	
	# Spawn fully charged orb immediately
	_spawn_orb(true)  # true = fully charged

func _start_wrong_portal_sequence() -> void:
	if debug_logs:
		pass
	
	# Spawn 3 random enemies
	_spawn_enemies()

func _spawn_enemies() -> void:
	if enemy_scenes.is_empty():
		push_error("[SubArenaController] No enemy scenes assigned!")
		_spawn_orb(false)  # Fail-safe: spawn uncharged orb
		return
	
	var spawn_count = mini(3, enemy_spawn_positions.size())
	
	for i in range(spawn_count):
		var enemy_scene = enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)]
		var enemy_node = enemy_scene.instantiate()
		var enemy_2d = enemy_node as Node2D
		
		if enemy_2d == null:
			push_warning("[SubArenaController] Enemy scene root must be Node2D")
			enemy_node.queue_free()
			continue
		
		get_tree().current_scene.add_child(enemy_2d)
		enemy_2d.global_position = enemy_spawn_positions[i]
		enemy_2d.add_to_group(&"subarena_enemies")  # Make targetable by Rogue ultimate
		
		_active_enemies.append(enemy_2d)
		
		# Connect death signal
		_connect_enemy_death(enemy_2d)
		
		if debug_logs:
			pass

func _connect_enemy_death(enemy: Node2D) -> void:
	var health = enemy.get_node_or_null("Health")
	if health and health.has_signal("died"):
		health.died.connect(func() -> void:
			_check_all_enemies_dead()
		)

func _check_all_enemies_dead() -> void:
	# Prevent multiple calls
	if _orb_spawned:
		return
	
	# Check if all enemies are dead
	var all_dead = true
	var _alive_count = 0
	
	for e in _active_enemies:
		if e != null and is_instance_valid(e):
			var h = e.get_node_or_null("Health")
			if h != null and "hp" in h:
				if h.hp > 0:
					all_dead = false
					_alive_count += 1
	
	if debug_logs:
		pass
	
	if all_dead:
		_orb_spawned = true
		if debug_logs:
			pass
		
		# Small delay before orb appears
		await get_tree().create_timer(1.0).timeout
		_spawn_orb(true)  # true = FULLY charged (penalty is just the debuff)

func _spawn_orb(fully_charged: bool) -> void:
	if orb_scene == null:
		push_error("[SubArenaController] orb_scene not assigned!")
		return
	
	var orb = orb_scene.instantiate() as AscensionCharge
	if orb == null:
		push_error("[SubArenaController] orb_scene must be AscensionCharge!")
		return
	
	get_tree().current_scene.add_child(orb)
	orb.global_position = orb_spawn_position
	
	# If fully charged, max it out immediately
	if fully_charged:
		orb.charged_seconds = orb.charge_required_seconds
		if orb.has_method("_emit_charge_progress"):
			orb._emit_charge_progress()
	
	_active_orb = orb
	
	# Connect pickup signal
	if orb.has_signal("picked_up"):
		orb.picked_up.connect(_on_orb_picked_up)
	
	if debug_logs:
		pass

func _on_orb_picked_up(_carrier: Node2D) -> void:
	if debug_logs:
		pass

	if lock_charge_drop_until_socketed:
		var charge_carrier: Node = _player.get_node_or_null("ChargeCarrier")
		if charge_carrier != null and charge_carrier.has_method("set_drop_locked"):
			charge_carrier.call("set_drop_locked", true)
			if debug_logs:
				print("[SubArenaController] Charge drop lock enabled.")
	
	# If wrong portal, apply damage debuff
	if not _is_correct_portal:
		_apply_damage_debuff()
	
	# Wait a moment, then start return teleport
	await get_tree().create_timer(0.5).timeout
	_start_return_teleport()

func _apply_damage_debuff() -> void:
	if _player == null:
		return
	
	if debug_logs:
		pass
	
	# Apply debuff to player
	if _player.has_method("apply_damage_modifier"):
		_player.apply_damage_modifier(-0.10, 30.0)  # -10% for 30s
	else:
		# Fallback: use metadata
		_player.set_meta("damage_modifier", 0.90)  # 90% damage output
		_player.set_meta("damage_modifier_expiry", Time.get_ticks_msec() + 30000)
		
		if debug_logs:
			pass

func _start_return_teleport() -> void:
	if _source_scene_path == "":
		push_error("[SubArenaController] No source scene to return to!")
		return
	
	_suppress_player_healing_vfx(4.0)

	if debug_logs:
		pass
		pass
	
	# Check if player is carrying a charge
	var has_charge: bool = false
	var charge_carrier = _player.get_node_or_null("ChargeCarrier")
	if charge_carrier != null and charge_carrier.has_method("is_carrying"):
		has_charge = charge_carrier.is_carrying()
		if debug_logs:
			pass
	
	# Get boss state to preserve (use saved values from _ready())
	var boss_phase: int = _boss_phase_saved
	var boss_hp: int = _boss_hp_saved
	
	# Get player state to preserve
	var player_hp: int = 100
	var player_max_hp: int = 100
	var player_cooldowns: Dictionary = {}
	var player_dodge_charges: int = 0
	var player_dodge_accum: float = 0.0
	
	if _player != null:
		var player_health = _player.get_node_or_null("Health")
		if player_health != null:
			if "hp" in player_health:
				player_hp = player_health.hp
			if "max_hp" in player_health:
				player_max_hp = player_health.max_hp
		
		# Save cooldowns from PlayerCombat
		var player_combat = _player.get_node_or_null("Combat")
		if player_combat != null:
			if "get_cooldown_left" in player_combat:
				# Save remaining cooldown times
				player_cooldowns["light"] = player_combat.get_cooldown_left(&"light")
				player_cooldowns["heavy"] = player_combat.get_cooldown_left(&"heavy")
				player_cooldowns["ultimate"] = player_combat.get_cooldown_left(&"ultimate")
				player_cooldowns["defend"] = player_combat.get_cooldown_left(&"defend")
				player_cooldowns["BIGD"] = player_combat.get_cooldown_left(&"BIGD")
		
		# Save dodge charges from PlayerController
		if "get_roll_charges" in _player:
			player_dodge_charges = _player.get_roll_charges()
		if "_roll_recharge_accum" in _player:
			player_dodge_accum = _player._roll_recharge_accum
	
	if debug_logs:
		pass
		pass
	
	# Disable player input
	if _player.has_method("set_input_locked"):
		_player.set_input_locked(true)
	
	# Store return data in global singleton (persists across scene changes)
	var portal_data = get_node_or_null("/root/PortalTransitionData")
	if portal_data == null:
		push_error("[SubArenaController] PortalTransitionData autoload not found!")
		return
	
	portal_data.set_return_data(_return_position, _source_scene_path, has_charge, boss_phase, boss_hp, player_hp, player_max_hp, player_cooldowns, player_dodge_charges, player_dodge_accum)
	
	# Create fade overlay
	var fade_overlay = _create_fade_overlay()
	
	# Fade to black (1.5s)
	await _fade_screen(fade_overlay, 0.0, 1.0, 1.5)
	
	# Change scene back to boss arena
	get_tree().change_scene_to_file(_source_scene_path)

func _create_fade_overlay() -> ColorRect:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1000
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(overlay)
	
	return overlay

func _fade_screen(overlay: ColorRect, from_alpha: float, to_alpha: float, duration: float) -> void:
	overlay.color.a = from_alpha
	
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", to_alpha, duration)
	
	await tween.finished

func _wait_for_settle_hidden(nodes: Array[Node], groups: Array[StringName], timeout_seconds: float) -> bool:
	var timeout: float = maxf(timeout_seconds, 0.0)
	var elapsed: float = 0.0
	var min_accept_time: float = maxf(settle_min_stable_time_before_accept, 0.0)
	var last_log_bucket: int = -1
	while elapsed < timeout:
		var settled_now: bool = _all_targets_settled(nodes, groups)
		if settled_now and elapsed >= min_accept_time:
			return true
		if debug_logs:
			var bucket: int = int(elapsed * 4.0) # every ~0.25s
			if bucket != last_log_bucket:
				last_log_bucket = bucket
				print("[SubArenaController] Settling... t=", snappedf(elapsed, 0.01), " min_accept=", snappedf(min_accept_time, 0.01), " settled_now=", settled_now, " player=", _describe_node_settle(_player))
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	var final_settled: bool = _all_targets_settled(nodes, groups)
	if debug_logs:
		print("[SubArenaController] Settle wait ended. final_settled=", final_settled, " player=", _describe_node_settle(_player))
	return final_settled

func _all_targets_settled(nodes: Array[Node], groups: Array[StringName]) -> bool:
	for n: Node in nodes:
		if not _is_node_settled(n):
			return false
	for g: StringName in groups:
		var group_nodes: Array[Node] = get_tree().get_nodes_in_group(g)
		for gn: Node in group_nodes:
			if not _is_node_settled(gn):
				return false
	return true

func _is_node_settled(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return true
	var body: CharacterBody2D = node as CharacterBody2D
	if body != null:
		return body.is_on_floor()
	if "velocity" in node:
		var v: Vector2 = node.get("velocity")
		return absf(v.y) <= 8.0
	return true

func _log_unsettled_targets(nodes: Array[Node], groups: Array[StringName]) -> void:
	if not debug_logs:
		return
	for n: Node in nodes:
		if not _is_node_settled(n):
			print("[SubArenaController] Unsettled direct target: ", _describe_node_settle(n))
	for g: StringName in groups:
		var group_nodes: Array[Node] = get_tree().get_nodes_in_group(g)
		for gn: Node in group_nodes:
			if not _is_node_settled(gn):
				print("[SubArenaController] Unsettled group target [", str(g), "]: ", _describe_node_settle(gn))

func _describe_node_settle(node: Node) -> String:
	if node == null:
		return "<null>"
	if not is_instance_valid(node):
		return "<invalid>"
	var body: CharacterBody2D = node as CharacterBody2D
	if body != null:
		return "%s floor=%s vel=%s pos=%s" % [body.name, str(body.is_on_floor()), str(body.velocity), str(body.global_position)]
	if "velocity" in node:
		return "%s vel=%s" % [node.name, str(node.get("velocity"))]
	return "%s (no velocity)" % node.name

func _set_subarena_enemy_physics_enabled(enabled: bool) -> void:
	var group_nodes: Array[Node] = get_tree().get_nodes_in_group(&"subarena_enemies")
	for n: Node in group_nodes:
		if n == null or not is_instance_valid(n):
			continue
		n.set_physics_process(enabled)
	if debug_logs:
		print("[SubArenaController] Subarena enemy physics set to ", "ENABLED" if enabled else "DISABLED")

func _suppress_player_healing_vfx(seconds: float) -> void:
	if _player == null:
		return
	var player_health: Node = _player.get_node_or_null("Health")
	if player_health != null and player_health.has_method("suppress_healing_vfx_for"):
		player_health.call("suppress_healing_vfx_for", seconds)
