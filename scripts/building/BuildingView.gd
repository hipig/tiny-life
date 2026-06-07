class_name BuildingView
extends Control

signal zoom_changed(zoom_scale: float)

const DEFAULT_MAP_SIZE: Vector2 = Vector2(360.0, 640.0)
const RENDER_PIXEL_SCALE: float = 1.0
const APARTMENT_WORLD_SCALE: float = 1.0
const MIN_ZOOM: float = 0.7
const MAX_ZOOM: float = 1.4
const ZOOM_STEP: float = 0.1
const FOCUS_EXTRA_BOTTOM_SPACE: float = 108.0
const FOCUS_ATTEMPTS: int = 3
const NORMAL_TOP_MIN: float = 44.0
const DEFAULT_GROUND_BAND_HEIGHT: float = 48.0
const BUILDING_GROUND_OVERLAP: float = 4.0
const FOCUS_SCREEN_ANCHOR: Vector2 = Vector2(0.5, 0.58)

@onready var world_clip: SubViewportContainer = $WorldClip
@onready var world_viewport: SubViewport = $WorldClip/WorldViewport
@onready var world_root: Node2D = $WorldClip/WorldViewport/WorldRoot
@onready var scene_backdrop: SceneBackdrop = $WorldClip/WorldViewport/WorldRoot/SceneBackdrop
@onready var building_root: ApartmentBuilding = $WorldClip/WorldViewport/WorldRoot/ApartmentBuilding
@onready var world_camera: Camera2D = $WorldClip/WorldViewport/WorldRoot/WorldCamera

var zoom_scale: float = 1.0
var world_base_size: Vector2 = DEFAULT_MAP_SIZE
var focus_extra_bottom_space: float = 0.0
var is_dragging_view: bool = false
var _camera_initialized: bool = false

func _ready() -> void:
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	world_camera.make_current()
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not _can_use_view_input():
		is_dragging_view = false
		return
	if event is InputEventMagnifyGesture:
		var gesture: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		zoom_by((gesture.factor - 1.0) * 0.8, _viewport_center())
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not _contains_screen_position(mouse_event.position):
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			zoom_by(0.08, screen_to_world_viewport_position(mouse_event.position))
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			zoom_by(-0.08, screen_to_world_viewport_position(mouse_event.position))
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_view = mouse_event.pressed
	elif event is InputEventMouseMotion and is_dragging_view:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_pan_camera(-motion.relative / maxf(zoom_scale * RENDER_PIXEL_SCALE, 0.001))
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_pan_camera(-drag.relative / maxf(zoom_scale * RENDER_PIXEL_SCALE, 0.001))
	elif event is InputEventPanGesture:
		var pan: InputEventPanGesture = event as InputEventPanGesture
		_pan_camera(pan.delta / maxf(zoom_scale * RENDER_PIXEL_SCALE, 0.001))

func refresh() -> void:
	if building_root == null:
		return
	building_root.refresh()
	_layout_world()
	zoom_changed.emit(zoom_scale)

func zoom_by(delta: float, anchor_viewport_position: Vector2 = Vector2.INF) -> void:
	set_zoom(zoom_scale + delta, anchor_viewport_position)

func set_zoom(value: float, anchor_viewport_position: Vector2 = Vector2.INF) -> void:
	if world_camera == null:
		return
	var next_zoom: float = clampf(value, MIN_ZOOM, MAX_ZOOM)
	var anchor: Vector2 = anchor_viewport_position
	if not is_finite(anchor.x) or not is_finite(anchor.y):
		anchor = _viewport_center()
	var anchor_world: Vector2 = _screen_to_world(anchor)
	zoom_scale = next_zoom
	world_camera.zoom = Vector2.ONE * zoom_scale
	_layout_world(false)
	world_camera.position = _camera_position_for_anchor(anchor_world, anchor)
	_clamp_camera()
	zoom_changed.emit(zoom_scale)

func get_zoom_scale() -> float:
	return zoom_scale

func focus_room(room_id: String) -> void:
	focus_extra_bottom_space = FOCUS_EXTRA_BOTTOM_SPACE
	_layout_world(false)
	call_deferred("_apply_room_focus", room_id, 0)

func clear_focus() -> void:
	if focus_extra_bottom_space <= 0.0:
		return
	focus_extra_bottom_space = 0.0
	_layout_world(false)
	_clamp_camera()

func find_room_node(room_id: String) -> Control:
	if building_root == null:
		return null
	return building_root.find_room_node(room_id)

func screen_to_world_viewport_position(screen_position: Vector2) -> Vector2:
	if world_clip == null:
		return screen_position
	return (screen_position - world_clip.get_global_rect().position) / RENDER_PIXEL_SCALE

func screen_to_world_position(screen_position: Vector2) -> Vector2:
	return _screen_to_world(screen_to_world_viewport_position(screen_position))

func _on_resized() -> void:
	_layout_world()
	zoom_changed.emit(zoom_scale)

func _layout_world(clamp_camera: bool = true) -> void:
	if building_root == null or scene_backdrop == null or world_camera == null:
		return
	var building_size: Vector2 = building_root.get_building_size()
	var building_world_size: Vector2 = building_size * APARTMENT_WORLD_SCALE
	world_base_size = DEFAULT_MAP_SIZE
	building_root.custom_minimum_size = building_size
	building_root.size = building_size
	building_root.scale = Vector2.ONE * APARTMENT_WORLD_SCALE
	building_root.position = _building_position_in_world(building_world_size, world_base_size)
	building_root.visible = true
	world_root.scale = Vector2.ONE
	world_camera.zoom = Vector2.ONE * zoom_scale
	_apply_camera_limits()
	if not _camera_initialized:
		world_camera.position = _default_camera_position()
		_camera_initialized = true
	elif clamp_camera:
		_clamp_camera()

func _building_position_in_world(building_size: Vector2, current_world_size: Vector2) -> Vector2:
	var ground_band: float = _ground_band_height()
	var y: float = current_world_size.y - focus_extra_bottom_space - ground_band - building_size.y + BUILDING_GROUND_OVERLAP
	return Vector2(
		maxf(24.0, (current_world_size.x - building_size.x) * 0.5),
		maxf(NORMAL_TOP_MIN, y)
	)

func _apply_room_focus(room_id: String, attempt: int = 0) -> void:
	var room_node: Control = find_room_node(room_id)
	if room_node == null:
		return
	var room_center: Vector2 = room_node.get_global_transform() * (room_node.size * 0.5)
	var desired_screen_position: Vector2 = _viewport_size() * FOCUS_SCREEN_ANCHOR
	world_camera.position = _camera_position_for_anchor(room_center, desired_screen_position)
	_clamp_camera()
	if attempt < FOCUS_ATTEMPTS:
		call_deferred("_apply_room_focus", room_id, attempt + 1)

func _pan_camera(delta_world: Vector2) -> void:
	if world_camera == null:
		return
	world_camera.position += delta_world
	_clamp_camera()

func _camera_position_for_anchor(world_position: Vector2, viewport_position: Vector2) -> Vector2:
	return world_position - (viewport_position - _viewport_center()) / maxf(zoom_scale, 0.001)

func _screen_to_world(viewport_position: Vector2) -> Vector2:
	return world_camera.position + (viewport_position - _viewport_center()) / maxf(zoom_scale, 0.001)

func _default_camera_position() -> Vector2:
	var visible_size: Vector2 = _visible_world_size()
	return _clamped_camera_position(Vector2(world_base_size.x * 0.5, world_base_size.y - visible_size.y * 0.5))

func _apply_camera_limits() -> void:
	world_camera.limit_left = 0
	world_camera.limit_top = 0
	world_camera.limit_right = int(ceil(world_base_size.x))
	world_camera.limit_bottom = int(ceil(world_base_size.y))

func _clamp_camera() -> void:
	world_camera.position = _clamped_camera_position(world_camera.position)

func _clamped_camera_position(position: Vector2) -> Vector2:
	var half_visible: Vector2 = _visible_world_size() * 0.5
	var min_x: float = half_visible.x
	var max_x: float = world_base_size.x - half_visible.x
	var min_y: float = half_visible.y
	var max_y: float = world_base_size.y - half_visible.y
	var result: Vector2 = position
	result.x = world_base_size.x * 0.5 if min_x > max_x else clampf(result.x, min_x, max_x)
	result.y = world_base_size.y * 0.5 if min_y > max_y else clampf(result.y, min_y, max_y)
	return result

func _visible_world_size() -> Vector2:
	return _viewport_size() / maxf(zoom_scale, 0.001)

func _viewport_size() -> Vector2:
	if world_viewport == null:
		return size
	var current_size: Vector2 = Vector2(world_viewport.size)
	if current_size.x <= 1.0 or current_size.y <= 1.0:
		return size.max(Vector2.ONE)
	return current_size

func _viewport_center() -> Vector2:
	return _viewport_size() * 0.5

func _ground_band_height() -> float:
	if scene_backdrop == null:
		return DEFAULT_GROUND_BAND_HEIGHT
	return maxf(1.0, scene_backdrop.ground_band_height)

func _contains_screen_position(screen_position: Vector2) -> bool:
	if world_clip == null:
		return true
	return world_clip.get_global_rect().has_point(screen_position)

func _can_use_view_input() -> bool:
	return UIManager.current_state == UIManager.UIState.NORMAL
