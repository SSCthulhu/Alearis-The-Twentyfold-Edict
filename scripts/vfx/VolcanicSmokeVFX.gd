extends Node2D

@export var rise_speed: float = 30.0
@export var rise_distance: float = 400.0
@export var fade_start_percent: float = 0.5
@export var drift_amount: float = 20.0
@export var animation_speed_variation: float = 0.2

var _start_y: float = 0.0
var _elapsed: float = 0.0
var _duration: float = 8.0
var _drift_offset: float = 0.0

func _ready() -> void:
	_start_y = global_position.y
	_elapsed = randf() * _duration
	_drift_offset = randf_range(-drift_amount, drift_amount)
	
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	if sprite:
		sprite.play("smoke_burst")
		var speed_mult := 1.0 + randf_range(-animation_speed_variation, animation_speed_variation)
		sprite.speed_scale = speed_mult

func _process(delta: float) -> void:
	_elapsed += delta
	
	if _elapsed >= _duration:
		_elapsed = 0.0
		global_position.y = _start_y
		modulate.a = 1.0
		return
	
	var progress := _elapsed / _duration
	global_position.y = _start_y - (progress * rise_distance)
	
	var drift := sin(progress * TAU * 2.0) * _drift_offset
	global_position.x = global_position.x + drift * delta
	
	if progress >= fade_start_percent:
		var fade_progress := (progress - fade_start_percent) / (1.0 - fade_start_percent)
		modulate.a = 1.0 - fade_progress
	else:
		modulate.a = 1.0
