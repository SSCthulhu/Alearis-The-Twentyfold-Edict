extends Control
class_name SettingsMenu

signal back_pressed()

@export var style: HUDStyle

# Button sizing (match MainMenu/PauseMenu style)
@export var panel_width: float = 1220.0
@export var panel_height: float = 1150.0
@export var title_font_size: int = 80
@export var label_font_size: int = 50
@export var button_font_size: int = 70
@export var slider_label_spacing: float = 20.0
@export var section_spacing: float = 40.0

@onready var _overlay: ColorRect = $Overlay
@onready var _root: Control = $Root
@onready var _master_slider: HSlider = $Root/SettingsPanel/VBox/AudioSection/AudioGrid/MasterSlider
@onready var _master_label: Label = $Root/SettingsPanel/VBox/AudioSection/AudioGrid/MasterValue
@onready var _music_slider: HSlider = $Root/SettingsPanel/VBox/AudioSection/AudioGrid/MusicSlider
@onready var _music_label: Label = $Root/SettingsPanel/VBox/AudioSection/AudioGrid/MusicValue
@onready var _sfx_slider: HSlider = $Root/SettingsPanel/VBox/AudioSection/AudioGrid/SFXSlider
@onready var _sfx_label: Label = $Root/SettingsPanel/VBox/AudioSection/AudioGrid/SFXValue
@onready var _fullscreen_option: OptionButton = $Root/SettingsPanel/VBox/DisplaySection/FullscreenRow/OptionButton
@onready var _vsync_option: OptionButton = $Root/SettingsPanel/VBox/DisplaySection/VSyncRow/OptionButton
@onready var _resolution_option: OptionButton = $Root/SettingsPanel/VBox/DisplaySection/ResolutionRow/OptionButton
@onready var _back_button: Button = $Root/SettingsPanel/VBox/BackButton

var _is_open: bool = false
var _settings_file: String = "user://settings.cfg"

# Available resolutions (common 16:9 resolutions)
var _resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),   # 720p
	Vector2i(1920, 1080),  # 1080p
	Vector2i(2560, 1440),  # 1440p
	Vector2i(3840, 2160),  # 4K
]

func _check_audio_buses() -> void:
	"""Check if required audio buses exist and warn if missing"""
	var missing_buses: Array[String] = []
	
	if AudioServer.get_bus_index("Music") == -1:
		missing_buses.append("Music")
	if AudioServer.get_bus_index("SFX") == -1:
		missing_buses.append("SFX")
	
	if missing_buses.size() > 0:
		push_warning("[Settings] Missing audio buses: " + str(missing_buses) + " - Please create them in Project Settings > Audio > Buses. Music and SFX controls will fall back to Master bus.")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Check audio bus setup
	_check_audio_buses()
	
	# Set up overlay
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Set pivot offset for back button scaling
	if _back_button != null:
		_back_button.pivot_offset = _back_button.size / 2.0
		_back_button.pressed.connect(_on_back_pressed)
		_back_button.mouse_entered.connect(_on_button_hover.bind(_back_button))
		_back_button.mouse_exited.connect(_on_button_unhover.bind(_back_button))
	
	# Connect slider signals
	if _master_slider != null:
		_master_slider.value_changed.connect(_on_master_volume_changed)
	if _music_slider != null:
		_music_slider.value_changed.connect(_on_music_volume_changed)
	if _sfx_slider != null:
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Connect dropdown signals
	if _fullscreen_option != null:
		_fullscreen_option.item_selected.connect(_on_fullscreen_selected)
		_populate_fullscreen_dropdown()
	if _vsync_option != null:
		_vsync_option.item_selected.connect(_on_vsync_selected)
		_populate_vsync_dropdown()
	
	# Connect resolution dropdown
	if _resolution_option != null:
		_resolution_option.item_selected.connect(_on_resolution_selected)
		_populate_resolution_dropdown()
	
	# Load saved settings
	_load_settings()
	
	# Start hidden
	visible = false
	_is_open = false


func open() -> void:
	if _is_open:
		return
	
	_is_open = true
	visible = true
	
	# Refresh UI to show current settings
	_update_ui_from_current_settings()


func close() -> void:
	if not _is_open:
		return
	
	_is_open = false
	visible = false
	
	back_pressed.emit()


func _on_back_pressed() -> void:
	close()


# ═══════════════════════════════════
# Audio Settings
# ═══════════════════════════════════
func _on_master_volume_changed(value: float) -> void:
	var db: float = _linear_to_db(value)
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
	_master_label.text = str(int(value)) + "%"
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	var db: float = _linear_to_db(value)
	var bus_idx: int = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
	else:
		# Fallback to Master if Music bus doesn't exist
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	_music_label.text = str(int(value)) + "%"
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	var db: float = _linear_to_db(value)
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
	else:
		# Fallback to Master if SFX bus doesn't exist
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	_sfx_label.text = str(int(value)) + "%"
	_save_settings()


func _linear_to_db(linear: float) -> float:
	"""Convert 0-100 linear volume to decibels"""
	if linear <= 0.0:
		return -80.0  # Effectively muted
	
	# Map 0-100 to -40db to 0db range
	var normalized: float = linear / 100.0
	return -40.0 + (normalized * 40.0)


# ═══════════════════════════════════
# Display Settings
# ═══════════════════════════════════
func _populate_fullscreen_dropdown() -> void:
	"""Add Enabled/Disabled options to fullscreen dropdown"""
	if _fullscreen_option == null:
		return
	
	_fullscreen_option.clear()
	_fullscreen_option.add_item("Disabled")
	_fullscreen_option.add_item("Enabled")


func _populate_vsync_dropdown() -> void:
	"""Add Enabled/Disabled options to vsync dropdown"""
	if _vsync_option == null:
		return
	
	_vsync_option.clear()
	_vsync_option.add_item("Disabled")
	_vsync_option.add_item("Enabled")


func _on_fullscreen_selected(index: int) -> void:
	"""Apply fullscreen setting from dropdown (0=Disabled, 1=Enabled)"""
	if index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _on_vsync_selected(index: int) -> void:
	"""Apply vsync setting from dropdown (0=Disabled, 1=Enabled)"""
	if index == 1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_save_settings()


func _populate_resolution_dropdown() -> void:
	"""Add resolution options to dropdown"""
	if _resolution_option == null:
		return
	
	_resolution_option.clear()
	
	for res in _resolutions:
		var label: String = str(res.x) + " x " + str(res.y)
		# Add quality labels
		if res.y == 720:
			label += " (720p)"
		elif res.y == 1080:
			label += " (1080p)"
		elif res.y == 1440:
			label += " (1440p)"
		elif res.y == 2160:
			label += " (4K)"
		
		_resolution_option.add_item(label)


func _on_resolution_selected(index: int) -> void:
	"""Apply selected resolution"""
	if index < 0 or index >= _resolutions.size():
		return
	
	var new_res: Vector2i = _resolutions[index]
	
	# Only apply if in windowed mode (fullscreen uses native resolution)
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(new_res)
		# Center window on screen
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		var window_pos: Vector2i = (screen_size - new_res) / 2
		DisplayServer.window_set_position(window_pos)
	
	_save_settings()


# ═══════════════════════════════════
# Settings Persistence
# ═══════════════════════════════════
func _save_settings() -> void:
	"""Save all settings to config file"""
	var config := ConfigFile.new()
	
	# Audio
	config.set_value("audio", "master_volume", _master_slider.value if _master_slider != null else 70.0)
	config.set_value("audio", "music_volume", _music_slider.value if _music_slider != null else 80.0)
	config.set_value("audio", "sfx_volume", _sfx_slider.value if _sfx_slider != null else 100.0)
	
	# Display
	config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.set_value("display", "vsync", DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED)
	
	if _resolution_option != null:
		config.set_value("display", "resolution_index", _resolution_option.selected)
	
	var err := config.save(_settings_file)
	if err != OK:
		push_warning("[Settings] Failed to save settings: " + str(err))


func _load_settings() -> void:
	"""Load settings from config file and apply them"""
	var config := ConfigFile.new()
	var err := config.load(_settings_file)
	
	if err != OK:
		pass
		_apply_default_settings()
		return
	
	# Load audio settings
	var master_vol: float = config.get_value("audio", "master_volume", 70.0)
	var music_vol: float = config.get_value("audio", "music_volume", 80.0)
	var sfx_vol: float = config.get_value("audio", "sfx_volume", 100.0)
	
	# Apply audio (this will trigger the sliders' value_changed signals)
	if _master_slider != null:
		_master_slider.value = master_vol
	if _music_slider != null:
		_music_slider.value = music_vol
	if _sfx_slider != null:
		_sfx_slider.value = sfx_vol
	
	# Load display settings
	var fullscreen: bool = config.get_value("display", "fullscreen", false)
	var vsync: bool = config.get_value("display", "vsync", true)
	var res_index: int = config.get_value("display", "resolution_index", 1)  # Default to 1080p
	
	# Apply display settings
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	if _resolution_option != null and res_index >= 0 and res_index < _resolutions.size():
		_resolution_option.selected = res_index
		# Apply resolution if windowed
		if not fullscreen:
			var new_res: Vector2i = _resolutions[res_index]
			DisplayServer.window_set_size(new_res)
	
	# Update UI dropdowns
	if _fullscreen_option != null:
		_fullscreen_option.selected = 1 if fullscreen else 0
	if _vsync_option != null:
		_vsync_option.selected = 1 if vsync else 0
	
	pass


func _apply_default_settings() -> void:
	"""Apply default settings on first launch"""
	# Default audio
	if _master_slider != null:
		_master_slider.value = 70.0
	if _music_slider != null:
		_music_slider.value = 80.0
	if _sfx_slider != null:
		_sfx_slider.value = 100.0
	
	# Default display
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if _vsync_option != null:
		_vsync_option.selected = 1  # Enabled by default
	
	# Default resolution (1080p)
	if _resolution_option != null:
		_resolution_option.selected = 1
	
	pass


func _update_ui_from_current_settings() -> void:
	"""Refresh UI sliders/checkboxes to match current game state"""
	# Update audio sliders from current bus volumes
	if _master_slider != null:
		var bus_idx: int = AudioServer.get_bus_index("Master")
		if bus_idx >= 0:
			var db: float = AudioServer.get_bus_volume_db(bus_idx)
			_master_slider.value = _db_to_linear(db)
			_master_label.text = str(int(_master_slider.value)) + "%"
	
	if _music_slider != null:
		var bus_idx: int = AudioServer.get_bus_index("Music")
		if bus_idx >= 0:
			var db: float = AudioServer.get_bus_volume_db(bus_idx)
			_music_slider.value = _db_to_linear(db)
			_music_label.text = str(int(_music_slider.value)) + "%"
	
	if _sfx_slider != null:
		var bus_idx: int = AudioServer.get_bus_index("SFX")
		if bus_idx >= 0:
			var db: float = AudioServer.get_bus_volume_db(bus_idx)
			_sfx_slider.value = _db_to_linear(db)
			_sfx_label.text = str(int(_sfx_slider.value)) + "%"
	
	# Update display dropdowns
	if _fullscreen_option != null:
		_fullscreen_option.selected = 1 if (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN) else 0
	
	if _vsync_option != null:
		_vsync_option.selected = 1 if (DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED) else 0


func _db_to_linear(db: float) -> float:
	"""Convert decibels to 0-100 linear scale"""
	if db <= -40.0:
		return 0.0
	return ((db + 40.0) / 40.0) * 100.0


# ✨ Button hover effects (matches MainMenu/PauseMenu style)
func _on_button_hover(btn: Button) -> void:
	create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)


func _on_button_unhover(btn: Button) -> void:
	create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
