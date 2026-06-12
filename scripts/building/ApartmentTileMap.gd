@tool
class_name ApartmentTileMap
extends Node2D

const TILE_SIZE := 16
const DEFAULT_FRAME_TILES := Vector2i(6, 4)
const MIN_FRAME_WIDTH_TILES := 3
const EDGE_TOP := "top"
const EDGE_BOTTOM := "bottom"
const EDGE_LEFT := "left"
const EDGE_RIGHT := "right"

@export_group("Tile Sources")
@export var wallpaper_source_id := 2
@export var wall_body_source_id := 0
@export var wall_edge_source_id := 0
@export var construction_source_id := 0

@export_group("Wallpaper")
@export var wallpaper_tile := Vector2i(0, 28)
@export var wallpaper_tiles: Array[Vector2i] = []

@export_group("Themed Wall Body")
@export var body_top_left_corner_tile := Vector2i(1, 17)
@export var body_top_edge_tiles: Array[Vector2i] = [Vector2i(3, 17)]
@export var body_top_right_corner_tile := Vector2i(5, 17)
@export var body_left_edge_tiles: Array[Vector2i] = [Vector2i(1, 18)]
@export var body_left_door_edge_tiles: Array[Vector2i] = [Vector2i(2, 18)]
@export var body_right_door_edge_tiles: Array[Vector2i] = [Vector2i(4, 18)]
@export var body_right_edge_tiles: Array[Vector2i] = [Vector2i(5, 18)]
@export var body_bottom_left_corner_tile := Vector2i(1, 19)
@export var body_bottom_edge_tiles: Array[Vector2i] = [Vector2i(2, 19)]
@export var body_bottom_right_corner_tile := Vector2i(5, 19)
@export var body_door_cutout_cells: Array[Vector2i] = []
@export var body_door_short_wall_cells: Array[Vector2i] = []
@export var body_door_short_wall_tiles: Array[Vector2i] = []

@export_group("Fixed Wall Edge")
@export var edge_top_left_corner_tile := Vector2i(0, 0)
@export var edge_top_edge_tiles: Array[Vector2i] = [Vector2i(1, 0)]
@export var edge_top_right_corner_tile := Vector2i(6, 0)
@export var edge_left_edge_tiles: Array[Vector2i] = [Vector2i(0, 3)]
@export var edge_left_door_edge_tiles: Array[Vector2i] = [Vector2i(4, 1)]
@export var edge_right_edge_tiles: Array[Vector2i] = [Vector2i(6, 1)]
@export var edge_bottom_left_corner_tile := Vector2i(0, 4)
@export var edge_bottom_edge_tiles: Array[Vector2i] = [Vector2i(5, 4)]
@export var edge_bottom_right_corner_tile := Vector2i(6, 4)
@export var edge_door_cutout_cells: Array[Vector2i] = []
@export var edge_door_short_wall_cells: Array[Vector2i] = []
@export var edge_door_short_wall_tiles: Array[Vector2i] = []

@export_group("Door Window And Roof Tiles")
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

@onready var wallpaper_layer: TileMapLayer = $WallpaperTileMap
@onready var wall_layer: TileMapLayer = $WallTileMap
@onready var infrastructure_layer: TileMapLayer = $InfrastructureTileMap
@onready var roof_layer: TileMapLayer = $RoofTileMap
@onready var construction_layer: TileMapLayer = $ConstructionTileMap

var current_frame_tiles := DEFAULT_FRAME_TILES
var current_roof_visible := false
var current_construction_visible := false
var current_edge_sides := {}
var current_body_sides := {}
var current_has_left_door := true
var current_has_right_door := false
var current_door_side := EDGE_LEFT

var current_wallpaper_source_id := 2
var current_wallpaper_tile := Vector2i.ZERO
var current_wallpaper_tiles: Array[Vector2i] = []
var current_wallpaper_pattern := {}
var current_wall_body_source_id := 0
var current_wall_edge_source_id := 0
var current_construction_source_id := 0

var current_body_top_left_corner_tile := Vector2i.ZERO
var current_body_top_edge_tiles: Array[Vector2i] = []
var current_body_top_right_corner_tile := Vector2i.ZERO
var current_body_left_edge_tiles: Array[Vector2i] = []
var current_body_left_door_edge_tiles: Array[Vector2i] = []
var current_body_right_door_edge_tiles: Array[Vector2i] = []
var current_body_right_edge_tiles: Array[Vector2i] = []
var current_body_bottom_left_corner_tile := Vector2i.ZERO
var current_body_bottom_edge_tiles: Array[Vector2i] = []
var current_body_bottom_right_corner_tile := Vector2i.ZERO
var current_body_door_cutout_cells: Array[Vector2i] = []
var current_body_door_short_wall_cells: Array[Vector2i] = []
var current_body_door_short_wall_tiles: Array[Vector2i] = []

var current_edge_top_left_corner_tile := Vector2i.ZERO
var current_edge_top_edge_tiles: Array[Vector2i] = []
var current_edge_top_right_corner_tile := Vector2i.ZERO
var current_edge_left_edge_tiles: Array[Vector2i] = []
var current_edge_left_door_edge_tiles: Array[Vector2i] = []
var current_edge_right_edge_tiles: Array[Vector2i] = []
var current_edge_bottom_left_corner_tile := Vector2i.ZERO
var current_edge_bottom_edge_tiles: Array[Vector2i] = []
var current_edge_bottom_right_corner_tile := Vector2i.ZERO
var current_edge_door_cutout_cells: Array[Vector2i] = []
var current_edge_door_short_wall_cells: Array[Vector2i] = []
var current_edge_door_short_wall_tiles: Array[Vector2i] = []

var current_window_tile := Vector2i.ZERO
var current_roof_left_tile := Vector2i.ZERO
var current_roof_tiles: Array[Vector2i] = []
var current_roof_right_tile := Vector2i.ZERO
var current_construction_marker_tile := Vector2i.ZERO

func _ready() -> void:
	render_room_skeleton(DEFAULT_FRAME_TILES, {}, current_roof_visible, current_construction_visible)

func render_room_skeleton(frame_tiles := DEFAULT_FRAME_TILES, theme: Dictionary = {}, show_roof := false, show_construction := false, edge_sides: Dictionary = {}, body_sides: Dictionary = {}, door_config: Variant = EDGE_LEFT) -> void:
	current_frame_tiles = _validated_frame_tiles(frame_tiles)
	current_roof_visible = show_roof
	current_construction_visible = show_construction
	current_edge_sides = _normalized_sides(edge_sides, true)
	current_body_sides = _normalized_sides(body_sides, true)
	current_door_side = _normalized_door_side(door_config)
	current_has_left_door = current_door_side == EDGE_LEFT
	current_has_right_door = current_door_side == EDGE_RIGHT
	if show_roof:
		current_edge_sides[EDGE_TOP] = false
	_apply_theme(theme)
	_clear_layers()
	_paint_wallpaper()
	_paint_wall_body()
	_paint_wall_edge()
	_paint_room_window()
	_paint_roof()
	_paint_construction()
	set_roof_visible(show_roof)
	set_construction_visible(show_construction)

func set_roof_visible(value: bool) -> void:
	current_roof_visible = value
	roof_layer.visible = value

func set_construction_visible(value: bool) -> void:
	current_construction_visible = value
	construction_layer.visible = value

func set_locked_visuals(locked: bool) -> void:
	var tint := Color(0.62, 0.62, 0.62, 0.58) if locked else Color.WHITE
	for layer in [wallpaper_layer, wall_layer, infrastructure_layer, roof_layer, construction_layer]:
		layer.modulate = tint

func room_pixel_size() -> Vector2:
	return Vector2(current_frame_tiles.x * TILE_SIZE, current_frame_tiles.y * TILE_SIZE)

func _apply_theme(theme: Dictionary) -> void:
	current_wallpaper_source_id = int(theme.get("wallpaper_source_id", wallpaper_source_id))
	current_wallpaper_tile = _vector2i_from_value(theme.get("wallpaper_tile", wallpaper_tile), wallpaper_tile)
	current_wallpaper_tiles = _vector2i_array_from_value(theme.get("wallpaper_tiles", wallpaper_tiles), wallpaper_tiles)
	current_wallpaper_pattern = theme.get("wallpaper_pattern", {})
	current_wall_body_source_id = int(theme.get("wall_body_source_id", wall_body_source_id))
	current_wall_edge_source_id = int(theme.get("wall_edge_source_id", wall_edge_source_id))
	current_construction_source_id = int(theme.get("construction_source_id", construction_source_id))

	current_body_top_left_corner_tile = _vector2i_from_value(theme.get("body_top_left_corner_tile", body_top_left_corner_tile), body_top_left_corner_tile)
	current_body_top_edge_tiles = _vector2i_array_from_value(theme.get("body_top_edge_tiles", body_top_edge_tiles), body_top_edge_tiles)
	current_body_top_right_corner_tile = _vector2i_from_value(theme.get("body_top_right_corner_tile", body_top_right_corner_tile), body_top_right_corner_tile)
	current_body_left_edge_tiles = _vector2i_array_from_value(theme.get("body_left_edge_tiles", body_left_edge_tiles), body_left_edge_tiles)
	current_body_left_door_edge_tiles = _vector2i_array_from_value(theme.get("body_left_door_edge_tiles", body_left_door_edge_tiles), body_left_door_edge_tiles)
	current_body_right_door_edge_tiles = _vector2i_array_from_value(theme.get("body_right_door_edge_tiles", body_right_door_edge_tiles), body_right_door_edge_tiles)
	current_body_right_edge_tiles = _vector2i_array_from_value(theme.get("body_right_edge_tiles", body_right_edge_tiles), body_right_edge_tiles)
	current_body_bottom_left_corner_tile = _vector2i_from_value(theme.get("body_bottom_left_corner_tile", body_bottom_left_corner_tile), body_bottom_left_corner_tile)
	current_body_bottom_edge_tiles = _vector2i_array_from_value(theme.get("body_bottom_edge_tiles", body_bottom_edge_tiles), body_bottom_edge_tiles)
	current_body_bottom_right_corner_tile = _vector2i_from_value(theme.get("body_bottom_right_corner_tile", body_bottom_right_corner_tile), body_bottom_right_corner_tile)
	current_body_door_cutout_cells = _vector2i_array_from_value(theme.get("body_door_cutout_cells", body_door_cutout_cells), body_door_cutout_cells)
	current_body_door_short_wall_cells = _vector2i_array_from_value(theme.get("body_door_short_wall_cells", body_door_short_wall_cells), body_door_short_wall_cells)
	current_body_door_short_wall_tiles = _vector2i_array_from_value(theme.get("body_door_short_wall_tiles", body_door_short_wall_tiles), body_door_short_wall_tiles)

	current_edge_top_left_corner_tile = _vector2i_from_value(theme.get("edge_top_left_corner_tile", edge_top_left_corner_tile), edge_top_left_corner_tile)
	current_edge_top_edge_tiles = _vector2i_array_from_value(theme.get("edge_top_edge_tiles", edge_top_edge_tiles), edge_top_edge_tiles)
	current_edge_top_right_corner_tile = _vector2i_from_value(theme.get("edge_top_right_corner_tile", edge_top_right_corner_tile), edge_top_right_corner_tile)
	current_edge_left_edge_tiles = _vector2i_array_from_value(theme.get("edge_left_edge_tiles", edge_left_edge_tiles), edge_left_edge_tiles)
	current_edge_left_door_edge_tiles = _vector2i_array_from_value(theme.get("edge_left_door_edge_tiles", edge_left_door_edge_tiles), edge_left_door_edge_tiles)
	current_edge_right_edge_tiles = _vector2i_array_from_value(theme.get("edge_right_edge_tiles", edge_right_edge_tiles), edge_right_edge_tiles)
	current_edge_bottom_left_corner_tile = _vector2i_from_value(theme.get("edge_bottom_left_corner_tile", edge_bottom_left_corner_tile), edge_bottom_left_corner_tile)
	current_edge_bottom_edge_tiles = _vector2i_array_from_value(theme.get("edge_bottom_edge_tiles", edge_bottom_edge_tiles), edge_bottom_edge_tiles)
	current_edge_bottom_right_corner_tile = _vector2i_from_value(theme.get("edge_bottom_right_corner_tile", edge_bottom_right_corner_tile), edge_bottom_right_corner_tile)
	current_edge_door_cutout_cells = _vector2i_array_from_value(theme.get("edge_door_cutout_cells", edge_door_cutout_cells), edge_door_cutout_cells)
	current_edge_door_short_wall_cells = _vector2i_array_from_value(theme.get("edge_door_short_wall_cells", edge_door_short_wall_cells), edge_door_short_wall_cells)
	current_edge_door_short_wall_tiles = _vector2i_array_from_value(theme.get("edge_door_short_wall_tiles", edge_door_short_wall_tiles), edge_door_short_wall_tiles)

	current_window_tile = _vector2i_from_value(theme.get("window_tile", window_tile), window_tile)
	current_roof_left_tile = _vector2i_from_value(theme.get("roof_left_tile", roof_left_tile), roof_left_tile)
	current_roof_tiles = _vector2i_array_from_value(theme.get("roof_tiles", roof_tiles), roof_tiles)
	current_roof_right_tile = _vector2i_from_value(theme.get("roof_right_tile", roof_right_tile), roof_right_tile)
	current_construction_marker_tile = _vector2i_from_value(theme.get("construction_marker_tile", construction_marker_tile), construction_marker_tile)

func _clear_layers() -> void:
	for layer in [wallpaper_layer, wall_layer, infrastructure_layer, roof_layer, construction_layer]:
		layer.clear()

func _paint_wallpaper() -> void:
	var pattern: Dictionary = current_wallpaper_pattern if current_wallpaper_pattern is Dictionary else {}
	if not pattern.is_empty():
		var max_y := current_frame_tiles.y - 1
		for y in range(current_frame_tiles.y):
			var row_key := "middle"
			if y == 0:
				row_key = "top"
			elif y == max_y:
				row_key = "bottom"
			var row_tiles := _vector2i_array_from_value(pattern.get(row_key, current_wallpaper_tiles), current_wallpaper_tiles)
			for x in range(current_frame_tiles.x):
				wallpaper_layer.set_cell(Vector2i(x, y), current_wallpaper_source_id, _cycled_tile(row_tiles, x, current_wallpaper_tile))
		return
	for y in range(current_frame_tiles.y):
		for x in range(current_frame_tiles.x):
			var index := y * current_frame_tiles.x + x
			wallpaper_layer.set_cell(Vector2i(x, y), current_wallpaper_source_id, _cycled_tile(current_wallpaper_tiles, index, current_wallpaper_tile))

func _paint_wall_body() -> void:
	var max_x := current_frame_tiles.x - 1
	var max_y := current_frame_tiles.y - 1
	for y in range(current_frame_tiles.y):
		for x in range(current_frame_tiles.x):
			if x > 0 and x < max_x and y > 0 and y < max_y:
				continue
			if not _should_paint_body_cell(x, y, max_x, max_y):
				continue
			wall_layer.set_cell(Vector2i(x, y), current_wall_body_source_id, _body_tile_at(x, y, max_x, max_y))
	if not current_door_side.is_empty() and _body_side_enabled(current_door_side):
		var door_cell := _door_cell_for_side(current_door_side)
		_clear_relative_cells(wall_layer, door_cell, _door_relative_cells_for_side(current_body_door_cutout_cells, current_door_side))
		_paint_relative_tiles(
			wall_layer,
			door_cell,
			_door_relative_cells_for_side(current_body_door_short_wall_cells, current_door_side),
			current_body_door_short_wall_tiles,
			current_wall_body_source_id
		)

func _paint_wall_edge() -> void:
	var max_x := current_frame_tiles.x - 1
	var max_y := current_frame_tiles.y - 1
	if _edge_side_enabled(EDGE_TOP):
		for x in range(current_frame_tiles.x):
			infrastructure_layer.set_cell(Vector2i(x, -1), current_wall_edge_source_id, _edge_tile_at(x, -1, max_x, max_y))
	if _edge_side_enabled(EDGE_BOTTOM):
		for x in range(current_frame_tiles.x):
			infrastructure_layer.set_cell(Vector2i(x, current_frame_tiles.y), current_wall_edge_source_id, _edge_tile_at(x, current_frame_tiles.y, max_x, max_y))
	if _edge_side_enabled(EDGE_LEFT):
		for y in range(current_frame_tiles.y):
			infrastructure_layer.set_cell(Vector2i(-1, y), current_wall_edge_source_id, _edge_tile_at(-1, y, max_x, max_y))
	if _edge_side_enabled(EDGE_RIGHT):
		for y in range(current_frame_tiles.y):
			infrastructure_layer.set_cell(Vector2i(current_frame_tiles.x, y), current_wall_edge_source_id, _edge_tile_at(current_frame_tiles.x, y, max_x, max_y))
	if _edge_side_enabled(EDGE_LEFT) and _edge_side_enabled(EDGE_TOP):
		infrastructure_layer.set_cell(Vector2i(-1, -1), current_wall_edge_source_id, current_edge_top_left_corner_tile)
	if _edge_side_enabled(EDGE_RIGHT) and _edge_side_enabled(EDGE_TOP):
		infrastructure_layer.set_cell(Vector2i(current_frame_tiles.x, -1), current_wall_edge_source_id, current_edge_top_right_corner_tile)
	if _edge_side_enabled(EDGE_LEFT) and _edge_side_enabled(EDGE_BOTTOM):
		infrastructure_layer.set_cell(Vector2i(-1, current_frame_tiles.y), current_wall_edge_source_id, current_edge_bottom_left_corner_tile)
	if _edge_side_enabled(EDGE_RIGHT) and _edge_side_enabled(EDGE_BOTTOM):
		infrastructure_layer.set_cell(Vector2i(current_frame_tiles.x, current_frame_tiles.y), current_wall_edge_source_id, current_edge_bottom_right_corner_tile)
	if not current_door_side.is_empty():
		var door_cell := _door_cell_for_side(current_door_side)
		_clear_relative_cells(infrastructure_layer, door_cell, _door_relative_cells_for_side(current_edge_door_cutout_cells, current_door_side))
		_paint_relative_tiles(
			infrastructure_layer,
			door_cell,
			_door_relative_cells_for_side(current_edge_door_short_wall_cells, current_door_side),
			current_edge_door_short_wall_tiles,
			current_wall_edge_source_id
		)

func _paint_room_window() -> void:
	if not _body_side_enabled(EDGE_RIGHT) or current_has_right_door:
		return
	var cell := Vector2i(
		clampi(current_frame_tiles.x - 1 - window_cell_from_right, 0, current_frame_tiles.x - 1),
		clampi(window_cell_from_top, 0, current_frame_tiles.y - 1)
	)
	infrastructure_layer.set_cell(cell, current_wall_edge_source_id, current_window_tile)

func _paint_roof() -> void:
	for x in range(current_frame_tiles.x):
		var atlas := current_roof_left_tile
		if x == 0:
			atlas = current_roof_left_tile
		elif x == current_frame_tiles.x - 1:
			atlas = current_roof_right_tile
		else:
			atlas = _cycled_tile(current_roof_tiles, x - 1, current_roof_left_tile)
		roof_layer.set_cell(Vector2i(x, -1), current_wall_edge_source_id, atlas)

func _paint_construction() -> void:
	var left_cell := Vector2i(
		clampi(construction_left_marker_cell.x, 0, current_frame_tiles.x - 1),
		clampi(construction_left_marker_cell.y, 0, current_frame_tiles.y - 1)
	)
	var right_cell := Vector2i(
		clampi(current_frame_tiles.x - construction_right_marker_from_bottom.x, 0, current_frame_tiles.x - 1),
		clampi(current_frame_tiles.y - construction_right_marker_from_bottom.y, 0, current_frame_tiles.y - 1)
	)
	construction_layer.set_cell(left_cell, current_construction_source_id, current_construction_marker_tile)
	construction_layer.set_cell(right_cell, current_construction_source_id, current_construction_marker_tile)

func _body_tile_at(x: int, y: int, max_x: int, max_y: int) -> Vector2i:
	if y == 0:
		if x == 0:
			if _body_side_enabled(EDGE_TOP) and _body_side_enabled(EDGE_LEFT):
				return current_body_top_left_corner_tile
			if _body_side_enabled(EDGE_TOP):
				return _cycled_tile(current_body_top_edge_tiles, x, current_body_top_left_corner_tile)
			return _cycled_tile(current_body_left_edge_tiles, y, current_body_top_left_corner_tile)
		if x == max_x:
			if _body_side_enabled(EDGE_TOP) and _body_side_enabled(EDGE_RIGHT):
				return current_body_top_right_corner_tile
			if _body_side_enabled(EDGE_TOP):
				return _cycled_tile(current_body_top_edge_tiles, x - 1, current_body_top_left_corner_tile)
			return _cycled_tile(current_body_right_edge_tiles, y, current_body_top_right_corner_tile)
		return _cycled_tile(current_body_top_edge_tiles, x - 1, current_body_top_left_corner_tile)
	if y == max_y:
		if x == 0:
			if not current_has_left_door and _body_side_enabled(EDGE_BOTTOM) and _body_side_enabled(EDGE_LEFT):
				return current_body_bottom_left_corner_tile
			if _body_side_enabled(EDGE_BOTTOM):
				return _cycled_tile(current_body_bottom_edge_tiles, x, current_body_bottom_left_corner_tile)
			return _cycled_tile(current_body_left_edge_tiles, y - 1, current_body_top_left_corner_tile)
		if x == max_x:
			if current_has_right_door and _body_side_enabled(EDGE_BOTTOM):
				return _cycled_tile(current_body_bottom_edge_tiles, x - 1, current_body_bottom_left_corner_tile)
			if _body_side_enabled(EDGE_BOTTOM) and _body_side_enabled(EDGE_RIGHT):
				return current_body_bottom_right_corner_tile
			if _body_side_enabled(EDGE_BOTTOM):
				return _cycled_tile(current_body_bottom_edge_tiles, x - 1, current_body_bottom_left_corner_tile)
			return _cycled_tile(current_body_right_edge_tiles, y - 1, current_body_top_right_corner_tile)
		return _cycled_tile(current_body_bottom_edge_tiles, x - 1, current_body_bottom_left_corner_tile)
	if x == 0:
		if current_has_left_door and _body_side_enabled(EDGE_LEFT) and y == max_y - 1:
			return _cycled_tile(current_body_left_door_edge_tiles, 0, current_body_top_left_corner_tile)
		return _cycled_tile(current_body_left_edge_tiles, y - 1, current_body_top_left_corner_tile)
	if x == max_x:
		if current_has_right_door and _body_side_enabled(EDGE_RIGHT) and y == max_y - 1:
			return _cycled_tile(current_body_right_door_edge_tiles, 0, current_body_top_right_corner_tile)
		return _cycled_tile(current_body_right_edge_tiles, y - 1, current_body_top_right_corner_tile)
	return current_body_top_left_corner_tile

func _edge_tile_at(x: int, y: int, max_x: int, max_y: int) -> Vector2i:
	if y < 0:
		return _cycled_tile(current_edge_top_edge_tiles, x, current_edge_top_left_corner_tile)
	if y > max_y:
		return _cycled_tile(current_edge_bottom_edge_tiles, x, current_edge_bottom_left_corner_tile)
	if x < 0:
		if current_has_left_door and y == max_y - 1:
			return _cycled_tile(current_edge_left_door_edge_tiles, 0, current_edge_top_left_corner_tile)
		return _cycled_tile(current_edge_left_edge_tiles, y, current_edge_top_left_corner_tile)
	if x > max_x:
		if current_has_right_door and y == max_y - 1:
			return _cycled_tile(current_edge_left_door_edge_tiles, 0, current_edge_top_right_corner_tile)
		return _cycled_tile(current_edge_right_edge_tiles, y, current_edge_top_right_corner_tile)
	return current_edge_top_left_corner_tile

func _door_cell_for_side(side: String) -> Vector2i:
	var x := door_cell_from_left
	if side == EDGE_RIGHT:
		x = current_frame_tiles.x - 1 - door_cell_from_left
	return Vector2i(
		clampi(x, 0, current_frame_tiles.x - 1),
		clampi(current_frame_tiles.y - 1 - door_cell_from_bottom, 0, current_frame_tiles.y - 1)
	)

func _door_relative_cells_for_side(cells: Array[Vector2i], side: String) -> Array[Vector2i]:
	if side != EDGE_RIGHT:
		return cells
	var mirrored: Array[Vector2i] = []
	for cell in cells:
		mirrored.append(Vector2i(-cell.x, cell.y))
	return mirrored

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

func _should_paint_body_cell(x: int, y: int, max_x: int, max_y: int) -> bool:
	return (y == 0 and _body_side_enabled(EDGE_TOP)) \
		or (y == max_y and _body_side_enabled(EDGE_BOTTOM)) \
		or (x == 0 and _body_side_enabled(EDGE_LEFT)) \
		or (x == max_x and _body_side_enabled(EDGE_RIGHT))

func _edge_side_enabled(side: String) -> bool:
	return bool(current_edge_sides.get(side, true))

func _body_side_enabled(side: String) -> bool:
	return bool(current_body_sides.get(side, true))

func _normalized_sides(sides: Dictionary, default_value: bool) -> Dictionary:
	return {
		EDGE_TOP: bool(sides.get(EDGE_TOP, default_value)),
		EDGE_BOTTOM: bool(sides.get(EDGE_BOTTOM, default_value)),
		EDGE_LEFT: bool(sides.get(EDGE_LEFT, default_value)),
		EDGE_RIGHT: bool(sides.get(EDGE_RIGHT, default_value))
	}

func _normalized_door_side(value: Variant) -> String:
	if value is bool:
		return EDGE_LEFT if bool(value) else ""
	var side := str(value).strip_edges().to_lower()
	if side == EDGE_LEFT or side == EDGE_RIGHT:
		return side
	return ""

func _cycled_tile(tiles: Array[Vector2i], index: int, required_tile: Vector2i) -> Vector2i:
	if tiles.is_empty():
		return required_tile
	return tiles[posmod(index, tiles.size())]

func _vector2i_from_value(value: Variant, required_value: Vector2i) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	push_error("ApartmentTileMap expected Vector2i-compatible tile coordinate.")
	return required_value

func _vector2i_array_from_value(value: Variant, required_values: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if value is Array:
		for item in value:
			result.append(_vector2i_from_value(item, Vector2i.ZERO))
	if result.is_empty():
		return required_values.duplicate()
	return result

func _validated_frame_tiles(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(MIN_FRAME_WIDTH_TILES, value.x), DEFAULT_FRAME_TILES.y)
