extends CenterContainer

@export var game_title_label: RichTextLabel
@export var d20_sprite: TextureRect
@export var start_button: Button
@export var settings_button: Button
@export var quit_button: Button

func _ready():
	# 1. Immediate Hard Reset: Force everything invisible before anything else happens
	if game_title_label: game_title_label.modulate.a = 0
	if d20_sprite: d20_sprite.modulate.a = 0
	if start_button: 
		start_button.modulate.a = 0
		start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Block clicks until visible
	if settings_button: 
		settings_button.modulate.a = 0
		settings_button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Block clicks until visible
	if quit_button: 
		quit_button.modulate.a = 0
		quit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Block clicks until visible
	

	# 2. Run the unified animation timeline
	start_menu_animations()

	# Auto-center the pivot points
	start_button.pivot_offset = start_button.size / 2
	if settings_button: settings_button.pivot_offset = settings_button.size / 2
	quit_button.pivot_offset = quit_button.size / 2
	
	# Connect the hover signals
	start_button.mouse_entered.connect(_on_button_hover.bind(start_button))
	start_button.mouse_exited.connect(_on_button_unhover.bind(start_button))
	if settings_button:
		settings_button.mouse_entered.connect(_on_button_hover.bind(settings_button))
		settings_button.mouse_exited.connect(_on_button_unhover.bind(settings_button))
	quit_button.mouse_entered.connect(_on_button_hover.bind(quit_button))
	quit_button.mouse_exited.connect(_on_button_unhover.bind(quit_button))

func start_menu_animations():
	var menu_tween = create_tween()
	
	# --- PHASE 1: THE TITLE (Starts at 3.0s) ---
	menu_tween.tween_interval(3.0)
	if game_title_label:
		menu_tween.tween_property(game_title_label, "modulate:a", 1.0, 1.0)
	
	# --- PHASE 2: THE CONTENT (Starts at 5.0s) ---
	# We wait 1 more second after the title finishes (3s wait + 1s fade + 1s wait = 5s)
	menu_tween.tween_interval(1.0) 
	
	# .set_parallel() makes the next properties happen at the same time
	menu_tween.set_parallel(true)
	
	if d20_sprite:
		menu_tween.tween_property(d20_sprite, "modulate:a", 1.0, 1.5)
	if start_button:
		menu_tween.tween_property(start_button, "modulate:a", 1.0, 1.5)
	if settings_button:
		menu_tween.tween_property(settings_button, "modulate:a", 1.0, 1.5)
	if quit_button:
		menu_tween.tween_property(quit_button, "modulate:a", 1.0, 1.5)
	
	# --- PHASE 3: ENABLE BUTTONS AFTER FADE-IN COMPLETES ---
	menu_tween.set_parallel(false)  # Back to sequential
	menu_tween.tween_callback(_enable_buttons)

func _enable_buttons():
	"""Enable buttons after fade-in animation completes"""
	if start_button:
		start_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if settings_button:
		settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if quit_button:
		quit_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_button_hover(btn):
	create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_unhover(btn):
	create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
