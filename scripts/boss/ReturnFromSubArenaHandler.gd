extends Node

# Handles player return from sub-arena to boss arena
# Checks if player has "return_to_position" metadata
# If yes: teleport player, fade in from black, re-enable input

@export var player_path: NodePath = ^"../Player"
@export var charge_scene: PackedScene  # AscensionCharge scene
@export var debug_logs: bool = false

var _fade_overlay: ColorRect = null
var _should_handle_return: bool = false

func _enter_tree() -> void:
	# _enter_tree fires BEFORE _ready, before scene is fully set up
	# Check if we're returning from sub-arena
	var portal_data = get_node_or_null("/root/PortalTransitionData")
	if portal_data == null or not portal_data.is_returning:
		return
	
	_should_handle_return = true
	
	# Create black overlay IMMEDIATELY
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0)  # Fully black
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1000
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(overlay)
	
	# Add to scene tree using call_deferred (but overlay is already attached)
	get_tree().current_scene.call_deferred("add_child", canvas_layer)
	
	_fade_overlay = overlay
	
	if debug_logs:
		pass

func _ready() -> void:
	if not _should_handle_return:
		return
	
	# Wait one frame for overlay to be added and scene to settle
	await get_tree().process_frame
	
	if debug_logs:
		pass
	
	var player = get_node_or_null(player_path)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	
	if player == null:
		push_error("[ReturnHandler] Player not found!")
		if _fade_overlay != null and _fade_overlay.get_parent() != null:
			_fade_overlay.get_parent().queue_free()
		return
	
	_handle_return(player, _fade_overlay)

func _handle_return(player: Node2D, fade_overlay: ColorRect) -> void:
	var portal_data = get_node_or_null("/root/PortalTransitionData")
	if portal_data == null:
		return
	
	var return_pos: Vector2 = portal_data.return_position
	
	# Clear the return flag
	portal_data.is_returning = false
	
	if debug_logs:
		pass
	
	# Lock player input during entire return sequence
	if player.has_method("set_input_locked"):
		player.set_input_locked(true)
	
	# Overlay already created in _ready() (fully black from frame 0)
	# (No need to wait additional frames - we already waited in _ready())
	
	# Teleport player (while screen is still black)
	player.global_position = return_pos
	
	# Reset player velocity to prevent "falling" visual
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	
	if debug_logs:
		pass
	
	# CRITICAL: Force camera to snap to player position (disable smoothing)
	var camera = player.get_node_or_null("Camera2D")
	if camera != null:
		if debug_logs:
			pass
		# Reset smoothing forces camera to target position instantly
		camera.reset_smoothing()
		if debug_logs:
			pass
		
		# CRITICAL: Expand camera limits to full view (returning to boss area)
		var camera_controller = player.get_node_or_null("CameraController")
		if camera_controller != null and camera_controller.has_method("expand_to_full_view"):
			camera_controller.expand_to_full_view()
			if debug_logs:
				pass
	
	# Wait several frames for physics and scene to fully settle
	for i in range(15):
		await get_tree().process_frame
	
	if debug_logs and camera != null:
		pass
	
	# Restore player HP (before charge restoration)
	var player_health = player.get_node_or_null("Health")
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
	
	# Restore player cooldowns
	var player_combat = player.get_node_or_null("Combat")
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
	
	# Restore dodge charges
	if "_roll_charges" in player:
		player._roll_charges = portal_data.player_dodge_charges
	if "_roll_recharge_accum" in player:
		player._roll_recharge_accum = portal_data.player_dodge_recharge_accum
	
	if debug_logs:
		pass
	
	# Restore charge DURING black screen (so player is visibly holding it before fade-in)
	if portal_data.has_charge:
		if debug_logs:
			pass
		await _restore_charge_to_player(player)
		if debug_logs:
			pass
	
	# Short final delay for physics to settle
	await get_tree().create_timer(0.2).timeout
	
	# NOW fade to transparent (1.5s) - player is already holding charge and camera is stable
	if debug_logs:
		pass
	await _fade_screen(fade_overlay, 1.0, 0.0, 1.5)
	
	# Remove overlay
	fade_overlay.queue_free()
	
	if debug_logs:
		pass
	
	# Re-enable player input after fade completes
	if player.has_method("set_input_locked"):
		player.set_input_locked(false)
		if debug_logs:
			pass
	else:
		if debug_logs:
			pass
	
	if debug_logs:
		pass

func _restore_charge_to_player(player: Node2D) -> void:
	if charge_scene == null:
		push_error("[ReturnHandler] Cannot restore charge - charge_scene not assigned!")
		return
	
	if debug_logs:
		pass
	
	# Spawn charge at player position
	var charge: AscensionCharge = charge_scene.instantiate()
	charge.global_position = player.global_position
	
	# Set charge to 0 (will be set to full after initialization)
	charge.charged_seconds = 0.0
	
	# Add to scene (triggers _ready())
	get_tree().current_scene.add_child(charge)
	
	# Wait for charge's _ready() to complete and signals to connect
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Now use the public API to fully charge it
	# This will properly emit signals and update visuals
	charge.add_charge_seconds(charge.charge_required_seconds)
	
	if debug_logs:
		pass
		pass
	
	# Wait for visual update to complete
	await get_tree().process_frame
	
	# Clear any volatile debuff from the scene change (prevents drop damage)
	var player_debuffs = player.get_node_or_null("Debuffs")
	if player_debuffs != null and player_debuffs.has_method("clear_debuff"):
		player_debuffs.call("clear_debuff", &"volatile")
		if debug_logs:
			pass
	
	# Auto-pickup for player
	var charge_carrier = player.get_node_or_null("ChargeCarrier")
	if charge_carrier != null and charge_carrier.has_method("_pickup"):
		charge_carrier.call("_pickup", charge)
		if debug_logs:
			pass
		
		# CRITICAL: pickup_to() calls reset_charge(), so we need to re-charge it!
		await get_tree().process_frame
		charge.add_charge_seconds(charge.charge_required_seconds)
		
		# Force the ready ring to show (it might get hidden after reparenting)
		if charge.has_method("_set_ready_ring"):
			charge.call("_set_ready_ring", true)
		
		if debug_logs:
			pass
	else:
		push_error("[ReturnHandler] Could not auto-pickup charge - ChargeCarrier not found")

func _create_fade_overlay() -> ColorRect:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1000
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(overlay)
	
	return overlay

func _create_fade_overlay_deferred() -> ColorRect:
	# Create overlay first
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0)  # Fully black
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1000
	
	# Create canvas layer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	
	# CRITICAL: Add overlay to canvas layer BEFORE adding canvas to scene
	# This way both appear together in the same frame
	canvas_layer.add_child(overlay)
	
	# Now add canvas layer (with overlay already attached) using call_deferred
	# The deferred call happens at the end of this frame, so overlay appears immediately
	get_tree().current_scene.call_deferred("add_child", canvas_layer)
	
	# Return overlay immediately (no await needed - we have the reference)
	return overlay

func _fade_screen(overlay: ColorRect, from_alpha: float, to_alpha: float, duration: float) -> void:
	overlay.color.a = from_alpha
	
	var tween = get_tree().create_tween()
	tween.tween_property(overlay, "color:a", to_alpha, duration)
	
	await tween.finished
