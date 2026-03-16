extends RefCounted
class_name DiceCouncilMember

var number: int = 0
var name: String = ""
var theme: String = ""
var council_event: Resource = null
var divine_event: Resource = null

func _init(
	number_value: int = 0,
	name_value: String = "",
	theme_value: String = "",
	council_event_value: Resource = null,
	divine_event_value: Resource = null
) -> void:
	number = number_value
	name = name_value
	theme = theme_value
	council_event = council_event_value
	divine_event = divine_event_value
