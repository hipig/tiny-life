extends Button

const DEFAULT_SLOT_WIDTH := 272.0
const DEFAULT_SLOT_HEIGHT := 88.0
const DEFAULT_SERVICE_WIDTH := 48.0
const DEFAULT_ROOM_WIDTH := 224.0

@export_group("Layout")
@export var service_width := DEFAULT_SERVICE_WIDTH
@export var default_room_size := Vector2(DEFAULT_ROOM_WIDTH, DEFAULT_SLOT_HEIGHT)
@export_range(0.0, 24.0, 1.0) var wall_inset := 9.0
@export_range(8.0, 44.0, 1.0) var floor_height := 22.0
@export_range(4.0, 24.0, 1.0) var roof_height := 13.0

@export_group("Scene Text")
@export var locked_label_template := "%s Lv.%d"
@export var buildable_label_template := "%s %d"

var floor_index := 0
var shell: BuildSlotShell

func _ready() -> void:
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
		_add_build_visual(locked_label_template % [display_name, required_level], floor, true)
		return
	disabled = false
	_add_build_visual(buildable_label_template % [display_name, int(floor.get("build_cost", 0))], floor, false)

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
