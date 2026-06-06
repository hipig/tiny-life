class_name PlacementOverlay
extends "res://scripts/ui/AppPanel.gd"

signal new_placement_confirmed(room_id: String, furniture_id: String, grid_pos: Array)
signal move_confirmed(room_id: String, instance_id: String, grid_pos: Array)
signal cancelled(room_id: String)

var room_id := ""
var furniture_id := ""
var instance_id := ""
var grid_pos: Array = [0, 0]
var is_move := false

func open_new(target_room_id: String, target_furniture_id: String) -> void:
	room_id = target_room_id
	furniture_id = target_furniture_id
	instance_id = ""
	grid_pos = [0, 0]
	is_move = false
	_refresh()

func open_move(target_room_id: String, target_instance_id: String) -> void:
	room_id = target_room_id
	instance_id = target_instance_id
	var room: Dictionary = GameState.rooms.get(room_id, {})
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		if str(instance_data.get("instance_id", "")) == instance_id:
			furniture_id = str(instance_data.get("furniture_id", ""))
			grid_pos = instance_data.get("grid_pos", [0, 0])
			break
	is_move = true
	_refresh()

func _refresh() -> void:
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	setup_panel(("移动 " if is_move else "摆放 ") + str(data.get("name", "家具")))
	add_text("选择网格位置。绿色为合法，红色为不可摆放。")

	var room: Dictionary = GameState.rooms.get(room_id, {})
	var grid_size: Array = room.get("grid_size", [8, 5])
	var grid := GridContainer.new()
	grid.columns = int(grid_size[0])
	content_root.add_child(grid)
	for y in range(int(grid_size[1])):
		for x in range(int(grid_size[0])):
			var cell := Button.new()
			UIPanelFactory.style_button(cell, Vector2(48, 42))
			cell.text = "%d,%d" % [x, y]
			var valid := FurniturePlacementRules.can_place_furniture(room_id, furniture_id, [x, y], instance_id)
			cell.modulate = Color("#9be7a1") if valid else Color("#f4a3a3")
			cell.disabled = not valid
			cell.pressed.connect(_on_cell_pressed.bind(x, y))
			if grid_pos == [x, y]:
				cell.text = "✓"
			grid.add_child(cell)

	var row := add_row()
	var confirm := Button.new()
	UIPanelFactory.style_button(confirm, Vector2(260, 56))
	confirm.text = "确认移动" if is_move else "确认摆放并扣金币"
	confirm.disabled = not FurniturePlacementRules.can_place_furniture(room_id, furniture_id, grid_pos, instance_id)
	confirm.pressed.connect(_on_confirm_pressed)
	row.add_child(confirm)

	var cancel := Button.new()
	UIPanelFactory.style_button(cancel, Vector2(140, 56))
	cancel.text = "取消"
	cancel.pressed.connect(func(): cancelled.emit(room_id))
	row.add_child(cancel)

func _on_confirm_pressed() -> void:
	if is_move:
		move_confirmed.emit(room_id, instance_id, grid_pos)
	else:
		new_placement_confirmed.emit(room_id, furniture_id, grid_pos)

func _on_cell_pressed(x: int, y: int) -> void:
	grid_pos = [x, y]
	_refresh()
