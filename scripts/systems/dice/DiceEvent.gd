extends Resource
class_name DiceEvent

@export var id: StringName = &""
@export var display_name: String = ""
@export var brief_text: String = ""
@export_multiline var description: String = ""
@export var effect_id: StringName = &""
@export var duration_seconds: float = 8.0
@export var effect_params: Dictionary = {}

func is_valid() -> bool:
	return id != &"" and display_name != "" and duration_seconds >= 0.0

func execute(_player: Node, _combat_room: Node) -> Dictionary:
	return {
		"event_id": id,
		"display_name": display_name,
		"brief_text": brief_text,
		"description": description,
		"effect_id": effect_id,
		"duration_seconds": duration_seconds,
		"effect_params": effect_params.duplicate(true)
	}
