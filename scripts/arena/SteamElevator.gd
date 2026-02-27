extends Node2D
class_name SteamElevator

signal player_entered  # Emitted when player enters the elevator
signal player_exited   # Emitted when player exits the elevator
signal teleport_completed  # Emitted when launch+teleport+fade sequence is fully complete

# References
@export var animated_sprite_path: NodePath = ^"AnimatedSprite2D"
@export var detection_area_path: NodePath = ^"DetectionArea"
@export var player_path: NodePath = ^"../../../Player"
@export var floor_progression_path: NodePath = ^"../../../FloorProgressionController"
@export var destination_spawn_path: NodePath = ^"../../Spawns/Floor5/PlayerSpawn2"
@export var fade_rect_path: NodePath = ^"../../../UI/ScreenRoot/HUDRoot/SteamElevatorFade"

# Mode settings
@export_group("Mode")
@export var forge_mode: bool = false  # If true, elevator forges charges instead of launching player

# Animation settings
@export_group("Animation")
@export var steam_animation_name: String = "default"
@export var activation_interval: float = 5.0  # Play animation every 5 seconds
@export var stop_animation_when_finished: bool = true  # Stop animation after one play
@export var forge_loop_animation: bool = true  # Loop animation continuously in forge mode

# Launch settings (only used when forge_mode = false)
@export_group("Launch Mode")
@export var launch_velocity: float = -1200.0  # Upward velocity
@export var fade_delay: float = 0.2  # Short delay to see the launch before fade
@export var fade_out_time: float = 0.6  # Fade while player is rising
@export var post_fade_rise_time: float = 0.3  # Continue rising after fade (screen stays white)
@export var fade_in_time: float = 0.8

# Activation conditions (only used when forge_mode = false)
@export_group("Activation")
@export var required_floor_cleared: int = 4  # Floor 4 must be cleared
@export var require_chest_opened: bool = true

# Debug
@export var debug_logs: bool = false

var _animated_sprite: AnimatedSprite2D = null
var _detection_area: Area2D = null
var _player: Node2D = null
var _floor_controller: Node = null
var _destination: Node2D = null
var _fade_rect: ColorRect = null

var _is_active: bool = false
var _animation_timer: float = 0.0
var _player_on_platform: bool = false
var _launch_in_progress: bool = false
var _applying_launch_velocity: bool = false
var _chest_opened: bool = false

func _ready() -> void:
	# Get references
	_animated_sprite = get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	_detection_area = get_node_or_null(detection_area_path) as Area2D
	_player = get_node_or_null(player_path) as Node2D
	_floor_controller = get_node_or_null(floor_progression_path)
	_destination = get_node_or_null(destination_spawn_path) as Node2D
	_fade_rect = get_node_or_null(fade_rect_path) as ColorRect
	
	if _animated_sprite == null:
		push_warning("[SteamElevator] AnimatedSprite2D not found at: ", animated_sprite_path)
		return
	if _detection_area == null:
		push_warning("[SteamElevator] DetectionArea not found at: ", detection_area_path)
		return
	if _player == null:
		push_warning("[SteamElevator] Player not found at: ", player_path)
		return
	
	# Only require destination if NOT in forge mode
	if not forge_mode:
		if _destination == null:
			push_warning("[SteamElevator] Destination spawn not found at: ", destination_spawn_path)
			return
		if _fade_rect == null:
			push_warning("[SteamElevator] Fade rect not found at: ", fade_rect_path)
	
	# Connect signals
	_detection_area.body_entered.connect(_on_body_entered)
	_detection_area.body_exited.connect(_on_body_exited)
	
	# Connect to animated sprite signals
	if _animated_sprite != null:
		_animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Only connect floor progression signals if NOT in forge mode
	if not forge_mode and _floor_controller != null:
		if _floor_controller.has_signal("floor_status_changed"):
			_floor_controller.floor_status_changed.connect(_on_floor_status_changed)
		if _floor_controller.has_signal("chest_opened"):
			_floor_controller.chest_opened.connect(_on_chest_opened)
	
	# Setup based on mode
	if forge_mode:
		# Forge mode: always visible and active (will be controlled by encounter)
		_is_active = true
		if _animated_sprite != null:
			_animated_sprite.visible = true
		if debug_logs:
			pass
	else:
		# Launch mode: start inactive and hidden
		_is_active = false
		_animation_timer = 0.0
		if _animated_sprite != null:
			_animated_sprite.visible = false
			_animated_sprite.stop()
		if debug_logs:
			pass

func _physics_process(_delta: float) -> void:
	# Only apply launch velocity in launch mode
	if not forge_mode and _applying_launch_velocity and _player != null:
		if _player is CharacterBody2D:
			var player_body := _player as CharacterBody2D
			player_body.velocity.y = launch_velocity
			player_body.move_and_slide()  # Actually apply the movement

func _process(delta: float) -> void:
	# In forge mode, don't play animation automatically
	if forge_mode:
		return
	
	if not _is_active or _launch_in_progress:
		return
	
	# Increment timer
	_animation_timer += delta
	
	# Check if it's time to play animation
	if _animation_timer >= activation_interval:
		_animation_timer = 0.0
		_play_steam_animation()

func _on_body_entered(body: Node2D) -> void:
	if body == _player:
		_player_on_platform = true
		player_entered.emit()
		if debug_logs:
			pass

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_on_platform = false
		player_exited.emit()
		if debug_logs:
			pass

func _on_animation_finished() -> void:
	if stop_animation_when_finished and _animated_sprite != null:
		_animated_sprite.stop()
		_animated_sprite.frame = 0  # Reset to first frame so it doesn't show last frame
		if debug_logs:
			pass

func _on_floor_status_changed(floor_number: int, _enemies_left: int, floor_complete: bool) -> void:
	if floor_number == required_floor_cleared and floor_complete:
		_check_activation()

func _on_chest_opened(floor_number: int) -> void:
	if floor_number == required_floor_cleared:
		_chest_opened = true
		if debug_logs:
			pass
		_check_activation()

func _check_activation() -> void:
	# Check if conditions are met
	var floor_cleared: bool = false
	if _floor_controller != null and _floor_controller.has_method("is_floor_complete"):
		floor_cleared = _floor_controller.is_floor_complete(required_floor_cleared - 1)  # 0-indexed
	
	var can_activate: bool = floor_cleared
	if require_chest_opened:
		can_activate = can_activate and _chest_opened
	
	if can_activate and not _is_active:
		_is_active = true
		_animation_timer = 0.0
		
		# Show the elevator now that it's activated
		if _animated_sprite != null:
			_animated_sprite.stop()
			_animated_sprite.frame = 0  # Reset to first frame
			_animated_sprite.visible = true
		
		if debug_logs:
			pass

func _play_steam_animation() -> void:
	if _animated_sprite == null:
		return
	
	if debug_logs:
		pass
	
	_animated_sprite.play(steam_animation_name)
	
	# Only trigger launch in launch mode (not forge mode)
	if not forge_mode and _player_on_platform:
		_trigger_launch()

func set_forge_mode(enabled: bool) -> void:
	forge_mode = enabled
	if debug_logs:
		pass
	
	# Make visible if forge mode is enabled
	if forge_mode and _animated_sprite != null:
		_animated_sprite.visible = true

func start_forge_animation() -> void:
	"""Start looping forge animation (called by encounter)"""
	if _animated_sprite == null or not forge_mode:
		return
	
	# Always ensure loop is enabled for forge mode
	if _animated_sprite.sprite_frames != null:
		_animated_sprite.sprite_frames.set_animation_loop(steam_animation_name, true)
	
	# Only start if not already playing
	if not _animated_sprite.is_playing():
		_animated_sprite.play(steam_animation_name)
		if debug_logs:
			pass

func is_forge_animation_playing() -> bool:
	"""Check if forge animation is currently playing"""
	if _animated_sprite == null or not forge_mode:
		return false
	return _animated_sprite.is_playing()

func stop_forge_animation() -> void:
	"""Stop forge animation"""
	if _animated_sprite == null or not forge_mode:
		return
	
	_animated_sprite.stop()
	_animated_sprite.frame = 0
	
	# Reset loop setting
	if _animated_sprite.sprite_frames != null:
		_animated_sprite.sprite_frames.set_animation_loop(steam_animation_name, false)
	
	if debug_logs:
		pass

func _trigger_launch() -> void:
	if _launch_in_progress:
		return
	
	_launch_in_progress = true
	
	if debug_logs:
		pass
	
	# Lock player input and disable their physics processing so we can control movement
	_set_player_input_locked(true)
	if _player != null:
		_player.set_physics_process(false)
		if debug_logs:
			pass
	
	# Start the fade sequence - this will handle the launch
	call_deferred("_launch_sequence")

func _launch_sequence() -> void:
	# Start applying upward velocity continuously (handled in _physics_process)
	_applying_launch_velocity = true
	if debug_logs:
		pass
	
	# Short delay to see the launch start, then begin fade while player is rising
	await get_tree().create_timer(fade_delay).timeout
	
	if debug_logs:
		pass
	
	# Step 1: Fade OUT to white (while velocity is still being applied)
	if _fade_rect != null:
		_fade_rect.visible = true
		var tween_out := create_tween()
		tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_out.tween_method(_set_fade_alpha, 0.0, 1.0, fade_out_time)
		await tween_out.finished
		if debug_logs:
			pass
	else:
		await get_tree().create_timer(fade_out_time).timeout
	
	# Continue applying velocity for a bit longer while screen is white (so player doesn't stop before fade)
	if debug_logs:
		pass
	await get_tree().create_timer(post_fade_rise_time).timeout
	
	# NOW stop applying launch velocity
	_applying_launch_velocity = false
	if debug_logs:
		pass
	
	# Step 2: Teleport player while screen is FULLY white
	_set_player_visible(false)
	
	if _player != null and _destination != null:
		var _old_pos := _player.global_position
		_player.global_position = _destination.global_position
		# Reset player velocity
		if "velocity" in _player:
			_player.velocity = Vector2.ZERO
		
		if debug_logs:
			pass
		
		# Force camera to snap to new position
		if _player.has_node("Camera2D"):
			var camera = _player.get_node("Camera2D") as Camera2D
			if camera != null:
				camera.reset_smoothing()
				if debug_logs:
					pass
	
	# Step 3: Wait for camera to FULLY settle (screen still white)
	await get_tree().create_timer(0.5).timeout
	if debug_logs:
		pass
	
	# Make player visible
	_set_player_visible(true)
	
	# Step 4: Fade IN from white
	if _fade_rect != null:
		var tween_in := create_tween()
		tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_in.tween_method(_set_fade_alpha, 1.0, 0.0, fade_in_time)
		await tween_in.finished
		_fade_rect.visible = false
		if debug_logs:
			pass
	else:
		await get_tree().create_timer(fade_in_time).timeout
	
	# Re-enable player physics and unlock input
	if _player != null:
		_player.set_physics_process(true)
		if debug_logs:
			pass
	_set_player_input_locked(false)
	
	_launch_in_progress = false
	
	if debug_logs:
		pass
	
	# Emit signal that teleport is fully complete
	teleport_completed.emit()
	if debug_logs:
		pass

func _set_fade_alpha(alpha: float) -> void:
	if _fade_rect == null:
		return
	var c := _fade_rect.color
	c.a = alpha
	_fade_rect.color = c

func _set_player_input_locked(locked: bool) -> void:
	if _player == null:
		return
	if _player.has_method("set_input_locked"):
		_player.set_input_locked(locked)

func _set_player_visible(vis: bool) -> void:
	if _player == null:
		return
	if _player.has_node("Visual"):
		var visual := _player.get_node("Visual")
		visual.visible = vis
