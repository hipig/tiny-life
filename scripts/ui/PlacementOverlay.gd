class_name PlacementOverlay
extends Control

signal new_placement_confirmed(room_id: String, furniture_id: String, grid_pos: Array)
signal move_confirmed(room_id: String, instance_id: String, grid_pos: Array)
signal cancelled(room_id: String)

const FURNITURE_PREVIEW_SCENE := preload("res://scenes/furniture/FurniturePreview.tscn")

var place_title_prefix := ""
var move_title_prefix := ""
var fallback_furniture_name := ""
var place_confirm_text := ""
var move_confirm_text := ""

var room_id := ""
var furniture_id := ""
var instance_id := ""
var grid_pos: Array = [0, 0]
var is_move := false
var target_room: Button
var preview: FurniturePreview

var panel: PanelContainer
var title_label: Label
var hint_label: Label
var confirm_button: Button
var cancel_button: Button

func _ready() -> void:
	_bind_scene_text()
	_build_controls()

func open_new(target_room_id: String, target_furniture_id: String) -> void:
	room_id = target_room_id
	furniture_id = target_furniture_id
	instance_id = ""
	is_move = false
	_attach_to_room()
	grid_pos = FurniturePlacementRules.find_first_valid_grid(room_id, furniture_id, instance_id)
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
	_attach_to_room()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if target_room == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_try_select_grid(get_viewport().get_mouse_position())
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_try_select_grid(touch_event.position)
			accept_event()

func _exit_tree() -> void:
	_clear_room_preview()

func _build_controls() -> void:
	panel = get_node_or_null("PlacementControls") as PanelContainer
	if panel == null:
		push_error("PlacementOverlay scene is missing PlacementControls.")
		return

	var box := panel.get_node_or_null("ControlBox") as VBoxContainer
	if box == null:
		push_error("PlacementOverlay scene is missing ControlBox.")
		return

	title_label = box.get_node_or_null("TitleLabel") as Label
	if title_label == null:
		push_error("PlacementOverlay scene is missing TitleLabel.")
		return

	hint_label = box.get_node_or_null("HintLabel") as Label
	if hint_label == null:
		push_error("PlacementOverlay scene is missing HintLabel.")
		return

	var row := box.get_node_or_null("ActionRow") as HBoxContainer
	if row == null:
		push_error("PlacementOverlay scene is missing ActionRow.")
		return

	confirm_button = row.get_node_or_null("ConfirmButton") as Button
	if confirm_button == null:
		push_error("PlacementOverlay scene is missing ConfirmButton.")
		return
	if not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)

	cancel_button = row.get_node_or_null("CancelButton") as Button
	if cancel_button == null:
		push_error("PlacementOverlay scene is missing CancelButton.")
		return
	if not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)

func _on_cancel_pressed() -> void:
	cancelled.emit(room_id)

func _attach_to_room() -> void:
	target_room = _find_room_node()
	if target_room == null:
		return
	if target_room.has_method("show_placement_grid"):
		target_room.call("show_placement_grid", true, furniture_id, grid_pos, instance_id)
	if preview == null:
		preview = FURNITURE_PREVIEW_SCENE.instantiate() as FurniturePreview
		preview.name = "SceneFurniturePreview"
		var visual_layer := target_room.get_node_or_null("RoomVisualLayer") as Control
		if visual_layer != null:
			visual_layer.add_child(preview)

func _refresh() -> void:
	_bind_scene_text()
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var valid := FurniturePlacementRules.can_place_furniture(room_id, furniture_id, grid_pos, instance_id)
	var title_prefix := move_title_prefix if is_move else place_title_prefix
	title_label.text = ("%s %s" % [title_prefix, str(data.get("name", fallback_furniture_name))])
	confirm_button.text = move_confirm_text if is_move else place_confirm_text
	confirm_button.disabled = not valid
	if target_room != null and target_room.has_method("show_placement_grid"):
		target_room.call("show_placement_grid", true, furniture_id, grid_pos, instance_id)
	if preview != null:
		preview.setup(furniture_id, grid_pos, valid)
		if target_room != null and target_room.has_method("get_preview_position"):
			preview.position = target_room.call("get_preview_position", furniture_id, grid_pos)
			preview.custom_minimum_size = target_room.call("get_preview_size", furniture_id)
			preview.size = preview.custom_minimum_size

func _try_select_grid(viewport_position: Vector2) -> void:
	if target_room == null or not target_room.has_method("global_position_to_grid"):
		return
	var next_grid: Array = target_room.call("global_position_to_grid", _screen_to_room_world_position(viewport_position))
	if next_grid.is_empty():
		return
	grid_pos = next_grid
	_refresh()

func _on_confirm_pressed() -> void:
	if not FurniturePlacementRules.can_place_furniture(room_id, furniture_id, grid_pos, instance_id):
		return
	if is_move:
		move_confirmed.emit(room_id, instance_id, grid_pos)
	else:
		new_placement_confirmed.emit(room_id, furniture_id, grid_pos)

func _find_room_node() -> Button:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var expected_name := "Room_%s" % room_id
	var found := tree.current_scene.find_child(expected_name, true, false)
	if found is Button:
		return found as Button
	return null

func _screen_to_room_world_position(screen_position: Vector2) -> Vector2:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return screen_position
	var building_view := tree.current_scene.find_child("BuildingView", true, false)
	if building_view != null and building_view.has_method("screen_to_world_position"):
		return building_view.call("screen_to_world_position", screen_position)
	return screen_position

func _clear_room_preview() -> void:
	if target_room != null and target_room.has_method("show_placement_grid"):
		target_room.call("show_placement_grid", false, furniture_id, grid_pos, instance_id)
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null

func _bind_scene_text() -> void:
	place_title_prefix = _template_text("PlaceTitlePrefix")
	move_title_prefix = _template_text("MoveTitlePrefix")
	fallback_furniture_name = _template_text("FallbackFurnitureName")
	place_confirm_text = _template_text("PlaceConfirmText")
	move_confirm_text = _template_text("MoveConfirmText")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("PlacementOverlay scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
