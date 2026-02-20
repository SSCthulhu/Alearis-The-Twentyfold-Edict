extends StaticBody2D
class_name BossController

signal health_changed(current: int, max_value: int)
signal died

@export var max_hp: int = 5000
var hp: int = 0

@export var player_path: NodePath = ^"../Player"

# ----------------------------
# Damage numbers (via emitter)
# ----------------------------
@export var damage_number_emitter_path: NodePath = ^"DamageNumberEmitter"
var _dn: DamageNumberEmitter = null

# ----------------------------
# Visuals
# ----------------------------
@export var visual_path: NodePath = ^"Sprite2D"
@export var shield_color: Color = Color(0.2, 0.7, 1.0, 1.0)
@export var vulnerable_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var hit_flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var hit_flash_time: float = 0.06

@export var boss_name: String = "Valtrex, the Severed"

# ------------------------------------------------------------
# Projectile Attacks (Bullet Hell System)
# ------------------------------------------------------------
@export var projectile_attack_path: NodePath = ^"BossProjectileAttack"
@export var projectile_auto_cast: bool = true
@export var projectile_interval_min: float = 1.5
@export var projectile_interval_max: float = 3.5

var _projectile_attack: Node = null
var _projectile_ai_timer: Timer = null
var _projectile_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _manual_facing_control: bool = false  # When true, disable automatic facing updates
var _attack_speed_multiplier: float = 1.0  # Speed up attacks during forge phase

# ------------------------------------------------------------
# 3D Visual & Facing
# ------------------------------------------------------------
@export var boss_3d_visual_path: NodePath = ^"BlackKnight3DView"
@export var idle_animation: String = "KAnim/Idle_B"
@export var hit_animation: String = "KAnim/Hit_A"
@export var death_animation: String = "KAnim/Death_A"

var _boss_3d_visual: Node2D = null

func get_boss_name() -> String:
	return boss_name

var _player: Node2D = null

var _vulnerable: bool = false
var _attacks_enabled: bool = false  # Start disabled, encounter controller will enable

var _visual: CanvasItem = null
var _flash_timer: float = 0.0

var _combat_paused: bool = false
var _dead: bool = false


func _ready() -> void:
	add_to_group(&"boss")
	add_to_group(&"floor5_enemies")  # Make boss targetable by Rogue ultimate
	
	# Debug: Verify groups
	#print("[Boss DEBUG] Added to groups. Current groups: ", get_groups())
	#print("[Boss DEBUG] In 'boss' group: ", is_in_group(&"boss"))
	#print("[Boss DEBUG] In 'floor5_enemies' group: ", is_in_group(&"floor5_enemies"))

	set_process(true)

	hp = max_hp
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if _player == null:
		push_warning("[Boss] Player not found. Set player_path in Inspector or add player to group 'player'.")

	_dn = get_node_or_null(damage_number_emitter_path) as DamageNumberEmitter
	if _dn == null:
		push_warning("[Boss] DamageNumberEmitter not found. Add a child named 'DamageNumberEmitter' or set damage_number_emitter_path.")

	_visual = get_node_or_null(visual_path) as CanvasItem
	if _visual == null:
		push_warning("[Boss] Visual not found. Set visual_path to your Sprite2D.")
	#else:
		#print("[Boss] Visual found:", _visual.name)

	_init_projectile_attack()
	_init_projectile_scheduler()
	# Don't arm projectile scheduler yet - wait for set_attacks_enabled(true) from encounter controller

	_init_3d_visual()

	_apply_visual_state()

	health_changed.emit(hp, max_hp)
	#print("[Boss] Ready. HP=", hp)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer = maxf(_flash_timer - delta, 0.0)
		if _flash_timer <= 0.0:
			_apply_visual_state()

	# Update facing to look at player
	_update_facing()

	if _combat_paused:
		return

	# Attacks triggered externally by EncounterController.
	pass


func set_combat_paused(p: bool) -> void:
	_combat_paused = p

	if _combat_paused:
		_disarm_projectile_scheduler()
	else:
		_arm_projectile_scheduler()


func set_vulnerable(v: bool) -> void:
	_vulnerable = v
	#print("[Boss] set_vulnerable(", _vulnerable, ")")
	_apply_visual_state()

	# Notify player relics (R6 Orb Surge)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	# Prefer node by name if that's how your Player scene is structured
	var rep := player.get_node_or_null(^"RelicEffectsPlayer")
	if rep == null:
		# Fallback: search any child (safe)
		rep = player.find_child("RelicEffectsPlayer", true, false)

	if rep != null and rep.has_method("set_boss_vulnerable"):
		rep.call("set_boss_vulnerable", _vulnerable) # or v


func set_attacks_enabled(enabled: bool) -> void:
	_attacks_enabled = enabled
	#print("[Boss] set_attacks_enabled(", _attacks_enabled, ")")

	if not _attacks_enabled:
		_disarm_projectile_scheduler()
	else:
		_arm_projectile_scheduler()


func set_attack_speed_multiplier(multiplier: float) -> void:
	"""Set attack speed multiplier (1.0 = normal, 1.5 = 50% faster)"""
	_attack_speed_multiplier = maxf(multiplier, 0.1)
	# Reschedule next attack with new timing
	if _projectile_ai_timer != null and _attacks_enabled:
		_disarm_projectile_scheduler()
		_arm_projectile_scheduler()


func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0


func take_damage(amount: int, _source: Node = null, tag: StringName = &"", is_crit: bool = false) -> void:
	pass
	
	if amount <= 0:
		return
	if hp <= 0:
		return

	if not _vulnerable:
		#print("[Boss] Immune (not in DPS).")
		if _dn != null:
			_dn.show_text("IMMUNE", Color(0.65, 0.85, 1.0), 1.05)
		return

	# Forward to BossHealth for VFX handling
	var boss_health: Node = get_node_or_null("BossHealth")
	if boss_health != null and boss_health.has_method("take_damage"):
		pass
		boss_health.call("take_damage", amount, _source, tag, is_crit)
	else:
		pass
	
	hp = maxi(hp - amount, 0)
	#print("[Boss] took ", amount, " dmg. HP now=", hp)

	health_changed.emit(hp, max_hp)
	_flash_hit()
	
	# Play hit animation
	if _boss_3d_visual != null and _boss_3d_visual.has_method("play_one_shot") and hit_animation != "":
		_boss_3d_visual.call("play_one_shot", hit_animation, true, 1.5)  # Play faster (1.5x speed)
		#print("[Boss] Playing hit animation: ", hit_animation)

	if _dn != null:
		_dn.show_damage(amount, tag, is_crit)

	if hp <= 0:
		_dead = true
		#print("[Boss] defeated (prototype).")
		
		# Play death animation
		if _boss_3d_visual != null and _boss_3d_visual.has_method("play_one_shot") and death_animation != "":
			_boss_3d_visual.call("play_one_shot", death_animation)
			#print("[Boss] Playing death animation: ", death_animation)
		
		died.emit()

		set_attacks_enabled(false)
		set_combat_paused(true)

		set_combat_paused(true)
		set_attacks_enabled(false)
		set_vulnerable(false)

		visible = false
		collision_layer = 0
		collision_mask = 0
		set_process(false)


func _apply_visual_state() -> void:
	if _visual == null:
		return
	if _flash_timer > 0.0:
		return
	_set_visual_color(vulnerable_color)


func _flash_hit() -> void:
	if _visual == null:
		return
	_set_visual_color(hit_flash_color)
	_flash_timer = hit_flash_time


func _set_visual_color(c: Color) -> void:
	_visual.modulate = c
	if _visual is Sprite2D:
		(_visual as Sprite2D).self_modulate = c


func _get_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	
	return _player


# ============================================================
# PROJECTILE ATTACK SYSTEM (Bullet Hell)
# ============================================================

func _init_projectile_attack() -> void:
	_projectile_rng.randomize()
	_projectile_attack = get_node_or_null(projectile_attack_path)
	
	# Only warn if projectile auto-cast is enabled and the path is set but node not found
	if _projectile_attack == null and projectile_auto_cast and projectile_attack_path != NodePath():
		push_warning("[Boss] BossProjectileAttack not found at: ", projectile_attack_path)
	#else:
		#print("[Boss] BossProjectileAttack found: ", _projectile_attack.name)


func _init_projectile_scheduler() -> void:
	if _projectile_ai_timer != null:
		return
	
	_projectile_ai_timer = Timer.new()
	_projectile_ai_timer.one_shot = true
	add_child(_projectile_ai_timer)
	_projectile_ai_timer.timeout.connect(_on_projectile_ai_timeout)


func _arm_projectile_scheduler() -> void:
	if not projectile_auto_cast:
		return
	if _combat_paused or _dead:
		return
	if not _attacks_enabled:
		return
	if _projectile_ai_timer == null:
		return
	
	var base_time: float = _projectile_rng.randf_range(
		maxf(projectile_interval_min, 0.5), 
		maxf(projectile_interval_max, projectile_interval_min)
	)
	# Apply attack speed multiplier (higher multiplier = faster attacks)
	var t: float = base_time / _attack_speed_multiplier
	_projectile_ai_timer.stop()
	_projectile_ai_timer.wait_time = t
	_projectile_ai_timer.start()
	#print("[Boss] Projectile attack scheduled in %.2fs (multiplier: %.2f)" % [t, _attack_speed_multiplier])


func _disarm_projectile_scheduler() -> void:
	if _projectile_ai_timer == null:
		return
	_projectile_ai_timer.stop()


func _on_projectile_ai_timeout() -> void:
	if _projectile_attack != null and _projectile_attack.has_method("execute_attack"):
		# Pick a random attack pattern
		var attack_index: int = _projectile_rng.randi() % 2  # 0 or 1 (two World 2 patterns)
		_projectile_attack.call("execute_attack", attack_index)
		#print("[Boss] Executing projectile attack pattern #%d" % attack_index)
	
	# Schedule next attack
	_arm_projectile_scheduler()


## Public function to trigger a specific projectile pattern by index or name
func trigger_projectile_attack(pattern_id: Variant = -1) -> bool:
	if _projectile_attack == null:
		return false
	if not _projectile_attack.has_method("execute_attack"):
		return false
	
	_projectile_attack.call("execute_attack", pattern_id)
	return true


# ============================================================
# 3D VISUAL & FACING SYSTEM
# ============================================================

func _init_3d_visual() -> void:
	_boss_3d_visual = get_node_or_null(boss_3d_visual_path)
	
	if _boss_3d_visual == null:
		push_warning("[Boss] BlackKnight3DView not found at: ", boss_3d_visual_path)
		return
	
	#print("[Boss] 3D Visual found: ", _boss_3d_visual.name)
	#print("[Boss] 3D Visual type: ", _boss_3d_visual.get_class())
	#print("[Boss] Has play_loop method: ", _boss_3d_visual.has_method("play_loop"))
	
	# Start playing idle animation
	if idle_animation != "":
		if _boss_3d_visual.has_method("play_loop"):
			_boss_3d_visual.call("play_loop", StringName(idle_animation))
			#print("[Boss] Called play_loop with animation: ", idle_animation)
		else:
			push_warning("[Boss] 3D Visual doesn't have play_loop method!")
	else:
		push_warning("[Boss] No idle_animation configured!")


func _update_facing() -> void:
	if _manual_facing_control:
		return  # Skip automatic facing when manually controlled
	
	if _boss_3d_visual == null:
		return
	if not _boss_3d_visual.has_method("set_facing"):
		return
	
	var player: Node2D = _get_player()
	if player == null:
		return
	
	# Calculate facing direction based on player position
	var direction_to_player: float = player.global_position.x - global_position.x
	var facing_dir: int = 1 if direction_to_player > 0 else -1
	
	_boss_3d_visual.call("set_facing", facing_dir)

## Allow external control of facing (for attacks that need directional facing)
func set_manual_facing_control(enabled: bool) -> void:
	_manual_facing_control = enabled
