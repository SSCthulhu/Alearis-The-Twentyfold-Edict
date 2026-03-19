extends Node2D

@export var clone_alpha: float = 0.95
@export var stage_scene: PackedScene = preload("res://scenes/player/Player3DStage.tscn")
@export var viewport_size: Vector2i = Vector2i(512, 512)
@export var screen_pixels: Vector2i = Vector2i(256, 256)
const PLAYER_SCENE_PATH: String = "res://scenes/player/player.tscn"
const PLAYER_VIEW_SCENE_PATH: String = "res://scenes/player/Player3DView.tscn"
const PLAYER_CONTROLLER_SCRIPT_PATH: String = "res://scripts/player/PlayerControllerV3.gd"
const PLAYER_VIEW_SCRIPT_PATH: String = "res://scripts/player/Player3DView.gd"
const KNIGHT_MODEL_PATH: String = "res://assets/scenes/knight.tscn"
const ROGUE_MODEL_PATH: String = "res://assets/scenes/rogue.tscn"

var _subviewport: SubViewport = null
var _screen_sprite: Sprite2D = null
var _stage_root: Node3D = null
var _facing_pivot: Node3D = null
var _anim_player: AnimationPlayer = null
var _animation_map: Dictionary = {}
var _loop_anim_name: String = ""
var _debug_marker: Polygon2D = null
var _debug_marker_mode: bool = false

func _ready() -> void:
	top_level = true
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	set_meta("dice_meter_reflection", true)
	add_to_group(&"dice_meter_reflection_clone")
	_ensure_renderer()
	_apply_clone_alpha(clone_alpha)

func configure_from_player(player_root: Node) -> void:
	if player_root == null:
		return
	_ensure_renderer()
	if _anim_player == null:
		return
	var character_name: String = ""
	var src_view: Node2D = player_root.get_node_or_null("Visual/Body3DView") as Node2D
	if src_view != null:
		scale = src_view.global_scale
		if "viewport_size" in src_view:
			var src_vs: Variant = src_view.get("viewport_size")
			if src_vs is Vector2i:
				viewport_size = src_vs as Vector2i
		if "screen_pixels" in src_view:
			var src_sp: Variant = src_view.get("screen_pixels")
			if src_sp is Vector2i:
				screen_pixels = src_sp as Vector2i
		_configure_render_surface()
	else:
		scale = Vector2.ONE
	var char_data_obj: Object = null
	if "character_data" in player_root:
		char_data_obj = player_root.get("character_data") as Object
	if char_data_obj != null:
		var model_scene_path: String = String(char_data_obj.get("model_scene_path")) if "model_scene_path" in char_data_obj else ""
		character_name = String(char_data_obj.get("character_name")) if "character_name" in char_data_obj else ""
		var safe_path: String = _resolve_safe_model_scene_path(model_scene_path, character_name)
		if safe_path != "":
			_load_character_model(safe_path)
		_animation_map.clear()
		if "animation_mappings" in char_data_obj:
			var mappings: Variant = char_data_obj.get("animation_mappings")
			if mappings is Dictionary:
				_animation_map = (mappings as Dictionary).duplicate(true)
	else:
		var fallback_path: String = _resolve_safe_model_scene_path("", CharacterDatabase.get_selected_character())
		if fallback_path != "":
			_load_character_model(fallback_path)

func configure_from_character_data(char_data_obj: Object) -> void:
	_ensure_renderer()
	if _anim_player == null:
		return
	var character_name: String = ""
	var model_scene_path: String = ""
	_animation_map.clear()
	if char_data_obj != null:
		if "character_name" in char_data_obj:
			character_name = String(char_data_obj.get("character_name"))
		if "model_scene_path" in char_data_obj:
			model_scene_path = String(char_data_obj.get("model_scene_path"))
		if "animation_mappings" in char_data_obj:
			var mappings: Variant = char_data_obj.get("animation_mappings")
			if mappings is Dictionary:
				_animation_map = (mappings as Dictionary).duplicate(true)
	var safe_path: String = _resolve_safe_model_scene_path(model_scene_path, character_name)
	if safe_path != "":
		_load_character_model(safe_path)

func configure_surface_from_player_view(player_root: Node) -> void:
	if player_root == null:
		return
	_ensure_renderer()
	var src_view: Node2D = player_root.get_node_or_null("Visual/Body3DView") as Node2D
	if src_view == null:
		return
	scale = src_view.global_scale
	if "viewport_size" in src_view:
		var src_vs: Variant = src_view.get("viewport_size")
		if src_vs is Vector2i:
			viewport_size = src_vs as Vector2i
	if "screen_pixels" in src_view:
		var src_sp: Variant = src_view.get("screen_pixels")
		if src_sp is Vector2i:
			screen_pixels = src_sp as Vector2i
	_configure_render_surface()

func freeze_clone_visual() -> void:
	call_deferred("_freeze_clone_visual_deferred")

func set_debug_marker_mode(enabled: bool) -> void:
	_debug_marker_mode = enabled
	_ensure_renderer()
	if _debug_marker_mode:
		_ensure_debug_marker()
		if _screen_sprite != null:
			_screen_sprite.visible = false
		if _subviewport != null:
			_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _debug_marker != null:
			_debug_marker.visible = true
	else:
		if _screen_sprite != null:
			_screen_sprite.visible = true
		if _debug_marker != null:
			_debug_marker.visible = false
		if _subviewport != null:
			_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func set_facing_toward(target_pos: Vector2) -> void:
	_ensure_renderer()
	if _facing_pivot == null:
		return
	var facing: int = 1 if target_pos.x >= global_position.x else -1
	_facing_pivot.rotation.y = deg_to_rad(90.0) if facing == 1 else deg_to_rad(-90.0)

func play_heavy() -> void:
	_ensure_renderer()
	if _anim_player == null:
		return
	var anim_name: String = _resolve_anim_name(&"heavy_attack")
	if anim_name == "":
		return
	_anim_player.speed_scale = 1.0
	_anim_player.play(anim_name, 0.0, 1.0, false)
	_loop_anim_name = ""

func play_idle() -> void:
	_play_loop_anim(&"idle")

func play_run() -> void:
	var run_anim: String = _resolve_anim_name(&"run")
	if run_anim == "":
		_play_loop_anim(&"idle")
		return
	if _anim_player != null and _anim_player.current_animation == run_anim and _anim_player.is_playing():
		return
	_play_loop_anim(&"run")

func set_facing(dir: int) -> void:
	_ensure_renderer()
	if _facing_pivot == null:
		return
	var facing: int = -1 if dir < 0 else 1
	_facing_pivot.rotation.y = deg_to_rad(90.0) if facing == 1 else deg_to_rad(-90.0)

func set_clone_alpha(alpha: float) -> void:
	clone_alpha = clampf(alpha, 0.05, 1.0)
	_apply_clone_alpha(clone_alpha)

func _ensure_renderer() -> void:
	if _subviewport != null and _screen_sprite != null and _stage_root != null:
		return
	if _subviewport == null:
		_subviewport = SubViewport.new()
		_subviewport.name = "SubViewport"
		add_child(_subviewport)
	if _screen_sprite == null:
		_screen_sprite = Sprite2D.new()
		_screen_sprite.name = "ScreenSprite"
		_screen_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_screen_sprite)
	_configure_render_surface()
	_instance_stage_if_needed()

func _configure_render_surface() -> void:
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
	_screen_sprite.scale = Vector2(
		float(screen_pixels.x) / maxf(float(viewport_size.x), 1.0),
		float(screen_pixels.y) / maxf(float(viewport_size.y), 1.0)
	)

func _instance_stage_if_needed() -> void:
	if _subviewport == null:
		return
	if _stage_root != null and is_instance_valid(_stage_root):
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
		_facing_pivot.remove_child(child)
		child.queue_free()
	var model_inst: Node = model_scene.instantiate()
	if model_inst == null or not (model_inst is Node3D):
		if model_inst != null and is_instance_valid(model_inst):
			model_inst.queue_free()
		return
	if _contains_forbidden_player_nodes(model_inst):
		model_inst.queue_free()
		return
	_facing_pivot.add_child(model_inst)
	_anim_player = _find_animation_player(model_inst)

func _resolve_safe_model_scene_path(candidate_path: String, character_name: String) -> String:
	var path: String = candidate_path
	if not _is_safe_model_scene_path(path):
		path = ""
	if path != "":
		return path
	var lowered_name: String = character_name.to_lower()
	if lowered_name == "knight":
		return KNIGHT_MODEL_PATH
	if lowered_name == "rogue":
		return ROGUE_MODEL_PATH
	var selected_name: String = CharacterDatabase.get_selected_character().to_lower()
	if selected_name == "knight":
		return KNIGHT_MODEL_PATH
	return ROGUE_MODEL_PATH

func _is_safe_model_scene_path(path: String) -> bool:
	if path == "":
		return false
	if not ResourceLoader.exists(path):
		return false
	if path == PLAYER_SCENE_PATH or path == PLAYER_VIEW_SCENE_PATH:
		return false
	if path.begins_with("res://scenes/player/"):
		return false
	return true

func _contains_forbidden_player_nodes(root: Node) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null or not is_instance_valid(n):
			continue
		if n is CharacterBody2D or n is Node2D:
			return true
		var scene_path: String = String(n.scene_file_path)
		if scene_path == PLAYER_SCENE_PATH or scene_path == PLAYER_VIEW_SCENE_PATH:
			return true
		var script_ref: Script = n.get_script() as Script
		if script_ref != null:
			var script_path: String = String(script_ref.resource_path)
			if script_path == PLAYER_CONTROLLER_SCRIPT_PATH or script_path == PLAYER_VIEW_SCRIPT_PATH:
				return true
		for child: Node in n.get_children():
			stack.append(child)
	return false

func _resolve_anim_name(generic_anim: StringName) -> String:
	if _anim_player == null:
		return ""
	if _animation_map.has(generic_anim):
		var mapped: String = String(_animation_map[generic_anim])
		if _anim_player.has_animation(mapped):
			return mapped
	var raw: String = String(generic_anim)
	if _anim_player.has_animation(raw):
		return raw
	return ""

func _play_loop_anim(generic_anim: StringName) -> void:
	_ensure_renderer()
	if _anim_player == null:
		return
	var anim_name: String = _resolve_anim_name(generic_anim)
	if anim_name == "":
		return
	if _loop_anim_name == anim_name and _anim_player.is_playing() and _anim_player.current_animation == anim_name:
		return
	_anim_player.speed_scale = 1.0
	_anim_player.play(anim_name, 0.12, 1.0, false)
	_loop_anim_name = anim_name

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _apply_clone_alpha(alpha: float) -> void:
	var ci: CanvasItem = self as CanvasItem
	if ci == null:
		return
	var c: Color = ci.modulate
	c.a = alpha
	ci.modulate = c

func _freeze_clone_visual_deferred() -> void:
	if _subviewport == null:
		return
	if _debug_marker_mode:
		return
	_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _ensure_debug_marker() -> void:
	if _debug_marker != null and is_instance_valid(_debug_marker):
		return
	_debug_marker = Polygon2D.new()
	_debug_marker.name = "DebugMarker"
	_debug_marker.color = Color(1.0, 0.0, 1.0, 0.65)
	_debug_marker.polygon = PackedVector2Array([
		Vector2(0.0, -42.0),
		Vector2(32.0, 0.0),
		Vector2(0.0, 42.0),
		Vector2(-32.0, 0.0)
	])
	_debug_marker.visible = false
	add_child(_debug_marker)

func get_debug_snapshot() -> Dictionary:
	var out: Dictionary = {
		"anim": "",
		"anim_playing": false,
		"loop_anim": _loop_anim_name,
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
