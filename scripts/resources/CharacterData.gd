extends Resource
class_name CharacterData

## Character Data Resource
## Stores all configuration for a playable character including model, animations, and gameplay parameters

# Character identification
@export var character_name: String = ""
@export var character_display_name: String = ""

# 3D Model
@export var model_scene_path: String = ""

# Gameplay parameters
@export var move_speed_multiplier: float = 1.0

# Attack movement (for dash attacks, charges, etc.)
# Format: { "attack_kind": { "distance": float, "duration": float } }
# Example: { "heavy": { "distance": 200.0, "duration": 0.5 } }
@export var attack_movement: Dictionary = {}

# Roll/Dodge movement configuration
# Format: { "direction": "forward" or "backward", "distance": float, "duration": float }
# Example: { "direction": "forward", "distance": 300.0, "duration": 0.5 }
@export var roll_movement: Dictionary = {}

# Animation mappings: generic_name -> actual_animation_name
# Generic names used by PlayerController:
# - idle, run, hold
# - jump, jump_start, jump_land
# - light_attack, heavy_attack, ultimate
# - dodge, hit, death, interact
@export var animation_mappings: Dictionary = {}

## Validation
func is_valid() -> bool:
	if character_name == "":
		push_warning("CharacterData: character_name is empty")
		return false
	if model_scene_path == "":
		push_warning("CharacterData: model_scene_path is empty")
		return false
	if animation_mappings.is_empty():
		push_warning("CharacterData: animation_mappings is empty")
		return false
	return true

## Get mapped animation name
func get_animation(generic_name: StringName) -> StringName:
	if animation_mappings.has(generic_name):
		return StringName(animation_mappings[generic_name])
	push_warning("CharacterData '%s': No mapping found for animation '%s'" % [character_name, generic_name])
	return &""
