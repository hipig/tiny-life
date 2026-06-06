class_name RecycleConfirmPopup
extends "res://scripts/ui/AppPanel.gd"

signal recycle_confirmed(room_id: String, instance_id: String)
signal recycle_cancelled(room_id: String)

var room_id := ""
var instance_id := ""

func open(target_room_id: String, target_instance_id: String) -> void:
	room_id = target_room_id
	instance_id = target_instance_id
	setup_panel("确认回收")
	var furniture_id := _furniture_id()
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var refund: int = int(float(data.get("price", 0)) * float(data.get("refund_rate", 0.5)))
	add_text("确认回收 %s？" % data.get("name", "家具"))
	add_text("将返还 %d 金币。" % refund)
	var row := add_row()
	var confirm := Button.new()
	UIPanelFactory.style_button(confirm, Vector2(220, 56))
	confirm.text = "确认回收"
	confirm.pressed.connect(func(): recycle_confirmed.emit(room_id, instance_id))
	row.add_child(confirm)
	var cancel := Button.new()
	UIPanelFactory.style_button(cancel, Vector2(160, 56))
	cancel.text = "取消"
	cancel.pressed.connect(func(): recycle_cancelled.emit(room_id))
	row.add_child(cancel)

func _furniture_id() -> String:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		if str(instance_data.get("instance_id", "")) == instance_id:
			return str(instance_data.get("furniture_id", ""))
	return ""
