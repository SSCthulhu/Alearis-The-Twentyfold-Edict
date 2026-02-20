extends SubViewportContainer

@export var knight_model: PackedScene
@export var rogue_model: PackedScene
@export var wizard_model: PackedScene

# Character-specific preview animations
@export var knight_preview_anim: String = "QAnim/Idle_Shield"
@export var rogue_preview_anim: String = "QAnim/Sword_Idle"
@export var wizard_preview_anim: String = "MAnim/Idle_B"

# Character-specific preview rotation (Y-axis degrees)
@export var knight_rotation: float = 45.0  # Turn to their left
@export var rogue_rotation: float = 0.0
@export var wizard_rotation: float = 0.0

# Character-specific animation speed multipliers
@export var knight_anim_speed: float = 0.5  # Slower, heavier
@export var rogue_anim_speed: float = 1.0
@export var wizard_anim_speed: float = 1.0

# Ensure path matches: SubViewportContainer -> SubViewport -> ModelAnchor
@onready var anchor = $SubViewport/ModelAnchor
@onready var viewport = $SubViewport

func display_character(character_name: String):
	# 1. Safety Checks
	if not anchor: 
		push_error("DEBUG ERROR: ModelAnchor node not found! Check scene path.")
		return
	if not viewport:
		push_error("DEBUG ERROR: SubViewport node not found!")
		return

	#print("PREVIEW: Attempting to instance ", character_name)
		
	# 2. Clear previous models immediately
	for child in anchor.get_children():
		child.queue_free()
	
	# 3. Select and Instance the new model
	var new_model: Node3D = null
	var preview_anim: String = ""
	var rotation_y: float = 0.0
	var anim_speed: float = 1.0
	
	match character_name:
		"Knight": 
			if knight_model: 
				new_model = knight_model.instantiate()
				preview_anim = knight_preview_anim
				rotation_y = knight_rotation
				anim_speed = knight_anim_speed
			#else: print("PREVIEW ERROR: Knight PackedScene is NULL in Inspector!")
		"Rogue":  
			if rogue_model: 
				new_model = rogue_model.instantiate()
				preview_anim = rogue_preview_anim
				rotation_y = rogue_rotation
				anim_speed = rogue_anim_speed
			#else: print("PREVIEW ERROR: Rogue PackedScene is NULL in Inspector!")
		"Wizard": 
			if wizard_model: 
				new_model = wizard_model.instantiate()
				preview_anim = wizard_preview_anim
				rotation_y = wizard_rotation
				anim_speed = wizard_anim_speed
			#else: print("PREVIEW ERROR: Wizard PackedScene is NULL in Inspector!")
	
	# 4. Add to scene and force a render update
	if new_model:
		anchor.add_child(new_model)
		
		# Apply character-specific rotation
		if rotation_y != 0.0:
			new_model.rotation_degrees.y = rotation_y
		
		# 5. Play character-specific preview animation
		_play_preview_animation(new_model, preview_anim, anim_speed)
		
		# Force the viewport to refresh its render state
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		#print("PREVIEW SUCCESS: ", character_name, " added to scene.")
	#else:
		#print("PREVIEW ERROR: Failed to create instance for ", character_name)

func clear_preview():
	if anchor:
		for child in anchor.get_children():
			child.queue_free()
		#print("PREVIEW: Anchor cleared.")

func _play_preview_animation(model: Node3D, anim_name: String, speed: float = 1.0) -> void:
	"""Find the AnimationPlayer in the model and play the specified animation"""
	if anim_name == "":
		return
	
	# Search for AnimationPlayer in the model tree
	var anim_player: AnimationPlayer = _find_animation_player(model)
	
	if anim_player != null:
		if anim_player.has_animation(anim_name):
			# Force animation to loop for preview
			var animation: Animation = anim_player.get_animation(anim_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			
			# Apply character-specific animation speed
			anim_player.speed_scale = speed
			
			anim_player.play(anim_name)
			#print("PREVIEW: Playing animation '%s' at %.2fx speed" % [anim_name, speed])
		else:
			push_warning("PREVIEW: Animation '%s' not found in model" % anim_name)
	else:
		push_warning("PREVIEW: No AnimationPlayer found in model")

func _find_animation_player(node: Node) -> AnimationPlayer:
	"""Recursively search for AnimationPlayer in node tree"""
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	
	return null



