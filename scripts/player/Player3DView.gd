# res://scripts/player/Player3DView.gd
extends Node2D
class_name Player3DView

signal stage_animation_finished(anim_name: StringName)

@export var stage_scene: PackedScene

@export var subviewport_path: NodePath = ^"SubViewport"
@export var screen_sprite_path: NodePath = ^"ScreenSprite"
@export var onscreen_notifier_path: NodePath = ^"VisibleOnScreenNotifier2D"

@export var viewport_size: Vector2i = Vector2i(512, 512)

# Optional: not required by PlayerController (it sends explicit names),
# but kept here for future use / inspector convenience.
@export var anim_idle: StringName = &""
@export var anim_run: StringName = &""
@export var anim_jump_start: StringName = &""
@export var anim_jump: StringName = &""
@export var anim_fall: StringName = &""
@export var anim_light_attack: StringName = &""

@export var screen_pixels: Vector2i = Vector2i(256, 256) # how big the character appears in 2D

# Debugging: when true, missing animation names print warnings instead of failing silently.
@export var debug_print_missing_anims: bool = false

# Paths inside your stage scene
@export var stage_knight_root_path: NodePath = ^"FacingPivot"
@export var stage_animation_player_path: NodePath = ^"FacingPivot/Knight/AnimationPlayer"

var _subviewport: SubViewport
var _screen_sprite: Sprite2D
var _notifier: VisibleOnScreenNotifier2D

var _stage_root: Node3D
var _knight_root: Node3D  # Legacy name - now points to current model
var _model_root: Node3D  # Generic reference to current character model
var _anim_player: AnimationPlayer

var _facing: int = 1

# Dynamic character loading
var _animation_map: Dictionary = {}  # generic_name -> actual_animation_name
var _loaded_model_path: String = ""  # Track currently loaded model
var _default_speed_scale: float = 1.0  # Character's default animation speed



func _ready() -> void:
	_subviewport = get_node_or_null(subviewport_path) as SubViewport
	_screen_sprite = get_node_or_null(screen_sprite_path) as Sprite2D
	_notifier = get_node_or_null(onscreen_notifier_path) as VisibleOnScreenNotifier2D

	if _subviewport == null:
		push_error("Player3DView: Missing SubViewport at %s" % [subviewport_path])
		return
	if _screen_sprite == null:
		push_error("Player3DView: Missing ScreenSprite at %s" % [screen_sprite_path])
		return

	_configure_viewport()
	_instance_stage()
	
	# ✅ Character Selection Integration: Load character from GameManager if available
	_load_selected_character()

	if _notifier != null:
		if not _notifier.screen_entered.is_connected(_on_screen_entered):
			_notifier.screen_entered.connect(_on_screen_entered)
		if not _notifier.screen_exited.is_connected(_on_screen_exited):
			_notifier.screen_exited.connect(_on_screen_exited)


func _process(_delta: float) -> void:
	# Safety: If a loop animation stops playing unexpectedly, restart it
	if _anim_player != null and _last_loop_anim != "" and not _anim_player.is_playing():
		# Animation stopped but we expected it to loop
		_anim_player.play(_last_loop_anim, 0.0, 1.0, false)

func _configure_viewport() -> void:
	_subviewport.size = viewport_size
	_subviewport.transparent_bg = true
	_subviewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_screen_sprite.texture = _subviewport.get_texture()
	_screen_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# ✅ Decouple render resolution from on-screen size:
	# Draw the viewport texture at a fixed pixel size in 2D.
	_screen_sprite.region_enabled = true
	_screen_sprite.region_rect = Rect2(Vector2.ZERO, Vector2(viewport_size))
	_screen_sprite.scale = Vector2(
		float(screen_pixels.x) / maxf(float(viewport_size.x), 1.0),
		float(screen_pixels.y) / maxf(float(viewport_size.y), 1.0)
	)

func _instance_stage() -> void:
	if stage_scene == null:
		push_error("Player3DView: stage_scene not set.")
		return

	for c in _subviewport.get_children():
		c.queue_free()

	var inst: Node = stage_scene.instantiate()
	_subviewport.add_child(inst)

	_stage_root = inst as Node3D
	if _stage_root == null:
		push_error("Player3DView: stage_scene root must be Node3D.")
		return

	_knight_root = _stage_root.get_node_or_null(stage_knight_root_path) as Node3D
	# _knight_root is FacingPivot (the container)
	# _model_root should point to the actual character model inside FacingPivot
	if _knight_root != null and _knight_root.get_child_count() > 0:
		_model_root = _knight_root.get_child(0) as Node3D
	
	_anim_player = _stage_root.get_node_or_null(stage_animation_player_path) as AnimationPlayer

	if _anim_player == null:
		push_error("Player3DView: Missing AnimationPlayer at %s" % [stage_animation_player_path])
		return

	if not _anim_player.animation_finished.is_connected(_on_stage_anim_finished):
		_anim_player.animation_finished.connect(_on_stage_anim_finished)

	_apply_facing()

func _on_stage_anim_finished(anim_name_str: String) -> void:
	stage_animation_finished.emit(StringName(anim_name_str))

## Called by PlayerController when dash movement ends - trigger early idle transition
func set_facing(dir: int) -> void:
	_facing = -1 if dir < 0 else 1
	_apply_facing()

func _apply_facing() -> void:
	# Rotate FacingPivot container (not the model itself)
	# _knight_root points to FacingPivot after _instance_stage()
	if _knight_root == null:
		return
	# Your rig faces the camera by default, so we rotate it to side-view.
	_knight_root.rotation.y = deg_to_rad(90.0) if _facing == 1 else deg_to_rad(-90.0)

func _extract_generic_name(anim_name: String) -> StringName:
	"""Extract generic animation name from full animation path
	e.g., 'Player/Idle_B' -> 'idle', 'Player/Melee_1H_Attack_Slice_Diagonal' -> 'light_attack'
	"""
	# Create a reverse lookup from Knight's animation names to generic names
	# This is based on knight_data.tres mappings
	const KNIGHT_TO_GENERIC := {
		"Player/Idle_B": &"idle",
		"Player/Running_B": &"run",
		"Player/Jump_Start": &"jump_start",
		"Player/Jump_Idle": &"jump",
		"Player/Jump_Land": &"jump_land",
		"Player/Melee_1H_Attack_Slice_Diagonal": &"light_attack",
		"Player/Melee_2H_Attack_Spin": &"heavy_attack",
		"Player/Hit_A": &"hit",
		"Player/Death_B": &"death",
		"Player/Interact": &"interact",
		"Player/Holding_A": &"hold",
		"Player/Dodge_Backward": &"dodge",
		"Player/Dodge_Forward": &"dodge",  # Both dodge directions map to same generic
	}
	
	# Check if this is a Knight animation that needs mapping
	if KNIGHT_TO_GENERIC.has(anim_name):
		return KNIGHT_TO_GENERIC[anim_name]
	
	# If not found, try to extract from the animation name itself
	# e.g., if someone passes "idle" directly, use it as-is
	return StringName(anim_name)

func _get_actual_anim_name(a: String) -> String:
	"""Convert generic animation name to actual animation name using mapping"""
	if _animation_map.is_empty():
		return a  # No mapping, use as-is (backward compatibility)
	
	# Extract generic name first (in case full path was passed)
	var generic_name := _extract_generic_name(a)
	
	if _animation_map.has(generic_name):
		return String(_animation_map[generic_name])
	
	return a  # No mapping found, use as-is

func _has_anim_name(a: String) -> bool:
	if _anim_player == null:
		return false
	
	# If we have animation mappings, ALWAYS use them (character-specific animations)
	if not _animation_map.is_empty():
		# Try to extract generic name from full animation path
		# e.g., "Player/Idle_B" -> "idle", "Player/Running_B" -> "run"
		var generic_name := _extract_generic_name(a)
		
		if _animation_map.has(generic_name):
			var mapped := String(_animation_map[generic_name])
			if _anim_player.has_animation(mapped):
				return true
			elif debug_print_missing_anims:
				push_warning("Player3DView: Mapped animation '%s' -> '%s' not found" % [a, mapped])
				return false
		else:
			# Generic name not in mapping
			if debug_print_missing_anims:
				push_warning("Player3DView: No mapping for animation: '%s' (generic: '%s')" % [a, generic_name])
			return false
	
	# No mapping (backward compatibility) - check direct animation name
	if _anim_player.has_animation(a):
		return true
	
	if debug_print_missing_anims:
		push_warning("Player3DView: Missing animation: '%s' (check spaces/case)" % a)
	return false

var _last_loop_anim: String = ""

func play_loop(anim: StringName, restart: bool = false) -> void:
	if _anim_player == null:
		return
	if anim == &"":
		return

	var a: String = String(anim)
	if not _has_anim_name(a):
		return
	
	# Get actual animation name (mapped or direct)
	var actual_anim: String = _get_actual_anim_name(a)

	# For loops, restore character's default animation speed (Knight=2.0, Rogue=1.0)
	_anim_player.speed_scale = _default_speed_scale

	# Only skip if same animation is actively playing
	if (not restart) and _anim_player.is_playing() and _anim_player.current_animation == actual_anim:
		_last_loop_anim = actual_anim
		return

	# Play animation with explicit blend time for smooth transitions
	_anim_player.play(actual_anim, 0.1, 1.0, false)  # 0.1s blend time
	_last_loop_anim = actual_anim


func force_reset_animation(anim: StringName) -> void:
	# ✅ NUCLEAR OPTION: Force animation change with complete reset
	if _anim_player == null:
		return
	if anim == &"":
		return
	
	var a: String = String(anim)
	if not _has_anim_name(a):
		return
	
	# Get actual animation name (mapped or direct)
	var actual_anim: String = _get_actual_anim_name(a)
	
	# Stop current animation
	_anim_player.stop()
	# Reset to beginning
	_anim_player.seek(0.0, true)
	# Play new animation
	_anim_player.play(actual_anim)
	# Force advance to first frame
	_anim_player.advance(0.0)

func play_one_shot(anim: StringName, restart: bool = true, speed: float = 1.0) -> void:
	if _anim_player == null:
		return
	if anim == &"":
		return

	var a: String = String(anim)
	if not _has_anim_name(a):
		return
	
	# Get actual animation name (mapped or direct)
	var actual_anim: String = _get_actual_anim_name(a)

	var s: float = clampf(speed, 0.05, 10.0)  # Increased max speed to 10x for rapid animations
	_anim_player.speed_scale = s

	if (not restart) and _anim_player.is_playing() and _anim_player.current_animation == actual_anim:
		return

	# Clear loop tracking since we're playing a one-shot
	_last_loop_anim = ""
	
	# When using speed_scale, keep custom_speed at 1.0
	_anim_player.play(actual_anim, 0.0, 1.0, false)


func play_one_shot_from_end(anim: StringName, restart: bool = true, speed: float = 1.0) -> void:
	if _anim_player == null:
		return
	if anim == &"":
		return

	var a: String = String(anim)
	if not _has_anim_name(a):
		return
	
	# Get actual animation name (mapped or direct)
	var actual_anim: String = _get_actual_anim_name(a)

	# If we're already playing this clip and restart == false, do nothing (matches play_one_shot behavior)
	if (not restart) and _anim_player.is_playing() and _anim_player.current_animation == actual_anim:
		return

	# Reverse playback:
	# - negative custom_speed plays backwards
	# - from_end=true starts at the end
	var s: float = clampf(speed, 0.05, 5.0)

	# Important: do NOT use speed_scale + custom_speed together (it multiplies).
	_anim_player.speed_scale = 1.0
	_anim_player.play(actual_anim, 0.0, -s, true)

func set_viewport_updates_enabled(enabled: bool) -> void:
	if _subviewport == null:
		return
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED

func _on_screen_entered() -> void:
	set_viewport_updates_enabled(true)

func _on_screen_exited() -> void:
	set_viewport_updates_enabled(false)

func get_anim_length(anim: StringName) -> float:
	if _anim_player == null:
		return 0.0
	if anim == &"":
		return 0.0

	var a: String = String(anim)
	if not _has_anim_name(a):
		return 0.0
	
	# Get actual animation name (mapped or direct)
	var actual_anim: String = _get_actual_anim_name(a)

	var clip: Animation = _anim_player.get_animation(actual_anim)
	return maxf(clip.length, 0.0)

func is_playing_any() -> bool:
	return _anim_player != null and _anim_player.is_playing()

func get_current_anim() -> StringName:
	if _anim_player == null:
		return &""
	return StringName(_anim_player.current_animation)

## Load character based on CharacterDatabase.selected_character
func _load_selected_character() -> void:
	# Check CharacterDatabase for selected character
	var selected_char: String = CharacterDatabase.get_selected_character()
	if selected_char == "":
		pass
		_load_default_character()
		return
	
	# Get character data from database
	if CharacterDatabase == null:
		push_error("[Player3DView] CharacterDatabase not found, loading default")
		_load_default_character()
		return
	
	if not CharacterDatabase.has_character(selected_char):
		push_error("[Player3DView] Character '%s' not found in database, loading default" % selected_char)
		_load_default_character()
		return
	
	var char_data: CharacterData = CharacterDatabase.get_character_data(selected_char)
	if char_data == null or not char_data.is_valid():
		push_error("[Player3DView] Invalid character data for '%s', loading default" % selected_char)
		_load_default_character()
		return
	
	pass
	
	# Load the character model
	if not load_character_model(char_data.model_scene_path):
		push_error("[Player3DView] Failed to load character model: %s" % char_data.model_scene_path)
		return
	
	# Set animation mappings
	set_animation_map(char_data.animation_mappings)
	
	pass


func _load_default_character() -> void:
	"""Load Rogue as default character"""
	const ROGUE_DATA := preload("res://resources/characters/rogue_data.tres")
	
	if not load_character_model(ROGUE_DATA.model_scene_path):
		push_error("[Player3DView] Failed to load default character model")
		return
	
	set_animation_map(ROGUE_DATA.animation_mappings)
	pass

## Set animation mappings for character-specific animations
func set_animation_map(mappings: Dictionary) -> void:
	_animation_map = mappings.duplicate()
	#print("[Player3DView] Animation map set with %d mappings" % _animation_map.size())

## Dynamically load a character model into the stage
func load_character_model(model_scene_path: String) -> bool:
	if model_scene_path == "":
		push_error("[Player3DView] load_character_model: empty model_scene_path")
		return false
	
	# Don't reload if it's already loaded
	if _loaded_model_path == model_scene_path and _model_root != null:
		pass
		return true
	
	# Find FacingPivot node in stage (the container for character models)
	var facing_pivot: Node3D = _stage_root.get_node_or_null(stage_knight_root_path) as Node3D
	if facing_pivot == null:
		push_error("[Player3DView] FacingPivot not found at: %s" % stage_knight_root_path)
		return false
	
	# Clear existing model(s) from FacingPivot (remove children, keep container)
	for child in facing_pivot.get_children():
		facing_pivot.remove_child(child)
		child.queue_free()
	
	# Load the model scene
	var model_scene: PackedScene = load(model_scene_path)
	if model_scene == null:
		push_error("[Player3DView] Failed to load model scene: %s" % model_scene_path)
		return false
	
	# Instance new model
	var model_inst: Node = model_scene.instantiate()
	if model_inst == null:
		push_error("[Player3DView] Failed to instantiate model: %s" % model_scene_path)
		return false
	
	# Add model to FacingPivot
	facing_pivot.add_child(model_inst)
	_model_root = model_inst as Node3D
	
	# Find AnimationPlayer in the new model
	var new_anim_player: AnimationPlayer = _find_animation_player(model_inst)
	if new_anim_player == null:
		push_error("[Player3DView] No AnimationPlayer found in model: %s" % model_scene_path)
		return false
	
	# Disconnect old animation player
	if _anim_player != null and _anim_player.animation_finished.is_connected(_on_stage_anim_finished):
		_anim_player.animation_finished.disconnect(_on_stage_anim_finished)
	
	# Connect new animation player
	_anim_player = new_anim_player
	if not _anim_player.animation_finished.is_connected(_on_stage_anim_finished):
		_anim_player.animation_finished.connect(_on_stage_anim_finished)
	
	# Save the character's default animation speed (Knight=2.0, Rogue=1.0)
	_default_speed_scale = _anim_player.speed_scale
	pass
	
	_loaded_model_path = model_scene_path
	_apply_facing()
	
	#print("[Player3DView] Loaded character model: %s" % model_scene_path)
	return true

## Find AnimationPlayer in node tree (recursive search)
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	
	return null
