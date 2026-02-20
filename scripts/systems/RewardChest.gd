extends Area2D
class_name RewardChest

signal opened(chest: RewardChest)

@export var interact_action: StringName = &"interact"
@export var player_group: StringName = &"player"
@export var open_once: bool = true
@export var auto_open_on_enter: bool = false # optional convenience

# Optional: UI prompt node path (Label) if you have one
@export var prompt_label_path: NodePath = ^"Prompt"

# --- Optional animation hookups (use either one) ---
@export var animated_sprite_path: NodePath = ^"AnimatedSprite2D"
@export var animation_player_path: NodePath = ^"AnimationPlayer"

@export var anim_closed: StringName = &"idle_closed"
@export var anim_open: StringName = &"open"
@export var anim_open_idle: StringName = &"idle_open"

@export var play_open_sfx: bool = false
@export var open_sfx_path: NodePath = ^"OpenSFX"

var _player_in_range: bool = false
var _opened: bool = false
var _opening: bool = false

var _prompt: Label = null
var _anim_sprite: AnimatedSprite2D = null
var _anim_player: AnimationPlayer = null
var _sfx: AudioStreamPlayer = null

func _ready() -> void:
	_prompt = get_node_or_null(prompt_label_path) as Label
	if _prompt != null:
		_prompt.visible = false

	_anim_sprite = get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	_anim_player = get_node_or_null(animation_player_path) as AnimationPlayer

	if play_open_sfx:
		_sfx = get_node_or_null(open_sfx_path) as AudioStreamPlayer

	# Start in closed anim if available
	_play_closed_visual()

	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	# Hook animation finished (AnimatedSprite2D)
	if _anim_sprite != null and not _anim_sprite.animation_finished.is_connected(_on_anim_sprite_finished):
		_anim_sprite.animation_finished.connect(_on_anim_sprite_finished)

func _process(_delta: float) -> void:
	if _opened and open_once:
		return
	if _opening:
		return
	if not _player_in_range:
		return

	if Input.is_action_just_pressed(String(interact_action)):
		_open()

func _open() -> void:
	if _opened and open_once:
		return
	if _opening:
		return

	_opening = true
	_opened = true

	if _prompt != null:
		_prompt.visible = false

	# Play visuals (if any). If none exist, we just emit immediately.
	var played_anim: bool = _play_open_visual()

	if play_open_sfx and _sfx != null:
		_sfx.play()

	if not played_anim:
		_finalize_open()

func _finalize_open() -> void:
	_opening = false
	_play_open_idle_visual()

	opened.emit(self)

	if open_once:
		# Stop further overlap checks after opening
		monitoring = false
		monitorable = false

func _on_body_entered(body: Node) -> void:
	if _opened and open_once:
		return
	if body != null and body.is_in_group(String(player_group)):
		_player_in_range = true

		if auto_open_on_enter and not _opening and not (_opened and open_once):
			_open()
			return

		if _prompt != null:
			_prompt.text = _build_prompt_text()
			_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body != null and body.is_in_group(String(player_group)):
		_player_in_range = false
		if _prompt != null:
			_prompt.visible = false

func _on_anim_sprite_finished() -> void:
	# AnimatedSprite2D only emits when a non-looping animation completes.
	if _anim_sprite == null:
		return
	if _anim_sprite.animation == String(anim_open):
		_finalize_open()

# -----------------------------
# Visual helpers
# -----------------------------
func _play_closed_visual() -> void:
	if _anim_sprite != null and anim_closed != &"":
		if _anim_sprite.sprite_frames != null and _anim_sprite.sprite_frames.has_animation(String(anim_closed)):
			_anim_sprite.play(String(anim_closed))
			return

	if _anim_player != null and anim_closed != &"":
		if _anim_player.has_animation(String(anim_closed)):
			_anim_player.play(String(anim_closed))

func _play_open_visual() -> bool:
	# Returns true if we started an animation that will call finalize later.
	if _anim_sprite != null and anim_open != &"":
		if _anim_sprite.sprite_frames != null and _anim_sprite.sprite_frames.has_animation(String(anim_open)):
			_anim_sprite.play(String(anim_open))
			# Only works properly if "open" is NOT looping.
			return true

	if _anim_player != null and anim_open != &"":
		if _anim_player.has_animation(String(anim_open)):
			_anim_player.play(String(anim_open))
			# AnimationPlayer doesn't auto notify us unless we wire a track.
			# Easiest: put a Call Method track at the end calling "_finalize_open".
			# If you don't do that, we'll finalize immediately (below).
			return false

	return false

func _play_open_idle_visual() -> void:
	if _anim_sprite != null and anim_open_idle != &"":
		if _anim_sprite.sprite_frames != null and _anim_sprite.sprite_frames.has_animation(String(anim_open_idle)):
			_anim_sprite.play(String(anim_open_idle))
			return

	if _anim_player != null and anim_open_idle != &"":
		if _anim_player.has_animation(String(anim_open_idle)):
			_anim_player.play(String(anim_open_idle))

# -----------------------------
# Prompt text
# -----------------------------
func _build_prompt_text() -> String:
	var key_text: String = _get_first_key_for_action(String(interact_action))
	if key_text == "":
		key_text = String(interact_action)
	return "Press [%s] to open" % key_text

func _get_first_key_for_action(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return ""

	var events: Array = InputMap.action_get_events(action_name)
	for e in events:
		if e is InputEventKey:
			var k := e as InputEventKey
			# Godot 4: physical_keycode is best for display
			if k.physical_keycode != 0:
				return OS.get_keycode_string(k.physical_keycode)
			if k.keycode != 0:
				return OS.get_keycode_string(k.keycode)

	# (Optional) you can add joypad button display here later
	return ""

func _exit_tree() -> void:
	pass

func lock_open_state() -> void:
	# Force chest to remain opened and non-interactable.
	_opened = true
	_opening = false
	_player_in_range = false

	monitoring = false
	monitorable = false

	if _prompt != null:
		_prompt.visible = false

	# Prefer AnimatedSprite2D (your scene uses this)
	if _anim_sprite != null:
		# If you have a dedicated open-idle, use it
		if anim_open_idle != &"" and _anim_sprite.sprite_frames != null and _anim_sprite.sprite_frames.has_animation(String(anim_open_idle)):
			_anim_sprite.play(String(anim_open_idle))
			return

		# Otherwise fall back to open (and stop on last frame if it loops)
		if anim_open != &"" and _anim_sprite.sprite_frames != null and _anim_sprite.sprite_frames.has_animation(String(anim_open)):
			_anim_sprite.play(String(anim_open))
			# If "open" is non-looping it will finish and (if connected) call finalize,
			# but since we're force-locking, we just ensure it doesn't keep re-opening.
			return

	# Fallback: AnimationPlayer (if you ever add it later)
	if _anim_player != null:
		if anim_open_idle != &"" and _anim_player.has_animation(String(anim_open_idle)):
			_anim_player.play(String(anim_open_idle))
			return
		if anim_open != &"" and _anim_player.has_animation(String(anim_open)):
			_anim_player.play(String(anim_open))
			return
