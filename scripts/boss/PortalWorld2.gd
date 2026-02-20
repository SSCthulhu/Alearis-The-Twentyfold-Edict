extends Node2D
class_name PortalWorld2

# Portal that teleports player to sub-arena
@export var player_path: NodePath = ^"../Player"
@export var interact_key: String = "interact"
@export var debug_logs: bool = false

var _player: CharacterBody2D = null
var _player_nearby: bool = false
var _portal_active: bool = true

var _portal_color: String = ""  # "void", "light", "shadow"
var _is_correct: bool = false
var _target_scene_path: String = ""
var _return_position: Vector2 = Vector2.ZERO

@onready var interaction_area: Area2D = $InteractionArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_player = get_node_or_null(player_path)
	if _player == null:
		push_error("[PortalWorld2] Player not found at: ", player_path)
		return
	
	if interaction_area:
		# Connecting signals to the functions defined below
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	
	if debug_logs:
		pass

# --- Configuration Methods ---

func setup(portal_color: String, is_correct: bool, _visual_color: Color) -> void:
	_portal_color = portal_color
	_is_correct = is_correct
	
	# Set the animation based on the portal type
	if sprite and sprite.sprite_frames.has_animation(portal_color):
		sprite.play(portal_color)
		# Optional: Use the old color variable to modulate/tint the sprite
		sprite.modulate = _visual_color
	else:
		push_warning("[PortalWorld2] Animation not found: ", portal_color)
	
	if debug_logs:
		pass

func set_target_scene(scene_path: String) -> void:
	_target_scene_path = scene_path

func set_return_position(pos: Vector2) -> void:
	_return_position = pos

# --- Signal Callbacks ---

func _on_body_entered(body: Node2D) -> void:
	if body == _player:
		_player_nearby = true
		if debug_logs:
			pass

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_nearby = false

# --- Interaction Logic ---

func _process(_delta: float) -> void:
	if not _portal_active or not _player_nearby:
		return
	
	if Input.is_action_just_pressed(interact_key):
		_enter_portal()

func _enter_portal() -> void:
	if _player == null or _target_scene_path == "":
		return
	
	_portal_active = false
	
	if debug_logs:
		pass

	# --- Save Game State to Global Singleton ---
	var portal_data = get_node_or_null("/root/PortalTransitionData")
	if portal_data:
		# Extract Boss Data
		var boss_phase: int = 1
		var boss_hp: int = 2000
		var boss_encounter = get_tree().current_scene.get_node_or_null("BossEncounterWorld2")
		if boss_encounter:
			if "phase" in boss_encounter: boss_phase = boss_encounter.phase
			var boss = get_tree().get_first_node_in_group("boss")
			if boss and "hp" in boss: boss_hp = boss.hp

		# Extract Player Data
		var p_hp: int = 100
		var p_max: int = 100
		var p_cds: Dictionary = {}
		var p_charges: int = 0
		var p_accum: float = 0.0

		var p_health = _player.get_node_or_null("Health")
		if p_health:
			p_hp = p_health.hp
			p_max = p_health.max_hp
		
		var p_combat = _player.get_node_or_null("Combat")
		if p_combat and p_combat.has_method("get_cooldown_left"):
			for cd in ["light", "heavy", "ultimate", "defend", "BIGD"]:
				p_cds[cd] = p_combat.get_cooldown_left(StringName(cd))

		if _player.has_method("get_roll_charges"):
			p_charges = _player.get_roll_charges()
			p_accum = _player._roll_recharge_accum if "_roll_recharge_accum" in _player else 0.0

		portal_data.set_portal_data(
			_is_correct, _return_position, get_tree().current_scene.scene_file_path,
			boss_phase, boss_hp, p_hp, p_max, p_cds, p_charges, p_accum
		)
	
	_do_fade_teleport()

# --- Visual Effects & Scene Transition ---

func _do_fade_teleport() -> void:
	if _player.has_method("set_input_locked"):
		_player.set_input_locked(true)
	
	var fade_overlay = _create_fade_overlay()
	await _fade_screen(fade_overlay, 0.0, 1.0, 1.5)
	
	get_tree().change_scene_to_file(_target_scene_path)

func _create_fade_overlay() -> ColorRect:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().current_scene.add_child(canvas_layer)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	# Critical: Forces the UI element to fill the screen regardless of Node2D position
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(overlay)
	
	return overlay

func _fade_screen(overlay: ColorRect, from_alpha: float, to_alpha: float, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", to_alpha, duration).from(from_alpha)
	await tween.finished


	
