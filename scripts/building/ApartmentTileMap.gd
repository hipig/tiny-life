class_name ApartmentTileMap
extends Node2D

const TILE_SIZE := 16
const DEFAULT_FRAME_TILES := Vector2i(8, 4)
const MIN_FRAME_WIDTH_TILES := 3

@export_group("Tile Sources")
@export var wallpaper_source_id := 2
@export var wall_body_source_id := 0
@export var wall_edge_source_id := 0
@export var door_source_id := 0
@export var construction_source_id := 0

@export_group("Wallpaper")
@export var wallpaper_tile := Vector2i(0, 28)
@export var wallpaper_tiles: Array[Vector2i] = []

@export_group("Themed Wall Body")
@export var body_top_left_corner_tile := Vector2i(1, 17)
@export var body_top_edge_tiles: Array[Vector2i] = [Vector2i(3, 17)]
@export var body_top_right_corner_tile := Vector2i(5, 17)
@export var body_left_edge_tiles: Array[Vector2i] = [Vector2i(1, 18), Vector2i(2, 18)]
@export var body_right_edge_tiles: Array[Vector2i] = [Vector2i(5, 18)]
@export var body_bottom_left_corner_tile := Vector2i(2, 19)
@export var body_bottom_edge_tiles: Array[Vector2i] = [Vector2i(2, 19)]
@export var body_bottom_right_corner_tile := Vector2i(5, 19)
@export var body_door_cutout_cells: Array[Vector2i] = []
@export var body_door_short_wall_cells: Array[Vector2i] = []
@export var body_door_short_wall_tiles: Array[Vector2i] = []

@export_group("Fixed Wall Edge")
@export var edge_top_left_corner_tile := Vector2i(0, 0)
@export var edge_top_edge_tiles: Array[Vector2i] = [Vector2i(1, 0)]
@export var edge_top_right_corner_tile := Vector2i(6, 0)
@export var edge_left_edge_tiles: Array[Vector2i] = [Vector2i(0, 3), Vector2i(0, 3), Vector2i(4, 1), Vector2i(4, 2)]
@export var edge_right_edge_tiles: Array[Vector2i] = [Vector2i(6, 1)]
@export var edge_bottom_left_corner_tile := Vector2i(0, 4)
@export var edge_bottom_edge_tiles: Array[Vector2i] = [Vector2i(5, 4)]
@export var edge_bottom_right_corner_tile := Vector2i(6, 4)
@export var edge_door_cutout_cells: Array[Vector2i] = []
@export var edge_door_short_wall_cells: Array[Vector2i] = []
@export var edge_door_short_wall_tiles: Array[Vector2i] = []

@export_group("Door Window And Roof Tiles")
@export var door_tile := Vector2i(7, 14)
@export var door_cell_from_left := 0
@export var door_cell_from_bottom := 0
@export var window_tile := Vector2i(5, 2)
@export var window_cell_from_right := 0
@export var window_cell_from_top := 1
@export var roof_left_tile := Vector2i.ZERO
@export var roof_tiles: Array[Vector2i] = []
@export var roof_right_tile := Vector2i.ZERO

@export_group("Construction Tiles")
@export var construction_marker_tile := Vector2i.ZERO
@export var construction_left_marker_cell := Vector2i(1, 3)
@export var construction_right_marker_from_bottom := Vector2i(2, 1)

@onready var wallpaper_layer: TileMapLayer = get_node_or_null("WallpaperTileMap") as TileMapLayer
@onready var wall_layer: TileMapLayer = get_node_or_null("WallTileMap") as TileMapLayer
@onready var infrastructure_layer: TileMapLayer = get_node_or_null("InfrastructureTileMap") as TileMapLayer
@onready var roof_layer: TileMapLayer = get_node_or_null("RoofTileMap") as TileMapLayer
@onready var construction_layer: TileMapLayer = get_node_or_null("ConstructionTileMap") as TileMapLayer

var current_frame_tiles := DEFAULT_FRAME_TILES
var current_roof_visible := false
var current_construction_visible := false
var current_theme := {}

var _template_captured := false
var _template_frame_origin := Vector2i.ZERO
var _template_frame_tiles := DEFAULT_FRAME_TILES
var _wallpaper_template: Array[Dictionary] = []
var _wall_template: Array[Dictionary] = []
var _infrastructure_template: Array[Dictionary] = []

func _ready() -> void:
	render_room_skeleton(DEFAULT_FRAME_TILES, {}, current_roof_visible, current_construction_visible)

func render_room_skeleton(frame_tiles := DEFAULT_FRAME_TILES, theme := {}, show_roof := false, show_construction := false) -> void:
	_bind_layers()
	_ensure_template_captured()
	current_frame_tiles = _validated_frame_tiles(frame_tiles)
	current_theme = theme.duplicate()
	current_roof_visible = show_roof
	current_construction_visible = show_construction
	_clear_layers()
	_paint_wallpaper()
	_paint_wall_body()
	_paint_wall_edge()
	# Editor-painted infrastructure templates own doors, windows, and black wall edges.
	if _infrastructure_template.is_empty():
		_paint_room_door()
		_paint_room_window()
	_paint_roof()
	_paint_construction()
	set_roof_visible(show_roof)
	set_construction_visible(show_construction)

func set_roof_visible(value: bool) -> void:
	current_roof_visible = value
	if roof_layer != null:
		roof_layer.visible = value

func set_construction_visible(value: bool) -> void:
	current_construction_visible = value
	if construction_layer != null:
		construction_layer.visible = value

func set_locked_visuals(locked: bool) -> void:
	var tint := Color(0.62, 0.62, 0.62, 0.58) if locked else Color.WHITE
	for layer in [wallpaper_layer, wall_layer, infrastructure_layer, roof_layer, construction_layer]:
		if layer != null:
			layer.modulate = tint

func room_pixel_size() -> Vector2:
	return Vector2(current_frame_tiles.x * TILE_SIZE, current_frame_tiles.y * TILE_SIZE)

func _bind_layers() -> void:
	if wallpaper_layer == null:
		wallpaper_layer = get_node_or_null("WallpaperTileMap") as TileMapLayer
	if wall_layer == null:
		wall_layer = get_node_or_null("WallTileMap") as TileMapLayer
	if infrastructure_layer == null:
		infrastructure_layer = get_node_or_null("InfrastructureTileMap") as TileMapLayer
	if roof_layer == null:
		roof_layer = get_node_or_null("RoofTileMap") as TileMapLayer
	if construction_layer == null:
		construction_layer = get_node_or_null("ConstructionTileMap") as TileMapLayer

func _ensure_template_captured() -> void:
	if _template_captured:
		return
	_template_captured = true
	if wallpaper_layer != null and not wallpaper_layer.get_used_cells().is_empty():
		var wallpaper_rect := wallpaper_layer.get_used_rect()
		_template_frame_origin = wallpaper_rect.position
		_template_frame_tiles = wallpaper_rect.size
		_wallpaper_template = _capture_layer_template(wallpaper_layer, _template_frame_origin)
	else:
		_template_frame_origin = Vector2i.ZERO
		_template_frame_tiles = DEFAULT_FRAME_TILES
	if wall_layer != null and not wall_layer.get_used_cells().is_empty():
		_wall_template = _capture_layer_template(wall_layer, _template_frame_origin)
	if infrastructure_layer != null and not infrastructure_layer.get_used_cells().is_empty():
		_infrastructure_template = _capture_layer_template(infrastructure_layer, _template_frame_origin)

func _capture_layer_template(layer: TileMapLayer, origin: Vector2i) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for cell in layer.get_used_cells():
		cells.append({
			"cell": cell - origin,
			"source_id": layer.get_cell_source_id(cell),
			"atlas": layer.get_cell_atlas_coords(cell),
			"alternative": layer.get_cell_alternative_tile(cell)
		})
	cells.sort_custom(_sort_template_cells)
	return cells

func _sort_template_cells(a: Dictionary, b: Dictionary) -> bool:
	var a_cell: Vector2i = a["cell"]
	var b_cell: Vector2i = b["cell"]
	if a_cell.y == b_cell.y:
		return a_cell.x < b_cell.x
	return a_cell.y < b_cell.y

func _clear_layers() -> void:
	for layer in [wallpaper_layer, wall_layer, infrastructure_layer, roof_layer, construction_layer]:
		if layer != null:
			layer.clear()

func _paint_wallpaper() -> void:
	if wallpaper_layer == null:
		return
	var fallback_tiles := _theme_vector2i_array("wallpaper_tiles", wallpaper_tiles)
	for y in range(current_frame_tiles.y):
		for x in range(current_frame_tiles.x):
			var template_cell := _template_pattern_cell(_wallpaper_template, Vector2i(x, y), Vector2i.ZERO, _template_frame_tiles)
			if template_cell.is_empty():
				var index := y * current_frame_tiles.x + x
				var atlas := _cycled_tile(fallback_tiles, index, _theme_vector2i("wallpaper_tile", wallpaper_tile))
				wallpaper_layer.set_cell(Vector2i(x, y), wallpaper_source_id, atlas)
			else:
				_set_cell_from_template(wallpaper_layer, Vector2i(x, y), template_cell)

func _paint_wall_body() -> void:
	if wall_layer == null:
		return
	var max_x := current_frame_tiles.x - 1
	var max_y := current_frame_tiles.y - 1
	for y in range(current_frame_tiles.y):
		for x in range(current_frame_tiles.x):
			if x > 0 and x < max_x and y > 0 and y < max_y:
				continue
			var target := Vector2i(x, y)
			var template_cell := _template_body_border_cell(_wall_template, target)
			if template_cell.is_empty():
				wall_layer.set_cell(target, wall_body_source_id, _body_tile_at(x, y, max_x, max_y))
			else:
				_set_cell_from_template(wall_layer, target, template_cell)
	var door_cell := _door_cell()
	_clear_relative_cells(wall_layer, door_cell, _theme_vector2i_array("body_door_cutout_cells", body_door_cutout_cells))
	_paint_relative_tiles(
		wall_layer,
		door_cell,
		_theme_vector2i_array("body_door_short_wall_cells", body_door_short_wall_cells),
		_theme_vector2i_array("body_door_short_wall_tiles", body_door_short_wall_tiles),
		wall_body_source_id
	)

func _paint_wall_edge() -> void:
	if infrastructure_layer == null:
		return
	if not _infrastructure_template.is_empty():
		_paint_infrastructure_template()
		return
	_paint_exported_wall_edge()

func _paint_infrastructure_template() -> void:
	var template_width := maxi(1, _template_frame_tiles.x)
	var template_height := maxi(1, _template_frame_tiles.y)
	var top_edges: Array[Dictionary] = []
	var bottom_edges: Array[Dictionary] = []
	var left_edges: Array[Dictionary] = []
	var right_edges: Array[Dictionary] = []

	for data in _infrastructure_template:
		var cell: Vector2i = data["cell"]
		if cell.x < 0 and cell.y < 0:
			_set_cell_from_template(infrastructure_layer, cell, data)
		elif cell.x >= template_width and cell.y < 0:
			_set_cell_from_template(infrastructure_layer, Vector2i(current_frame_tiles.x + cell.x - template_width, cell.y), data)
		elif cell.x < 0 and cell.y >= template_height:
			_set_cell_from_template(infrastructure_layer, Vector2i(cell.x, current_frame_tiles.y + cell.y - template_height), data)
		elif cell.x >= template_width and cell.y >= template_height:
			_set_cell_from_template(infrastructure_layer, Vector2i(current_frame_tiles.x + cell.x - template_width, current_frame_tiles.y + cell.y - template_height), data)
		elif cell.x >= 0 and cell.x < template_width and cell.y >= 0 and cell.y < template_height:
			var target_x := current_frame_tiles.x - 1 if cell.x == template_width - 1 else cell.x
			var target_y := current_frame_tiles.y - 1 if cell.y == template_height - 1 else cell.y
			if _cell_is_inside_room(Vector2i(target_x, target_y)):
				_set_cell_from_template(infrastructure_layer, Vector2i(target_x, target_y), data)
		elif cell.y < 0 and cell.x >= 0 and cell.x < template_width:
			top_edges.append(data)
		elif cell.y >= template_height and cell.x >= 0 and cell.x < template_width:
			bottom_edges.append(data)
		elif cell.x < 0 and cell.y >= 0 and cell.y < template_height:
			left_edges.append(data)
		elif cell.x >= template_width and cell.y >= 0 and cell.y < template_height:
			right_edges.append(data)

	top_edges.sort_custom(_sort_template_cells)
	bottom_edges.sort_custom(_sort_template_cells)
	left_edges.sort_custom(_sort_template_cells)
	right_edges.sort_custom(_sort_template_cells)
	_paint_repeated_template_row(top_edges, -1)
	_paint_repeated_template_row(bottom_edges, current_frame_tiles.y)
	_paint_repeated_template_column(left_edges, -1)
	_paint_repeated_template_column(right_edges, current_frame_tiles.x)

func _paint_repeated_template_row(cells: Array[Dictionary], target_y: int) -> void:
	if cells.is_empty():
		return
	for x in range(current_frame_tiles.x):
		_set_cell_from_template(infrastructure_layer, Vector2i(x, target_y), cells[posmod(x, cells.size())])

func _paint_repeated_template_column(cells: Array[Dictionary], target_x: int) -> void:
	if cells.is_empty():
		return
	for y in range(current_frame_tiles.y):
		_set_cell_from_template(infrastructure_layer, Vector2i(target_x, y), cells[posmod(y, cells.size())])

func _paint_exported_wall_edge() -> void:
	var max_x := current_frame_tiles.x - 1
	var max_y := current_frame_tiles.y - 1
	for x in range(current_frame_tiles.x):
		infrastructure_layer.set_cell(Vector2i(x, -1), wall_edge_source_id, _edge_tile_at(x, -1, max_x, max_y))
		infrastructure_layer.set_cell(Vector2i(x, current_frame_tiles.y), wall_edge_source_id, _edge_tile_at(x, current_frame_tiles.y, max_x, max_y))
	for y in range(current_frame_tiles.y):
		infrastructure_layer.set_cell(Vector2i(-1, y), wall_edge_source_id, _edge_tile_at(-1, y, max_x, max_y))
		infrastructure_layer.set_cell(Vector2i(current_frame_tiles.x, y), wall_edge_source_id, _edge_tile_at(current_frame_tiles.x, y, max_x, max_y))
	infrastructure_layer.set_cell(Vector2i(-1, -1), wall_edge_source_id, _theme_vector2i("edge_top_left_corner_tile", edge_top_left_corner_tile))
	infrastructure_layer.set_cell(Vector2i(current_frame_tiles.x, -1), wall_edge_source_id, _theme_vector2i("edge_top_right_corner_tile", edge_top_right_corner_tile))
	infrastructure_layer.set_cell(Vector2i(-1, current_frame_tiles.y), wall_edge_source_id, _theme_vector2i("edge_bottom_left_corner_tile", edge_bottom_left_corner_tile))
	infrastructure_layer.set_cell(Vector2i(current_frame_tiles.x, current_frame_tiles.y), wall_edge_source_id, _theme_vector2i("edge_bottom_right_corner_tile", edge_bottom_right_corner_tile))
	var door_cell := _door_cell()
	_clear_relative_cells(infrastructure_layer, door_cell, _theme_vector2i_array("edge_door_cutout_cells", edge_door_cutout_cells))
	_paint_relative_tiles(
		infrastructure_layer,
		door_cell,
		_theme_vector2i_array("edge_door_short_wall_cells", edge_door_short_wall_cells),
		_theme_vector2i_array("edge_door_short_wall_tiles", edge_door_short_wall_tiles),
		wall_edge_source_id
	)

func _paint_room_door() -> void:
	if infrastructure_layer == null or current_frame_tiles.y < 2:
		return
	infrastructure_layer.set_cell(_door_cell(), door_source_id, _theme_vector2i("door_tile", door_tile))

func _paint_room_window() -> void:
	if infrastructure_layer == null:
		return
	var cell := Vector2i(
		clampi(current_frame_tiles.x - 1 - window_cell_from_right, 0, current_frame_tiles.x - 1),
		clampi(window_cell_from_top, 0, current_frame_tiles.y - 1)
	)
	infrastructure_layer.set_cell(cell, wall_edge_source_id, _theme_vector2i("window_tile", window_tile))

func _paint_roof() -> void:
	if roof_layer == null:
		return
	var tiles := _theme_vector2i_array("roof_tiles", roof_tiles)
	for x in range(current_frame_tiles.x):
		var atlas := _cycled_tile(tiles, x - 1, roof_left_tile)
		if x == 0:
			atlas = _theme_vector2i("roof_left_tile", roof_left_tile)
		elif x == current_frame_tiles.x - 1:
			atlas = _theme_vector2i("roof_right_tile", roof_right_tile)
		roof_layer.set_cell(Vector2i(x, -1), wall_edge_source_id, atlas)

func _paint_construction() -> void:
	if construction_layer == null:
		return
	var marker_tile := _theme_vector2i("construction_marker_tile", construction_marker_tile)
	var left_cell := Vector2i(
		clampi(construction_left_marker_cell.x, 0, current_frame_tiles.x - 1),
		clampi(construction_left_marker_cell.y, 0, current_frame_tiles.y - 1)
	)
	var right_cell := Vector2i(
		clampi(current_frame_tiles.x - construction_right_marker_from_bottom.x, 0, current_frame_tiles.x - 1),
		clampi(current_frame_tiles.y - construction_right_marker_from_bottom.y, 0, current_frame_tiles.y - 1)
	)
	construction_layer.set_cell(left_cell, construction_source_id, marker_tile)
	construction_layer.set_cell(right_cell, construction_source_id, marker_tile)

func _body_tile_at(x: int, y: int, max_x: int, max_y: int) -> Vector2i:
	return _border_tile_at(
		x,
		y,
		max_x,
		max_y,
		_theme_vector2i("body_top_left_corner_tile", body_top_left_corner_tile),
		_theme_vector2i_array("body_top_edge_tiles", body_top_edge_tiles),
		_theme_vector2i("body_top_right_corner_tile", body_top_right_corner_tile),
		_theme_vector2i_array("body_left_edge_tiles", body_left_edge_tiles),
		_theme_vector2i_array("body_right_edge_tiles", body_right_edge_tiles),
		_theme_vector2i("body_bottom_left_corner_tile", body_bottom_left_corner_tile),
		_theme_vector2i_array("body_bottom_edge_tiles", body_bottom_edge_tiles),
		_theme_vector2i("body_bottom_right_corner_tile", body_bottom_right_corner_tile)
	)

func _edge_tile_at(x: int, y: int, max_x: int, max_y: int) -> Vector2i:
	if y < 0:
		return _cycled_tile(_theme_vector2i_array("edge_top_edge_tiles", edge_top_edge_tiles), x, _theme_vector2i("edge_top_edge_tile", edge_top_left_corner_tile))
	if y > max_y:
		return _cycled_tile(_theme_vector2i_array("edge_bottom_edge_tiles", edge_bottom_edge_tiles), x, _theme_vector2i("edge_bottom_edge_tile", edge_bottom_left_corner_tile))
	if x < 0:
		return _cycled_tile(_theme_vector2i_array("edge_left_edge_tiles", edge_left_edge_tiles), y, _theme_vector2i("edge_left_edge_tile", edge_top_left_corner_tile))
	if x > max_x:
		return _cycled_tile(_theme_vector2i_array("edge_right_edge_tiles", edge_right_edge_tiles), y, _theme_vector2i("edge_right_edge_tile", edge_top_right_corner_tile))
	return _theme_vector2i("edge_top_left_corner_tile", edge_top_left_corner_tile)

func _border_tile_at(
	x: int,
	y: int,
	max_x: int,
	max_y: int,
	top_left_corner: Vector2i,
	top_edges: Array[Vector2i],
	top_right_corner: Vector2i,
	left_edges: Array[Vector2i],
	right_edges: Array[Vector2i],
	bottom_left_corner: Vector2i,
	bottom_edges: Array[Vector2i],
	bottom_right_corner: Vector2i
) -> Vector2i:
	if y == 0:
		if x == 0:
			return top_left_corner
		if x == max_x:
			return top_right_corner
		return _cycled_tile(top_edges, x - 1, top_left_corner)
	if y == max_y:
		if x == 0:
			return bottom_left_corner
		if x == max_x:
			return bottom_right_corner
		return _cycled_tile(bottom_edges, x - 1, bottom_left_corner)
	if x == 0:
		return _cycled_tile(left_edges, y - 1, top_left_corner)
	if x == max_x:
		return _cycled_tile(right_edges, y - 1, top_right_corner)
	return top_left_corner

func _template_body_border_cell(cells: Array[Dictionary], target: Vector2i) -> Dictionary:
	if cells.is_empty():
		return {}
	var template_max_x := maxi(0, _template_frame_tiles.x - 1)
	var template_max_y := maxi(0, _template_frame_tiles.y - 1)
	var max_x := current_frame_tiles.x - 1
	var max_y := current_frame_tiles.y - 1
	var source := Vector2i.ZERO
	if target.y == 0:
		if target.x == 0:
			source = Vector2i(0, 0)
		elif target.x == max_x:
			source = Vector2i(template_max_x, 0)
		else:
			source = Vector2i(1 + posmod(target.x - 1, maxi(1, template_max_x - 1)), 0)
	elif target.y == max_y:
		if target.x == 0:
			source = Vector2i(0, template_max_y)
		elif target.x == max_x:
			source = Vector2i(template_max_x, template_max_y)
		else:
			source = Vector2i(1 + posmod(target.x - 1, maxi(1, template_max_x - 1)), template_max_y)
	elif target.x == 0:
		source = Vector2i(0, 1 + posmod(target.y - 1, maxi(1, template_max_y - 1)))
	elif target.x == max_x:
		source = Vector2i(template_max_x, 1 + posmod(target.y - 1, maxi(1, template_max_y - 1)))
	return _template_cell_at(cells, source)

func _template_pattern_cell(cells: Array[Dictionary], target: Vector2i, origin: Vector2i, size: Vector2i) -> Dictionary:
	if cells.is_empty():
		return {}
	var pattern_size := Vector2i(maxi(1, size.x), maxi(1, size.y))
	var source := Vector2i(
		origin.x + posmod(target.x - origin.x, pattern_size.x),
		origin.y + posmod(target.y - origin.y, pattern_size.y)
	)
	var data := _template_cell_at(cells, source)
	if data.is_empty():
		return cells[0]
	return data

func _template_cell_at(cells: Array[Dictionary], cell: Vector2i) -> Dictionary:
	for data in cells:
		if data.get("cell", Vector2i.ZERO) == cell:
			return data
	return {}

func _set_cell_from_template(layer: TileMapLayer, cell: Vector2i, data: Dictionary) -> void:
	layer.set_cell(
		cell,
		int(data.get("source_id", -1)),
		data.get("atlas", Vector2i.ZERO),
		int(data.get("alternative", 0))
	)

func _door_cell() -> Vector2i:
	return Vector2i(
		clampi(door_cell_from_left, 0, current_frame_tiles.x - 1),
		clampi(current_frame_tiles.y - 1 - door_cell_from_bottom, 0, current_frame_tiles.y - 1)
	)

func _clear_relative_cells(layer: TileMapLayer, origin: Vector2i, cells: Array[Vector2i]) -> void:
	for cell in cells:
		var target := origin + cell
		if _cell_is_inside_room(target):
			layer.erase_cell(target)

func _paint_relative_tiles(layer: TileMapLayer, origin: Vector2i, cells: Array[Vector2i], tiles: Array[Vector2i], source_id: int) -> void:
	if cells.is_empty() or tiles.is_empty():
		return
	for index in range(cells.size()):
		var target := origin + cells[index]
		if _cell_is_inside_room(target):
			layer.set_cell(target, source_id, _cycled_tile(tiles, index, tiles[0]))

func _cell_is_inside_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < current_frame_tiles.x and cell.y >= 0 and cell.y < current_frame_tiles.y

func _cycled_tile(tiles: Array[Vector2i], index: int, fallback: Vector2i) -> Vector2i:
	if tiles.is_empty():
		return fallback
	return tiles[posmod(index, tiles.size())]

func _theme_vector2i(key: String, fallback: Vector2i) -> Vector2i:
	var value: Variant = current_theme.get(key, fallback)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

func _theme_vector2i_array(key: String, fallback: Array[Vector2i]) -> Array[Vector2i]:
	var value: Variant = current_theme.get(key, fallback)
	var result: Array[Vector2i] = []
	if value is Array:
		for item in value:
			if item is Vector2i:
				result.append(item)
			elif item is Vector2:
				result.append(Vector2i(int(item.x), int(item.y)))
			elif item is Array and item.size() >= 2:
				result.append(Vector2i(int(item[0]), int(item[1])))
	if result.is_empty():
		return fallback
	return result

func _validated_frame_tiles(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(MIN_FRAME_WIDTH_TILES, value.x), DEFAULT_FRAME_TILES.y)
