class_name FurnitureShopPanel
extends "res://scripts/ui/AppPanel.gd"

const FURNITURE_SHOP_ITEM_ROW_SCENE := preload("res://scenes/ui/FurnitureShopItemRow.tscn")

signal place_requested(furniture_id: String, room_id: String)

var room_id := ""
var list_root: VBoxContainer

var title_template := ""
var fallback_room_name := ""

func open(target_room_id: String) -> void:
	room_id = target_room_id
	var room: Dictionary = GameState.rooms.get(room_id, {})
	setup_panel("", false)
	list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ListRoot") as VBoxContainer
	_bind_scene_text()
	title_label.text = title_template % room.get("room_name", fallback_room_name)
	_refresh_list()

func _bind_scene_text() -> void:
	title_template = _template_text("TitleTemplate")
	fallback_room_name = _template_text("FallbackRoomName")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("FurnitureShopPanel scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _refresh_list() -> void:
	UIPanelFactory.clear_children(list_root)
	for item_data in ConfigManager.furniture:
		var item: Dictionary = item_data
		var can_buy := GameState.coins >= int(item.get("price", 0))
		var row := FURNITURE_SHOP_ITEM_ROW_SCENE.instantiate() as FurnitureShopItemRow
		list_root.add_child(row)
		row.setup(item, can_buy)
		row.place_requested.connect(_on_place_pressed)

func _on_place_pressed(furniture_id: String) -> void:
	place_requested.emit(furniture_id, room_id)
