extends Node2D
class_name Portal

# Portal that becomes visible after Floor 4 is cleared and teleports player to Floor 5

@export var floor_progression_path: NodePath = ^"../../../FloorProgressionController"
@export var player_path: NodePath = ^"../../../Player"
@export var target_position: Vector2 = Vector2(-1091, -21060)
@export var required_floor: int = 4
@export var interact_key: String = "interact"
@export var debug_logs: bool = false

var _floor_progression: Node = null
var _player: CharacterBody2D = null
var _player_nearby: bool = false
var _portal_active: bool = false
var _interaction_area: Area2D = null

func _ready() -> void:
	# CRITICAL: Print IMMEDIATELY to verify script is running
	pass
	pass
	pass
	pass
	
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Find InteractionArea child (don't use @onready)
	_interaction_area = get_node_or_null("InteractionArea")
	if _interaction_area == null:
		push_error("[Portal] InteractionArea child not found!")
	else:
		pass
		# Start disabled - will be enabled when portal activates
		_interaction_area.monitoring = false
		_interaction_area.monitorable = false
		_interaction_area.body_entered.connect(_on_body_entered)
		_interaction_area.body_exited.connect(_on_body_exited)
	
	# Get references using get_node instead of get_node_or_null to see exact errors
	pass
	_floor_progression = get_node_or_null(floor_progression_path)
	
	if _floor_progression == null:
		push_error("[Portal] FloorProgressionController not found!")
		# Try different paths
		pass
		_floor_progression = get_node_or_null("../../../FloorProgressionController")
		if _floor_progression:
			pass
	else:
		pass
	
	pass
	_player = get_node_or_null(player_path)
	
	if _player == null:
		push_error("[Portal] Player not found!")
		# Try different paths
		pass
		_player = get_node_or_null("../../../Player")
		if _player:
			pass
	else:
		pass
	
	# Connect signal
	if _floor_progression and _floor_progression.has_signal("floor_unlocked"):
		_floor_progression.floor_unlocked.connect(_on_floor_unlocked)
		pass
	else:
		if _floor_progression:
			push_error("[Portal] FloorProgressionController missing 'floor_unlocked' signal!")
		else:
			push_error("[Portal] Cannot connect signal - FloorProgressionController is null")
	
	pass

func _on_floor_unlocked(floor_number: int) -> void:
	pass
	if floor_number == required_floor:
		pass
		_activate_portal()

func _activate_portal() -> void:
	_portal_active = true
	visible = true
	
	# Enable the InteractionArea for player detection
	if _interaction_area:
		_interaction_area.monitoring = true
		_interaction_area.monitorable = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.76, 0.5)
	
	pass
	pass
	if _interaction_area:
		pass
		pass
		pass
		pass
		pass
	else:
		pass

func _on_body_entered(body: Node2D) -> void:
	pass
	if body == _player:
		_player_nearby = true
		pass

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_nearby = false
		pass

func _process(_delta: float) -> void:
	if not _portal_active or not _player_nearby or not _player:
		return
	
	if Input.is_action_just_pressed(interact_key):
		_teleport_player()

func _teleport_player() -> void:
	if _player == null:
		return
	
	pass
	pass
	_player.global_position = target_position
	_player_nearby = false
	
	# Wait 1 second then trigger boss encounter
	if _floor_progression != null and _floor_progression.has_method("trigger_boss_encounter_after_portal"):
		await get_tree().create_timer(1.0).timeout
		_floor_progression.call("trigger_boss_encounter_after_portal")
		pass
