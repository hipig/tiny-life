@tool
class_name ApartmentTileMap
extends Node2D

const TILE_SIZE := 16
const DEFAULT_FRAME_TILES := Vector2i(8, 4)
const MIN_FRAME_WIDTH_TILES := 3
const EDGE_TOP := "top"
const EDGE_BOTTOM := "bottom"
const EDGE_LEFT := "left"
const EDGE_RIGHT := "right"

@export_group("Tile Sources")
## 壁纸层使用的 TileSet source id，通常指向 Wallpaper Tilesets.png。
@export var wallpaper_source_id := 2
## 普通墙体层使用的 TileSet source id，通常指向 Infrastructure.png。
@export var wall_body_source_id := 0
## 黑色外轮廓/窗户等装饰层使用的 TileSet source id，通常指向 Infrastructure.png。
@export var wall_edge_source_id := 0
## 施工标记层使用的 TileSet source id，通常指向 Infrastructure.png。
@export var construction_source_id := 0

@export_group("Wallpaper")
## 当 wallpaper_tiles 为空时使用的默认壁纸 atlas 坐标。
@export var wallpaper_tile := Vector2i(0, 28)
## 壁纸平铺序列；会按房间格子顺序循环铺满背景。
@export var wallpaper_tiles: Array[Vector2i] = []

@export_group("Themed Wall Body")
## 普通墙体左上角 tile；用于左墙和上墙同时存在的位置。
@export var body_top_left_corner_tile := Vector2i(1, 17)
## 普通墙体顶部横边 tile 序列；顶部会按 x 方向循环。
@export var body_top_edge_tiles: Array[Vector2i] = [Vector2i(3, 17)]
## 普通墙体右上角 tile；用于右墙和上墙同时存在的位置。
@export var body_top_right_corner_tile := Vector2i(5, 17)
## 无门左墙的竖向长边 tile 序列；2F+ 服务区左墙闭合时使用。
@export var body_left_edge_tiles: Array[Vector2i] = [Vector2i(1, 18)]
## 有门左墙的短边 tile 序列；固定画在门上方一格，房间门和 1F 出口门使用。
@export var body_left_door_edge_tiles: Array[Vector2i] = [Vector2i(2, 18)]
## 普通墙体右侧竖边 tile 序列；仅右墙存在时使用。
@export var body_right_edge_tiles: Array[Vector2i] = [Vector2i(5, 18)]
## 无门左墙底部的左下角 tile；未装修房间和 2F+ 服务区闭合时使用。
@export var body_bottom_left_corner_tile := Vector2i(1, 19)
## 普通墙体底部横边 tile 序列；有门左墙的门下方也使用下边 tile。
@export var body_bottom_edge_tiles: Array[Vector2i] = [Vector2i(2, 19)]
## 普通墙体右下角 tile；用于右墙和下墙同时存在的位置。
@export var body_bottom_right_corner_tile := Vector2i(5, 19)
## 有门左墙需要额外清空的墙体格子，相对门底部格；默认留空。
@export var body_door_cutout_cells: Array[Vector2i] = []
## 有门左墙需要额外补画的格子，相对门底部格；通常留空。
@export var body_door_short_wall_cells: Array[Vector2i] = []
## body_door_short_wall_cells 对应的 tile 序列。
@export var body_door_short_wall_tiles: Array[Vector2i] = []

@export_group("Fixed Wall Edge")
## 黑色外轮廓左上角 tile；只在 top 和 left 黑边都启用时使用。
@export var edge_top_left_corner_tile := Vector2i(0, 0)
## 黑色外轮廓顶部横边 tile 序列；当前楼体规则通常禁用顶部黑边。
@export var edge_top_edge_tiles: Array[Vector2i] = [Vector2i(1, 0)]
## 黑色外轮廓右上角 tile；只在 top 和 right 黑边都启用时使用。
@export var edge_top_right_corner_tile := Vector2i(6, 0)
## 黑色外轮廓左侧竖边 tile 序列；服务区最左侧外轮廓使用。
@export var edge_left_edge_tiles: Array[Vector2i] = [Vector2i(0, 3)]
## 有门左黑边的短边 tile 序列；固定画在门上方一格，1F 出口门使用。
@export var edge_left_door_edge_tiles: Array[Vector2i] = [Vector2i(4, 1)]
## 黑色外轮廓右侧竖边 tile 序列；最右房间外轮廓使用。
@export var edge_right_edge_tiles: Array[Vector2i] = [Vector2i(6, 1)]
## 黑色外轮廓左下角 tile；只有 bottom 和 left 黑边都启用时使用。
@export var edge_bottom_left_corner_tile := Vector2i(0, 4)
## 黑色外轮廓底部横边 tile 序列；当前楼体规则通常禁用底部黑边。
@export var edge_bottom_edge_tiles: Array[Vector2i] = [Vector2i(5, 4)]
## 黑色外轮廓右下角 tile；只有 bottom 和 right 黑边都启用时使用。
@export var edge_bottom_right_corner_tile := Vector2i(6, 4)
## 黑色外轮廓需要清空的门洞格子，相对门底部格；当前门由独立场景承载，通常留空。
@export var edge_door_cutout_cells: Array[Vector2i] = []
## 黑色外轮廓需要额外补画的门边格子，相对门底部格；通常留空。
@export var edge_door_short_wall_cells: Array[Vector2i] = []
## edge_door_short_wall_cells 对应的 tile 序列。
@export var edge_door_short_wall_tiles: Array[Vector2i] = []

@export_group("Door Window And Roof Tiles")
## 左侧门底部所在列，0 表示最左列；门视觉由 RoomDoor/ExitDoor 场景绘制。
@export var door_cell_from_left := 0
## 左侧门底部距离底边的格数，0 表示最底行。
@export var door_cell_from_bottom := 0
## 右墙窗户 tile；只有右侧普通墙体存在时才绘制。
@export var window_tile := Vector2i(5, 2)
## 窗户距离右墙的格数，0 表示最右列。
@export var window_cell_from_right := 0
## 窗户距离顶部的格数。
@export var window_cell_from_top := 1
## 屋顶左端 tile；show_roof 为 true 时绘制在房间上方。
@export var roof_left_tile := Vector2i.ZERO
## 屋顶中段 tile 序列；会按 x 方向循环。
@export var roof_tiles: Array[Vector2i] = []
## 屋顶右端 tile；show_roof 为 true 时绘制在房间上方。
@export var roof_right_tile := Vector2i.ZERO

@export_group("Construction Tiles")
## 施工状态标记 tile。
@export var construction_marker_tile := Vector2i.ZERO
## 施工状态左侧标记所在格。
@export var construction_left_marker_cell := Vector2i(1, 3)
## 施工状态右侧标记距离右下角的格偏移。
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
var current_edge_sides := {}
var current_body_sides := {}
var current_has_left_door := true

func _ready() -> void:
	render_room_skeleton(DEFAULT_FRAME_TILES, {}, current_roof_visible, current_construction_visible)

func render_room_skeleton(frame_tiles := DEFAULT_FRAME_TILES, theme: Dictionary = {}, show_roof := false, show_construction := false, edge_sides: Dictionary = {}, body_sides: Dictionary = {}, has_left_door := true) -> void:
	_bind_layers()
	current_frame_tiles = _validated_frame_tiles(frame_tiles)
	current_theme = theme.duplicate()
	current_roof_visible = show_roof
	current_construction_visible = show_construction
	current_edge_sides = _normalized_sides(edge_sides, true)
	current_body_sides = _normalized_sides(body_sides, true)
	current_has_left_door = has_left_door
	if show_roof:
		current_edge_sides[EDGE_TOP] = false
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
			var index := y * current_frame_tiles.x + x
			var atlas := _cycled_tile(fallback_tiles, index, _theme_vector2i("wallpaper_tile", wallpaper_tile))
			wallpaper_layer.set_cell(Vector2i(x, y), wallpaper_source_id, atlas)

func _paint_wall_body() -> void:
	if wall_layer == null:
		return
	var max_x := current_frame_tiles.x - 1
	var max_y := current_frame_tiles.y - 1
	for y in range(current_frame_tiles.y):
		for x in range(current_frame_tiles.x):
			if x > 0 and x < max_x and y > 0 and y < max_y:
				continue
			if not _should_paint_body_cell(x, y, max_x, max_y):
				continue
			var target := Vector2i(x, y)
			wall_layer.set_cell(target, wall_body_source_id, _body_tile_at(x, y, max_x, max_y))
	var door_cell := _door_cell()
	if _body_side_enabled(EDGE_LEFT) and current_has_left_door:
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
	_paint_exported_wall_edge()

func _paint_exported_wall_edge() -> void:
	var max_x := current_frame_tiles.x - 1
	var max_y := current_frame_tiles.y - 1
	if _edge_side_enabled(EDGE_TOP):
		for x in range(current_frame_tiles.x):
			infrastructure_layer.set_cell(Vector2i(x, -1), wall_edge_source_id, _edge_tile_at(x, -1, max_x, max_y))
	if _edge_side_enabled(EDGE_BOTTOM):
		for x in range(current_frame_tiles.x):
			infrastructure_layer.set_cell(Vector2i(x, current_frame_tiles.y), wall_edge_source_id, _edge_tile_at(x, current_frame_tiles.y, max_x, max_y))
	if _edge_side_enabled(EDGE_LEFT):
		for y in range(current_frame_tiles.y):
			infrastructure_layer.set_cell(Vector2i(-1, y), wall_edge_source_id, _edge_tile_at(-1, y, max_x, max_y))
	if _edge_side_enabled(EDGE_RIGHT):
		for y in range(current_frame_tiles.y):
			infrastructure_layer.set_cell(Vector2i(current_frame_tiles.x, y), wall_edge_source_id, _edge_tile_at(current_frame_tiles.x, y, max_x, max_y))
	if _edge_side_enabled(EDGE_LEFT) and _edge_side_enabled(EDGE_TOP):
		infrastructure_layer.set_cell(Vector2i(-1, -1), wall_edge_source_id, _theme_vector2i("edge_top_left_corner_tile", edge_top_left_corner_tile))
	if _edge_side_enabled(EDGE_RIGHT) and _edge_side_enabled(EDGE_TOP):
		infrastructure_layer.set_cell(Vector2i(current_frame_tiles.x, -1), wall_edge_source_id, _theme_vector2i("edge_top_right_corner_tile", edge_top_right_corner_tile))
	if _edge_side_enabled(EDGE_LEFT) and _edge_side_enabled(EDGE_BOTTOM):
		infrastructure_layer.set_cell(Vector2i(-1, current_frame_tiles.y), wall_edge_source_id, _theme_vector2i("edge_bottom_left_corner_tile", edge_bottom_left_corner_tile))
	if _edge_side_enabled(EDGE_RIGHT) and _edge_side_enabled(EDGE_BOTTOM):
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

func _paint_room_window() -> void:
	if infrastructure_layer == null or not _body_side_enabled(EDGE_RIGHT):
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
	var top_left := _theme_vector2i("body_top_left_corner_tile", body_top_left_corner_tile)
	var top_edges := _theme_vector2i_array("body_top_edge_tiles", body_top_edge_tiles)
	var top_right := _theme_vector2i("body_top_right_corner_tile", body_top_right_corner_tile)
	var left_edges := _theme_vector2i_array("body_left_edge_tiles", body_left_edge_tiles)
	var left_door_edges := _theme_vector2i_array("body_left_door_edge_tiles", body_left_door_edge_tiles)
	var right_edges := _theme_vector2i_array("body_right_edge_tiles", body_right_edge_tiles)
	var bottom_left := _theme_vector2i("body_bottom_left_corner_tile", body_bottom_left_corner_tile)
	var bottom_edges := _theme_vector2i_array("body_bottom_edge_tiles", body_bottom_edge_tiles)
	var bottom_right := _theme_vector2i("body_bottom_right_corner_tile", body_bottom_right_corner_tile)
	if y == 0:
		if x == 0:
			if _body_side_enabled(EDGE_TOP) and _body_side_enabled(EDGE_LEFT):
				return top_left
			if _body_side_enabled(EDGE_TOP):
				return _cycled_tile(top_edges, x, top_left)
			return _cycled_tile(left_edges, y, top_left)
		if x == max_x:
			if _body_side_enabled(EDGE_TOP) and _body_side_enabled(EDGE_RIGHT):
				return top_right
			if _body_side_enabled(EDGE_TOP):
				return _cycled_tile(top_edges, x - 1, top_left)
			return _cycled_tile(right_edges, y, top_right)
		return _cycled_tile(top_edges, x - 1, top_left)
	if y == max_y:
		if x == 0:
			if not current_has_left_door and _body_side_enabled(EDGE_BOTTOM) and _body_side_enabled(EDGE_LEFT):
				return bottom_left
			if _body_side_enabled(EDGE_BOTTOM):
				return _cycled_tile(bottom_edges, x, bottom_left)
			return _cycled_tile(left_edges, y - 1, top_left)
		if x == max_x:
			if _body_side_enabled(EDGE_BOTTOM) and _body_side_enabled(EDGE_RIGHT):
				return bottom_right
			if _body_side_enabled(EDGE_BOTTOM):
				return _cycled_tile(bottom_edges, x - 1, bottom_left)
			return _cycled_tile(right_edges, y - 1, top_right)
		return _cycled_tile(bottom_edges, x - 1, bottom_left)
	if x == 0:
		if current_has_left_door and _body_side_enabled(EDGE_LEFT):
			if y == max_y - 1:
				return _cycled_tile(left_door_edges, 0, top_left)
			return _cycled_tile(left_edges, y - 1, top_left)
		return _cycled_tile(left_edges, y - 1, top_left)
	if x == max_x:
		return _cycled_tile(right_edges, y - 1, top_right)
	return top_left

func _edge_tile_at(x: int, y: int, max_x: int, max_y: int) -> Vector2i:
	if y < 0:
		return _cycled_tile(_theme_vector2i_array("edge_top_edge_tiles", edge_top_edge_tiles), x, _theme_vector2i("edge_top_edge_tile", edge_top_left_corner_tile))
	if y > max_y:
		return _cycled_tile(_theme_vector2i_array("edge_bottom_edge_tiles", edge_bottom_edge_tiles), x, _theme_vector2i("edge_bottom_edge_tile", edge_bottom_left_corner_tile))
	if x < 0:
		if current_has_left_door and y == max_y - 1:
			return _cycled_tile(_theme_vector2i_array("edge_left_door_edge_tiles", edge_left_door_edge_tiles), 0, _theme_vector2i("edge_left_edge_tile", edge_top_left_corner_tile))
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
