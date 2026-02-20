# res://scripts/enemies/Enemy3DView.gd
extends Node2D
class_name Enemy3DView

signal stage_animation_finished(anim_name: StringName)

@export var stage_scene: PackedScene

@export var subviewport_path: NodePath = ^"SubViewport"
@export var screen_sprite_path: NodePath = ^"ScreenSprite"
@export var onscreen_notifier_path: NodePath = ^"VisibleOnScreenNotifier2D"

@export var viewport_size: Vector2i = Vector2i(512, 512)
@export var screen_pixels: Vector2i = Vector2i(256, 256) # how big the character appears in 2D

# Debugging: when true, missing animation names print warnings instead of failing silently.
@export var debug_print_missing_anims: bool = true

# Paths inside your stage scene
@export var stage_skeleton_root_path: NodePath = ^"FacingPivot"
@export var stage_animation_player_path: NodePath = ^"FacingPivot/Skeleton_Warrior/AnimationPlayer"

var _subviewport: SubViewport
var _screen_sprite: Sprite2D
var _notifier: VisibleOnScreenNotifier2D

var _stage_root: Node3D
var _skeleton_root: Node3D
var _anim_player: AnimationPlayer
var _default_speed_scale: float = 1.0  # Enemy's default animation speed

var _facing: int = 1

func _ready() -> void:
	_subviewport = get_node_or_null(subviewport_path) as SubViewport
	_screen_sprite = get_node_or_null(screen_sprite_path) as Sprite2D
	_notifier = get_node_or_null(onscreen_notifier_path) as VisibleOnScreenNotifier2D

	if _subviewport == null:
		push_error("Enemy3DView: Missing SubViewport at %s" % [subviewport_path])
		return
	if _screen_sprite == null:
		push_error("Enemy3DView: Missing ScreenSprite at %s" % [screen_sprite_path])
		return

	_configure_viewport()
	_instance_stage()

	if _notifier != null:
		if not _notifier.screen_entered.is_connected(_on_screen_entered):
			_notifier.screen_entered.connect(_on_screen_entered)
		if not _notifier.screen_exited.is_connected(_on_screen_exited):
			_notifier.screen_exited.connect(_on_screen_exited)

func _configure_viewport() -> void:
	# ✅ CRITICAL: Give each viewport its own 3D world to prevent merging
	# Must be set BEFORE configuring size/clear mode
	_subviewport.own_world_3d = true
	
	_subviewport.size = viewport_size
	_subviewport.transparent_bg = true
	_subviewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_screen_sprite.texture = _subviewport.get_texture()
	_screen_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Decouple render resolution from on-screen size
	_screen_sprite.region_enabled = true
	_screen_sprite.region_rect = Rect2(Vector2.ZERO, Vector2(viewport_size))
	_screen_sprite.scale = Vector2(
		float(screen_pixels.x) / maxf(float(viewport_size.x), 1.0),
		float(screen_pixels.y) / maxf(float(viewport_size.y), 1.0)
	)

func _instance_stage() -> void:
	if stage_scene == null:
		push_error("Enemy3DView: stage_scene not set.")
		return

	for c in _subviewport.get_children():
		c.queue_free()

	var inst: Node = stage_scene.instantiate()
	_subviewport.add_child(inst)

	_stage_root = inst as Node3D
	if _stage_root == null:
		push_error("Enemy3DView: stage_scene root must be Node3D.")
		return

	_skeleton_root = _stage_root.get_node_or_null(stage_skeleton_root_path) as Node3D
	_anim_player = _stage_root.get_node_or_null(stage_animation_player_path) as AnimationPlayer

	# AnimationPlayer is optional - if not found, model will be static
	if _anim_player == null:
		if stage_animation_player_path != NodePath(""):
			push_warning("Enemy3DView: AnimationPlayer not found at %s (model will be static)" % [stage_animation_player_path])
	else:
		if not _anim_player.animation_finished.is_connected(_on_stage_anim_finished):
			_anim_player.animation_finished.connect(_on_stage_anim_finished)
		
		# Save the enemy's default animation speed (usually 1.0, but can be customized per enemy)
		_default_speed_scale = _anim_player.speed_scale

	_apply_facing()

## Set a texture on all MeshInstance3D nodes in the stage
## Useful for applying variant textures (e.g., skeleton_texture_B for World3)
func set_model_texture(texture_path: String) -> void:
	if _stage_root == null:
		push_warning("[Enemy3DView] Cannot set texture: stage_root not initialized")
		return
	
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		push_warning("[Enemy3DView] Failed to load texture: %s" % texture_path)
		return
	
	# Find all MeshInstance3D nodes recursively and apply texture
	_apply_texture_recursive(_stage_root, texture)

func _apply_texture_recursive(node: Node, texture: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var mesh_material := mesh_inst.get_active_material(0)
		if mesh_material is StandardMaterial3D:
			var std_mat := mesh_material as StandardMaterial3D
			# Create a duplicate to avoid modifying the shared resource
			var new_mat := std_mat.duplicate() as StandardMaterial3D
			new_mat.albedo_texture = texture
			mesh_inst.set_surface_override_material(0, new_mat)
	
	# Recurse through children
	for child in node.get_children():
		_apply_texture_recursive(child, texture)

func _on_stage_anim_finished(anim_name_str: String) -> void:
	# CRITICAL: Reset speed_scale to default after one-shot animations finish
	# This ensures play_one_shot custom speeds don't persist
	if _anim_player != null:
		_anim_player.speed_scale = _default_speed_scale
	
	stage_animation_finished.emit(StringName(anim_name_str))

func set_facing(dir: int) -> void:
	_facing = -1 if dir < 0 else 1
	_apply_facing()

func _apply_facing() -> void:
	if _skeleton_root == null:
		return
	# Rotate the rig for side-view
	_skeleton_root.rotation.y = deg_to_rad(90.0) if _facing == 1 else deg_to_rad(-90.0)

func _has_anim_name(a: String) -> bool:
	if _anim_player == null:
		return false
	if _anim_player.has_animation(a):
		return true
	if debug_print_missing_anims:
		push_warning("Enemy3DView: Missing animation: '%s' (check spaces/case)" % a)
	return false

func play_loop(anim: StringName, restart: bool = false) -> void:
	if _anim_player == null:
		return
	if anim == &"":
		return

	var a: String = String(anim)
	if not _has_anim_name(a):
		return

	# Restore enemy's default animation speed (respects per-enemy customization)
	_anim_player.speed_scale = _default_speed_scale

	if (not restart) and _anim_player.is_playing() and _anim_player.current_animation == a:
		return

	_anim_player.play(a)

func play_one_shot(anim: StringName, restart: bool = true, speed: float = 1.0) -> void:
	if _anim_player == null:
		return
	if anim == &"":
		return

	var a: String = String(anim)
	if not _has_anim_name(a):
		return

	var s: float = clampf(speed, 0.05, 10.0)  # Increased max speed to 10x for rapid animations
	_anim_player.speed_scale = s

	if (not restart) and _anim_player.is_playing() and _anim_player.current_animation == a:
		return

	_anim_player.play(a, 0.0, 1.0, false)

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

	var clip: Animation = _anim_player.get_animation(a)
	return maxf(clip.length, 0.0)

func is_playing_any() -> bool:
	return _anim_player != null and _anim_player.is_playing()

func get_current_anim() -> StringName:
	if _anim_player == null:
		return &""
	return StringName(_anim_player.current_animation)
