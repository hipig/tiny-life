class_name ApartmentBuilding
extends VBoxContainer

const DEFAULT_SERVICE_CORE_WIDTH := 48.0
const DEFAULT_FRAME_TILES := Vector2i(6, 4)

const META_FLOOR_SCENE_PATH := &"floor_scene_path"
const META_BUILD_SLOT_SCENE_PATH := &"build_slot_scene_path"
const META_SERVICE_CORE_WIDTH := &"service_core_width"
const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"

var floor_scene: PackedScene
var build_slot_scene: PackedScene
var service_core_width := DEFAULT_SERVICE_CORE_WIDTH
var default_frame_tiles := DEFAULT_FRAME_TILES

func _ready() -> void:
	_bind_scene_config()

func refresh() -> void:
	_bind_scene_config()
	_clear_runtime_floors()
	for floor_index in range(_max_floor_index(), 0, -1):
		var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
		if floor_index <= GameState.highest_built_floor:
			var built_floor_scene := _scene_from_path(str(floor_data.get("floor_scene_path", "")), floor_scene)
			if built_floor_scene == null:
				push_error("ApartmentBuilding.tscn must assign a floor_scene template.")
				return
			var floor_view := built_floor_scene.instantiate()
			add_child(floor_view)
			floor_view.setup(floor_index, not _has_visible_next_build_slot())
		elif floor_index == GameState.highest_built_floor + 1 and _has_visible_next_build_slot():
			var next_build_slot_scene := _scene_from_path(str(floor_data.get("build_slot_scene_path", "")), build_slot_scene)
			if next_build_slot_scene == null:
				push_error("ApartmentBuilding.tscn must assign a build_slot_scene template.")
				return
			var build_slot := next_build_slot_scene.instantiate()
			add_child(build_slot)
			build_slot.setup(floor_index)
	var building_size := get_building_size()
	custom_minimum_size = building_size
	size = building_size
	update_minimum_size()

func get_building_size() -> Vector2:
	_bind_scene_config()
	var default_room_pixel_size := _room_pixel_size_from_frame_tiles(default_frame_tiles)
	var width: float = service_core_width + default_room_pixel_size.x * 2.0
	var height: float = 0.0
	for floor_index in range(_max_floor_index(), 0, -1):
		if floor_index <= GameState.highest_built_floor:
			var floor_size := _floor_size(floor_index, true)
			width = maxf(width, floor_size.x)
			height += floor_size.y
		elif floor_index == GameState.highest_built_floor + 1 and _has_visible_next_build_slot():
			var build_slot_size := _floor_size(floor_index, false)
			width = maxf(width, build_slot_size.x)
			height += build_slot_size.y
	return Vector2(width, maxf(height, default_room_pixel_size.y))

func find_room_node(room_id: String) -> Control:
	var expected_name := "Room_%s" % room_id
	var found := find_child(expected_name, true, false)
	if found is Control:
		return found as Control
	return null

func find_floor_service_core(floor_index: int) -> FloorServiceCore:
	var floor_node := find_child("Floor_%d" % floor_index, true, false)
	if floor_node == null:
		return null
	var service := floor_node.get_node_or_null("FloorServiceCore")
	return service as FloorServiceCore

func _max_floor_index() -> int:
	var max_floor: int = 1
	for floor in ConfigManager.floors:
		var floor_data: Dictionary = floor
		max_floor = maxi(max_floor, int(floor_data.get("floor_index", 1)))
	return max_floor

func _has_visible_next_build_slot() -> bool:
	var next_floor := GameState.highest_built_floor + 1
	var floor_data: Dictionary = ConfigManager.get_floor_data(next_floor)
	if floor_data.is_empty():
		return false
	var required_level := int(floor_data.get("required_apartment_level", 1))
	return GameState.apartment_level >= required_level

func _floor_size(floor_index: int, built_floor: bool) -> Vector2:
	var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
	var left_width := _side_width(floor_index, floor_data, "left", built_floor)
	var right_width := _side_width(floor_index, floor_data, "right", built_floor)
	var height := _floor_height(floor_index, floor_data, built_floor)
	return Vector2(left_width + service_core_width + right_width, height)

func _floor_height(floor_index: int, floor_data: Dictionary, built_floor: bool) -> float:
	var height := _room_pixel_size_from_frame_tiles(default_frame_tiles).y
	for item in _content_configs_for_floor(floor_index, floor_data, built_floor):
		var content: Dictionary = item
		height = maxf(height, _content_pixel_size(content).y)
	return height

func _side_width(floor_index: int, floor_data: Dictionary, side: String, built_floor: bool) -> float:
	var width := 0.0
	for item in _content_configs_for_floor(floor_index, floor_data, built_floor):
		var content: Dictionary = item
		var layout_side := str(content.get("layout_side", "left")).strip_edges().to_lower()
		if layout_side == side:
			width += _content_pixel_size(content).x
		elif layout_side == "suite" and side == "left":
			width += _content_pixel_size(content).x
	if width <= 0.0:
		width = _room_pixel_size_from_frame_tiles(default_frame_tiles).x
	return width

func _content_configs_for_floor(floor_index: int, floor_data: Dictionary, built_floor: bool) -> Array:
	var public_areas: Array = floor_data.get("public_areas", [])
	if not public_areas.is_empty():
		return public_areas
	var result: Array = []
	for room in ConfigManager.get_room_configs_for_floor(floor_index):
		var room_data: Dictionary = room
		if built_floor and not _room_is_visible(room_data):
			continue
		result.append(room_data)
	return result

func _content_pixel_size(content: Dictionary) -> Vector2:
	return _room_pixel_size_from_frame_tiles(_frame_tiles_for_content(content))

func _frame_tiles_for_content(content: Dictionary) -> Vector2i:
	var room_id := str(content.get("id", ""))
	var runtime_room: Dictionary = GameState.rooms.get(room_id, {})
	var runtime_tiles: Variant = runtime_room.get("frame_tiles", [])
	if runtime_tiles is Array and runtime_tiles.size() >= 2:
		return _fixed_height_frame_tiles(_vector2i_from_array(runtime_tiles, default_frame_tiles))
	var frame_tiles: Variant = content.get("frame_tiles", [])
	if frame_tiles is Array and frame_tiles.size() >= 2:
		return _fixed_height_frame_tiles(_vector2i_from_array(frame_tiles, default_frame_tiles))
	return default_frame_tiles

func _room_pixel_size_from_frame_tiles(value: Vector2i) -> Vector2:
	return Vector2(value.x * ApartmentTileMap.TILE_SIZE, value.y * ApartmentTileMap.TILE_SIZE)

func _vector2i_from_array(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

func _fixed_height_frame_tiles(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(2, value.x), default_frame_tiles.y)

func _room_is_visible(room_data: Dictionary) -> bool:
	var room_id := str(room_data.get("id", ""))
	if room_id.is_empty():
		return false
	var runtime_room: Dictionary = GameState.rooms.get(room_id, {})
	if not runtime_room.is_empty():
		return bool(runtime_room.get("unlocked", false))
	return bool(room_data.get("initial_unlocked", true)) and int(room_data.get("floor_index", 0)) <= GameState.highest_built_floor

func _clear_runtime_floors() -> void:
	for child in get_children():
		if child.name == "SceneConfig":
			continue
		remove_child(child)
		child.queue_free()

func _bind_scene_config() -> void:
	var config := get_node_or_null("SceneConfig")
	if config == null:
		push_error("ApartmentBuilding.tscn must expose a SceneConfig node.")
		return
	floor_scene = _scene_from_path(_scene_meta_text(config, META_FLOOR_SCENE_PATH), floor_scene)
	build_slot_scene = _scene_from_path(_scene_meta_text(config, META_BUILD_SLOT_SCENE_PATH), build_slot_scene)
	service_core_width = _scene_meta_float(config, META_SERVICE_CORE_WIDTH, DEFAULT_SERVICE_CORE_WIDTH)
	default_frame_tiles = _scene_meta_vector2i(config, META_DEFAULT_FRAME_TILES, DEFAULT_FRAME_TILES)

func _scene_from_path(path: String, fallback: PackedScene) -> PackedScene:
	if path.is_empty():
		return fallback
	var loaded := ResourceLoader.load(path) as PackedScene
	if loaded == null:
		push_warning("Building scene template could not be loaded: %s" % path)
		return fallback
	return loaded

func _scene_meta_text(node: Node, meta_key: StringName) -> String:
	if node == null or not node.has_meta(meta_key):
		return ""
	return str(node.get_meta(meta_key)).strip_edges()

func _scene_meta_float(node: Node, meta_key: StringName, fallback: float) -> float:
	if node == null or not node.has_meta(meta_key):
		return fallback
	return float(node.get_meta(meta_key))

func _scene_meta_vector2i(node: Node, meta_key: StringName, fallback: Vector2i) -> Vector2i:
	if node == null or not node.has_meta(meta_key):
		return fallback
	var value: Variant = node.get_meta(meta_key)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback
