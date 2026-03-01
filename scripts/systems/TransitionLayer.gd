extends CanvasLayer

@onready var rect = $ColorRect
@onready var loading_label = $Label
var _is_transitioning: bool = false

func _ready():
	_force_hidden()

func fade_to_scene(target_scene_path: String):
	_is_transitioning = true
	visible = true
	rect.visible = true
	loading_label.visible = true
	rect.modulate.a = 0.0
	loading_label.modulate.a = 0.0

	var tween = create_tween()
	
	# --- PHASE 1: FADE TO BLACK (Parallel) ---
	# We use .set_parallel() only for the first two properties
	tween.set_parallel(true)
	tween.tween_property(rect, "modulate:a", 1.0, 0.5)
	tween.tween_property(loading_label, "modulate:a", 1.0, 0.5)
	
	# --- PHASE 2: THE SWITCH (Chained) ---
	# .chain() forces the next step to wait for the previous parallel block to finish
	tween.chain().tween_callback(func(): get_tree().change_scene_to_file(target_scene_path))
	
	# --- PHASE 3: FADE OUT (Parallel) ---
	# We start a new parallel block for the reveal
	tween.chain().set_parallel(true)
	tween.tween_property(rect, "modulate:a", 0.0, 0.5)
	tween.tween_property(loading_label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(_force_hidden)

func _force_hidden() -> void:
	_is_transitioning = false
	if rect != null:
		rect.modulate.a = 0.0
		rect.visible = false
	if loading_label != null:
		loading_label.modulate.a = 0.0
		loading_label.visible = false
	visible = false

