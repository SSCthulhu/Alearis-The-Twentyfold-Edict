extends Control
class_name InteractionPrompt

## Displays interaction prompt above player's head when near interactable objects
## Shows the key to press (e.g., "E") based on the input action mapping

@export var style: Resource = null # HUDStyle
@export var interact_action: StringName = &"interact"
@export var prompt_offset_x: float = 0.0  # Horizontal offset from player center
@export var prompt_offset_y: float = -120.0  # How far above player's head
@export var font_size: int = 35
@export var distance_check_radius: float = 80.0  # For doors/portals that use distance-based interaction

@onready var _label: Label = $PromptLabel

var _interactables_in_range: Array[Node] = []
var _player: Node2D = null
var _distance_check_timer: float = 0.0
var _distance_check_interval: float = 0.1

func _ready() -> void:
	visible = false
	set_process(true)
	
	# Apply style
	if style != null and _label != null:
		_apply_style()
	
	pass

func _process(delta: float) -> void:
	"""Update position and check for distance-based interactables"""
	# Always keep the prompt positioned at the offset from origin
	position = Vector2(prompt_offset_x, prompt_offset_y)
	
	if _player == null:
		return
	
	_distance_check_timer += delta
	if _distance_check_timer < _distance_check_interval:
		return
	_distance_check_timer = 0.0
	
	_check_distance_interactables()

func _apply_style() -> void:
	"""Apply HUDStyle to the label"""
	if style == null or _label == null:
		return
	
	if style.has_method("get_font"):
		var font: Font = style.get_font()
		if font != null:
			_label.add_theme_font_override("font", font)
	
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Add outline for visibility
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)

func set_player(player: Node2D) -> void:
	"""Set the player reference and connect to their InteractArea"""
	_player = player
	
	if _player == null:
		push_warning("[InteractionPrompt] Player is null!")
		return
	
	# Find player's InteractArea
	var interact_area: Area2D = _player.get_node_or_null("InteractArea")
	if interact_area == null:
		push_warning("[InteractionPrompt] Player has no InteractArea!")
		return
	
	# Connect to area signals
	if not interact_area.area_entered.is_connected(_on_interact_area_entered):
		interact_area.area_entered.connect(_on_interact_area_entered)
	if not interact_area.area_exited.is_connected(_on_interact_area_exited):
		interact_area.area_exited.connect(_on_interact_area_exited)
	
	# Also connect to body signals for CharacterBody2D interactables
	if not interact_area.body_entered.is_connected(_on_interact_body_entered):
		interact_area.body_entered.connect(_on_interact_body_entered)
	if not interact_area.body_exited.is_connected(_on_interact_body_exited):
		interact_area.body_exited.connect(_on_interact_body_exited)
	
	pass

func _on_interact_area_entered(area: Area2D) -> void:
	"""Detect when player enters an interactable area"""
	var parent: Node = area.get_parent()
	var _parent_name: String = String(parent.name) if parent != null else "no parent"
	var _parent_groups: String = ""
	if parent != null:
		_parent_groups = str(parent.get_groups())
	pass
	
	if _is_interactable(area):
		if not _interactables_in_range.has(area):
			_interactables_in_range.append(area)
			_update_prompt()
			pass
	else:
		pass

func _on_interact_area_exited(area: Area2D) -> void:
	"""Detect when player exits an interactable area"""
	var idx := _interactables_in_range.find(area)
	if idx != -1:
		_interactables_in_range.remove_at(idx)
		_update_prompt()
		pass

func _on_interact_body_entered(body: Node2D) -> void:
	"""Detect when player enters an interactable body"""
	if _is_interactable(body):
		if not _interactables_in_range.has(body):
			_interactables_in_range.append(body)
			_update_prompt()
			pass

func _on_interact_body_exited(body: Node2D) -> void:
	"""Detect when player exits an interactable body"""
	var idx := _interactables_in_range.find(body)
	if idx != -1:
		_interactables_in_range.remove_at(idx)
		_update_prompt()
		pass

func _is_interactable(node: Node) -> bool:
	"""Check if a node is interactable"""
	if node == null:
		return false
	
	# Check class types
	if node is RewardChest:
		var chest := node as RewardChest
		return not chest._opened  # Only show prompt if chest is closed
	if node is AscensionCharge:
		var charge := node as AscensionCharge
		return not charge.is_carried and not charge.is_consumed and not charge.pickup_locked
	
	# Check for LightBeamStation (must check before "interactable" group!)
	if "LightBeamStation" in node.name or (node.get_script() != null and "LightBeamStation" in str(node.get_script().resource_path)):
		# Check if it's enabled via monitoring property (Area2D)
		if node is Area2D:
			var area: Area2D = node as Area2D
			var is_enabled: bool = area.monitoring and area.monitorable
			pass
			return is_enabled
		pass
		return false
	
	# Check for common interactable groups (but skip LightBeamStation - handled above)
	if node.is_in_group("interactable"):
		# Double-check if this is a LightBeamStation (already handled above)
		if "LightBeamStation" in str(node.get_script()) or node.get_class() == "LightBeamStation":
			pass
			return false  # Already handled by specific check above
		return true
	if node.is_in_group("door"):
		# For doors, only show if they have an unlocked InteractArea
		if node is AnimatedSprite2D:
			var interact_area: Node = node.get_node_or_null("InteractArea")
			if interact_area != null and interact_area is Area2D:
				var area: Area2D = interact_area as Area2D
				return area.monitoring  # Only show if area is active (door is unlocked)
		return true
	if node.is_in_group("portal"):
		return true
	if node.is_in_group("cave"):
		return true
	
	# Check node name patterns for Area2D children of interactables
	# (e.g., CaveEntrance/InteractArea, PortalWorld2/InteractionArea)
	if "InteractArea" in node.name or "InteractionArea" in node.name:
		var parent: Node = node.get_parent()
		var _parent_debug_name: String = "null"
		if parent != null:
			_parent_debug_name = String(parent.name)
		pass
		
		if parent != null:
			# Check if parent is in an interactable group
			if parent.is_in_group("portal") or parent.is_in_group("cave") or parent.is_in_group("door"):
				pass
				return true
			# Check parent name patterns
			if "Cave" in parent.name or "Door" in parent.name or "Portal" in parent.name:
				pass
				return true
			# Check if parent has Portal.gd script
			var parent_script = parent.get_script()
			pass
			if parent_script != null:
				var script_path: String = str(parent_script.resource_path)
				pass
				if "Portal.gd" in script_path:
					# Check if portal is active (visible and active)
					if parent is Node2D:
						var portal_node: Node2D = parent as Node2D
						var portal_active_val = portal_node.get("_portal_active")
						var is_active: bool = portal_node.visible and portal_active_val == true
						pass
						return is_active
					pass
					return true
		else:
			pass
	
	# Direct name checks
	if "Door" in node.name or "Portal" in node.name or "Cave" in node.name:
		return true
	
	# Fallback: Check if this is an Area2D whose parent has Portal.gd or is in portal group
	if node is Area2D:
		var parent: Node = node.get_parent()
		if parent != null:
			# Check if parent is in portal group
			if parent.is_in_group("portal"):
				pass
				# For Portal.gd, check if it's active
				if parent.get_script() != null and "Portal.gd" in str(parent.get_script().resource_path):
					if parent is Node2D:
						var portal_node: Node2D = parent as Node2D
						var portal_active_val = portal_node.get("_portal_active")
						var is_active: bool = portal_node.visible and portal_active_val == true
						pass
						return is_active
				return true
	
	return false

func _update_prompt() -> void:
	"""Update prompt visibility based on nearby interactables"""
	# Clean up invalid references
	_interactables_in_range = _interactables_in_range.filter(func(n): return n != null and is_instance_valid(n))
	
	if _interactables_in_range.is_empty():
		visible = false
		return
	
	# Show prompt with the correct key
	var key_text: String = _get_key_for_action()
	if key_text == "":
		key_text = "E"  # Fallback
	
	_label.text = key_text
	visible = true

func _get_key_for_action() -> String:
	"""Get the first keyboard key bound to the interact action"""
	if not InputMap.has_action(String(interact_action)):
		return ""
	
	var events: Array = InputMap.action_get_events(String(interact_action))
	for e in events:
		if e is InputEventKey:
			var k := e as InputEventKey
			if k.physical_keycode != 0:
				return OS.get_keycode_string(k.physical_keycode)
			if k.keycode != 0:
				return OS.get_keycode_string(k.keycode)
	
	return ""

func _check_distance_interactables() -> void:
	"""Check for distance-based interactables (doors, portals, caves) using groups"""
	if _player == null:
		return
	
	# Track which distance-based interactables are in range
	var distance_interactables_in_range: Array[Node] = []
	
	# Check all nodes in interactable-related groups
	var groups_to_check: Array[StringName] = [&"door", &"portal", &"cave", &"interactable"]
	
	for group in groups_to_check:
		var nodes: Array[Node] = get_tree().get_nodes_in_group(group)
		for node in nodes:
			if node == null or not is_instance_valid(node):
				continue
			
			var node_2d: Node2D = node as Node2D
			if node_2d == null:
				continue
			
			var distance: float = _player.global_position.distance_to(node_2d.global_position)
			if distance <= distance_check_radius:
				# IMPORTANT: Verify node is actually interactable before adding
				if _is_interactable(node):
					distance_interactables_in_range.append(node)
	
	# Update the list: add new ones, remove ones no longer in range
	for node in distance_interactables_in_range:
		if not _interactables_in_range.has(node):
			_interactables_in_range.append(node)
	
	# Remove distance-based interactables that are no longer in range
	for i in range(_interactables_in_range.size() - 1, -1, -1):
		var node: Node = _interactables_in_range[i]
		if node == null or not is_instance_valid(node):
			_interactables_in_range.remove_at(i)
			continue
		
		# Check if this is a group-based interactable
		var is_group_based: bool = false
		for group in groups_to_check:
			if node.is_in_group(group):
				is_group_based = true
				break
		
		# If it's group-based and not in our current distance list, check if we're still overlapping it
		if is_group_based and not distance_interactables_in_range.has(node):
			# DON'T remove if this is an Area2D that the player's InteractArea is currently overlapping
			if node is Area2D and _player != null:
				var interact_area: Area2D = _player.get_node_or_null("InteractArea")
				if interact_area != null and interact_area.overlaps_area(node as Area2D):
					# Still overlapping, keep it in the list
					continue
			
			# Not overlapping or not an Area2D, safe to remove
			_interactables_in_range.remove_at(i)
	
	# Update prompt display
	_update_prompt()
