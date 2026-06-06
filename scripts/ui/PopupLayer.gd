class_name PopupLayer
extends CanvasLayer

const FLOATING_COIN_TEXT_SCENE := preload("res://scenes/effects/FloatingCoinText.tscn")

var toast_label: FloatingCoinText

func _ready() -> void:
	toast_label = get_node_or_null("Toast") as FloatingCoinText
	if toast_label == null:
		toast_label = FLOATING_COIN_TEXT_SCENE.instantiate() as FloatingCoinText
		toast_label.name = "Toast"
		add_child(toast_label)

func open_panel(scene: PackedScene, close_callback: Callable) -> AppPanel:
	clear_panels()
	var panel := scene.instantiate() as AppPanel
	panel.close_requested.connect(close_callback)
	add_child(panel)
	return panel

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
