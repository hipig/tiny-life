class_name BuildingView
extends Control

signal zoom_changed(zoom_scale: float)

const FLOOR_SCENE := preload("res://scenes/building/Floor.tscn")
const BUILD_SLOT_SCENE := preload("res://scenes/building/BuildSlot.tscn")
const ROOM_WIDTH := 250.0
const ROOM_HEIGHT := 130.0
const MIN_ZOOM := 0.7
const MAX_ZOOM := 1.4
const ZOOM_STEP := 0.1

@onready var building_scroll: ScrollContainer = $ScrollContainer
@onready var building_zoom_shell: Control = $ScrollContainer/BuildingZoomShell
@onready var building_root: VBoxContainer = $ScrollContainer/BuildingZoomShell/BuildingRoot
@onready var ground_band: ColorRect = $GroundBand

var zoom_scale := 1.0
var is_dragging_view := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	building_root.add_theme_constant_override("separation", 10)
	_apply_zoom()

func _unhandled_input(event: InputEvent) -> void:
	if not _can_use_view_input():
		is_dragging_view = false
		return
	if event is InputEventMagnifyGesture:
		zoom_by((event.factor - 1.0) * 0.8)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(-0.08)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_view = event.pressed
	elif event is InputEventMouseMotion and is_dragging_view:
		building_scroll.scroll_horizontal -= int(event.relative.x)
		building_scroll.scroll_vertical -= int(event.relative.y)
	elif event is InputEventPanGesture:
		building_scroll.scroll_horizontal += int(event.delta.x)
		building_scroll.scroll_vertical += int(event.delta.y)

func refresh() -> void:
	if building_root == null:
		return
	UIPanelFactory.clear_children(building_root)
	for floor_index in range(_max_floor_index(), 0, -1):
		if floor_index <= GameState.highest_built_floor:
			var floor_view := FLOOR_SCENE.instantiate()
			building_root.add_child(floor_view)
			floor_view.setup(floor_index)
		elif floor_index == GameState.highest_built_floor + 1:
			var build_slot := BUILD_SLOT_SCENE.instantiate()
			building_root.add_child(build_slot)
			build_slot.setup(floor_index)
	_apply_zoom()

func zoom_by(delta: float) -> void:
	set_zoom(zoom_scale + delta)

func set_zoom(value: float) -> void:
	var next_zoom := clampf(value, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, zoom_scale):
		_apply_zoom()
		return
	zoom_scale = next_zoom
	_apply_zoom()

func get_zoom_scale() -> float:
	return zoom_scale

func _apply_zoom() -> void:
	if building_root == null:
		return
	var base_size := _calculate_building_base_size()
	building_root.position = Vector2.ZERO
	building_root.scale = Vector2.ONE * zoom_scale
	building_root.custom_minimum_size = base_size
	building_root.size = base_size
	var scaled_size := base_size * zoom_scale
	building_zoom_shell.custom_minimum_size = scaled_size
	building_zoom_shell.size = scaled_size
	building_root.update_minimum_size()
	building_zoom_shell.update_minimum_size()
	zoom_changed.emit(zoom_scale)

func _calculate_building_base_size() -> Vector2:
	var width: float = 560.0
	var height: float = 0.0
	var visible_rows: int = 0
	for floor_index in range(_max_floor_index(), 0, -1):
		if floor_index <= GameState.highest_built_floor:
			var room_count := _room_count_on_floor(floor_index)
			width = maxf(width, 64.0 + float(room_count) * ROOM_WIDTH + float(room_count) * 8.0)
			height += ROOM_HEIGHT
			visible_rows += 1
		elif floor_index == GameState.highest_built_floor + 1:
			height += 100.0
			visible_rows += 1
	if visible_rows > 1:
		height += float(visible_rows - 1) * 10.0
	return Vector2(width, maxf(height, ROOM_HEIGHT))

func _max_floor_index() -> int:
	var max_floor: int = 1
	for floor in ConfigManager.floors:
		var floor_data: Dictionary = floor
		max_floor = maxi(max_floor, int(floor_data.get("floor_index", 1)))
	return max_floor

func _room_count_on_floor(floor_index: int) -> int:
	var count := 0
	for room in ConfigManager.rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) == floor_index:
			count += 1
	return count

func _can_use_view_input() -> bool:
	return UIManager.current_state == UIManager.UIState.NORMAL
