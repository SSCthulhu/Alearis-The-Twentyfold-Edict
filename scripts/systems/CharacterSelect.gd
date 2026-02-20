extends Control

@onready var preview = %CharacterPreview
@onready var knight_button: Button = $CenterContainer/HBoxContainer/Knight
@onready var rogue_button: Button = $CenterContainer/HBoxContainer/Rogue
@onready var wizard_button: Button = $CenterContainer/HBoxContainer/Wizard
@onready var back_button: Button = $BackButton
@onready var play_button: Button = $PlayButton
@onready var reset_dice_button: Button = $ResetDiceButton
@onready var dice_range_label: Label = $DiceRangeLabel
@onready var reset_confirm_dialog: ConfirmationDialog = $ResetConfirmDialog

var selected_character: String = ""

func _ready():
	# Verification: Ensure the preview node exists
	if preview == null:
		push_error("CharacterPreview node not found!")
	
	# Update dice range display
	_update_dice_range_display()
	
	# ✨ Set pivot offsets and connect hover effects (matches MainMenu style)
	_setup_button_hover_effects()

# --- HOVER LOGIC (Preview) ---

func _on_knight_hover():
	# Always show preview on hover, even if another is selected
	preview.display_character("Knight")

func _on_rogue_hover():
	preview.display_character("Rogue")

func _on_wizard_hover():
	preview.display_character("Wizard")

func _on_button_mouse_exited():
	# If we have a selection, keep showing that selection
	if selected_character != "":
		preview.display_character(selected_character)
	else:
		# If nothing is selected, clear the screen
		preview.clear_preview()

# --- CLICK LOGIC (Selection) ---

func _on_knight_pressed():
	selected_character = "Knight"
	CharacterDatabase.set_selected_character("Knight")

func _on_rogue_pressed():
	selected_character = "Rogue"
	CharacterDatabase.set_selected_character("Rogue")

func _on_wizard_pressed():
	selected_character = "Wizard"
	CharacterDatabase.set_selected_character("Wizard")

# --- PLAY BUTTON LOGIC ---

func _on_play_button_pressed():
	if selected_character != "":
		load_world()
	else:
		pass

func load_world():
	# Reset run state with saved starting dice range
	if RunStateSingleton != null:
		RunStateSingleton.start_new_run()
		pass
	
	TransitionLayer.fade_to_scene("res://scenes/world/World1.tscn")


# --- BACK BUTTON LOGIC ---

func _on_back_button_pressed():
	"""Return to main menu"""
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_reset_dice_button_pressed():
	"""Show confirmation dialog before resetting dice range"""
	if reset_confirm_dialog != null:
		reset_confirm_dialog.popup_centered()


func _on_reset_confirmed():
	"""Reset dice range to default 10-10 after confirmation"""
	if RunStateSingleton != null:
		RunStateSingleton.update_starting_dice_range(10)
		_update_dice_range_display()
		print("[CharacterSelect] Dice range reset to 10-10")


func _update_dice_range_display():
	"""Update the dice range label with current values"""
	if dice_range_label != null and RunStateSingleton != null:
		var dice_min = RunStateSingleton.starting_dice_min
		var dice_max = RunStateSingleton.starting_dice_max
		dice_range_label.text = "Current Dice Range: %d-%d" % [dice_min, dice_max]


# ✨ Button hover effects (matches MainMenu style)
func _setup_button_hover_effects() -> void:
	"""Set up button scaling on hover"""
	var buttons: Array[Button] = [knight_button, rogue_button, wizard_button, back_button, play_button, reset_dice_button]
	
	for btn in buttons:
		if btn != null:
			# Set pivot to center for scaling
			btn.pivot_offset = btn.size / 2.0
			# Connect hover signals
			btn.mouse_entered.connect(_on_button_scale_hover.bind(btn))
			btn.mouse_exited.connect(_on_button_scale_unhover.bind(btn))


func _on_button_scale_hover(btn: Button) -> void:
	"""Scale button to 105% on hover (matches MainMenu)"""
	create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)


func _on_button_scale_unhover(btn: Button) -> void:
	"""Scale button back to 100% when not hovered (matches MainMenu)"""
	create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)

