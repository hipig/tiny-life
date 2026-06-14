extends TextureRect

const LONG_PRESS_SECONDS := 0.5

var instance_data: Dictionary = {}
var furniture_id := ""
var instance_id := ""
var room_id := ""
var _pressing := false
var _press_token := 0
var _interaction_active := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_start_long_press_watch()
		else:
			var was_short := _pressing
			_pressing = false
			if was_short:
				UIManager.show_toast(str(tooltip_text))
		accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_start_long_press_watch()
		else:
			var was_short_touch := _pressing
			_pressing = false
			if was_short_touch:
				UIManager.show_toast(str(tooltip_text))
		accept_event()

func setup(data: Dictionary) -> void:
	instance_data = data
	furniture_id = str(instance_data.get("furniture_id", ""))
	instance_id = str(instance_data.get("instance_id", ""))
	room_id = str(instance_data.get("room_id", room_id))
	var furniture_data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var orientation := str(instance_data.get("orientation", FurniturePlacementRules.DEFAULT_ORIENTATION))
	var asset := FurniturePlacementRules.orientation_asset_for(furniture_data, orientation)
	AssetResolver.apply_asset_to_texture_rect(self, asset, Vector2i(26, 26))
	rotation_degrees = FurniturePlacementRules.orientation_rotation_degrees_for(furniture_data, orientation)
	pivot_offset = size * 0.5
	tooltip_text = _furniture_name(furniture_data)
	_connect_interaction_events()
	set_interaction_active(false)

func set_interaction_active(active: bool) -> void:
	_interaction_active = active
	modulate = Color(1.08, 1.0, 0.72, 1.0) if _interaction_active else Color.WHITE

func _connect_interaction_events() -> void:
	if not GameEvents.furniture_interaction_started.is_connected(_on_furniture_interaction_started):
		GameEvents.furniture_interaction_started.connect(_on_furniture_interaction_started)
	if not GameEvents.furniture_interaction_finished.is_connected(_on_furniture_interaction_finished):
		GameEvents.furniture_interaction_finished.connect(_on_furniture_interaction_finished)

func _on_furniture_interaction_started(target_room_id: String, target_instance_id: String, _behavior: String) -> void:
	if target_room_id == room_id and target_instance_id == instance_id:
		set_interaction_active(true)

func _on_furniture_interaction_finished(target_room_id: String, target_instance_id: String, _behavior: String) -> void:
	if target_room_id == room_id and target_instance_id == instance_id:
		set_interaction_active(false)

func _furniture_name(furniture_data: Dictionary) -> String:
	var configured_name := str(furniture_data.get("name", "")).strip_edges()
	if not configured_name.is_empty():
		return configured_name
	return _template_text("FallbackFurnitureName")

func _start_long_press_watch() -> void:
	_pressing = true
	_press_token += 1
	var token := _press_token
	var timer := get_tree().create_timer(LONG_PRESS_SECONDS)
	timer.timeout.connect(_on_long_press_timeout.bind(token), CONNECT_ONE_SHOT)

func _on_long_press_timeout(token: int) -> void:
	if not _pressing or token != _press_token:
		return
	_pressing = false
	if UIManager.current_state != UIManager.UIState.NORMAL and UIManager.current_state != UIManager.UIState.ROOM_PANEL:
		return
	if not room_id.is_empty():
		UIManager.start_move_existing(room_id, str(instance_data.get("instance_id", "")))

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("Furniture scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
