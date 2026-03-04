extends Resource
class_name DiceMeterEventData

enum OutcomeBand {
	DANGER,
	CHAOS,
	NEUTRAL,
	POSITIVE,
	STRONG,
	MIRACLE
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var brief_text: String = ""
@export_multiline var description: String = ""

@export var min_roll: int = 1
@export var max_roll: int = 20
@export var band: OutcomeBand = OutcomeBand.NEUTRAL

@export var effect_id: StringName = &""
@export var duration_seconds: float = 8.0
@export var effect_params: Dictionary = {}
@export var weight: float = 1.0

func matches_roll(roll: int) -> bool:
	return roll >= min_roll and roll <= max_roll

func is_valid() -> bool:
	return id != &"" and display_name != "" and min_roll <= max_roll and weight > 0.0 and duration_seconds >= 0.0
