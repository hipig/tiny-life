class_name ApartmentBuilding
extends VBoxContainer

const META_SERVICE_CORE_WIDTH := &"service_core_width"
const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"

var service_core_width := 0.0
var default_frame_tiles := Vector2i.ZERO
var floor_nodes_by_index := {}
var build_slot_nodes_by_index := {}

func _ready() -> void:
	_bind_scene_config()
	_bind_floor_nodes()

func refresh() -> void:
	_bind_scene_config()
	_bind_floor_nodes()
	var highest_built_floor := GameState.highest_built_floor
	var next_floor_index := highest_built_floor + 1
	var show_next_build_slot := _has_next_build_slot()
	for floor_data in ConfigManager.floors:
		var data: Dictionary = floor_data
		var floor_index := int(data["floor_index"])
		var floor_node := floor_nodes_by_index.get(floor_index) as Floor
		if floor_node == null:
			continue
		if floor_index <= highest_built_floor:
			floor_node.visible = true
			floor_node.setup(floor_index, floor_index == highest_built_floor and not show_next_build_slot)
		else:
			floor_node.visible = false
		var build_slot := build_slot_nodes_by_index.get(floor_index) as BuildSlot
		if build_slot == null:
			continue
		if floor_index == next_floor_index and show_next_build_slot:
			build_slot.visible = true
			build_slot.setup(floor_index)
		else:
			build_slot.visible = false
	var building_size := get_building_size()
	custom_minimum_size = building_size
	size = building_size
	update_minimum_size()

func get_building_size() -> Vector2:
	var default_room_pixel_size := _room_pixel_size_from_frame_tiles(default_frame_tiles)
	var width: float = service_core_width + default_room_pixel_size.x * 2.0
	var height: float = 0.0
	for floor_data in ConfigManager.floors:
		var data: Dictionary = floor_data
		var floor_index := int(data["floor_index"])
		if floor_index <= GameState.highest_built_floor:
			var floor_size := _floor_size(floor_index, true)
			width = maxf(width, floor_size.x)
			height += floor_size.y
		elif floor_index == GameState.highest_built_floor + 1 and _has_next_build_slot():
			var build_slot_size := _floor_size(floor_index, false)
			width = maxf(width, build_slot_size.x)
			height += build_slot_size.y
	return Vector2(width, maxf(height, default_room_pixel_size.y))

func find_room_node(room_id: String) -> Control:
	var room_config := ConfigManager.get_room_config(room_id)
	var floor_node := floor_nodes_by_index.get(int(room_config["floor_index"])) as Floor
	if floor_node == null:
		return null
	return floor_node.get_room_node(room_id)

func find_floor_service_core(floor_index: int) -> FloorServiceCore:
	var floor_node := floor_nodes_by_index.get(floor_index) as Floor
	if floor_node == null:
		return null
	return floor_node.get_service_core()

func get_floor_node(floor_index: int) -> Floor:
	return floor_nodes_by_index.get(floor_index) as Floor

func _has_next_build_slot() -> bool:
	var next_floor_index := GameState.highest_built_floor + 1
	for floor_data in ConfigManager.floors:
		if int((floor_data as Dictionary)["floor_index"]) == next_floor_index:
			return true
	return false

func _floor_size(floor_index: int, built_floor: bool) -> Vector2:
	var floor_data := ConfigManager.get_floor_data(floor_index)
	var left_width := _side_width(floor_index, floor_data, "left", built_floor)
	var right_width := _side_width(floor_index, floor_data, "right", built_floor)
	var height := _floor_height(floor_index, floor_data, built_floor)
	return Vector2(left_width + service_core_width + right_width, height)

func _floor_height(floor_index: int, floor_data: Dictionary, built_floor: bool) -> float:
	var height := _room_pixel_size_from_frame_tiles(default_frame_tiles).y
	for item in _content_configs_for_floor(floor_index, floor_data, built_floor):
		var content: Dictionary = item
		height = maxf(height, _content_pixel_size(content, built_floor))
	return height

func _side_width(floor_index: int, floor_data: Dictionary, side: String, built_floor: bool) -> float:
	var width := 0.0
	for item in _content_configs_for_floor(floor_index, floor_data, built_floor):
		var content: Dictionary = item
		var layout_side := str(content["layout_side"]).strip_edges().to_lower()
		if layout_side == side:
			width += _content_pixel_size(content, built_floor).x
		elif layout_side == "suite" and side == "left":
			width += _content_pixel_size(content, built_floor).x
	if width <= 0.0:
		width = _room_pixel_size_from_frame_tiles(default_frame_tiles).x
	return width

func _content_configs_for_floor(floor_index: int, floor_data: Dictionary, built_floor: bool) -> Array:
	var public_areas: Array = floor_data["public_areas"]
	if not public_areas.is_empty():
		return public_areas
	var result: Array = []
	for room_data in ConfigManager.get_room_configs_for_floor(floor_index):
		var room: Dictionary = room_data
		if built_floor and not _room_is_visible(room):
			continue
		result.append(room)
	return result

func _content_pixel_size(content: Dictionary, built_floor: bool) -> Vector2:
	return _room_pixel_size_from_frame_tiles(_frame_tiles_for_content(content, built_floor))

func _frame_tiles_for_content(content: Dictionary, built_floor: bool) -> Vector2i:
	var content_type := "room"
	if content.has("id") and str(content["id"]).begins_with("room_"):
		content_type = "room"
	elif content.has("label"):
		content_type = "public"
	if content_type == "room" and built_floor:
		var runtime_room := GameState.get_room(str(content["id"]))
		return _vector2i_from_array(runtime_room["frame_tiles"])
	return _vector2i_from_array(content["frame_tiles"])

func _room_pixel_size_from_frame_tiles(value: Vector2i) -> Vector2:
	return Vector2(value.x * ApartmentTileMap.TILE_SIZE, value.y * ApartmentTileMap.TILE_SIZE)

func _vector2i_from_array(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	push_error("Expected a [width, height] tile array.")
	return Vector2i.ZERO

func _room_is_visible(room_data: Dictionary) -> bool:
	var runtime_room := GameState.get_room(str(room_data["id"]))
	return not runtime_room.is_empty() and bool(runtime_room["unlocked"])

func _bind_scene_config() -> void:
	var config := $SceneConfig
	service_core_width = _required_scene_meta_float(config, META_SERVICE_CORE_WIDTH)
	default_frame_tiles = _required_scene_meta_vector2i(config, META_DEFAULT_FRAME_TILES)

func _bind_floor_nodes() -> void:
	floor_nodes_by_index.clear()
	build_slot_nodes_by_index.clear()
	for floor_data in ConfigManager.floors:
		var floor_index := int((floor_data as Dictionary)["floor_index"])
		var floor_node := get_node("Floor_%d" % floor_index) as Floor
		floor_nodes_by_index[floor_index] = floor_node
		if floor_index > 1:
			var slot_node := get_node("BuildSlot_%d" % floor_index) as BuildSlot
			build_slot_nodes_by_index[floor_index] = slot_node

func _required_scene_meta_float(node: Node, meta_key: StringName) -> float:
	if node == null or not node.has_meta(meta_key):
		push_error("ApartmentBuilding.tscn SceneConfig is missing metadata '%s'." % str(meta_key))
		return 0.0
	return float(node.get_meta(meta_key))

func _required_scene_meta_vector2i(node: Node, meta_key: StringName) -> Vector2i:
	if node == null or not node.has_meta(meta_key):
		push_error("ApartmentBuilding.tscn SceneConfig is missing metadata '%s'." % str(meta_key))
		return Vector2i.ZERO
	var value: Variant = node.get_meta(meta_key)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	push_error("ApartmentBuilding.tscn SceneConfig metadata '%s' must be Vector2i." % str(meta_key))
	return Vector2i.ZERO

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
