extends Node
class_name EnemyCastingHelper

## Enemy Casting Helper Component
## Handles common casting UI and timing logic for casting enemies
## Reduces duplication across Mage, Necromancer, and Golem

# References (set by parent enemy)
var cast_bar: ProgressBar = null
var is_casting: bool = false

# Internal state
var _cast_timer: float = 0.0
var _cast_duration: float = 0.0

## Initialize the cast bar (call in enemy's _ready)
func initialize_cast_bar(bar: ProgressBar) -> void:
	cast_bar = bar
	if cast_bar:
		cast_bar.visible = false
		cast_bar.value = 0.0
		cast_bar.max_value = 1.0

## Start a cast with given duration
func start_cast(duration: float) -> void:
	is_casting = true
	_cast_timer = 0.0
	_cast_duration = maxf(duration, 0.01)
	
	if cast_bar:
		cast_bar.visible = true
		cast_bar.value = 0.0

## Update cast progress (call in _physics_process)
## Returns true when cast is complete
func update_cast(delta: float) -> bool:
	if not is_casting:
		return false
	
	_cast_timer += delta
	
	if cast_bar:
		cast_bar.value = _cast_timer / _cast_duration
	
	# Check if cast finished
	if _cast_timer >= _cast_duration:
		return true
	
	return false

## Finish the cast (hides cast bar, resets state)
func finish_cast() -> void:
	is_casting = false
	_cast_timer = 0.0
	
	if cast_bar:
		cast_bar.visible = false

## Cancel the cast (for interrupts)
func cancel_cast() -> void:
	is_casting = false
	_cast_timer = 0.0
	
	if cast_bar:
		cast_bar.visible = false

## Get current cast progress (0.0 to 1.0)
func get_cast_progress() -> float:
	if _cast_duration <= 0.0:
		return 0.0
	return clampf(_cast_timer / _cast_duration, 0.0, 1.0)

## Get remaining cast time
func get_remaining_time() -> float:
	return maxf(_cast_duration - _cast_timer, 0.0)
