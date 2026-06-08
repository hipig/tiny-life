@tool
class_name TenantRoomLocator
extends RefCounted

const TENANT_FOOTPRINT := [1, 1]
const TILE_SIZE := FurniturePlacementRules.TILE_SIZE

static func spawn_grid(room: Dictionary) -> Array:
	var cells := standing_grids(room)
	if cells.is_empty():
		return [0, 0]
	return cells[mini(cells.size() - 1, int(floor(float(cells.size()) * 0.6)))]

static func spawn_position(room: Dictionary) -> Vector2:
	return grid_to_position(room, spawn_grid(room))

static func walk_grids(room: Dictionary) -> Array:
	var cells := standing_grids(room)
	if cells.is_empty():
		return [[0, 0], [0, 0]]
	return [cells.front(), cells.back()]

static func walk_positions(room: Dictionary) -> Array[Vector2]:
	var grids := walk_grids(room)
	return [grid_to_position(room, grids[0]), grid_to_position(room, grids[1])]

static func interaction_grid(room: Dictionary, furniture_instance: Dictionary, furniture_data: Dictionary) -> Array:
	var floor_row := floor_grid_y(room)
	var grid_pos: Array = furniture_instance.get("grid_pos", [0, floor_row])
	var size: Array = furniture_data.get("size", [1, 1])
	var gx := int(grid_pos[0]) if grid_pos.size() >= 1 else 0
	var width := maxi(1, int(size[0]) if size.size() >= 1 else 1)
	var candidates := [
		[gx + width, floor_row],
		[gx - 1, floor_row],
		[gx, floor_row]
	]
	var cells := standing_grids(room)
	for candidate in candidates:
		if cells.has(candidate):
			return candidate
	if cells.is_empty():
		return [0, floor_row]
	return _nearest_grid(cells, [gx, floor_row])

static func interaction_position(room: Dictionary, furniture_instance: Dictionary, furniture_data: Dictionary) -> Vector2:
	return grid_to_position(room, interaction_grid(room, furniture_instance, furniture_data))

static func standing_grids(room: Dictionary) -> Array:
	var grid_size := FurniturePlacementRules.grid_size_for_layer(room, FurniturePlacementRules.LAYER_FLOOR)
	var columns := maxi(1, int(grid_size[0]) if grid_size.size() >= 1 else 1)
	var floor_row := floor_grid_y(room)
	var blocked := _blocked_floor_grids(room)
	var cells := []
	for x in range(columns):
		var cell := [x, floor_row]
		if blocked.has(cell):
			continue
		cells.append(cell)
	if cells.is_empty():
		for x in range(columns):
			var cell := [x, floor_row]
			if FurniturePlacementRules.door_cells_for_layer(room, FurniturePlacementRules.LAYER_FLOOR).has(cell):
				continue
			cells.append(cell)
	return cells

static func floor_grid_y(room: Dictionary) -> int:
	return FurniturePlacementRules.floor_grid_y_for(
		FurniturePlacementRules.grid_size_for_layer(room, FurniturePlacementRules.LAYER_FLOOR),
		TENANT_FOOTPRINT
	)

static func grid_to_position(room: Dictionary, grid: Array) -> Vector2:
	var floor_rect := floor_rect(room)
	var grid_size := FurniturePlacementRules.grid_size_for_layer(room, FurniturePlacementRules.LAYER_FLOOR)
	var columns := maxf(1.0, float(grid_size[0]) if grid_size.size() >= 1 else 1.0)
	var rows := maxf(1.0, float(grid_size[1]) if grid_size.size() >= 2 else 1.0)
	var gx := clampf(float(grid[0]) if grid.size() >= 1 else 0.0, 0.0, columns - 1.0)
	var gy := clampf(float(grid[1]) if grid.size() >= 2 else floor_grid_y(room), 0.0, rows - 1.0)
	var cell_x := floor_rect.size.x / columns
	var cell_y := floor_rect.size.y / rows
	return Vector2(
		floor_rect.position.x + (gx + 0.5) * cell_x,
		floor_rect.position.y + (gy + 1.0) * cell_y
	)

static func floor_rect(room: Dictionary) -> Rect2:
	var frame_tiles := _frame_tiles(room)
	return Rect2(
		TILE_SIZE,
		0.0,
		float(maxi(1, frame_tiles.x - 2) * TILE_SIZE),
		float(maxi(1, frame_tiles.y) * TILE_SIZE)
	)

static func _blocked_floor_grids(room: Dictionary) -> Array:
	var blocked := FurniturePlacementRules.door_cells_for_layer(room, FurniturePlacementRules.LAYER_FLOOR).duplicate()
	var grid_size := FurniturePlacementRules.grid_size_for_layer(room, FurniturePlacementRules.LAYER_FLOOR)
	var floor_row := floor_grid_y(room)
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		var furniture_data := ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		if FurniturePlacementRules.placement_layer_for(furniture_data) != FurniturePlacementRules.LAYER_FLOOR:
			continue
		var pos: Array = instance_data.get("grid_pos", [0, 0])
		var size: Array = furniture_data.get("size", [1, 1])
		var gx := int(pos[0]) if pos.size() >= 1 else 0
		var gy := int(pos[1]) if pos.size() >= 2 else floor_row
		var width := maxi(1, int(size[0]) if size.size() >= 1 else 1)
		var height := maxi(1, int(size[1]) if size.size() >= 2 else 1)
		for y in range(gy, mini(int(grid_size[1]), gy + height)):
			for x in range(gx, mini(int(grid_size[0]), gx + width)):
				if y == floor_row and not blocked.has([x, y]):
					blocked.append([x, y])
	return blocked

static func _nearest_grid(cells: Array, target: Array) -> Array:
	var nearest: Array = cells[0]
	var nearest_distance: int = abs(int(nearest[0]) - int(target[0]))
	for cell in cells:
		var distance: int = abs(int(cell[0]) - int(target[0]))
		if distance < nearest_distance:
			nearest = cell
			nearest_distance = distance
	return nearest

static func _frame_tiles(room: Dictionary) -> Vector2i:
	var raw: Variant = room.get("frame_tiles", [8, 4])
	if raw is Array and raw.size() >= 2:
		return Vector2i(maxi(4, int(raw[0])), int(raw[1]))
	if raw is Vector2i:
		return Vector2i(maxi(4, raw.x), raw.y)
	if raw is Vector2:
		return Vector2i(maxi(4, int(raw.x)), int(raw.y))
	return Vector2i(8, 4)
