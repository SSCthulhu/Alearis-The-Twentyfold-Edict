extends Node
class_name HealthBarsController

@export var boss_health_ui_path: NodePath = NodePath()

# NEW: Point to PlayerHUDCluster instead of PlayerHealthUI
@export var player_hud_cluster_path: NodePath = NodePath()

var _player_health: PlayerHealth = null
var _boss: BossController = null

# Boss legacy widgets (keep for now)
var _boss_bar: ProgressBar = null
var _boss_pct: Label = null

# NEW: Player HUD cluster
var _player_hud: PlayerHUDCluster = null

func _ready() -> void:
	# --- Resolve UI roots ---
	var boss_ui: Node = _resolve_ui_root(boss_health_ui_path, "BossHealthUI")
	_player_hud = _resolve_ui_root(player_hud_cluster_path, "PlayerHUDCluster") as PlayerHUDCluster

	if boss_ui == null:
		push_error("HealthBarsController: Could not resolve BossHealthUI.")
		return

	if _player_hud == null:
		push_error("HealthBarsController: Could not resolve PlayerHUDCluster. Drag-drop path or ensure node is named PlayerHUDCluster.")
		return

	# --- Resolve boss widgets inside BossHealthUI ---
	_boss_bar = boss_ui.get_node_or_null("BossBar") as ProgressBar
	_boss_pct = boss_ui.get_node_or_null("BossPercentLabel") as Label
	if _boss_bar == null or _boss_pct == null:
		push_error("HealthBarsController: Missing boss child nodes. Expected BossBar/BossPercentLabel.")
		return

	# --- Resolve gameplay sources ---
	_player_health = _find_first_player_health(get_tree().current_scene)
	if _player_health == null:
		push_error("HealthBarsController: Could not find PlayerHealth in current scene.")
		return

	_boss = _find_first_boss_controller(get_tree().current_scene)
	if _boss == null:
		# Only warn in main world scenes (sub-arenas and FinalWorld are expected to not have BossController)
		var scene_name: String = ""
		if get_tree().current_scene:
			scene_name = String(get_tree().current_scene.name)
		if not ("SubArena" in scene_name or "FinalWorld" in scene_name):
			push_warning("HealthBarsController: Could not find BossController in current scene.")
		# Hide the entire boss UI when no boss present
		if boss_ui != null:
			boss_ui.visible = false
		# Continue anyway - player health will still work
	else:
		# Show boss UI when boss is present
		if boss_ui != null:
			boss_ui.visible = true

	# --- Connect signals ---
	if not _player_health.health_changed.is_connected(_on_player_health_changed):
		_player_health.health_changed.connect(_on_player_health_changed)

	if _boss != null and not _boss.health_changed.is_connected(_on_boss_health_changed):
		_boss.health_changed.connect(_on_boss_health_changed)

	# --- Push initial ---
	_on_player_health_changed(_player_health.hp, _player_health.max_hp)
	if _boss != null:
		_on_boss_health_changed(_boss.hp, _boss.max_hp)

func _resolve_ui_root(path: NodePath, fallback_name: String) -> Node:
	# 1) Prefer explicit drag-drop path
	if path != NodePath():
		var n: Node = get_node_or_null(path)
		if n != null:
			return n

	# 2) Find by name anywhere under UI
	var ui: Node = get_tree().current_scene.get_node_or_null("UI")
	if ui != null:
		var found: Node = _find_first_named(ui, fallback_name)
		if found != null:
			return found

	# 3) Whole scene fallback
	return _find_first_named(get_tree().current_scene, fallback_name)

func _find_first_named(n: Node, target_name: String) -> Node:
	if n.name == target_name:
		return n
	for c: Node in n.get_children():
		var found := _find_first_named(c, target_name)
		if found != null:
			return found
	return null

func _find_first_player_health(n: Node) -> PlayerHealth:
	var ph: PlayerHealth = n as PlayerHealth
	if ph != null:
		return ph
	for c: Node in n.get_children():
		var found: PlayerHealth = _find_first_player_health(c)
		if found != null:
			return found
	return null

func _find_first_boss_controller(n: Node) -> BossController:
	var bc: BossController = n as BossController
	if bc != null:
		return bc
	for c: Node in n.get_children():
		var found: BossController = _find_first_boss_controller(c)
		if found != null:
			return found
	return null

# -----------------------------
# Player -> NEW HUD cluster
# -----------------------------
func _on_player_health_changed(current: int, max_value: int) -> void:
	# Feed the cluster (it forwards to PlayerHealthHUD)
	_player_hud.set_health(float(current), float(max_value))

	# Optional: if you want numeric text by default:
	# PlayerHealthHUD.TextMode.NUMERIC == 2 (based on enum order)
	# You can set once elsewhere; leaving this off keeps it simple.

# -----------------------------
# Boss -> legacy widgets (unchanged)
# -----------------------------
func _on_boss_health_changed(current: int, max_value: int) -> void:
	_boss_bar.max_value = float(max_value)
	_boss_bar.value = float(current)

	var pct: float = 0.0
	if max_value > 0:
		pct = (float(current) / float(max_value)) * 100.0
	_boss_pct.text = "%d%%" % int(round(pct))
