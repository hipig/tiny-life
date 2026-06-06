extends Button

const TENANT_SCENE := preload("res://scenes/tenant/Tenant.tscn")
const FURNITURE_SCENE := preload("res://scenes/furniture/Furniture.tscn")
const ROOM_WIDTH := 250.0
const ROOM_HEIGHT := 130.0

var room_id := ""
var visuals_root: HBoxContainer

func _ready() -> void:
	custom_minimum_size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
	clip_text = true
	focus_mode = Control.FOCUS_ALL
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not room_id.is_empty():
		_rebuild()

func setup(id: String) -> void:
	room_id = id
	if is_inside_tree():
		_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var room: Dictionary = GameState.rooms.get(room_id, {})
	text = _room_card_text(room)
	_add_visual_preview(room)

func _add_visual_preview(room: Dictionary) -> void:
	visuals_root = HBoxContainer.new()
	visuals_root.name = "VisualPreview"
	visuals_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visuals_root.position = Vector2(12, 92)
	visuals_root.custom_minimum_size = Vector2(170, 28)
	visuals_root.add_theme_constant_override("separation", 4)
	add_child(visuals_root)

	var furniture_count := 0
	for instance in room.get("furniture_instances", []):
		if furniture_count >= 5:
			break
		var furniture_view := FURNITURE_SCENE.instantiate()
		furniture_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visuals_root.add_child(furniture_view)
		furniture_view.setup(instance)
		furniture_count += 1

	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		return
	var tenant_view := TENANT_SCENE.instantiate()
	tenant_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tenant_view.position = Vector2(202, 78)
	tenant_view.custom_minimum_size = Vector2(40, 44)
	add_child(tenant_view)
	tenant_view.setup(tenant_id)

func _room_card_text(room: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(str(room.get("room_name", "")))
	lines.append("评分 %d  租金 %.1f" % [int(room.get("score", 0)), float(room.get("rent_per_minute", 0.0))])
	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		lines.append("空房")
	else:
		var tenant_data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
		var tenant_state: Dictionary = GameState.tenants.get(tenant_id, {})
		lines.append("%s：%s" % [tenant_data.get("name", "租客"), tenant_state.get("current_behavior", "闲逛")])
	var furniture_names: Array[String] = []
	for instance in room.get("furniture_instances", []):
		furniture_names.append(str(ConfigManager.get_furniture_data(str(instance.get("furniture_id", ""))).get("name", "家具")))
	lines.append("家具：" + (", ".join(furniture_names) if furniture_names.size() > 0 else "无"))
	return "\n".join(lines)

func _on_pressed() -> void:
	if not room_id.is_empty():
		UIManager.open_room_panel(room_id)
