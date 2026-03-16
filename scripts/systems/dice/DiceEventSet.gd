extends Resource
class_name DiceEventSet

@export var council_event: Resource
@export var divine_event: Resource

func is_valid() -> bool:
	return council_event != null and divine_event != null
