extends HBoxContainer

const DEFAULT_SERVICE_WIDTH := 48.0
const DEFAULT_FRAME_TILES := Vector2i(8, 4)

const META_ROOM_SCENE_PATH := &"room_scene_path"
const META_SERVICE_WIDTH := &"service_width"
const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"

var room_scene: PackedScene
var service_width := DEFAULT_SERVICE_WIDTH
var default_frame_tiles := DEFAULT_FRAME_TILES

var floor_index := 0
var show_roof_on_top_room := true
var service_core: FloorServiceCore

func _ready() -> void:
	_bind_scene_config()

func setup(index: int, show_roof := true) -> void:
	floor_index = index
	show_roof_on_top_room = show_roof
	_bind_scene_config()
	_ensure_service_core()
	if service_core == null:
		return
	_clear_runtime_rooms()
	var floor_size := _floor_size()
	custom_minimum_size = floor_size
	size = floor_size

	var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
	_apply_service_core(floor_data)

	for room in ConfigManager.rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) != floor_index:
			continue
		if not _room_is_visible(room_data):
			continue
		var target_room_scene := _scene_from_path(str(room_data.get("room_scene_path", "")), room_scene)
		if target_room_scene == null:
			push_error("Floor.tscn must assign a room_scene template.")
			return
		var room_view := target_room_scene.instantiate()
		room_view.name = "Room_%s" % str(room_data.get("id", ""))
		room_view.custom_minimum_size = _room_pixel_size(room_data)
		add_child(room_view)
		room_view.setup(str(room_data.get("id", "")), show_roof_on_top_room)

func _ensure_service_core() -> void:
	service_core = get_node_or_null("FloorServiceCore") as FloorServiceCore
	if service_core == null:
		push_error("Floor.tscn must expose a FloorServiceCore child.")
		return
	move_child(service_core, 0)

func _clear_runtime_rooms() -> void:
	for child in get_children():
		if child == service_core or child.name == "SceneConfig":
			continue
		remove_child(child)
		child.queue_free()

func _apply_service_core(floor_data: Dictionary) -> void:
	var floor_height := _floor_height()
	service_core.apply_layout(service_width, floor_height)
	service_core.set_floor_label(str(floor_data.get("display_name", "%dF" % floor_index)))

func _floor_size() -> Vector2:
	var width := service_width
	var height := _floor_height()
	var room_count := 0
	for room in ConfigManager.rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) != floor_index:
			continue
		if not _room_is_visible(room_data):
			continue
		var room_pixel_size := _room_pixel_size(room_data)
		width += room_pixel_size.x
		height = maxf(height, room_pixel_size.y)
		room_count += 1
	if room_count == 0:
		width += _room_pixel_size_from_frame_tiles(default_frame_tiles).x
	return Vector2(width, height)

func _floor_height() -> float:
	var height := _room_pixel_size_from_frame_tiles(default_frame_tiles).y
	for room in ConfigManager.rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) == floor_index and _room_is_visible(room_data):
			height = maxf(height, _room_pixel_size(room_data).y)
	return height

func _room_pixel_size(room_data: Dictionary) -> Vector2:
	var room_id := str(room_data.get("id", ""))
	var runtime_room: Dictionary = GameState.rooms.get(room_id, {})
	var runtime_tiles: Variant = runtime_room.get("frame_tiles", [])
	if runtime_tiles is Array and runtime_tiles.size() >= 2:
		return _room_pixel_size_from_frame_tiles(_fixed_height_frame_tiles(_vector2i_from_array(runtime_tiles, default_frame_tiles)))
	var frame_tiles: Variant = room_data.get("frame_tiles", [])
	if frame_tiles is Array and frame_tiles.size() >= 2:
		return _room_pixel_size_from_frame_tiles(_fixed_height_frame_tiles(_vector2i_from_array(frame_tiles, default_frame_tiles)))
	return _room_pixel_size_from_frame_tiles(default_frame_tiles)

func _room_pixel_size_from_frame_tiles(value: Vector2i) -> Vector2:
	return Vector2(value.x * ApartmentTileMap.TILE_SIZE, value.y * ApartmentTileMap.TILE_SIZE)

func _vector2i_from_array(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

func _fixed_height_frame_tiles(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(4, value.x), default_frame_tiles.y)

func _room_is_visible(room_data: Dictionary) -> bool:
	var room_id := str(room_data.get("id", ""))
	if room_id.is_empty():
		return false
	var runtime_room: Dictionary = GameState.rooms.get(room_id, {})
	if not runtime_room.is_empty():
		return bool(runtime_room.get("unlocked", false))
	return bool(room_data.get("initial_unlocked", true)) and int(room_data.get("floor_index", 0)) <= GameState.highest_built_floor

func _scene_from_path(path: String, fallback: PackedScene) -> PackedScene:
	if path.is_empty():
		return fallback
	var loaded := ResourceLoader.load(path) as PackedScene
	if loaded == null:
		push_warning("Room scene template could not be loaded: %s" % path)
		return fallback
	return loaded

func _bind_scene_config() -> void:
	var config := get_node_or_null("SceneConfig")
	if config == null:
		push_error("Floor.tscn must expose a SceneConfig node.")
		return
	room_scene = _scene_from_path(_scene_meta_text(config, META_ROOM_SCENE_PATH), room_scene)
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
