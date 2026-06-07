class_name UIPanelFactory
extends RefCounted

const ICON_DIR := "res://assets/pixel_spaces/icons/"
enum ButtonSkin {
	ORANGE,
	BLUE,
	GREEN,
	RED,
	YELLOW,
	WHITE,
	GREY
}

static func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func clear_active_panels(panel_layer: Node) -> void:
	for child in panel_layer.get_children():
		if child is PanelContainer or child is PlacementOverlay:
			panel_layer.remove_child(child)
			child.queue_free()

static func icon_asset(file_name: String) -> Dictionary:
	return {"type": "single_sprite", "texture": ICON_DIR + file_name}
