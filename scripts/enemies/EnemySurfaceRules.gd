extends RefCounted
class_name EnemySurfaceRules

enum SurfaceKind {
	UNKNOWN,
	WALKABLE_FLOOR,
	DROPTHROUGH_PLATFORM,
	FORBIDDEN
}

static func matches_surface_name_tokens(name_value: String, tokens: PackedStringArray) -> bool:
	var name_lower: String = name_value.to_lower()
	for token: String in tokens:
		if token.is_empty():
			continue
		if name_lower.contains(token.to_lower()):
			return true
	return false

static func surface_kind_for_collider(
	collider_obj: Variant,
	forbidden_drop_surface_name_tokens: PackedStringArray,
	no_drop_surface_name_tokens: PackedStringArray,
	never_dropthrough_surface_name_tokens: PackedStringArray,
	drop_surface_name_tokens: PackedStringArray
) -> SurfaceKind:
	if not (collider_obj is Node):
		return SurfaceKind.UNKNOWN

	var node_name: String = String((collider_obj as Node).name)
	if matches_surface_name_tokens(node_name, forbidden_drop_surface_name_tokens):
		return SurfaceKind.FORBIDDEN
	if matches_surface_name_tokens(node_name, no_drop_surface_name_tokens):
		return SurfaceKind.WALKABLE_FLOOR
	if matches_surface_name_tokens(node_name, never_dropthrough_surface_name_tokens):
		return SurfaceKind.WALKABLE_FLOOR
	if matches_surface_name_tokens(node_name, drop_surface_name_tokens):
		return SurfaceKind.DROPTHROUGH_PLATFORM
	return SurfaceKind.WALKABLE_FLOOR
