@tool
class_name FurniturePlacementRules
extends RefCounted

const LAYER_FLOOR := "floor"
const LAYER_WALL := "wall"
const TILE_SIZE := 16
const HORIZONTAL_SUBDIVISIONS := 2
const DEFAULT_ORIENTATION := "default"
const ROTATED_ORIENTATION := "rotated"
const ORIENTATION_MODE_ROTATABLE := "rotatable"
const ANCHOR_EPSILON := 0.01

static func can_place_furniture(room_id: String, furniture_id: String, anchor_pos: Array, ignored_instance_id := "", orientation := DEFAULT_ORIENTATION) -> bool:
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
		anchor_pos,
		ignored_instance_id,
		orientation
	)

static func can_place_furniture_in_room(
	room: Dictionary,
	furniture_id: String,
	furniture_data: Dictionary,
	furniture_lookup: Callable,
	anchor_pos: Array,
	ignored_instance_id := "",
	orientation := DEFAULT_ORIENTATION
) -> bool:
	if anchor_pos.size() < 2:
		return false
	var layer := placement_layer_for(furniture_data)
	var rect := placement_rect_for_layer(room, layer)
	var footprint_size := footprint_pixel_size_for(room, furniture_data, orientation)
	var normalized_anchor := normalized_anchor_for(room, furniture_data, anchor_pos, orientation)
	if not _anchors_equal(anchor_pos, normalized_anchor):
		return false
	var bounds := bounds_rect_for_anchor(room, furniture_data, anchor_pos, footprint_size, orientation)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return false
	if not _rect_contains_rect(rect, bounds):
		return false

	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		if str(instance_data.get("instance_id", "")) == ignored_instance_id:
			continue
		var other_data: Dictionary = furniture_lookup.call(str(instance_data.get("furniture_id", "")))
		if placement_layer_for(other_data) != layer:
			continue
		var other_anchor: Array = instance_data.get("anchor_pos", [])
		if other_anchor.size() < 2:
			continue
		var other_orientation := str(instance_data.get("orientation", DEFAULT_ORIENTATION))
		var other_size := footprint_pixel_size_for(room, other_data, other_orientation)
		var other_bounds := bounds_rect_for_anchor(room, other_data, other_anchor, other_size, other_orientation)
		if bounds.intersects(other_bounds):
			return false
	return true

static func find_first_valid_anchor(room_id: String, furniture_id: String, ignored_instance_id := "", orientation := DEFAULT_ORIENTATION) -> Array:
	var game_state := _game_state()
	var config_manager := _config_manager()
	if game_state == null or config_manager == null:
		return [0.0, 0.0]
	var rooms: Dictionary = game_state.get("rooms")
	var room: Dictionary = rooms.get(room_id, {})
	var data: Dictionary = config_manager.call("get_furniture_data", furniture_id)
	return find_first_valid_anchor_in_room(
		room,
		furniture_id,
		data,
		func(other_furniture_id: String) -> Dictionary:
			return config_manager.call("get_furniture_data", other_furniture_id),
		ignored_instance_id,
		orientation
	)

static func find_first_valid_anchor_in_room(
	room: Dictionary,
	furniture_id: String,
	furniture_data: Dictionary,
	furniture_lookup: Callable,
	ignored_instance_id := "",
	orientation := DEFAULT_ORIENTATION
) -> Array:
	var layer := placement_layer_for(furniture_data)
	var rect := placement_rect_for_layer(room, layer)
	var footprint_size := footprint_pixel_size_for(room, furniture_data, orientation)
	var anchor := [0.0, 0.0]
	if layer == LAYER_FLOOR:
		anchor = [
			roundf(rect.position.x + maxf(0.0, (rect.size.x - footprint_size.x) * 0.5)),
			floor_baseline_y(room)
		]
	else:
		anchor = [
			roundf(rect.position.x + maxf(0.0, (rect.size.x - footprint_size.x) * 0.5)),
			roundf(rect.position.y + maxf(0.0, (rect.size.y - footprint_size.y) * 0.5))
		]
	anchor = normalized_anchor_for(room, furniture_data, anchor, orientation)
	if can_place_furniture_in_room(room, furniture_id, furniture_data, furniture_lookup, anchor, ignored_instance_id, orientation):
		return anchor

	var step := 1.0
	var min_x := rect.position.x
	var max_x := rect.end.x - footprint_size.x
	var min_y := rect.position.y
	var max_y := rect.end.y - footprint_size.y
	if layer == LAYER_FLOOR:
		for x_index in range(maxi(1, int(ceil(maxf(0.0, max_x - min_x) / step)) + 1)):
			var candidate := normalized_anchor_for(room, furniture_data, [roundf(min_x + float(x_index) * step), floor_baseline_y(room)], orientation)
			if can_place_furniture_in_room(room, furniture_id, furniture_data, furniture_lookup, candidate, ignored_instance_id, orientation):
				return candidate
	else:
		for y_index in range(maxi(1, int(ceil(maxf(0.0, max_y - min_y) / step)) + 1)):
			for x_index in range(maxi(1, int(ceil(maxf(0.0, max_x - min_x) / step)) + 1)):
				var candidate := normalized_anchor_for(room, furniture_data, [roundf(min_x + float(x_index) * step), roundf(min_y + float(y_index) * step)], orientation)
				if can_place_furniture_in_room(room, furniture_id, furniture_data, furniture_lookup, candidate, ignored_instance_id, orientation):
					return candidate
	return normalized_anchor_for(room, furniture_data, anchor, orientation)

static func normalized_anchor_for(room: Dictionary, furniture_data: Dictionary, anchor_pos: Array, orientation := DEFAULT_ORIENTATION) -> Array:
	var layer := placement_layer_for(furniture_data)
	var rect := placement_rect_for_layer(room, layer)
	var footprint_size := footprint_pixel_size_for(room, furniture_data, orientation)
	var x := roundf(float(anchor_pos[0]) if anchor_pos.size() >= 1 else rect.position.x)
	var y := roundf(float(anchor_pos[1]) if anchor_pos.size() >= 2 else rect.position.y)
	var max_x := floorf(maxf(rect.position.x, rect.end.x - footprint_size.x))
	x = clampf(x, rect.position.x, max_x)
	if layer == LAYER_FLOOR:
		y = floor_baseline_y(room)
	else:
		var max_y := floorf(maxf(rect.position.y, rect.end.y - footprint_size.y))
		y = clampf(y, rect.position.y, max_y)
	return [x, y]

static func bounds_rect_for_anchor(room: Dictionary, furniture_data: Dictionary, anchor_pos: Array, placement_size := Vector2.ZERO, orientation := DEFAULT_ORIENTATION) -> Rect2:
	var size := placement_size
	if size == Vector2.ZERO:
		size = footprint_pixel_size_for(room, furniture_data, orientation)
	var layer := placement_layer_for(furniture_data)
	var anchor := Vector2(
		float(anchor_pos[0]) if anchor_pos.size() >= 1 else 0.0,
		float(anchor_pos[1]) if anchor_pos.size() >= 2 else 0.0
	)
	if layer == LAYER_FLOOR:
		return Rect2(Vector2(anchor.x, anchor.y - size.y), size)
	return Rect2(anchor, size)

static func visual_size_for(room: Dictionary, furniture_data: Dictionary, orientation := DEFAULT_ORIENTATION) -> Vector2:
	var orientation_data := orientation_data_for(furniture_data, orientation)
	var asset_size := _asset_region_size(orientation_data.get("asset", {}))
	var visual_grid: Array = orientation_data.get("size", [1, 1])
	var layer := placement_layer_for(furniture_data)
	var rect := placement_rect_for_layer(room, layer)
	var layer_grid := visual_grid_size_for_layer(room, layer)
	var cell_x := rect.size.x / maxf(1.0, float(layer_grid[0]) if layer_grid.size() >= 1 else 1.0)
	var cell_y := rect.size.y / maxf(1.0, float(layer_grid[1]) if layer_grid.size() >= 2 else 1.0)
	var max_width := maxf(16.0, float(visual_grid[0]) * cell_x * 1.05)
	var max_height := maxf(15.0, float(visual_grid[1]) * cell_y * 1.8)
	if bool(furniture_data.get("wall_item", false)):
		max_width = maxf(14.0, float(visual_grid[0]) * cell_x * 0.85)
		max_height = maxf(12.0, float(visual_grid[1]) * cell_y * 1.15)
	if asset_size == Vector2.ZERO:
		return Vector2(roundf(max_width), roundf(max_height))
	var scale := minf(max_width / asset_size.x, max_height / asset_size.y)
	scale = clampf(scale, 0.9, 2.0)
	return Vector2(
		roundf(maxf(12.0, asset_size.x * scale)),
		roundf(maxf(10.0, asset_size.y * scale))
	)

static func footprint_pixel_size_for(room: Dictionary, furniture_data: Dictionary, orientation := DEFAULT_ORIENTATION) -> Vector2:
	var footprint := footprint_for_orientation(furniture_data, orientation)
	var layer := placement_layer_for(furniture_data)
	var rect := placement_rect_for_layer(room, layer)
	var grid := grid_size_for_layer(room, layer)
	var cell_x := rect.size.x / maxf(1.0, float(grid[0]) if grid.size() >= 1 else 1.0)
	var cell_y := rect.size.y / maxf(1.0, float(grid[1]) if grid.size() >= 2 else 1.0)
	return Vector2(
		roundf(maxf(1.0, float(footprint[0]) * cell_x)),
		roundf(maxf(1.0, float(footprint[1]) * cell_y))
	)

static func placement_rect_for_layer(room: Dictionary, layer: String) -> Rect2:
	var floor_rect := floor_rect(room)
	if layer == LAYER_WALL:
		return Rect2(floor_rect.position, Vector2(floor_rect.size.x, maxf(TILE_SIZE, floor_rect.size.y - TILE_SIZE)))
	return floor_rect

static func floor_rect(room: Dictionary) -> Rect2:
	var frame_tiles := _frame_tiles(room)
	return Rect2(
		Vector2.ZERO,
		Vector2(float(maxi(1, frame_tiles.x) * TILE_SIZE), float(maxi(1, frame_tiles.y) * TILE_SIZE))
	)

static func floor_baseline_y(room: Dictionary) -> float:
	return floor_rect(room).end.y

static func placement_layer_for(furniture_data: Dictionary) -> String:
	return LAYER_WALL if bool(furniture_data.get("wall_item", false)) else LAYER_FLOOR

static func grid_size_for_layer(room: Dictionary, layer: String) -> Array:
	var visual_grid := visual_grid_size_for_layer(room, layer)
	if visual_grid.size() < 2:
		return [1, 1]
	return [maxi(1, int(visual_grid[0]) * HORIZONTAL_SUBDIVISIONS), maxi(1, int(visual_grid[1]))]

static func visual_grid_size_for_layer(room: Dictionary, layer: String) -> Array:
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

static func footprint_for_orientation(furniture_data: Dictionary, orientation := DEFAULT_ORIENTATION) -> Array:
	var footprint: Array = orientation_data_for(furniture_data, orientation)["footprint"]
	return [maxi(1, int(footprint[0])), maxi(1, int(footprint[1]))]

static func orientation_data_for(furniture_data: Dictionary, orientation := DEFAULT_ORIENTATION) -> Dictionary:
	var orientations: Dictionary = furniture_data.get("orientations", {})
	var selected := orientation.strip_edges()
	if selected.is_empty():
		selected = str(furniture_data.get("default_orientation", DEFAULT_ORIENTATION))
	if not orientations.has(selected):
		selected = str(furniture_data.get("default_orientation", DEFAULT_ORIENTATION))
	if orientations.has(selected):
		var data: Variant = orientations[selected]
		if data is Dictionary:
			return data
	push_error("Furniture '%s' is missing orientation '%s'." % [str(furniture_data.get("id", "")), orientation])
	return {}

static func orientation_asset_for(furniture_data: Dictionary, orientation := DEFAULT_ORIENTATION) -> Dictionary:
	return orientation_data_for(furniture_data, orientation).get("asset", {})

static func orientation_rotation_degrees_for(furniture_data: Dictionary, orientation := DEFAULT_ORIENTATION) -> float:
	return float(orientation_data_for(furniture_data, orientation).get("rotation_degrees", 0.0))

static func default_orientation_for(furniture_data: Dictionary) -> String:
	return str(furniture_data.get("default_orientation", DEFAULT_ORIENTATION)).strip_edges()

static func can_rotate(furniture_data: Dictionary) -> bool:
	return str(furniture_data.get("orientation_mode", "")).strip_edges() == ORIENTATION_MODE_ROTATABLE

static func next_orientation_for(furniture_data: Dictionary, orientation := DEFAULT_ORIENTATION) -> String:
	if not can_rotate(furniture_data):
		return default_orientation_for(furniture_data)
	return DEFAULT_ORIENTATION if orientation == ROTATED_ORIENTATION else ROTATED_ORIENTATION

static func door_cells_for_layer(room: Dictionary, layer: String) -> Array:
	return []

static func _rect_contains_rect(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x \
		and inner.position.y >= outer.position.y \
		and inner.end.x <= outer.end.x \
		and inner.end.y <= outer.end.y

static func _anchors_equal(left: Array, right: Array) -> bool:
	if left.size() < 2 or right.size() < 2:
		return false
	return absf(float(left[0]) - float(right[0])) <= ANCHOR_EPSILON \
		and absf(float(left[1]) - float(right[1])) <= ANCHOR_EPSILON

static func _frame_tiles(room: Dictionary) -> Vector2i:
	var raw: Variant = room.get("frame_tiles", room.get("grid_size", [6, 4]))
	if raw is Array and raw.size() >= 2:
		return Vector2i(maxi(2, int(raw[0])), int(raw[1]))
	if raw is Vector2i:
		return Vector2i(maxi(2, raw.x), raw.y)
	if raw is Vector2:
		return Vector2i(maxi(2, int(raw.x)), int(raw.y))
	return Vector2i(6, 4)

static func _asset_region_size(asset_config: Dictionary) -> Vector2:
	var asset_type := str(asset_config.get("type", "")).strip_edges()
	match asset_type:
		"atlas_region":
			var region: Array = asset_config.get("region", [])
			if region.size() >= 4:
				return Vector2(float(region[2]), float(region[3]))
		"spritesheet_frame":
			var frame_size: Array = asset_config.get("frame_size", [])
			if frame_size.size() >= 2:
				return Vector2(float(frame_size[0]), float(frame_size[1]))
		"single_sprite":
			var texture := load(str(asset_config.get("texture", ""))) as Texture2D
			if texture != null:
				return Vector2(texture.get_width(), texture.get_height())
	return Vector2.ZERO

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
