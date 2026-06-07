class_name PopupLayer
extends CanvasLayer

var toast_label: FloatingCoinText

func _ready() -> void:
	toast_label = get_node_or_null("Toast") as FloatingCoinText
	if toast_label == null:
		push_error("PopupLayer.tscn must expose a Toast FloatingCoinText node.")

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

func clear_panels() -> void:
	UIPanelFactory.clear_active_panels(self)

func show_toast(message: String) -> void:
	if toast_label == null:
		return
	toast_label.show_message(message)
