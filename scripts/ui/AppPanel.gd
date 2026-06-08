class_name AppPanel
extends PanelContainer

signal close_requested

var title_label: Label
var close_button: Button
var content_root: VBoxContainer
var scroll_container: ScrollContainer
var _layout_ready := false

func _ready() -> void:
	_ensure_layout()

func _gui_input(event: InputEvent) -> void:
	if _is_world_camera_event(event):
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if visible and _is_world_camera_event(event):
		get_viewport().set_input_as_handled()

func setup_panel(title := "", clear_existing := false) -> void:
	_ensure_layout()
	if not title.is_empty():
		title_label.text = title
	if clear_existing:
		clear_content()

func clear_content() -> void:
	_ensure_layout()
	UIPanelFactory.clear_children(content_root)

func _ensure_layout() -> void:
	if _layout_ready:
		return
	name = "ActivePanel"
	_bind_scene_layout()
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	_layout_ready = true

func _bind_scene_layout() -> void:
	title_label = get_node_or_null("PanelBox/Header/TitleLabel") as Label
	close_button = get_node_or_null("PanelBox/Header/CloseButton") as Button
	scroll_container = get_node_or_null("PanelBox/ScrollContainer") as ScrollContainer
	content_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot") as VBoxContainer
	if title_label != null and close_button != null and scroll_container != null and content_root != null:
		return
	push_error("AppPanel scene is missing PanelBox/Header/TitleLabel, CloseButton, ScrollContainer, or ContentRoot.")

func _on_close_pressed() -> void:
	close_requested.emit()

func _is_world_camera_event(event: InputEvent) -> bool:
	if event is InputEventMagnifyGesture or event is InputEventPanGesture:
		return true
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return true
	if event is InputEventMouseMotion:
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT \
			or mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP \
			or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
	return false
