class_name BuildSlot
extends Button

const META_DEFAULT_FRAME_TILES := &"default_frame_tiles"
const META_WALL_INSET := &"wall_inset"
const META_FLOOR_HEIGHT := &"floor_height"
const META_ROOF_HEIGHT := &"roof_height"

var default_frame_tiles := Vector2i.ZERO
var wall_inset := 0.0
var floor_height := 0.0
var roof_height := 0.0
var locked_label_template := ""
var buildable_label_template := ""

var room_id := ""
var room_edge_sides: Dictionary = {}
var shell: BuildSlotShell

func _ready() -> void:
	_bind_scene_config()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clip_contents = false
	clip_text = true
	text = ""
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	shell = $BuildSlotShell

func setup(target_room_id: String, edge_sides: Dictionary = {}) -> void:
	room_id = target_room_id
	room_edge_sides = edge_sides.duplicate()
	if is_inside_tree():
		_refresh()

func _refresh() -> void:
	_bind_scene_config()
	text = ""
	var room_config := ConfigManager.get_room_config(room_id)
	custom_minimum_size = _slot_size(room_config)
	size = custom_minimum_size
	var required_level := int(room_config["required_apartment_level"])
	var locked := not GameState.is_room_buildable(room_id)
	disabled = locked
	if locked and GameState.apartment_level < required_level:
		_add_build_visual(locked_label_template % required_level, true, room_config)
		return
	_add_build_visual(buildable_label_template % int(room_config["build_cost"]), locked, room_config)

func _add_build_visual(label_text: String, locked: bool, room_config: Dictionary) -> void:
	var tile_theme := ConfigManager.tile_theme_from_decor_state(GameState.get_room(room_id))
	shell.apply_layout(
		_slot_size(room_config),
		wall_inset,
		floor_height,
		roof_height,
		_frame_tiles(room_config),
		tile_theme,
		room_edge_sides
	)
	shell.set_locked_visuals(locked)
	shell.label.text = label_text

func _on_pressed() -> void:
	if not room_id.is_empty() and not disabled:
		UIManager.open_build_confirm(room_id)

func _slot_size(room_config: Dictionary) -> Vector2:
	return _room_pixel_size_from_frame_tiles(_frame_tiles(room_config))

func _frame_tiles(room_config: Dictionary) -> Vector2i:
	return _fixed_height_frame_tiles(Vector2i(int(room_config["frame_tiles"][0]), int(room_config["frame_tiles"][1])))

func _room_pixel_size_from_frame_tiles(value: Vector2i) -> Vector2:
	return Vector2(value.x * ApartmentTileMap.TILE_SIZE, value.y * ApartmentTileMap.TILE_SIZE)

func _fixed_height_frame_tiles(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(2, value.x), default_frame_tiles.y)

func _bind_scene_config() -> void:
	var config := $SceneConfig
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
