class_name BuildSlot
extends Button

const META_SERVICE_WIDTH := &"service_width"
const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"
const META_WALL_INSET := &"wall_inset"
const META_FLOOR_HEIGHT := &"floor_height"
const META_ROOF_HEIGHT := &"roof_height"

var service_width := 0.0
var default_frame_tiles := Vector2i.ZERO
var wall_inset := 0.0
var floor_height := 0.0
var roof_height := 0.0
var locked_label_template := ""
var buildable_label_template := ""

var floor_index := 0
var shell: BuildSlotShell

func _ready() -> void:
	_bind_scene_config()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clip_contents = true
	clip_text = true
	text = ""
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	shell = $BuildSlotShell

func setup(index: int) -> void:
	floor_index = index
	if is_inside_tree():
		_refresh()

func _refresh() -> void:
	_bind_scene_config()
	text = ""
	custom_minimum_size = _slot_size()
	size = custom_minimum_size
	var floor := ConfigManager.get_floor_data(floor_index)
	var required_level := int(floor["required_apartment_level"])
	var display_name := str(floor["display_name"])
	if GameState.apartment_level < required_level:
		disabled = true
		_add_build_visual(locked_label_template % [display_name, required_level], true)
		return
	disabled = false
	_add_build_visual(buildable_label_template % [display_name, int(floor["build_cost"])], false)

func _add_build_visual(label_text: String, locked: bool) -> void:
	var frames := _side_frame_tiles()
	var left_frame_tiles: Vector2i = frames["left"]
	var right_frame_tiles: Vector2i = frames["right"]
	shell.apply_layout(
		_slot_size(),
		service_width,
		wall_inset,
		floor_height,
		roof_height,
		left_frame_tiles,
		right_frame_tiles,
		{}
	)
	shell.set_locked_visuals(locked)
	shell.label.text = label_text

func _on_pressed() -> void:
	if floor_index > 0 and not disabled:
		UIManager.open_build_confirm(floor_index)

func _slot_size() -> Vector2:
	var frames := _side_frame_tiles()
	var left_size := _room_pixel_size_from_frame_tiles(frames["left"])
	var right_size := _room_pixel_size_from_frame_tiles(frames["right"])
	return Vector2(left_size.x + service_width + right_size.x, maxf(left_size.y, right_size.y))

func _side_frame_tiles() -> Dictionary:
	var result := {
		"left": default_frame_tiles,
		"right": default_frame_tiles
	}
	var floor_data := ConfigManager.get_floor_data(floor_index)
	var public_areas: Array = floor_data["public_areas"]
	if not public_areas.is_empty():
		for item in public_areas:
			var area: Dictionary = item
			var side := str(area["layout_side"]).strip_edges().to_lower()
			if side == "left" or side == "right":
				result[side] = _frame_tiles(area)
		return result
	for room_data in ConfigManager.get_room_configs_for_floor(floor_index):
		var room: Dictionary = room_data
		var side := str(room["layout_side"]).strip_edges().to_lower()
		if side == "suite":
			result["left"] = _frame_tiles(room)
		elif side == "left" or side == "right":
			result[side] = _frame_tiles(room)
	return result

func _frame_tiles(content: Dictionary) -> Vector2i:
	return _fixed_height_frame_tiles(Vector2i(int(content["frame_tiles"][0]), int(content["frame_tiles"][1])))

func _room_pixel_size_from_frame_tiles(value: Vector2i) -> Vector2:
	return Vector2(value.x * ApartmentTileMap.TILE_SIZE, value.y * ApartmentTileMap.TILE_SIZE)

func _fixed_height_frame_tiles(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(2, value.x), default_frame_tiles.y)

func _bind_scene_config() -> void:
	var config := $SceneConfig
	service_width = _required_scene_meta_float(config, META_SERVICE_WIDTH)
	default_frame_tiles = _required_scene_meta_vector2i(config, META_DEFAULT_FRAME_TILES)
	wall_inset = _required_scene_meta_float(config, META_WALL_INSET)
	floor_height = _required_scene_meta_float(config, META_FLOOR_HEIGHT)
	roof_height = _required_scene_meta_float(config, META_ROOF_HEIGHT)
	locked_label_template = _template_text("LockedLabelTemplate")
	buildable_label_template = _template_text("BuildableLabelTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node("TemplateText/%s" % node_name) as Label
	return template_label.text

func _required_scene_meta_float(node: Node, meta_key: StringName) -> float:
	if node == null or not node.has_meta(meta_key):
		push_error("BuildSlot.tscn SceneConfig is missing metadata '%s'." % str(meta_key))
		return 0.0
	return float(node.get_meta(meta_key))

func _required_scene_meta_vector2i(node: Node, meta_key: StringName) -> Vector2i:
	if node == null or not node.has_meta(meta_key):
		push_error("BuildSlot.tscn SceneConfig is missing metadata '%s'." % str(meta_key))
		return Vector2i.ZERO
	var value: Variant = node.get_meta(meta_key)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	push_error("BuildSlot.tscn SceneConfig metadata '%s' must be Vector2i." % str(meta_key))
	return Vector2i.ZERO
