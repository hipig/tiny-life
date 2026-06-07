class_name RecycleConfirmPopup
extends "res://scripts/ui/AppPanel.gd"

signal recycle_confirmed(room_id: String, instance_id: String)
signal recycle_cancelled(room_id: String)

var room_id := ""
var instance_id := ""
var message_label: Label
var refund_label: Label
var confirm_button: PanelActionButton
var cancel_button: PanelActionButton

var message_template := ""
var refund_template := ""
var fallback_furniture_name := ""

func open(target_room_id: String, target_instance_id: String) -> void:
	room_id = target_room_id
	instance_id = target_instance_id
	setup_panel("", false)
	_bind_scene_nodes()
	_bind_scene_text()
	var furniture_id := _furniture_id()
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var refund: int = int(float(data.get("price", 0)) * float(data.get("refund_rate", 0.5)))
	message_label.text = message_template % data.get("name", fallback_furniture_name)
	refund_label.text = refund_template % refund
	if not confirm_button.action_requested.is_connected(_on_confirm_pressed):
		confirm_button.action_requested.connect(_on_confirm_pressed)
	if not cancel_button.action_requested.is_connected(_on_cancel_pressed):
		cancel_button.action_requested.connect(_on_cancel_pressed)

func _bind_scene_nodes() -> void:
	message_label = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/MessageLabel") as Label
	refund_label = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/RefundLabel") as Label
	confirm_button = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ActionRow/ConfirmButton") as PanelActionButton
	cancel_button = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ActionRow/CancelButton") as PanelActionButton

func _bind_scene_text() -> void:
	message_template = _template_text("MessageTemplate")
	refund_template = _template_text("RefundTemplate")
	fallback_furniture_name = _template_text("FallbackFurnitureName")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("RecycleConfirmPopup scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _on_confirm_pressed() -> void:
	recycle_confirmed.emit(room_id, instance_id)

func _on_cancel_pressed() -> void:
	recycle_cancelled.emit(room_id)

func _furniture_id() -> String:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		if str(instance_data.get("instance_id", "")) == instance_id:
			return str(instance_data.get("furniture_id", ""))
	return ""
