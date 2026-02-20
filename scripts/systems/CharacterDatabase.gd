extends Node

## CharacterDatabase Singleton
## Manages character data resources and provides access to character configurations

# Preload character data resources
const KNIGHT_DATA := preload("res://resources/characters/knight_data.tres")
const ROGUE_DATA := preload("res://resources/characters/rogue_data.tres")

# Character registry: name -> CharacterData
var _characters: Dictionary = {}

# Currently selected character (merged from GameManager)
var selected_character: String = ""

func _ready() -> void:
	_register_characters()
	#print("[CharacterDatabase] Initialized with %d characters" % _characters.size())

func _register_characters() -> void:
	"""Register all available character data"""
	_register_character(KNIGHT_DATA)
	_register_character(ROGUE_DATA)

func _register_character(data: CharacterData) -> void:
	"""Register a single character data resource"""
	if data == null:
		push_error("CharacterDatabase: Attempted to register null CharacterData")
		return
	
	if not data.is_valid():
		push_error("CharacterDatabase: CharacterData '%s' failed validation" % data.character_name)
		return
	
	_characters[data.character_name] = data
	#print("[CharacterDatabase] Registered character: %s" % data.character_name)

func get_character_data(character_name: String) -> CharacterData:
	"""Get character data by name (e.g., 'Knight', 'Rogue')"""
	if not _characters.has(character_name):
		push_error("CharacterDatabase: Character '%s' not found" % character_name)
		return null
	
	return _characters[character_name]

func has_character(character_name: String) -> bool:
	"""Check if a character exists in the database"""
	return _characters.has(character_name)

func get_all_character_names() -> Array[String]:
	"""Get list of all available character names"""
	var names: Array[String] = []
	for key in _characters.keys():
		names.append(String(key))
	return names

func get_character_count() -> int:
	"""Get total number of registered characters"""
	return _characters.size()

# -----------------------------
# Character Selection (merged from GameManager)
# -----------------------------
func set_selected_character(character_name: String) -> void:
	"""Set the currently selected character with validation"""
	if character_name == "":
		selected_character = ""
		pass
		return
	
	if not has_character(character_name):
		push_warning("[CharacterDatabase] Attempted to select unknown character: %s" % character_name)
		return
	
	selected_character = character_name
	#print("[CharacterDatabase] Selected character: %s" % character_name)

func get_selected_character() -> String:
	"""Get the currently selected character name"""
	return selected_character

func get_selected_character_data() -> CharacterData:
	"""Get CharacterData for the currently selected character. Returns null if none selected."""
	if selected_character == "":
		return null
	return get_character_data(selected_character)
