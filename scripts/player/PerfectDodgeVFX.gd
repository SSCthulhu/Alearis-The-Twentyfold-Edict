extends Node
class_name PerfectDodgeVFX

@export var detector_path: NodePath = ^"../PerfectDodgeDetector"

# Add the toast under your CanvasLayer UI (any Control is fine)
# Your tree: World1/UI/ScreenRoot/HUDRoot
@export var toast_parent_path: NodePath = ^"../../UI/ScreenRoot/HUDRoot"

@export var toast_scene: PackedScene

# Visual tuning
@export var head_offset_px: float = 25.0

# Anti-spam
@export var toast_cooldown: float = 0.15

@export var debug_logs: bool = false

var _detector: Node = null
var _toast_parent: Control = null
var _cooldown_left: float = 0.0

func _ready() -> void:
	_detector = get_node_or_null(detector_path)
	_toast_parent = get_node_or_null(toast_parent_path) as Control

	if toast_scene == null:
		push_warning("[PerfectDodgeVFX] toast_scene not assigned.")
	if _detector == null:
		push_warning("[PerfectDodgeVFX] PerfectDodgeDetector not found at: %s" % String(detector_path))
		return
	if _toast_parent == null:
		# This is expected in scenes without UI (like sub-arenas) - don't return, just disable toasts
		if debug_logs:
			pass
		# Continue anyway - detector still works, just no visual toasts
	
	if _detector.has_signal("perfect_dodge"):
		if not _detector.perfect_dodge.is_connected(_on_perfect_dodge):
			_detector.perfect_dodge.connect(_on_perfect_dodge)
			if debug_logs:
				pass
	else:
		push_warning("[PerfectDodgeVFX] Detector missing signal: perfect_dodge")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func _on_perfect_dodge(_trigger_source: Node, _attempted_damage: int) -> void:
	if _cooldown_left > 0.0:
		return
	_cooldown_left = maxf(toast_cooldown, 0.0)
	_spawn_toast_above_player()

func _spawn_toast_above_player() -> void:
	if toast_scene == null:
		return
	if _toast_parent == null or not is_instance_valid(_toast_parent):
		return

	var toast_node: Node = toast_scene.instantiate()
	var toast: Control = toast_node as Control
	if toast == null:
		push_warning("[PerfectDodgeVFX] PerfectDodgeToast.tscn root must be a Control.")
		toast_node.queue_free()
		return

	_toast_parent.add_child(toast)

	# Optional: let the toast set its label text
	if toast.has_method("show_text"):
		toast.call("show_text", "PERFECT")

	# Get player world position
	var player_body: Node2D = get_parent() as Node2D
	if player_body == null:
		return

	# Use HeadPoint if available, otherwise fallback to player position
	var head: Node2D = player_body.get_node_or_null("Visual/HeadPoint") as Node2D
	var world_pos: Vector2 = head.global_position if head != null else player_body.global_position

	# ALWAYS offset upward (higher toast)
	world_pos.y -= head_offset_px
	
	# ✅ World -> Screen (viewport) using canvas transform (works with any Camera2D)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos

	# ✅ Screen -> local position under the chosen HUD Control parent
	# (HUDRoot is typically full-screen at (0,0), but this keeps it robust.)
	var local_pos: Vector2 = _toast_parent.get_global_transform().affine_inverse() * screen_pos

	# Center + animate (toast will queue_free itself)
	toast.call_deferred("_place_centered", local_pos)

	if debug_logs:
		pass

	if debug_logs:
		pass
