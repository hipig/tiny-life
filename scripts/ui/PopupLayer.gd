class_name PopupLayer
extends CanvasLayer

var toast_label: FloatingCoinText

func _ready() -> void:
	toast_label = get_node_or_null("Toast") as FloatingCoinText
	if toast_label == null:
		push_error("PopupLayer.tscn must expose a Toast FloatingCoinText node.")

func _unhandled_input(event: InputEvent) -> void:
	if has_blocking_panel() and _is_world_camera_event(event):
		get_viewport().set_input_as_handled()

func open_panel(scene: PackedScene, close_callback: Callable) -> AppPanel:
	clear_panels()
	var panel := scene.instantiate() as AppPanel
	panel.close_requested.connect(close_callback)
	add_child(panel)
	return panel

func open_overlay(scene: PackedScene) -> Control:
	clear_panels()
	var overlay := scene.instantiate() as Control
	add_child(overlay)
	return overlay

func active_panel() -> AppPanel:
	for child in get_children():
		if child is AppPanel:
			return child
	return null

func has_blocking_panel() -> bool:
	return active_panel() != null

func clear_panels() -> void:
	UIPanelFactory.clear_active_panels(self)

func show_toast(message: String) -> void:
	if toast_label == null:
		return
	toast_label.show_message(message)

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
