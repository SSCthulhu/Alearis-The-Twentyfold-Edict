extends Resource
class_name RelicData

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum Band { SURVIVAL, CORE, GREED_DAMAGE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var band: Band = Band.CORE

# Synergy tags (free-form)
@export var tags: Array[StringName] = []

# Lines rendered on the card
@export var description_lines: Array[String] = []

# Apply token + optional params
@export var effect_id: StringName = &""
@export var effect_params: Dictionary = {}

# Weight inside its rarity pool
@export var roll_weight: float = 1.0

func is_valid() -> bool:
	return id != &"" and display_name != "" and effect_id != &""
