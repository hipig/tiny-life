class_name FurnitureShopPanel
extends "res://scripts/ui/AppPanel.gd"

signal place_requested(furniture_id: String, room_id: String)

var room_id := ""

func open(target_room_id: String) -> void:
	room_id = target_room_id
	var room: Dictionary = GameState.rooms.get(room_id, {})
	setup_panel("为 %s 添加家具" % room.get("room_name", "房间"))
	_refresh_list()

func _refresh_list() -> void:
	for item_data in ConfigManager.furniture:
		var item: Dictionary = item_data
		var row := add_row()
		row.add_child(UIPanelFactory.make_label("%s  %d 金币  评分 +%d" % [item.get("name", ""), int(item.get("price", 0)), _furniture_score(item)]))
		var place := Button.new()
		UIPanelFactory.style_button(place)
		place.text = "摆放" if GameState.coins >= int(item.get("price", 0)) else "金币不足"
		place.disabled = GameState.coins < int(item.get("price", 0))
		var furniture_id := str(item.get("id", ""))
		place.pressed.connect(_on_place_pressed.bind(furniture_id))
		row.add_child(place)

func _furniture_score(data: Dictionary) -> int:
	return int(data.get("comfort", 0)) + int(data.get("entertainment", 0)) + int(data.get("hygiene", 0)) + int(data.get("food", 0))

func _on_place_pressed(furniture_id: String) -> void:
	place_requested.emit(furniture_id, room_id)
