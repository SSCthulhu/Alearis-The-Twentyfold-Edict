extends Control
class_name PerfectDodgeToast

@export var text: String = "PERFECT"
@export var rise_px: float = 18.0
@export var in_time: float = 0.07
@export var hold_time: float = 0.20
@export var out_time: float = 0.16

@onready var label: Label = $Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if label != null:
		label.text = text

	modulate.a = 0.0

func show_text(v: String) -> void:
	text = v
	if label != null:
		label.text = v

# Called by PerfectDodgeVFX after it converts world->UI coordinates
func _place_centered(local_pos: Vector2) -> void:
	# Center toast on the position
	position = local_pos - (size * 0.5)

	# Start slightly lower and rise
	var start_pos: Vector2 = position + Vector2(0.0, 6.0)
	position = start_pos

	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, in_time)
	t.parallel().tween_property(self, "position", local_pos - (size * 0.5), in_time)

	t.tween_interval(hold_time)

	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, out_time)
	t.parallel().tween_property(self, "position", (local_pos - (size * 0.5)) - Vector2(0.0, rise_px), out_time)

	t.tween_callback(queue_free)
