extends HBoxContainer

const DEFAULT_SERVICE_WIDTH := 48.0
const DEFAULT_FRAME_TILES := Vector2i(6, 4)

const META_ROOM_SCENE_PATH := &"room_scene_path"
const META_PUBLIC_AREA_SCENE_PATH := &"public_area_scene_path"
const META_SERVICE_WIDTH := &"service_width"
const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"

var room_scene: PackedScene
var public_area_scene: PackedScene
var service_width := DEFAULT_SERVICE_WIDTH
var default_frame_tiles := DEFAULT_FRAME_TILES

var floor_index := 0
var show_roof_on_top_room := true
var service_core: FloorServiceCore

func _ready() -> void:
	_bind_scene_config()

func setup(index: int, show_roof := true) -> void:
	floor_index = index
	name = "Floor_%d" % floor_index
	show_roof_on_top_room = show_roof
	_bind_scene_config()
	_ensure_service_core()
	if service_core == null:
		return
	_detach_service_core()
	_clear_runtime_content()
	var floor_size := _floor_size()
	custom_minimum_size = floor_size
	size = floor_size

	var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
	var left_content := _content_configs_for_side("left", floor_data)
	var right_content := _content_configs_for_side("right", floor_data)

	for item in left_content:
		var node := _instantiate_content(item)
		if node != null:
			add_child(node)

	add_child(service_core)
	_apply_service_core(floor_data)

	for item in right_content:
		var node := _instantiate_content(item)
		if node != null:
			add_child(node)

func _ensure_service_core() -> void:
	service_core = get_node_or_null("FloorServiceCore") as FloorServiceCore
	if service_core == null:
		push_error("Floor.tscn must expose a FloorServiceCore child.")

func _detach_service_core() -> void:
	if service_core != null and service_core.get_parent() == self:
		remove_child(service_core)

func _clear_runtime_content() -> void:
	for child in get_children():
		if child.name == "SceneConfig":
			continue
		remove_child(child)
		child.queue_free()

func _apply_service_core(floor_data: Dictionary) -> void:
	var floor_height := _floor_height()
	service_core.apply_layout(service_width, floor_height, floor_index, _service_edge_sides(), _service_body_sides())
	service_core.set_floor_label(str(floor_data.get("service_label", floor_data.get("display_name", "%dF" % floor_index))))

func get_service_core() -> FloorServiceCore:
	return service_core

func _floor_size() -> Vector2:
	var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
	var left_width := _side_width("left", floor_data)
	var right_width := _side_width("right", floor_data)
	var height := _floor_height()
	return Vector2(left_width + service_width + right_width, height)

func _floor_height() -> float:
	var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
	var height := _room_pixel_size_from_frame_tiles(default_frame_tiles).y
	for item in _all_content_configs(floor_data):
		height = maxf(height, _content_pixel_size(item).y)
	return height

func _side_width(side: String, floor_data: Dictionary) -> float:
	var width := 0.0
	for item in _content_configs_for_side(side, floor_data):
		width += _content_pixel_size(item).x
	if width <= 0.0:
		width = _room_pixel_size_from_frame_tiles(default_frame_tiles).x
	return width

func _content_configs_for_side(side: String, floor_data: Dictionary) -> Array:
	var result: Array = []
	for item in _all_content_configs(floor_data):
		var content: Dictionary = item
		var layout_side := str(content.get("layout_side", "left")).strip_edges().to_lower()
		if layout_side == side:
			result.append(content)
		elif layout_side == "suite" and side == "left":
			result.append(content)
	return result

func _all_content_configs(floor_data: Dictionary) -> Array:
	var public_areas: Array = floor_data.get("public_areas", [])
	if not public_areas.is_empty():
		var public_result: Array = []
		for item in public_areas:
			var public_area: Dictionary = item
			var public_copy := public_area.duplicate(true)
			public_copy["content_type"] = "public"
			public_result.append(public_copy)
		return public_result

	var room_result: Array = []
	for room in ConfigManager.get_room_configs_for_floor(floor_index):
		var room_data: Dictionary = room
		if _room_is_visible(room_data):
			var room_copy := room_data.duplicate(true)
			room_copy["content_type"] = "room"
			room_result.append(room_copy)
	return room_result

func _instantiate_content(content: Dictionary) -> Control:
	var content_type := str(content.get("content_type", "room"))
	if content_type == "public":
		return _instantiate_public_area(content)
	return _instantiate_room(content)

func _instantiate_room(room_data: Dictionary) -> Control:
	var target_room_scene := _scene_from_path(str(room_data.get("room_scene_path", "")), room_scene)
	if target_room_scene == null:
		push_error("Floor.tscn must assign a room_scene template.")
		return null
	var room_view := target_room_scene.instantiate() as Control
	room_view.name = "Room_%s" % str(room_data.get("id", ""))
	room_view.custom_minimum_size = _content_pixel_size(room_data)
	var side := str(room_data.get("layout_side", "left")).strip_edges().to_lower()
	room_view.setup(str(room_data.get("id", "")), show_roof_on_top_room, _room_edge_sides(side))
	return room_view

func _instantiate_public_area(area_data: Dictionary) -> Control:
	var target_public_scene := _scene_from_path(str(area_data.get("public_area_scene_path", "")), public_area_scene)
	if target_public_scene == null:
		push_error("Floor.tscn must assign a public_area_scene template.")
		return null
	var area_view := target_public_scene.instantiate() as Control
	area_view.name = "PublicArea_%s" % str(area_data.get("id", area_data.get("layout_side", "")))
	var frame_tiles := _frame_tiles_for_content(area_data)
	var area_size := _room_pixel_size_from_frame_tiles(frame_tiles)
	area_view.custom_minimum_size = area_size
	if area_view.has_method("apply_layout"):
		area_view.call_deferred(
			"apply_layout",
			area_size,
			frame_tiles,
			{},
			_room_edge_sides(str(area_data.get("layout_side", "left")).strip_edges().to_lower()),
			_public_body_sides(str(area_data.get("layout_side", "left")).strip_edges().to_lower()),
			str(area_data.get("label", "")),
			bool(area_data.get("has_entrance_door", false)),
			str(area_data.get("door_side", "")),
			bool(area_data.get("door_mirrored", false))
		)
	return area_view

func _content_pixel_size(content: Dictionary) -> Vector2:
	return _room_pixel_size_from_frame_tiles(_frame_tiles_for_content(content))

func _frame_tiles_for_content(content: Dictionary) -> Vector2i:
	var content_type := str(content.get("content_type", "room"))
	if content_type == "room":
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

func _service_edge_sides() -> Dictionary:
	return {
		"left": false,
		"right": false,
		"top": false,
		"bottom": false
	}

func _service_body_sides() -> Dictionary:
	return {
		"left": false,
		"right": false,
		"top": true,
		"bottom": true
	}

func _room_edge_sides(layout_side: String) -> Dictionary:
	return {
		"left": layout_side == "left" or layout_side == "suite",
		"right": layout_side == "right" or layout_side == "suite",
		"top": false,
		"bottom": false
	}

func _public_body_sides(layout_side: String) -> Dictionary:
	return {
		"left": layout_side != "right",
		"right": layout_side != "left",
		"top": true,
		"bottom": true
	}

func _scene_from_path(path: String, fallback: PackedScene) -> PackedScene:
	if path.is_empty():
		return fallback
	var loaded := ResourceLoader.load(path) as PackedScene
	if loaded == null:
		push_warning("Building content scene template could not be loaded: %s" % path)
		return fallback
	return loaded

func _bind_scene_config() -> void:
	var config := get_node_or_null("SceneConfig")
	if config == null:
		push_error("Floor.tscn must expose a SceneConfig node.")
		return
	room_scene = _scene_from_path(_scene_meta_text(config, META_ROOM_SCENE_PATH), room_scene)
	public_area_scene = _scene_from_path(_scene_meta_text(config, META_PUBLIC_AREA_SCENE_PATH), public_area_scene)
	service_width = _scene_meta_float(config, META_SERVICE_WIDTH, DEFAULT_SERVICE_WIDTH)
	default_frame_tiles = _scene_meta_vector2i(config, META_DEFAULT_FRAME_TILES, DEFAULT_FRAME_TILES)

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
