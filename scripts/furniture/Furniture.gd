extends TextureRect

const LONG_PRESS_SECONDS := 0.5

var instance_data: Dictionary = {}
var furniture_id := ""
var room_id := ""
var _pressing := false
var _press_time := 0.0

func _process(delta: float) -> void:
	if not _pressing:
		return
	_press_time += delta
	if _press_time < LONG_PRESS_SECONDS:
		return
	_pressing = false
	if UIManager.current_state != UIManager.UIState.NORMAL and UIManager.current_state != UIManager.UIState.ROOM_PANEL:
		return
	if not room_id.is_empty():
		UIManager.start_move_existing(room_id, str(instance_data.get("instance_id", "")))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_pressing = true
			_press_time = 0.0
		else:
			var was_short := _pressing and _press_time < LONG_PRESS_SECONDS
			_pressing = false
			if was_short:
				UIManager.show_toast(str(tooltip_text))
		accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_pressing = true
			_press_time = 0.0
		else:
			var was_short_touch := _pressing and _press_time < LONG_PRESS_SECONDS
			_pressing = false
			if was_short_touch:
				UIManager.show_toast(str(tooltip_text))
		accept_event()

func setup(data: Dictionary) -> void:
	instance_data = data
	furniture_id = str(instance_data.get("furniture_id", ""))
	room_id = str(instance_data.get("room_id", room_id))
	var furniture_data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var asset: Dictionary = furniture_data.get("asset", {})
	AssetResolver.apply_asset_to_texture_rect(self, asset, Color("#b9784a"), Vector2i(26, 26))
	tooltip_text = _furniture_name(furniture_data)

func _furniture_name(furniture_data: Dictionary) -> String:
	var configured_name := str(furniture_data.get("name", "")).strip_edges()
	if not configured_name.is_empty():
		return configured_name
	return _template_text("FallbackFurnitureName")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("Furniture scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
