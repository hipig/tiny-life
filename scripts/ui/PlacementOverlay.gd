class_name PlacementOverlay
extends Control

signal new_placement_confirmed(room_id: String, furniture_id: String, grid_pos: Array)
signal move_confirmed(room_id: String, instance_id: String, grid_pos: Array)
signal cancelled(room_id: String)
signal recycle_requested(room_id: String, instance_id: String)

const FURNITURE_PREVIEW_SCENE := preload("res://scenes/furniture/FurniturePreview.tscn")
const FLOATING_CONTROL_MARGIN := 8.0
const FLOATING_CONTROL_OFFSET := Vector2(0.0, -12.0)

var place_title_prefix := ""
var move_title_prefix := ""
var fallback_furniture_name := ""
var place_confirm_text := ""
var move_confirm_text := ""
var place_hint_template := ""
var move_hint_template := ""

var room_id := ""
var furniture_id := ""
var instance_id := ""
var grid_pos: Array = [0, 0]
var is_move := false
var target_room: Button
var preview: FurniturePreview
var dragging_preview := false
var active_touch_index := -1
var active_touch_points: Dictionary = {}

var hint_strip: PanelContainer
var title_label: Label
var hint_label: Label
var floating_controls: FurnitureFloatingControls

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

func _gui_input(event: InputEvent) -> void:
	if target_room == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		var screen_position := mouse_event.global_position
		if _mouse_button_is_camera_event(mouse_event):
			if _input_is_over_floating_ui(screen_position):
				accept_event()
				return
			if _forward_camera_input(event, screen_position):
				accept_event()
			return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_drag(screen_position)
		else:
			if dragging_preview:
				_end_drag(screen_position)
			dragging_preview = false
		accept_event()
	elif event is InputEventMouseMotion and dragging_preview:
		var motion_event := event as InputEventMouseMotion
		_update_drag_preview(motion_event.global_position)
		accept_event()
	elif event is InputEventMagnifyGesture or event is InputEventPanGesture:
		var screen_position := _gesture_screen_position(event)
		if _input_is_over_floating_ui(screen_position):
			accept_event()
			return
		if _forward_camera_input(event, screen_position):
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var screen_position := _overlay_local_to_screen(touch_event.position)
		if _input_is_over_floating_ui(screen_position):
			accept_event()
			return
		if touch_event.pressed:
			active_touch_points[touch_event.index] = screen_position
			_forward_camera_input(event, screen_position)
			if active_touch_points.size() >= 2:
				_pause_preview_drag_for_camera()
			elif _begin_drag(screen_position):
				active_touch_index = touch_event.index
		else:
			var was_multi_touch := active_touch_points.size() >= 2
			_forward_camera_input(event, screen_position)
			active_touch_points.erase(touch_event.index)
			if was_multi_touch:
				_pause_preview_drag_for_camera()
				if active_touch_points.is_empty() and floating_controls != null:
					floating_controls.visible = true
					_position_floating_controls()
			elif touch_event.index == active_touch_index:
				if dragging_preview:
					_end_drag(screen_position)
				dragging_preview = false
				active_touch_index = -1
			elif active_touch_points.is_empty() and floating_controls != null:
				floating_controls.visible = true
				_position_floating_controls()
			if active_touch_points.is_empty():
				active_touch_index = -1
				dragging_preview = false
		accept_event()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		var screen_position := _overlay_local_to_screen(drag_event.position)
		if active_touch_points.has(drag_event.index):
			active_touch_points[drag_event.index] = screen_position
		if active_touch_points.size() >= 2:
			_pause_preview_drag_for_camera()
			_forward_camera_input(event, screen_position)
			accept_event()
			return
		_forward_camera_input(event, screen_position)
		if active_touch_index == -1:
			if not _begin_drag(screen_position):
				accept_event()
				return
			active_touch_index = drag_event.index
		if drag_event.index != active_touch_index:
			return
		dragging_preview = true
		_update_drag_preview(screen_position)
		accept_event()

func _exit_tree() -> void:
	_clear_room_preview()
	active_touch_points.clear()
	var building_view := _building_view()
	if building_view != null and building_view.has_method("clear_camera_gesture_state"):
		building_view.call("clear_camera_gesture_state")

func _build_controls() -> void:
	hint_strip = get_node_or_null("HintStrip") as PanelContainer
	if hint_strip == null:
		push_error("PlacementOverlay scene is missing HintStrip.")
		return

	var box := hint_strip.get_node_or_null("HintBox") as VBoxContainer
	if box == null:
		push_error("PlacementOverlay scene is missing HintBox.")
		return

	title_label = box.get_node_or_null("TitleLabel") as Label
	if title_label == null:
		push_error("PlacementOverlay scene is missing TitleLabel.")
		return

	hint_label = box.get_node_or_null("HintLabel") as Label
	if hint_label == null:
		push_error("PlacementOverlay scene is missing HintLabel.")
		return

	floating_controls = get_node_or_null("FloatingControls") as FurnitureFloatingControls
	if floating_controls == null:
		push_error("PlacementOverlay scene is missing FloatingControls.")
		return
	if not floating_controls.confirmed.is_connected(_on_confirm_pressed):
		floating_controls.confirmed.connect(_on_confirm_pressed)
	if not floating_controls.cancelled.is_connected(_on_cancel_pressed):
		floating_controls.cancelled.connect(_on_cancel_pressed)
	if not floating_controls.recycled.is_connected(_on_recycle_pressed):
		floating_controls.recycled.connect(_on_recycle_pressed)

func _on_cancel_pressed() -> void:
	cancelled.emit(room_id)

func _on_recycle_pressed() -> void:
	if is_move and not instance_id.is_empty():
		recycle_requested.emit(room_id, instance_id)

func _attach_to_room() -> void:
	target_room = _find_room_node()
	if target_room == null:
		return
	if is_move and target_room.has_method("set_furniture_instance_hidden"):
		target_room.call("set_furniture_instance_hidden", instance_id, true)
	if target_room.has_method("show_placement_grid"):
		target_room.call("show_placement_grid", true, furniture_id, grid_pos, instance_id)
	if preview == null:
		preview = FURNITURE_PREVIEW_SCENE.instantiate() as FurniturePreview
		preview.name = "SceneFurniturePreview"
		var visual_layer := target_room.find_child("RoomVisualLayer", true, false) as Control
		if visual_layer != null:
			visual_layer.add_child(preview)

func _refresh(snap_preview := true) -> void:
	_bind_scene_text()
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var valid := _grid_pos_is_valid() and FurniturePlacementRules.can_place_furniture(room_id, furniture_id, grid_pos, instance_id)
	var title_prefix := move_title_prefix if is_move else place_title_prefix
	var furniture_name := str(data.get("name", fallback_furniture_name))
	title_label.text = ("%s %s" % [title_prefix, furniture_name])
	var hint_template := move_hint_template if is_move else place_hint_template
	hint_label.text = _format_name_template(hint_template, furniture_name)
	if floating_controls != null:
		floating_controls.set_confirm_enabled(valid)
		floating_controls.set_recycle_visible(is_move)
	if target_room != null and target_room.has_method("show_placement_grid"):
		target_room.call("show_placement_grid", true, furniture_id, grid_pos, instance_id)
	if preview != null:
		preview.setup(furniture_id, grid_pos, valid)
		if snap_preview and _grid_pos_is_valid() and target_room != null and target_room.has_method("get_preview_position"):
			preview.position = target_room.call("get_preview_position", furniture_id, grid_pos)
			preview.custom_minimum_size = target_room.call("get_preview_size", furniture_id)
			preview.size = preview.custom_minimum_size
		_position_floating_controls()

func _begin_drag(screen_position: Vector2) -> bool:
	if _input_is_over_floating_ui(screen_position):
		return false
	dragging_preview = true
	if floating_controls != null:
		floating_controls.visible = false
	_update_drag_preview(screen_position)
	return true

func _update_drag_preview(screen_position: Vector2, snap_preview := false) -> bool:
	var inside_room := _select_grid(screen_position)
	_refresh(snap_preview and inside_room)
	if not snap_preview or not inside_room:
		_position_preview_under_pointer(screen_position)
		_position_floating_controls()
	return inside_room

func _end_drag(screen_position: Vector2) -> void:
	_update_drag_preview(screen_position, true)
	if floating_controls != null:
		floating_controls.visible = true
		_position_floating_controls()

func _select_grid(viewport_position: Vector2) -> bool:
	if target_room == null:
		return false
	var world_position := _screen_to_room_world_position(viewport_position)
	var next_grid: Array = []
	if target_room.has_method("world_position_to_placement_grid"):
		next_grid = target_room.call("world_position_to_placement_grid", world_position, furniture_id)
	elif target_room.has_method("global_position_to_grid"):
		next_grid = target_room.call("global_position_to_grid", world_position)
	if next_grid.is_empty():
		grid_pos = []
		return false
	grid_pos = next_grid
	return true

func _position_preview_under_pointer(screen_position: Vector2) -> void:
	if preview == null:
		return
	var preview_parent := preview.get_parent() as Control
	if preview_parent == null:
		return
	var world_position := _screen_to_room_world_position(screen_position)
	var local_position := preview_parent.get_global_transform().affine_inverse() * world_position
	preview.position = local_position - preview.size * 0.5

func _on_confirm_pressed() -> void:
	if not _grid_pos_is_valid() or not FurniturePlacementRules.can_place_furniture(room_id, furniture_id, grid_pos, instance_id):
		return
	if is_move:
		move_confirmed.emit(room_id, instance_id, grid_pos)
	else:
		new_placement_confirmed.emit(room_id, furniture_id, grid_pos)

func _find_room_node() -> Button:
	var building_view := _building_view()
	if building_view != null and building_view.has_method("find_room_node"):
		var room_node: Variant = building_view.call("find_room_node", room_id)
		if room_node is Button and _room_node_is_available(room_node):
			return room_node as Button
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var expected_name := "Room_%s" % room_id
	var found := tree.current_scene.find_child(expected_name, true, false)
	if found is Button and _room_node_is_available(found):
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

func _overlay_local_to_screen(local_position: Vector2) -> Vector2:
	return get_global_transform() * local_position

func _input_is_over_floating_ui(screen_position: Vector2) -> bool:
	for control in [floating_controls, hint_strip]:
		if control != null and control.visible and control.get_global_rect().has_point(screen_position):
			return true
	return false

func _mouse_button_is_camera_event(event: InputEventMouseButton) -> bool:
	return event.button_index == MOUSE_BUTTON_WHEEL_UP \
		or event.button_index == MOUSE_BUTTON_WHEEL_DOWN

func _gesture_screen_position(event: InputEvent) -> Vector2:
	if event is InputEventGesture:
		return _overlay_local_to_screen((event as InputEventGesture).position)
	return get_viewport_rect().size * 0.5

func _forward_camera_input(event: InputEvent, screen_position: Vector2) -> bool:
	var building_view := _building_view()
	if building_view != null and building_view.has_method("handle_camera_input"):
		return bool(building_view.call("handle_camera_input", event, screen_position))
	return false

func _pause_preview_drag_for_camera() -> void:
	dragging_preview = false
	active_touch_index = -1
	if floating_controls != null:
		floating_controls.visible = false

func _position_floating_controls() -> void:
	if floating_controls == null:
		return
	floating_controls.reset_size()
	var controls_size := floating_controls.size
	if controls_size.x <= 1.0 or controls_size.y <= 1.0:
		controls_size = floating_controls.get_combined_minimum_size()
	var anchor := _preview_screen_anchor()
	var desired := anchor + FLOATING_CONTROL_OFFSET - Vector2(controls_size.x * 0.5, controls_size.y)
	if desired.y < FLOATING_CONTROL_MARGIN:
		desired.y = anchor.y + 18.0
	floating_controls.position = _clamped_overlay_position(desired, controls_size)

func _preview_screen_anchor() -> Vector2:
	if preview != null:
		var preview_center := preview.get_global_rect().get_center()
		var building_view := _building_view()
		if building_view != null and building_view.has_method("world_to_screen_position"):
			return building_view.call("world_to_screen_position", preview_center)
	return get_viewport_rect().size * 0.5

func _clamped_overlay_position(position: Vector2, control_size: Vector2) -> Vector2:
	var overlay_size := get_viewport_rect().size
	return Vector2(
		clampf(position.x, FLOATING_CONTROL_MARGIN, maxf(FLOATING_CONTROL_MARGIN, overlay_size.x - control_size.x - FLOATING_CONTROL_MARGIN)),
		clampf(position.y, FLOATING_CONTROL_MARGIN, maxf(FLOATING_CONTROL_MARGIN, overlay_size.y - control_size.y - FLOATING_CONTROL_MARGIN))
	)

func _building_view() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.find_child("BuildingView", true, false)

func _room_node_is_available(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()

func _grid_pos_is_valid() -> bool:
	return grid_pos.size() >= 2

func _format_name_template(template: String, value: String) -> String:
	if template.contains("%s"):
		return template % value
	return template

func _clear_room_preview() -> void:
	if target_room != null and target_room.has_method("show_placement_grid"):
		target_room.call("show_placement_grid", false, furniture_id, grid_pos, instance_id)
	if is_move and target_room != null and target_room.has_method("set_furniture_instance_hidden"):
		target_room.call("set_furniture_instance_hidden", instance_id, false)
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null

func _bind_scene_text() -> void:
	place_title_prefix = _template_text("PlaceTitlePrefix")
	move_title_prefix = _template_text("MoveTitlePrefix")
	fallback_furniture_name = _template_text("FallbackFurnitureName")
	place_confirm_text = _template_text("PlaceConfirmText")
	move_confirm_text = _template_text("MoveConfirmText")
	place_hint_template = _template_text("PlaceHintTemplate")
	move_hint_template = _template_text("MoveHintTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("PlacementOverlay scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
