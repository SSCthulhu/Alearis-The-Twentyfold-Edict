extends Control
class_name ScreenRoot

func _ready() -> void:
	_fit()

	# Re-fit on window resize / resolution changes
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_fit):
		vp.size_changed.connect(_fit)

func _fit() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Debug
	#print("[ScreenRoot] viewport=", get_viewport().get_visible_rect(), " global_rect=", get_global_rect())
