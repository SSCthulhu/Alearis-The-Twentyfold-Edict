extends Control

@export var settings_menu_scene: PackedScene  # Reference to SettingsMenu.tscn

@onready var _music: AudioStreamPlayer = $MainMenuMusic

var _settings_menu_instance: SettingsMenu = null

func _ready() -> void:
	# Start menu music
	if _music == null:
		push_warning("[MainMenu] MainMenuMusic node not found. Check node name/path.")
		return

	if _music.stream == null:
		push_warning("[MainMenu] MainMenuMusic has no Stream assigned in the Inspector.")
		return

	# Make sure it isn't silent/misrouted
	_music.bus = &"Music"
	if _music.volume_db <= -70.0:
		_music.volume_db = -10.0

	_music.play()
	#print("[MainMenu] Music playing =", _music.playing)


# This function is called when the 'StartButton' is clicked
func _on_start_button_pressed() -> void:
	#print("Start button clicked!")
	start_game()


# This function allows starting the game using a keyboard input (like 'Enter')
func _input(event: InputEvent) -> void:
	# Assuming 'ui_accept' is mapped to your desired input in Project Settings
	if event.is_action_pressed(&"ui_accept"):
		start_game()


# Helper function to transition to the main game scene safely
func start_game() -> void:
	# Stop menu music when leaving the menu (optional)
	if _music != null and _music.playing:
		_music.stop()
	
	# Use call_deferred to safely change scenes without causing errors
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/CharacterSelect.tscn")


# This function is called when the 'SettingsButton' is clicked
func _on_settings_button_pressed() -> void:
	"""Open settings menu"""
	if settings_menu_scene == null:
		push_warning("[MainMenu] Settings menu scene not assigned!")
		return
	
	# Instantiate settings menu if not already created
	if _settings_menu_instance == null:
		var instance := settings_menu_scene.instantiate()
		_settings_menu_instance = instance as SettingsMenu
		if _settings_menu_instance == null:
			push_warning("[MainMenu] Settings menu scene is not a SettingsMenu!")
			instance.queue_free()
			return
		
		# Add as child of MainMenu
		add_child(_settings_menu_instance)
		
		# Connect back signal
		_settings_menu_instance.back_pressed.connect(_on_settings_back)
	
	# Show settings
	_settings_menu_instance.open()


func _on_settings_back() -> void:
	"""Return from settings menu to main menu"""
	# Hide settings
	if _settings_menu_instance != null:
		_settings_menu_instance.visible = false


# This function is called when the 'QuitButton' is clicked
func _on_quit_button_pressed() -> void:
	get_tree().quit() # Closes the application
