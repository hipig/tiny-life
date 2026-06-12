class_name Floor
extends HBoxContainer

const META_SERVICE_WIDTH := &"service_width"
const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"

@onready var left_content_root: Control = $LeftContent
@onready var left_room: Room = $LeftContent/LeftRoom
@onready var left_public_area: PublicAreaShell = $LeftContent/LeftPublicArea
@onready var service_core: FloorServiceCore = $FloorServiceCore
@onready var right_content_root: Control = $RightContent
@onready var right_room: Room = $RightContent/RightRoom
@onready var right_public_area: PublicAreaShell = $RightContent/RightPublicArea

var service_width := 0.0
var default_frame_tiles := Vector2i.ZERO
var floor_index := 0
var show_roof_on_top_room := true

func _ready() -> void:
	_bind_scene_config()

func setup(index: int, show_roof := true) -> void:
	floor_index = index
	name = "Floor_%d" % floor_index
	show_roof_on_top_room = show_roof
	_bind_scene_config()
	var floor_size := _floor_size()
	custom_minimum_size = floor_size
	size = floor_size
	var floor_data := ConfigManager.get_floor_data(floor_index)
	_apply_side("left", floor_data)
	_apply_service_core(floor_data)
	_apply_side("right", floor_data)

func get_service_core() -> FloorServiceCore:
	return service_core

func get_room_node(room_id: String) -> Room:
	for room_node in [left_room, right_room]:
		if room_node.visible and room_node.room_id == room_id:
			return room_node
	return null

func get_active_public_areas() -> Array[PublicAreaShell]:
	var result: Array[PublicAreaShell] = []
	for area in [left_public_area, right_public_area]:
		if area.visible:
			result.append(area)
	return result

func _apply_side(side: String, floor_data: Dictionary) -> void:
	var root := left_content_root if side == "left" else right_content_root
	var room_node := left_room if side == "left" else right_room
	var public_area_node := left_public_area if side == "left" else right_public_area
	var public_area := _public_area_for_side(side, floor_data)
	if not public_area.is_empty():
		var area_size := _content_pixel_size(public_area, false)
		root.custom_minimum_size = area_size
		root.size = area_size
		room_node.visible = false
		public_area_node.visible = true
		public_area_node.name = "PublicArea_%s" % str(public_area["id"])
		public_area_node.custom_minimum_size = area_size
		public_area_node.size = area_size
		public_area_node.apply_layout(
			area_size,
			_frame_tiles_for_content(public_area, false),
			{},
			_room_edge_sides(str(public_area["layout_side"]).strip_edges().to_lower()),
			_public_body_sides(str(public_area["layout_side"]).strip_edges().to_lower()),
			str(public_area["label"]),
			bool(public_area["has_entrance_door"]),
			str(public_area.get("door_side", "")),
			bool(public_area.get("door_mirrored", false))
		)
		return
	var room_data := _room_config_for_side(side)
	if room_data.is_empty() or not _room_is_visible(room_data):
		root.custom_minimum_size = _room_pixel_size_from_frame_tiles(default_frame_tiles)
		root.size = root.custom_minimum_size
		room_node.visible = false
		public_area_node.visible = false
		return
	var room_size := _content_pixel_size(room_data, true)
	root.custom_minimum_size = room_size
	root.size = room_size
	public_area_node.visible = false
	room_node.visible = true
	room_node.name = "Room_%s" % str(room_data["id"])
	room_node.custom_minimum_size = room_size
	room_node.size = room_size
	room_node.setup(str(room_data["id"]), show_roof_on_top_room, _room_edge_sides(str(room_data["layout_side"]).strip_edges().to_lower()))

func _apply_service_core(floor_data: Dictionary) -> void:
	var floor_height := _floor_height()
	service_core.apply_layout(service_width, floor_height, floor_index, _service_edge_sides(), _service_body_sides())
	var label_text := str(floor_data["service_label"])
	service_core.set_floor_label(label_text)

func _floor_size() -> Vector2:
	var floor_data := ConfigManager.get_floor_data(floor_index)
	var left_width := _side_width("left", floor_data)
	var right_width := _side_width("right", floor_data)
	return Vector2(left_width + service_width + right_width, _floor_height())

func _floor_height() -> float:
	var floor_data := ConfigManager.get_floor_data(floor_index)
	var height := _room_pixel_size_from_frame_tiles(default_frame_tiles).y
	for item in _all_content_configs(floor_data):
		var content: Dictionary = item
		height = maxf(height, _content_pixel_size(content, true).y)
	return height

func _side_width(side: String, floor_data: Dictionary) -> float:
	var width := 0.0
	for item in _content_configs_for_side(side, floor_data):
		var content: Dictionary = item
		width += _content_pixel_size(content, true).x
	if width <= 0.0:
		width = _room_pixel_size_from_frame_tiles(default_frame_tiles).x
	return width

func _content_configs_for_side(side: String, floor_data: Dictionary) -> Array:
	var result: Array = []
	for item in _all_content_configs(floor_data):
		var content: Dictionary = item
		var layout_side := str(content["layout_side"]).strip_edges().to_lower()
		if layout_side == side:
			result.append(content)
		elif layout_side == "suite" and side == "left":
			result.append(content)
	return result

func _all_content_configs(floor_data: Dictionary) -> Array:
	var public_areas: Array = floor_data["public_areas"]
	if not public_areas.is_empty():
		return public_areas
	var result: Array = []
	for room_data in ConfigManager.get_room_configs_for_floor(floor_index):
		var room: Dictionary = room_data
		if _room_is_visible(room):
			result.append(room)
	return result

func _public_area_for_side(side: String, floor_data: Dictionary) -> Dictionary:
	for item in floor_data["public_areas"]:
		var public_area: Dictionary = item
		if str(public_area["layout_side"]).strip_edges().to_lower() == side:
			return public_area
	return {}

func _room_config_for_side(side: String) -> Dictionary:
	for room_data in ConfigManager.get_room_configs_for_floor(floor_index):
		var room: Dictionary = room_data
		var layout_side := str(room["layout_side"]).strip_edges().to_lower()
		if layout_side == side or (layout_side == "suite" and side == "left"):
			return room
	return {}

func _content_pixel_size(content: Dictionary, built_floor: bool) -> Vector2:
	return _room_pixel_size_from_frame_tiles(_frame_tiles_for_content(content, built_floor))

func _frame_tiles_for_content(content: Dictionary, built_floor: bool) -> Vector2i:
	if built_floor and content.has("id") and str(content["id"]).begins_with("room_"):
		var room := GameState.get_room(str(content["id"]))
		if not room.is_empty():
			return _fixed_height_frame_tiles(_vector2i_from_array(room["frame_tiles"]))
	return _fixed_height_frame_tiles(_vector2i_from_array(content["frame_tiles"]))

func _room_pixel_size_from_frame_tiles(value: Vector2i) -> Vector2:
	return Vector2(value.x * ApartmentTileMap.TILE_SIZE, value.y * ApartmentTileMap.TILE_SIZE)

func _vector2i_from_array(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	push_error("Expected a [width, height] tile array.")
	return Vector2i.ZERO

func _fixed_height_frame_tiles(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(2, value.x), default_frame_tiles.y)

func _room_is_visible(room_data: Dictionary) -> bool:
	var room := GameState.get_room(str(room_data["id"]))
	return not room.is_empty() and bool(room["unlocked"])

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

func _bind_scene_config() -> void:
	var config := $SceneConfig
	service_width = _required_scene_meta_float(config, META_SERVICE_WIDTH)
	default_frame_tiles = _required_scene_meta_vector2i(config, META_DEFAULT_FRAME_TILES)

func _required_scene_meta_float(node: Node, meta_key: StringName) -> float:
	if node == null or not node.has_meta(meta_key):
		push_error("Floor.tscn SceneConfig is missing metadata '%s'." % str(meta_key))
		return 0.0
	return float(node.get_meta(meta_key))

func _required_scene_meta_vector2i(node: Node, meta_key: StringName) -> Vector2i:
	if node == null or not node.has_meta(meta_key):
		push_error("Floor.tscn SceneConfig is missing metadata '%s'." % str(meta_key))
		return Vector2i.ZERO
	var value: Variant = node.get_meta(meta_key)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	push_error("Floor.tscn SceneConfig metadata '%s' must be Vector2i." % str(meta_key))
	return Vector2i.ZERO
