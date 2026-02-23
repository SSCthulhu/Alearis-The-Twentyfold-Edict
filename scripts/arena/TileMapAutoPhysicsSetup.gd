@tool
extends TileMapLayer

@export var auto_setup_in_editor: bool = true
@export var auto_setup_in_game: bool = false
@export var one_shot: bool = true
@export var create_tileset_if_missing: bool = true
@export var source_texture: Texture2D
@export var source_region_size: Vector2i = Vector2i(444, 511)
@export var physics_layer_index: int = 0
@export var force_rect_collision: bool = false

var _setup_done: bool = false
var _last_run_setup_now: bool = false

@export var run_setup_now: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(true)


func _ready() -> void:
	if _setup_done:
		return
	if Engine.is_editor_hint() and not auto_setup_in_editor:
		return
	if not Engine.is_editor_hint() and not auto_setup_in_game:
		return
	_setup_done = true
	_setup_tilemap_physics()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	# Editor-safe one-shot trigger from Inspector toggle.
	if run_setup_now and not _last_run_setup_now:
		_setup_tilemap_physics()
		run_setup_now = false

	_last_run_setup_now = run_setup_now


func _setup_tilemap_physics() -> void:
	if tile_set == null:
		if not _try_create_tileset():
			return

	if tile_set == null:
		return

	var ts: TileSet = tile_set
	if ts.get_source_count() == 0:
		if not _try_add_source_to_tileset(ts):
			return

	# Ensure the requested physics layer exists.
	while ts.get_physics_layers_count() <= physics_layer_index:
		ts.add_physics_layer()

	if ts.has_method("set_physics_layer_collision_layer"):
		ts.call("set_physics_layer_collision_layer", physics_layer_index, 1)
	if ts.has_method("set_physics_layer_collision_mask"):
		ts.call("set_physics_layer_collision_mask", physics_layer_index, 1)

	for source_pos in ts.get_source_count():
		var source_id: int = ts.get_source_id(source_pos)
		var source: TileSetSource = ts.get_source(source_id)
		if source == null or not (source is TileSetAtlasSource):
			continue

		_setup_atlas_source(source as TileSetAtlasSource)

	if has_method("notify_runtime_tile_data_update"):
		call("notify_runtime_tile_data_update")
	if has_method("update_internals"):
		call("update_internals")

	if one_shot:
		auto_setup_in_editor = false
		auto_setup_in_game = false
		_setup_done = true


func _try_create_tileset() -> bool:
	if not create_tileset_if_missing:
		return false
	if source_texture == null:
		return false

	var region: Vector2i = source_region_size
	if region.x <= 0 or region.y <= 0:
		region = Vector2i(64, 64)

	var ts := TileSet.new()
	ts.tile_size = region

	if not _try_add_source_to_tileset(ts):
		return false
	tile_set = ts
	return true


func _try_add_source_to_tileset(ts: TileSet) -> bool:
	if ts == null or source_texture == null:
		return false

	var region: Vector2i = source_region_size
	if region.x <= 0 or region.y <= 0:
		region = Vector2i(64, 64)

	if ts.tile_size.x <= 0 or ts.tile_size.y <= 0:
		ts.tile_size = region

	var atlas := TileSetAtlasSource.new()
	atlas.texture = source_texture
	atlas.texture_region_size = region

	var tex_size: Vector2i = source_texture.get_size()
	var cols: int = maxi(1, int(float(tex_size.x) / float(region.x)))
	var rows: int = maxi(1, int(float(tex_size.y) / float(region.y)))
	for y in rows:
		for x in cols:
			var coord := Vector2i(x, y)
			if not atlas.has_tile(coord):
				atlas.create_tile(coord)

	ts.add_source(atlas, 0)
	return true


func _setup_atlas_source(source: TileSetAtlasSource) -> void:
	for tile_idx in source.get_tiles_count():
		var tile_coords: Vector2i = source.get_tile_id(tile_idx)
		_setup_tile_alternative(source, tile_coords, 0)

		if source.has_method("get_alternative_tiles_count") and source.has_method("get_alternative_tile_id"):
			var alt_count: int = source.call("get_alternative_tiles_count", tile_coords)
			for alt_idx in alt_count:
				var alt_id: int = source.call("get_alternative_tile_id", tile_coords, alt_idx)
				if alt_id == 0:
					continue
				_setup_tile_alternative(source, tile_coords, alt_id)


func _setup_tile_alternative(source: TileSetAtlasSource, tile_coords: Vector2i, alternative_id: int) -> void:
	var tile_data: TileData = source.get_tile_data(tile_coords, alternative_id)
	if tile_data == null:
		return

	var poly_count: int = tile_data.get_collision_polygons_count(physics_layer_index)
	if poly_count > 0 and not force_rect_collision:
		return

	if poly_count <= 0:
		tile_data.add_collision_polygon(physics_layer_index)

	var rect: Rect2i = source.get_tile_texture_region(tile_coords)
	var width: float = float(rect.size.x)
	var height: float = float(rect.size.y)
	if width <= 0.0 or height <= 0.0:
		var fallback: Vector2i = tile_set.tile_size
		width = float(maxi(1, fallback.x))
		height = float(maxi(1, fallback.y))

	var points := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(width, 0.0),
		Vector2(width, height),
		Vector2(0.0, height),
	])
	tile_data.set_collision_polygon_points(physics_layer_index, 0, points)
