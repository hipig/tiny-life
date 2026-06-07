class_name RentDetailPanel
extends "res://scripts/ui/AppPanel.gd"

const RENT_ROOM_ROW_SCENE := preload("res://scenes/ui/RentRoomRow.tscn")

var total_rent_card: StatCard
var list_root: VBoxContainer
var total_rent_value_template := "%.1f"

func open() -> void:
	setup_panel("", false)
	total_rent_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TotalRentCard") as StatCard
	list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ListRoot") as VBoxContainer
	total_rent_value_template = _template_text("RentValueTemplate", total_rent_value_template)
	total_rent_card.set_value(total_rent_value_template % GameState.total_rent_per_minute)
	UIPanelFactory.clear_children(list_root)
	for room in GameState.get_unlocked_rooms():
		var room_data: Dictionary = room
		var row := RENT_ROOM_ROW_SCENE.instantiate() as RentRoomRow
		list_root.add_child(row)
		row.setup(room_data)

func _template_text(node_name: String, fallback: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		return fallback
	return template_label.text
