class_name FurniturePlacementRules
extends RefCounted

static func can_place_furniture(room_id: String, furniture_id: String, grid_pos: Array, ignored_instance_id := "") -> bool:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var grid_size: Array = room.get("grid_size", [8, 5])
	var size: Array = data.get("size", [1, 1])
	if grid_pos.size() < 2 or grid_size.size() < 2 or size.size() < 2:
		return false
	var gx := int(grid_pos[0])
	var gy := int(grid_pos[1])
	var w := int(size[0])
	var h := int(size[1])
	if gx < 0 or gy < 0 or gx + w > int(grid_size[0]) or gy + h > int(grid_size[1]):
		return false
	if bool(data.get("requires_wall", false)) and gy != 0:
		return false

	var door_cells := [[0, int(grid_size[1]) - 1]]
	for yy in range(gy, gy + h):
		for xx in range(gx, gx + w):
			if [xx, yy] in door_cells:
				return false

	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		if str(instance_data.get("instance_id", "")) == ignored_instance_id:
			continue
		var other_data: Dictionary = ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		var other_pos: Array = instance_data.get("grid_pos", [0, 0])
		var other_size: Array = other_data.get("size", [1, 1])
		if _rects_overlap(gx, gy, w, h, int(other_pos[0]), int(other_pos[1]), int(other_size[0]), int(other_size[1])):
			return false
	return true

static func find_first_valid_grid(room_id: String, furniture_id: String, ignored_instance_id := "") -> Array:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var grid_size: Array = room.get("grid_size", [8, 5])
	if grid_size.size() < 2:
		return [0, 0]
	if bool(data.get("requires_wall", false)):
		for x in range(int(grid_size[0])):
			if can_place_furniture(room_id, furniture_id, [x, 0], ignored_instance_id):
				return [x, 0]
	for y in range(int(grid_size[1]) - 1, -1, -1):
		for x in range(int(grid_size[0])):
			if can_place_furniture(room_id, furniture_id, [x, y], ignored_instance_id):
				return [x, y]
	return [0, 0]

static func _rects_overlap(ax: int, ay: int, aw: int, ah: int, bx: int, by: int, bw: int, bh: int) -> bool:
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
