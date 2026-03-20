extends Node2D
class_name PlayerReflectionIndependentVFX

@export var clone_alpha: float = 0.95
@export var clone_scale: Vector2 = Vector2.ONE
@export var stage_scene: PackedScene = preload("res://scenes/vfx/Reflection3DStage.tscn")
@export var viewport_size: Vector2i = Vector2i(512, 512)
@export var screen_pixels: Vector2i = Vector2i(256, 256)

const KNIGHT_MODEL_PATH: String = "res://assets/scenes/knight.tscn"
const ROGUE_MODEL_PATH: String = "res://assets/scenes/rogue.tscn"

var _subviewport: SubViewport = null
var _screen_sprite: Sprite2D = null
var _stage_root: Node3D = null
var _facing_pivot: Node3D = null
var _anim_player: AnimationPlayer = null

func _ready() -> void:
	top_level = true
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	set_meta("dice_meter_reflection", true)
	_ensure_renderer()
	_apply_clone_visuals()

func configure_character(character_name: String, alpha: float = 0.95, visual_scale: float = 1.0) -> void:
	_ensure_renderer()
	clone_alpha = clampf(alpha, 0.05, 1.0)
	var clamped_scale: float = clampf(visual_scale, 0.35, 3.0)
	clone_scale = Vector2(clamped_scale, clamped_scale)
	var model_path: String = _resolve_model_path(character_name)
	_load_character_model(model_path)
	_apply_clone_visuals()
	play_idle()

func configure_render_profile(viewport_px: Vector2i, screen_px: Vector2i) -> void:
	viewport_size = viewport_px
	screen_pixels = screen_px
	_apply_render_surface()
	_apply_clone_visuals()

func set_facing_toward(target_pos: Vector2) -> void:
	if _facing_pivot == null:
		return
	var facing: int = 1 if target_pos.x >= global_position.x else -1
	_facing_pivot.rotation.y = deg_to_rad(90.0) if facing == 1 else deg_to_rad(-90.0)

func play_idle() -> void:
	var anim_name: String = _resolve_idle_anim_name()
	if anim_name == "" or _anim_player == null:
		return
	_anim_player.speed_scale = 1.0
	_anim_player.play(anim_name, 0.08, 1.0, false)

func play_heavy() -> void:
	var anim_name: String = _resolve_heavy_anim_name()
	if anim_name == "" or _anim_player == null:
		return
	_anim_player.speed_scale = 1.0
	_anim_player.play(anim_name, 0.0, 1.0, false)

func get_debug_snapshot() -> Dictionary:
	var out: Dictionary = {
		"anim": "",
		"anim_playing": false,
		"facing_child_count": 0,
		"facing_children": [],
		"subviewport_mode": -1,
		"global_pos": global_position
	}
	if _anim_player != null and is_instance_valid(_anim_player):
		out["anim"] = String(_anim_player.current_animation)
		out["anim_playing"] = _anim_player.is_playing()
	if _facing_pivot != null and is_instance_valid(_facing_pivot):
		var names: Array[String] = []
		for c: Node in _facing_pivot.get_children():
			if c != null and is_instance_valid(c):
				names.append(c.name)
		out["facing_child_count"] = names.size()
		out["facing_children"] = names
	if _subviewport != null and is_instance_valid(_subviewport):
		out["subviewport_mode"] = _subviewport.render_target_update_mode
	return out

func _ensure_renderer() -> void:
	if _subviewport != null and _screen_sprite != null and _stage_root != null:
		return
	if _subviewport == null:
		_subviewport = SubViewport.new()
		_subviewport.name = "SubViewport"
		# Critical isolation: keep reflection 3D world separate from player render world.
		_subviewport.own_world_3d = true
		add_child(_subviewport)
	if _screen_sprite == null:
		_screen_sprite = Sprite2D.new()
		_screen_sprite.name = "ScreenSprite"
		add_child(_screen_sprite)
	_apply_render_surface()
	_instance_stage_if_needed()

func _apply_render_surface() -> void:
	if _subviewport == null or _screen_sprite == null:
		return
	_subviewport.size = viewport_size
	_subviewport.transparent_bg = true
	_subviewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.msaa_3d = Viewport.MSAA_2X
	_screen_sprite.texture = _subviewport.get_texture()
	_screen_sprite.region_enabled = true
	_screen_sprite.region_rect = Rect2(Vector2.ZERO, Vector2(viewport_size))
	_screen_sprite.centered = true
	_screen_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_screen_sprite.scale = Vector2(
		float(screen_pixels.x) / maxf(float(viewport_size.x), 1.0),
		float(screen_pixels.y) / maxf(float(viewport_size.y), 1.0)
	)

func _instance_stage_if_needed() -> void:
	if _subviewport == null:
		return
	for c: Node in _subviewport.get_children():
		c.queue_free()
	if stage_scene == null:
		return
	var inst: Node = stage_scene.instantiate()
	if inst == null or not (inst is Node3D):
		return
	_stage_root = inst as Node3D
	_subviewport.add_child(_stage_root)
	_facing_pivot = _stage_root.get_node_or_null(^"FacingPivot") as Node3D
	_anim_player = _find_animation_player(_stage_root)

func _load_character_model(model_scene_path: String) -> void:
	if _facing_pivot == null or model_scene_path == "":
		return
	var model_scene: PackedScene = load(model_scene_path) as PackedScene
	if model_scene == null:
		return
	for child: Node in _facing_pivot.get_children():
		child.queue_free()
	var model_inst: Node = model_scene.instantiate()
	if model_inst == null:
		return
	_facing_pivot.add_child(model_inst)
	_anim_player = _find_animation_player(model_inst)

func _resolve_model_path(character_name: String) -> String:
	var lowered: String = character_name.to_lower()
	if lowered == "knight":
		return KNIGHT_MODEL_PATH
	return ROGUE_MODEL_PATH

func _resolve_idle_anim_name() -> String:
	if _anim_player == null:
		return ""
	var candidates: Array[String] = [
		"QAnim/Idle_Shield",
		"QAnim/Sword_Idle",
		"QAnim/Idle",
		"idle"
	]
	for a: String in candidates:
		if _anim_player.has_animation(a):
			return a
	for a: String in _anim_player.get_animation_list():
		if a.to_lower().contains("idle"):
			return a
	return ""

func _resolve_heavy_anim_name() -> String:
	if _anim_player == null:
		return ""
	var candidates: Array[String] = [
		"QAnim/Sword_Heavy",
		"QAnim/Heavy_Attack",
		"QAnim/Heavy",
		"heavy_attack"
	]
	for a: String in candidates:
		if _anim_player.has_animation(a):
			return a
	for a: String in _anim_player.get_animation_list():
		var low: String = a.to_lower()
		if low.contains("heavy"):
			return a
	return _resolve_idle_anim_name()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _apply_clone_visuals() -> void:
	scale = clone_scale
	modulate = Color(1.0, 1.0, 1.0, clone_alpha)
