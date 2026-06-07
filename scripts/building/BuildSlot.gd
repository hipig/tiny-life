extends Button

const DEFAULT_SLOT_WIDTH := 272.0
const DEFAULT_SLOT_HEIGHT := 88.0
const DEFAULT_SERVICE_WIDTH := 48.0
const DEFAULT_ROOM_WIDTH := 224.0

const META_SERVICE_WIDTH := &"service_width"
const META_DEFAULT_ROOM_SIZE := &"default_room_size"
const META_WALL_INSET := &"wall_inset"
const META_FLOOR_HEIGHT := &"floor_height"
const META_ROOF_HEIGHT := &"roof_height"

var service_width := DEFAULT_SERVICE_WIDTH
var default_room_size := Vector2(DEFAULT_ROOM_WIDTH, DEFAULT_SLOT_HEIGHT)
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
		disabled = true
		_add_build_visual(_format_label(locked_label_template, [display_name, required_level], display_name), floor, true)
		return
	disabled = false
	_add_build_visual(_format_label(buildable_label_template, [display_name, int(floor.get("build_cost", 0))], display_name), floor, false)

func _add_build_visual(label_text: String, _floor: Dictionary, locked: bool) -> void:
	var slot_size := _slot_size()
	shell.apply_layout(slot_size, service_width, wall_inset, floor_height, roof_height)
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
	var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
	var size_value: Variant = floor_data.get("room_size", [])
	var room_size := default_room_size
	if size_value is Array and size_value.size() >= 2:
		room_size = Vector2(float(size_value[0]), float(size_value[1]))
	else:
		for room in ConfigManager.rooms:
			var room_data: Dictionary = room
			if int(room_data.get("floor_index", 0)) == floor_index:
				var configured: Variant = room_data.get("room_size", [])
				if configured is Array and configured.size() >= 2:
					room_size = Vector2(float(configured[0]), float(configured[1]))
					break
	return Vector2(service_width + room_size.x, room_size.y)

func _bind_scene_config() -> void:
	var config := get_node_or_null("SceneConfig")
	if config == null:
		push_error("BuildSlot.tscn must expose a SceneConfig node.")
		return
	service_width = _scene_meta_float(config, META_SERVICE_WIDTH, DEFAULT_SERVICE_WIDTH)
	default_room_size = _scene_meta_vector2(config, META_DEFAULT_ROOM_SIZE, Vector2(DEFAULT_ROOM_WIDTH, DEFAULT_SLOT_HEIGHT))
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

func _scene_meta_vector2(node: Node, meta_key: StringName, fallback: Vector2) -> Vector2:
	if node == null or not node.has_meta(meta_key):
		return fallback
	var value: Variant = node.get_meta(meta_key)
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
