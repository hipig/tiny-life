extends Button

const DEFAULT_SLOT_WIDTH := 176.0
const DEFAULT_SLOT_HEIGHT := 64.0
const DEFAULT_SERVICE_WIDTH := 48.0
const DEFAULT_FRAME_TILES := Vector2i(8, 4)

const META_SERVICE_WIDTH := &"service_width"
const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"
const META_WALL_INSET := &"wall_inset"
const META_FLOOR_HEIGHT := &"floor_height"
const META_ROOF_HEIGHT := &"roof_height"

var service_width := DEFAULT_SERVICE_WIDTH
var default_frame_tiles := DEFAULT_FRAME_TILES
var wall_inset := 9.0
var floor_height := 22.0
var roof_height := 13.0
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
	_ensure_shell()

func setup(index: int) -> void:
	floor_index = index
	if is_inside_tree():
		_refresh()

func _refresh() -> void:
	_bind_scene_config()
	_ensure_shell()
	if shell == null:
		return
	text = ""
	custom_minimum_size = _slot_size()
	size = custom_minimum_size
	var floor: Dictionary = ConfigManager.get_floor_data(floor_index)
	if floor.is_empty():
		visible = false
		return
	visible = true
	var required_level := int(floor.get("required_apartment_level", 1))
	var display_name := str(floor.get("display_name", "%dF" % floor_index))
	if GameState.apartment_level < required_level:
		visible = false
		disabled = true
		return
	disabled = false
	_add_build_visual(_format_label(buildable_label_template, [display_name, int(floor.get("build_cost", 0))], display_name), floor, false)

func _add_build_visual(label_text: String, _floor: Dictionary, locked: bool) -> void:
	var slot_size := _slot_size()
	shell.apply_layout(slot_size, service_width, wall_inset, floor_height, roof_height, _frame_tiles(_floor), {})
	shell.set_locked_visuals(locked)
	shell.label.text = label_text

func _ensure_shell() -> void:
	shell = get_node_or_null("BuildSlotShell") as BuildSlotShell
	if shell == null:
		push_error("BuildSlot.tscn must expose a BuildSlotShell child.")

func _on_pressed() -> void:
	if floor_index > 0 and not disabled:
		UIManager.open_build_confirm(floor_index)

func _slot_size() -> Vector2:
	var room_pixel_size := Vector2(_frame_tiles(ConfigManager.get_floor_data(floor_index)) * ApartmentTileMap.TILE_SIZE)
	return Vector2(service_width + room_pixel_size.x, room_pixel_size.y)

func _frame_tiles(floor_data: Dictionary) -> Vector2i:
	var configured_frame_tiles: Variant = floor_data.get("frame_tiles", [])
	if configured_frame_tiles is Array and configured_frame_tiles.size() >= 2:
		return _fixed_height_frame_tiles(Vector2i(int(configured_frame_tiles[0]), int(configured_frame_tiles[1])))
	for room in ConfigManager.rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) != floor_index:
			continue
		var room_tiles: Variant = room_data.get("frame_tiles", [])
		if room_tiles is Array and room_tiles.size() >= 2:
			return _fixed_height_frame_tiles(Vector2i(int(room_tiles[0]), int(room_tiles[1])))
	return default_frame_tiles

func _fixed_height_frame_tiles(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(4, value.x), default_frame_tiles.y)

func _bind_scene_config() -> void:
	var config := get_node_or_null("SceneConfig")
	if config == null:
		push_error("BuildSlot.tscn must expose a SceneConfig node.")
		return
	service_width = _scene_meta_float(config, META_SERVICE_WIDTH, DEFAULT_SERVICE_WIDTH)
	default_frame_tiles = _scene_meta_vector2i(config, META_DEFAULT_FRAME_TILES, DEFAULT_FRAME_TILES)
	wall_inset = _scene_meta_float(config, META_WALL_INSET, 9.0)
	floor_height = _scene_meta_float(config, META_FLOOR_HEIGHT, 22.0)
	roof_height = _scene_meta_float(config, META_ROOF_HEIGHT, 13.0)
	locked_label_template = _template_text("LockedLabelTemplate")
	buildable_label_template = _template_text("BuildableLabelTemplate")

func _format_label(template: String, values: Array, fallback: String) -> String:
	if template.is_empty():
		return fallback
	return template % values

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("BuildSlot scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

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
