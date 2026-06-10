@tool
class_name FurniturePlacementRules
extends RefCounted

const LAYER_FLOOR := "floor"
const LAYER_WALL := "wall"
const TILE_SIZE := 16

static func can_place_furniture(room_id: String, furniture_id: String, grid_pos: Array, ignored_instance_id := "") -> bool:
	var game_state := _game_state()
	var config_manager := _config_manager()
	if game_state == null or config_manager == null:
		return false
	var rooms: Dictionary = game_state.get("rooms")
	var room: Dictionary = rooms.get(room_id, {})
	var data: Dictionary = config_manager.call("get_furniture_data", furniture_id)
	return can_place_furniture_in_room(
		room,
		furniture_id,
		data,
		func(other_furniture_id: String) -> Dictionary:
			return config_manager.call("get_furniture_data", other_furniture_id),
		grid_pos,
		ignored_instance_id
	)

static func can_place_furniture_in_room(
	room: Dictionary,
	furniture_id: String,
	furniture_data: Dictionary,
	furniture_lookup: Callable,
	grid_pos: Array,
	ignored_instance_id := ""
) -> bool:
	var layer := placement_layer_for(furniture_data)
	var grid_size := grid_size_for_layer(room, layer)
	var size: Array = furniture_data.get("size", [1, 1])
	if grid_pos.size() < 2 or grid_size.size() < 2 or size.size() < 2:
		return false
	var gx := int(grid_pos[0])
	var gy := int(grid_pos[1])
	var w := int(size[0])
	var h := int(size[1])
	if gx < 0 or gy < 0 or gx + w > int(grid_size[0]) or gy + h > int(grid_size[1]):
		return false
	if layer == LAYER_FLOOR and gy != floor_grid_y_for(grid_size, size):
		return false

	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		if str(instance_data.get("instance_id", "")) == ignored_instance_id:
			continue
		var other_data: Dictionary = furniture_lookup.call(str(instance_data.get("furniture_id", "")))
		if placement_layer_for(other_data) != layer:
			continue
		var other_pos: Array = instance_data.get("grid_pos", [0, 0])
		var other_size: Array = other_data.get("size", [1, 1])
		if _rects_overlap(gx, gy, w, h, int(other_pos[0]), int(other_pos[1]), int(other_size[0]), int(other_size[1])):
			return false
	return true

static func find_first_valid_grid(room_id: String, furniture_id: String, ignored_instance_id := "") -> Array:
	var game_state := _game_state()
	var config_manager := _config_manager()
	if game_state == null or config_manager == null:
		return [0, 0]
	var rooms: Dictionary = game_state.get("rooms")
	var room: Dictionary = rooms.get(room_id, {})
	var data: Dictionary = config_manager.call("get_furniture_data", furniture_id)
	return find_first_valid_grid_in_room(
		room,
		furniture_id,
		data,
		func(other_furniture_id: String) -> Dictionary:
			return config_manager.call("get_furniture_data", other_furniture_id),
		ignored_instance_id
	)

static func find_first_valid_grid_in_room(
	room: Dictionary,
	furniture_id: String,
	furniture_data: Dictionary,
	furniture_lookup: Callable,
	ignored_instance_id := ""
) -> Array:
	var layer := placement_layer_for(furniture_data)
	var grid_size := grid_size_for_layer(room, layer)
	if grid_size.size() < 2:
		return [0, 0]
	if layer == LAYER_FLOOR:
		var floor_y := floor_grid_y_for(grid_size, furniture_data.get("size", [1, 1]))
		for x in range(int(grid_size[0])):
			if can_place_furniture_in_room(room, furniture_id, furniture_data, furniture_lookup, [x, floor_y], ignored_instance_id):
				return [x, floor_y]
	else:
		for y in range(int(grid_size[1])):
			for x in range(int(grid_size[0])):
				if can_place_furniture_in_room(room, furniture_id, furniture_data, furniture_lookup, [x, y], ignored_instance_id):
					return [x, y]
		for x in range(int(grid_size[0])):
			if can_place_furniture_in_room(room, furniture_id, furniture_data, furniture_lookup, [x, 0], ignored_instance_id):
				return [x, 0]
	return [0, 0]

static func placement_layer_for(furniture_data: Dictionary) -> String:
	return LAYER_WALL if bool(furniture_data.get("wall_item", false)) else LAYER_FLOOR

static func grid_size_for_layer(room: Dictionary, layer: String) -> Array:
	var floor_grid: Array = room.get("grid_size", [6, 4])
	var columns := 6
	var rows := 4
	if floor_grid.size() >= 2:
		columns = maxi(1, int(floor_grid[0]))
		rows = maxi(1, int(floor_grid[1]))
	if layer == LAYER_WALL:
		return [columns, maxi(1, rows - 1)]
	return [columns, rows]

static func floor_grid_y_for(grid_size: Array, furniture_size: Array) -> int:
	if grid_size.size() < 2 or furniture_size.size() < 2:
		return 0
	return maxi(0, int(grid_size[1]) - maxi(1, int(furniture_size[1])))

static func door_cells_for_layer(room: Dictionary, layer: String) -> Array:
	return []

static func _rects_overlap(ax: int, ay: int, aw: int, ah: int, bx: int, by: int, bw: int, bh: int) -> bool:
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by

static func _game_state() -> Node:
	var main_loop := Engine.get_main_loop()
	if not main_loop is SceneTree:
		return null
	return (main_loop as SceneTree).root.get_node_or_null("GameState")

static func _config_manager() -> Node:
	var main_loop := Engine.get_main_loop()
	if not main_loop is SceneTree:
		return null
	return (main_loop as SceneTree).root.get_node_or_null("ConfigManager")
