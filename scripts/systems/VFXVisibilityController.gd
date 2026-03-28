extends Node
class_name VFXVisibilityController

signal vfx_enabled_changed(enabled: bool)

@export var vfx_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree: SceneTree = get_tree()
	if tree != null:
		if not tree.node_added.is_connected(_on_tree_node_added):
			tree.node_added.connect(_on_tree_node_added)
		call_deferred("_apply_to_tree")

func set_vfx_enabled(enabled: bool) -> void:
	if vfx_enabled == enabled:
		return
	vfx_enabled = enabled
	_apply_to_tree()
	vfx_enabled_changed.emit(vfx_enabled)

func toggle_vfx() -> void:
	set_vfx_enabled(not vfx_enabled)

func _on_tree_node_added(node: Node) -> void:
	# Defer so nodes finish their own _ready first.
	call_deferred("_apply_to_node_if_vfx", node)

func _apply_to_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Node = tree.root
	if root == null:
		return
	_apply_recursively(root)

func _apply_recursively(node: Node) -> void:
	_apply_to_node_if_vfx(node)
	for child: Node in node.get_children():
		_apply_recursively(child)

func _apply_to_node_if_vfx(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not _is_vfx_node(node):
		return
	_set_vfx_node_enabled(node, vfx_enabled)

func _is_vfx_node(node: Node) -> bool:
	if node == self:
		return false
	if node is GPUParticles2D or node is CPUParticles2D:
		return true
	var node_name: String = String(node.name)
	if node_name.find("VFX") >= 0 or node_name.find("vfx") >= 0:
		return true
	var script_res: Script = node.get_script() as Script
	if script_res != null:
		var script_path: String = String(script_res.resource_path)
		if script_path.find("/scripts/vfx/") >= 0:
			return true
	return false

func _set_vfx_node_enabled(node: Node, enabled: bool) -> void:
	if node is GPUParticles2D:
		var gpu: GPUParticles2D = node as GPUParticles2D
		if not enabled:
			gpu.emitting = false
	if node is CPUParticles2D:
		var cpu: CPUParticles2D = node as CPUParticles2D
		if not enabled:
			cpu.emitting = false
	if node is CanvasItem:
		(node as CanvasItem).visible = enabled
