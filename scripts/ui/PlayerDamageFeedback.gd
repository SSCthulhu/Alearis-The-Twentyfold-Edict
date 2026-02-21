extends Node
class_name PlayerDamageFeedback

@export var flash_rect_path: NodePath = ^"HitFlash"
@export var low_health_postfx_rect_path: NodePath = ^"LowHealthPostFX"
@export var low_health_rect_path: NodePath = ^"LowHealthBorder"

@export_group("Hit Flash")
@export var flash_color: Color = Color(1.0, 0.95, 0.90, 1.0)
@export var flash_peak_alpha: float = 0.18
@export var flash_rise_time: float = 0.03
@export var flash_fall_time: float = 0.11

@export_group("Low Health Border")
@export_range(0.05, 1.0, 0.01) var low_health_start_ratio: float = 0.30
@export var enable_low_health_cross_pulse: bool = true
@export var low_health_cross_pulse_strength: float = 0.16
@export var low_health_cross_pulse_rise_time: float = 0.08
@export var low_health_cross_pulse_fall_time: float = 0.22

@export_group("Low Health Heartbeat")
@export var enable_heartbeat_effect: bool = true
@export var enable_low_health_postfx: bool = false
@export var heartbeat_min_speed: float = 1.0
@export var heartbeat_max_speed: float = 2.2
@export var heartbeat_border_pulse_amount: float = 0.06
@export var heartbeat_postfx_pulse_amount: float = 0.08

var _health: PlayerHealth = null
var _flash_rect: ColorRect = null
var _low_health_postfx_rect: ColorRect = null
var _low_health_rect: ColorRect = null
var _flash_tween: Tween = null
var _pulse_tween: Tween = null
var _base_border_strength: float = 0.0
var _pulse_border_strength: float = 0.0
var _last_hp_ratio: float = 1.0
var _has_health_sample: bool = false
var _player_dead: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_flash_rect = get_node_or_null(flash_rect_path) as ColorRect
	_low_health_postfx_rect = get_node_or_null(low_health_postfx_rect_path) as ColorRect
	_low_health_rect = get_node_or_null(low_health_rect_path) as ColorRect

	if _flash_rect != null:
		_flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _low_health_rect != null:
		_low_health_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_base_border_strength(0.0)

	if _low_health_postfx_rect != null:
		_low_health_postfx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_low_health_postfx_rect.visible = false
		_apply_postfx_parameters(0.0)

	_try_bind_health()

func _try_bind_health() -> void:
	if _health != null and is_instance_valid(_health):
		return

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("Health"):
		return

	var health_node: PlayerHealth = player.get_node("Health") as PlayerHealth
	if health_node == null:
		return

	_health = health_node

	if not _health.damage_applied.is_connected(_on_damage_applied):
		_health.damage_applied.connect(_on_damage_applied)
	if not _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.connect(_on_health_changed)
	if _health.has_signal("died") and not _health.died.is_connected(_on_player_died):
		_health.died.connect(_on_player_died)

	_on_health_changed(_health.hp, _health.max_hp)

func _process(_delta: float) -> void:
	# Late-bind in case player is spawned after UI initializes.
	if _health == null or not is_instance_valid(_health):
		_try_bind_health()

	_update_heartbeat_material_params()

func _on_damage_applied(_final_damage: int, _source: Node) -> void:
	if _player_dead:
		return
	_play_hit_flash()

func _on_health_changed(current: int, max_value: int) -> void:
	if current > 0 and _player_dead:
		_player_dead = false

	if max_value <= 0:
		_set_base_border_strength(0.0)
		return

	var hp_ratio: float = clampf(float(current) / float(max_value), 0.0, 1.0)
	var crossed_into_low: bool = _has_health_sample and (_last_hp_ratio > low_health_start_ratio and hp_ratio <= low_health_start_ratio)
	_has_health_sample = true
	_last_hp_ratio = hp_ratio

	if hp_ratio >= low_health_start_ratio:
		_set_base_border_strength(0.0)
		return

	var t: float = (low_health_start_ratio - hp_ratio) / low_health_start_ratio
	_set_base_border_strength(clampf(t, 0.0, 1.0))

	if crossed_into_low and enable_low_health_cross_pulse:
		_play_low_health_cross_pulse()

func _on_player_died() -> void:
	_player_dead = true
	_last_hp_ratio = 1.0
	_has_health_sample = false

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_border_strength = 0.0
	_set_base_border_strength(0.0)

	if _flash_rect != null:
		_flash_rect.color.a = 0.0
	if _low_health_postfx_rect != null:
		_low_health_postfx_rect.visible = false

func _set_base_border_strength(value: float) -> void:
	_base_border_strength = clampf(value, 0.0, 1.0)
	_apply_border_strength()

func _apply_border_strength() -> void:
	if _low_health_rect == null:
		return
	var mat: ShaderMaterial = _low_health_rect.material as ShaderMaterial
	if mat == null:
		return
	var total_strength: float = clampf(_base_border_strength + _pulse_border_strength, 0.0, 1.0)
	mat.set_shader_parameter("strength", total_strength)
	_apply_postfx_parameters(total_strength)

func _update_heartbeat_material_params() -> void:
	if not enable_heartbeat_effect:
		_set_heartbeat_params(heartbeat_min_speed, 0.0, 0.0)
		return

	var s: float = clampf(_base_border_strength, 0.0, 1.0)
	if s <= 0.0:
		_set_heartbeat_params(heartbeat_min_speed, 0.0, 0.0)
		return

	var speed: float = lerpf(heartbeat_min_speed, heartbeat_max_speed, s)
	var border_pulse: float = heartbeat_border_pulse_amount * s
	var postfx_pulse: float = heartbeat_postfx_pulse_amount * s
	_set_heartbeat_params(speed, border_pulse, postfx_pulse)

func _set_heartbeat_params(speed: float, border_pulse: float, postfx_pulse: float) -> void:
	if _low_health_rect != null:
		var border_mat: ShaderMaterial = _low_health_rect.material as ShaderMaterial
		if border_mat != null:
			border_mat.set_shader_parameter("pulse_speed", speed)
			border_mat.set_shader_parameter("pulse_amount", border_pulse)

	if _low_health_postfx_rect != null:
		var postfx_mat: ShaderMaterial = _low_health_postfx_rect.material as ShaderMaterial
		if postfx_mat != null:
			postfx_mat.set_shader_parameter("pulse_speed", speed)
			postfx_mat.set_shader_parameter("pulse_amount", postfx_pulse if enable_low_health_postfx else 0.0)

func _apply_postfx_parameters(total_strength: float) -> void:
	if _low_health_postfx_rect == null:
		return
	if not enable_low_health_postfx:
		_low_health_postfx_rect.visible = false
		return
	var visible_now: bool = total_strength > 0.001
	_low_health_postfx_rect.visible = visible_now
	if not visible_now:
		return
	var mat: ShaderMaterial = _low_health_postfx_rect.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("strength", clampf(total_strength, 0.0, 1.0))

func _play_low_health_cross_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_border_strength = 0.0
	_apply_border_strength()

	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_method(_on_pulse_strength_tweened, 0.0, low_health_cross_pulse_strength, maxf(low_health_cross_pulse_rise_time, 0.01))
	_pulse_tween.set_ease(Tween.EASE_IN)
	_pulse_tween.tween_method(_on_pulse_strength_tweened, low_health_cross_pulse_strength, 0.0, maxf(low_health_cross_pulse_fall_time, 0.01))

func _on_pulse_strength_tweened(value: float) -> void:
	_pulse_border_strength = value
	_apply_border_strength()

func _play_hit_flash() -> void:
	if _flash_rect == null:
		return

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)

	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_SINE)
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_flash_rect, "color:a", flash_peak_alpha, maxf(flash_rise_time, 0.01))
	_flash_tween.set_ease(Tween.EASE_IN)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, maxf(flash_fall_time, 0.01))
