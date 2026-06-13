class_name ApartmentBuilding
extends VBoxContainer

const META_SERVICE_CORE_WIDTH := &"service_core_width"
const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"

@onready var apartment_roof = $ApartmentRoof

var service_core_width := 0.0
var default_frame_tiles := Vector2i.ZERO
var floor_nodes_by_index := {}

func _ready() -> void:
	_bind_scene_config()
	_bind_floor_nodes()

func refresh() -> void:
	_bind_scene_config()
	_bind_floor_nodes()
	var highest_visible_floor := GameState.get_highest_visible_floor()
	for floor_data in ConfigManager.floors:
		var data: Dictionary = floor_data
		var floor_index := int(data["floor_index"])
		var floor_node = floor_nodes_by_index.get(floor_index)
		if floor_node == null:
			continue
		if GameState.is_floor_visible(floor_index):
			floor_node.visible = true
			floor_node.call("setup", floor_index)
		else:
			floor_node.visible = false
	_apply_roof(highest_visible_floor)
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
		if not GameState.is_floor_visible(floor_index):
			continue
		var floor_size := _floor_size(floor_index)
		width = maxf(width, floor_size.x)
		height += floor_size.y
	return Vector2(width, maxf(height, default_room_pixel_size.y))

func find_room_node(room_id: String) -> Control:
	var room_config := ConfigManager.get_room_config(room_id)
	var floor_node = floor_nodes_by_index.get(int(room_config["floor_index"]))
	if floor_node == null:
		return null
	return floor_node.call("get_room_node", room_id) as Control

func find_floor_service_core(floor_index: int):
	var floor_node = floor_nodes_by_index.get(floor_index)
	if floor_node == null:
		return null
	return floor_node.call("get_service_core")

func get_floor_node(floor_index: int):
	return floor_nodes_by_index.get(floor_index)

func _apply_roof(highest_visible_floor: int) -> void:
	if apartment_roof == null:
		return
	if highest_visible_floor <= 0:
		apartment_roof.call("hide_roof")
		return
	var roof_target_ref := GameState.space_decor_target(ConfigManager.TARGET_ROOF, ConfigManager.APARTMENT_ROOF_TARGET_ID)
	var roof_style_id := GameState.get_space_decor_id(roof_target_ref, ConfigManager.DECOR_ROOF)
	apartment_roof.call("apply_layout", ConfigManager.apartment_roof_theme_for_style(roof_style_id), roof_target_ref)

func _floor_size(floor_index: int) -> Vector2:
	var floor_data := ConfigManager.get_floor_data(floor_index)
	var left_width := _side_width(floor_index, floor_data, "left")
	var right_width := _side_width(floor_index, floor_data, "right")
	var height := _floor_height(floor_index, floor_data)
	return Vector2(left_width + service_core_width + right_width, height)

func _floor_height(floor_index: int, floor_data: Dictionary) -> float:
	var height := _room_pixel_size_from_frame_tiles(default_frame_tiles).y
	for item in _content_configs_for_floor(floor_index, floor_data):
		var content: Dictionary = item
		height = maxf(height, _content_pixel_size(content).y)
	return height

func _side_width(floor_index: int, floor_data: Dictionary, side: String) -> float:
	var width := 0.0
	for item in _content_configs_for_floor(floor_index, floor_data):
		var content: Dictionary = item
		var layout_side := str(content["layout_side"]).strip_edges().to_lower()
		if layout_side == side:
			width += _content_pixel_size(content).x
		elif layout_side == "suite" and side == "left":
			width += _content_pixel_size(content).x
	if width <= 0.0:
		width = _room_pixel_size_from_frame_tiles(default_frame_tiles).x
	return width

func _content_configs_for_floor(floor_index: int, floor_data: Dictionary) -> Array:
	var public_areas: Array = floor_data["public_areas"]
	if not public_areas.is_empty():
		return public_areas
	var result: Array = []
	for room_data in ConfigManager.get_room_configs_for_floor(floor_index):
		var room: Dictionary = room_data
		if _room_or_slot_is_visible(room):
			result.append(room)
	return result

func _content_pixel_size(content: Dictionary) -> Vector2:
	return _room_pixel_size_from_frame_tiles(_frame_tiles_for_content(content))

func _frame_tiles_for_content(content: Dictionary) -> Vector2i:
	var content_type := "room"
	if content.has("id") and str(content["id"]).begins_with("room_"):
		content_type = "room"
	elif content.has("label"):
		content_type = "public"
	if content_type == "room" and _room_is_visible(content):
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

func _room_or_slot_is_visible(room_data: Dictionary) -> bool:
	return _room_is_visible(room_data) or GameState.is_room_buildable(str(room_data["id"]))

func _bind_scene_config() -> void:
	var config := $SceneConfig
	service_core_width = _required_scene_meta_float(config, META_SERVICE_CORE_WIDTH)
	default_frame_tiles = _required_scene_meta_vector2i(config, META_DEFAULT_FRAME_TILES)

func _bind_floor_nodes() -> void:
	floor_nodes_by_index.clear()
	for floor_data in ConfigManager.floors:
		var floor_index := int((floor_data as Dictionary)["floor_index"])
		var floor_node := get_node("Floor_%d" % floor_index)
		floor_nodes_by_index[floor_index] = floor_node

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
