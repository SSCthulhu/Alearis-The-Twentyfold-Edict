extends CanvasLayer

@onready var rect = $ColorRect
@onready var loading_label = $Label

func _ready():
	# Force absolute invisibility on launch
	rect.modulate.a = 0
	loading_label.modulate.a = 0

func fade_to_scene(target_scene_path: String):
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


