extends RefCounted

static func promote(node: Node, z: int = 200) -> void:
	if node == null:
		return
	_apply_recursive(node, z)

static func _apply_recursive(node: Node, z: int) -> void:
	if node is CanvasItem:
		var ci: CanvasItem = node as CanvasItem
		ci.z_as_relative = false
		ci.z_index = z
	for child: Node in node.get_children():
		_apply_recursive(child, z)
