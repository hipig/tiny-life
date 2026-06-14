class_name BuildingView
extends Control

signal zoom_changed(zoom_scale: float)

const DEFAULT_MAP_SIZE: Vector2 = Vector2(360.0, 640.0)
const RENDER_PIXEL_SCALE: float = 1.0
const APARTMENT_WORLD_SCALE: float = 1.0
const MIN_ZOOM: float = 0.7
const MAX_ZOOM: float = 2.0
const ZOOM_STEP: float = 0.1
const PLACEMENT_FOCUS_ZOOM: float = 1.6
const PLACEMENT_FOCUS_SECONDS: float = 0.2
const FOCUS_ATTEMPTS: int = 3
const NORMAL_TOP_MIN: float = 44.0
const DEFAULT_GROUND_BAND_HEIGHT: float = 48.0
const BUILDING_GROUND_OVERLAP: float = 4.0
const BUILDING_VERTICAL_OFFSET_TILES: int = 1
const FOCUS_SCREEN_ANCHOR: Vector2 = Vector2(0.5, 0.58)
const TOUCH_PINCH_MIN_DISTANCE: float = 8.0

const TENANT_SCENE := preload("res://scenes/tenant/Tenant.tscn")

enum CameraInputMode {
	BLOCKED,
	NORMAL,
	PLACEMENT
}

@onready var world_clip: SubViewportContainer = $WorldClip
@onready var world_viewport: SubViewport = $WorldClip/WorldViewport
@onready var world_root: Node2D = $WorldClip/WorldViewport/WorldRoot
@onready var scene_backdrop: SceneBackdrop = $WorldClip/WorldViewport/WorldRoot/SceneBackdrop
@onready var building_root: ApartmentBuilding = $WorldClip/WorldViewport/WorldRoot/ApartmentBuilding
@onready var tenant_world_layer: Node2D = $WorldClip/WorldViewport/WorldRoot/TenantWorldLayer
@onready var left_offscreen_marker: Marker2D = $WorldClip/WorldViewport/WorldRoot/TenantRouteMarkers/LeftOffscreenMarker
@onready var world_camera: Camera2D = $WorldClip/WorldViewport/WorldRoot/WorldCamera

var zoom_scale: float = 1.0
var world_base_size: Vector2 = DEFAULT_MAP_SIZE
var camera_bounds: Rect2 = Rect2(Vector2.ZERO, DEFAULT_MAP_SIZE)
var effective_min_zoom: float = MIN_ZOOM
var is_dragging_view: bool = false
var _camera_initialized: bool = false
var _active_touch_points: Dictionary = {}
var _pinch_distance: float = 0.0
var _pinch_center: Vector2 = Vector2.ZERO
var _focus_tween: Tween

func _ready() -> void:
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	world_camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if handle_camera_input(event):
		get_viewport().set_input_as_handled()

func handle_camera_input(event: InputEvent, screen_position_override: Vector2 = Vector2.INF) -> bool:
	var input_mode := _camera_input_mode()
	if input_mode == CameraInputMode.BLOCKED:
		_clear_camera_gesture_state()
		return false
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton, screen_position_override, input_mode)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion, screen_position_override, input_mode)
	if event is InputEventScreenTouch:
		return _handle_screen_touch(event as InputEventScreenTouch, screen_position_override, input_mode)
	if event is InputEventScreenDrag:
		return _handle_screen_drag(event as InputEventScreenDrag, screen_position_override, input_mode)
	if event is InputEventMagnifyGesture:
		return _handle_magnify_gesture(event as InputEventMagnifyGesture, screen_position_override)
	if event is InputEventPanGesture:
		return _handle_pan_gesture(event as InputEventPanGesture, screen_position_override, input_mode)
	return false

func refresh() -> void:
	if building_root == null:
		return
	building_root.refresh()
	_layout_world()
	_ensure_tenant_views()
	zoom_changed.emit(zoom_scale)

func zoom_by(delta: float, anchor_viewport_position: Vector2 = Vector2.INF) -> void:
	_cancel_focus_tween()
	set_zoom(zoom_scale + delta, anchor_viewport_position)

func set_zoom(value: float, anchor_viewport_position: Vector2 = Vector2.INF) -> void:
	if world_camera == null:
		return
	var next_zoom: float = clampf(value, get_min_zoom_scale(), MAX_ZOOM)
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

func get_min_zoom_scale() -> float:
	return effective_min_zoom

func get_camera_bounds() -> Rect2:
	return camera_bounds

func get_visible_world_size() -> Vector2:
	return _visible_world_size()

static func calculate_min_zoom_for_bounds(viewport_size: Vector2, bounds_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or bounds_size.x <= 0.0 or bounds_size.y <= 0.0:
		return 1.0
	return maxf(viewport_size.x / bounds_size.x, viewport_size.y / bounds_size.y)

func focus_room(room_id: String) -> void:
	call_deferred("_focus_room_deferred", room_id, 0)

func clear_focus() -> void:
	_cancel_focus_tween()
	_layout_world(false)
	_clamp_camera()

func clear_camera_gesture_state() -> void:
	_clear_camera_gesture_state()

func find_room_node(room_id: String) -> Control:
	if building_root == null:
		return null
	return building_root.find_room_node(room_id)

func get_tenant_world_layer() -> Node2D:
	return tenant_world_layer

func get_room_visual_layer(room_id: String) -> Control:
	var room_node := find_room_node(room_id)
	if room_node != null and room_node.has_method("get_room_visual_layer"):
		return room_node.call("get_room_visual_layer") as Control
	return null

func get_room_door(room_id: String) -> TrafficDoor:
	var room_node := find_room_node(room_id)
	if room_node != null and room_node.has_method("get_room_door"):
		return room_node.call("get_room_door") as TrafficDoor
	return null

func get_room_door_world_position(room_id: String) -> Vector2:
	var room_node := find_room_node(room_id)
	if room_node != null and room_node.has_method("get_room_door_world_position"):
		return room_node.call("get_room_door_world_position")
	return Vector2.ZERO

func get_room_spawn_local_position(room_id: String) -> Vector2:
	var room_node := find_room_node(room_id)
	if room_node != null and room_node.has_method("get_room_spawn_local_position"):
		return room_node.call("get_room_spawn_local_position")
	return Vector2.ZERO

func get_room_spawn_world_position(room_id: String) -> Vector2:
	var room_node := find_room_node(room_id)
	if room_node != null and room_node.has_method("get_room_spawn_local_position"):
		var room_spawn_local: Variant = room_node.call("get_room_spawn_local_position")
		if room_spawn_local is Vector2:
			return room_node.get_global_transform() * room_spawn_local
	return Vector2.ZERO

func get_floor_service_core(floor_index: int) -> FloorServiceCore:
	if building_root == null:
		return null
	return building_root.find_floor_service_core(floor_index)

func get_service_exit_door() -> TrafficDoor:
	var entry_area := _public_entry_area()
	if entry_area != null and entry_area.has_method("get_exit_door"):
		var entry_door := entry_area.call("get_exit_door") as TrafficDoor
		if entry_door != null:
			return entry_door
	var service := get_floor_service_core(1)
	return service.get_exit_door() if service != null else null

func get_service_elevator_door(floor_index: int) -> TrafficDoor:
	var service := get_floor_service_core(floor_index)
	return service.get_elevator_door() if service != null else null

func get_service_exit_world_position() -> Vector2:
	var entry_area := _public_entry_area()
	if entry_area != null and entry_area.has_method("get_exit_anchor_local_position"):
		var entry_position: Vector2 = entry_area.call("get_exit_anchor_local_position")
		if entry_position != Vector2.ZERO:
			return entry_area.get_global_transform() * entry_position
	var service := get_floor_service_core(1)
	if service == null:
		return Vector2.ZERO
	return service.get_global_transform() * service.get_exit_anchor_local_position()

func get_service_elevator_world_position(floor_index: int) -> Vector2:
	var service := get_floor_service_core(floor_index)
	if service == null:
		return get_service_exit_world_position()
	return service.get_global_transform() * service.get_elevator_anchor_local_position()

func get_offscreen_left_world_position(y: float) -> Vector2:
	return get_left_offscreen_route_mark_world_position(y)

func get_tenant_entry_start_world_position(target_room_id: String) -> Vector2:
	return resolve_route_start_world_position(target_room_id, GameState.TENANT_PRESENCE_RETURNING)

func resolve_route_start_world_position(room_id: String, presence: String) -> Vector2:
	var safe_position := _first_valid_route_world_position(_route_start_candidates(room_id, presence))
	if _is_valid_route_world_position(safe_position):
		return safe_position
	var fallback_y := _route_fallback_y(room_id)
	return get_offscreen_left_world_position(fallback_y)

func get_left_offscreen_route_mark_world_position(y: float) -> Vector2:
	var marker_position := Vector2(_visible_world_left() - _tenant_route_offscreen_margin(), y)
	if left_offscreen_marker == null:
		push_error("BuildingView.tscn must expose TenantRouteMarkers/LeftOffscreenMarker.")
		return marker_position
	return marker_position

func _public_entry_area() -> Control:
	if building_root == null:
		return null
	var floor_node = building_root.get_floor_node(1)
	if floor_node == null:
		return null
	for child in floor_node.get_active_public_areas():
		var area := child as Control
		if area != null and area.has_method("get_exit_door") and area.call("get_exit_door") != null:
			return area
	return null

func screen_to_world_viewport_position(screen_position: Vector2) -> Vector2:
	if world_clip == null:
		return screen_position
	return (screen_position - world_clip.get_global_rect().position) / RENDER_PIXEL_SCALE

func screen_to_world_position(screen_position: Vector2) -> Vector2:
	return _screen_to_world(screen_to_world_viewport_position(screen_position))

func world_to_screen_position(world_position: Vector2) -> Vector2:
	if world_clip == null:
		return world_position
	return world_clip.get_global_rect().position + _world_to_viewport(world_position) * RENDER_PIXEL_SCALE

func _on_resized() -> void:
	_layout_world()
	zoom_changed.emit(zoom_scale)

func _layout_world(clamp_camera: bool = true) -> void:
	if building_root == null or scene_backdrop == null or world_camera == null:
		return
	var building_size: Vector2 = building_root.get_building_size()
	var building_world_size: Vector2 = building_size * APARTMENT_WORLD_SCALE
	world_base_size = _world_size_for_content(building_world_size)
	camera_bounds = Rect2(Vector2.ZERO, world_base_size)
	effective_min_zoom = clampf(calculate_min_zoom_for_bounds(_viewport_size(), camera_bounds.size), MIN_ZOOM, MAX_ZOOM)
	zoom_scale = clampf(zoom_scale, effective_min_zoom, MAX_ZOOM)
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
	_ensure_tenant_views()

func _building_position_in_world(building_size: Vector2, current_world_size: Vector2) -> Vector2:
	var ground_band: float = _ground_band_height()
	var y: float = current_world_size.y - ground_band - building_size.y + BUILDING_GROUND_OVERLAP
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

func _focus_room_deferred(room_id: String, attempt: int = 0) -> void:
	var room_node: Control = find_room_node(room_id)
	if room_node == null:
		if attempt < FOCUS_ATTEMPTS:
			call_deferred("_focus_room_deferred", room_id, attempt + 1)
		return
	_layout_world(false)
	var target_zoom := maxf(zoom_scale, PLACEMENT_FOCUS_ZOOM)
	target_zoom = clampf(target_zoom, get_min_zoom_scale(), MAX_ZOOM)
	var previous_zoom := zoom_scale
	zoom_scale = target_zoom
	world_camera.zoom = Vector2.ONE * zoom_scale
	var room_center: Vector2 = room_node.get_global_transform() * (room_node.size * 0.5)
	var desired_screen_position: Vector2 = _viewport_size() * FOCUS_SCREEN_ANCHOR
	var target_position := _clamped_camera_position(_camera_position_for_anchor(room_center, desired_screen_position))
	zoom_scale = previous_zoom
	world_camera.zoom = Vector2.ONE * zoom_scale
	_start_focus_tween(target_zoom, target_position)

func _start_focus_tween(target_zoom: float, target_position: Vector2) -> void:
	if world_camera == null:
		return
	_cancel_focus_tween()
	_focus_tween = create_tween()
	_focus_tween.set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_QUAD)
	_focus_tween.set_ease(Tween.EASE_OUT)
	_focus_tween.tween_method(_apply_focus_zoom, zoom_scale, target_zoom, PLACEMENT_FOCUS_SECONDS)
	_focus_tween.tween_property(world_camera, "position", target_position, PLACEMENT_FOCUS_SECONDS)

func _apply_focus_zoom(value: float) -> void:
	zoom_scale = clampf(value, get_min_zoom_scale(), MAX_ZOOM)
	world_camera.zoom = Vector2.ONE * zoom_scale
	_clamp_camera()
	zoom_changed.emit(zoom_scale)

func _cancel_focus_tween() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = null

func _ensure_tenant_views() -> void:
	if tenant_world_layer == null:
		return
	var tenant_views_by_id := _tenant_views_by_id()
	for tenant_id_value in GameState.tenants.keys():
		var tenant_id := str(tenant_id_value)
		var tenant_state: Dictionary = GameState.tenants[tenant_id]
		var presence := str(tenant_state.get("presence_state", GameState.TENANT_PRESENCE_HOME))
		var room_id := str(tenant_state.get("room_id", ""))
		var candidates: Array = tenant_views_by_id.get(tenant_id, [])
		if room_id.is_empty():
			_queue_free_tenant_views(candidates)
			continue
		match presence:
			GameState.TENANT_PRESENCE_HOME:
				_ensure_home_tenant_view(tenant_id, room_id, candidates)
			GameState.TENANT_PRESENCE_LEAVING:
				_ensure_leaving_tenant_view(tenant_id, room_id, candidates)
			GameState.TENANT_PRESENCE_AWAY, GameState.TENANT_PRESENCE_RETURNING:
				_ensure_route_tenant_view(tenant_id, room_id, presence, candidates)
			_:
				_queue_free_tenant_views(candidates)
	for tenant_id in tenant_views_by_id.keys():
		if not GameState.tenants.has(str(tenant_id)):
			_queue_free_tenant_views(tenant_views_by_id[tenant_id])

func _ensure_home_tenant_view(tenant_id: String, room_id: String, candidates: Array) -> void:
	var room_layer := get_room_visual_layer(room_id)
	var tenant_view := _select_tenant_view_in_parent(candidates, room_layer)
	if tenant_view != null:
		_queue_free_other_tenant_views(candidates, tenant_view)
		return
	var reusable := _select_existing_tenant_view(candidates)
	var room_node := find_room_node(room_id)
	if room_node == null or not room_node.has_method("ensure_home_tenant_view"):
		_queue_free_tenant_view(reusable)
		return
	var ensured := room_node.call("ensure_home_tenant_view", tenant_id, reusable) as Tenant
	_queue_free_other_tenant_views(candidates, ensured)

func _ensure_leaving_tenant_view(tenant_id: String, room_id: String, candidates: Array) -> void:
	var tenant_view := _select_tenant_view_in_parent(candidates, tenant_world_layer)
	if tenant_view != null:
		_snap_route_tenant_to_safe_world_position(tenant_view, room_id, GameState.TENANT_PRESENCE_LEAVING)
		_queue_free_other_tenant_views(candidates, tenant_view)
		return
	var room_layer := get_room_visual_layer(room_id)
	tenant_view = _select_tenant_view_in_parent(candidates, room_layer)
	if tenant_view == null:
		tenant_view = _create_route_tenant_view(tenant_id, room_id, GameState.TENANT_PRESENCE_LEAVING)
	_queue_free_other_tenant_views(candidates, tenant_view)

func _ensure_route_tenant_view(tenant_id: String, room_id: String, presence: String, candidates: Array) -> void:
	var tenant_view := _select_tenant_view_in_parent(candidates, tenant_world_layer)
	if tenant_view == null:
		tenant_view = _select_existing_tenant_view(candidates)
	if tenant_view == null:
		tenant_view = _create_route_tenant_view(tenant_id, room_id, presence)
	else:
		_move_tenant_to_world_layer(tenant_view)
		_snap_route_tenant_to_safe_world_position(tenant_view, room_id, presence)
	_queue_free_other_tenant_views(candidates, tenant_view)

func _create_route_tenant_view(tenant_id: String, room_id: String, presence: String) -> Tenant:
	var tenant_view := TENANT_SCENE.instantiate() as Tenant
	if tenant_view == null:
		return null
	tenant_view.name = "Tenant_%s" % tenant_id
	var route_start := resolve_route_start_world_position(room_id, presence)
	tenant_view.visible = false
	tenant_view.position = route_start
	tenant_view.ai_position_initialized = true
	tenant_world_layer.add_child(tenant_view)
	tenant_view.visible = presence != GameState.TENANT_PRESENCE_AWAY
	tenant_view.setup(tenant_id, room_id)
	return tenant_view

func _snap_route_tenant_to_safe_world_position(tenant_view: Tenant, room_id: String, presence: String) -> void:
	if not _tenant_view_is_available(tenant_view) or _is_valid_route_world_position(tenant_view.global_position):
		return
	tenant_view.global_position = resolve_route_start_world_position(room_id, presence)
	tenant_view.ai_position_initialized = true

func _route_start_candidates(room_id: String, presence: String) -> Array:
	var floor_index := _room_floor_index(room_id)
	var candidates: Array = []
	match presence:
		GameState.TENANT_PRESENCE_LEAVING:
			if floor_index > 1:
				candidates.append(get_service_elevator_world_position(floor_index))
			candidates.append(get_room_door_world_position(room_id))
			candidates.append(get_room_spawn_world_position(room_id))
			candidates.append(get_service_exit_world_position())
		GameState.TENANT_PRESENCE_AWAY, GameState.TENANT_PRESENCE_RETURNING:
			candidates.append(get_service_exit_world_position())
			if floor_index > 1:
				candidates.append(get_service_elevator_world_position(1))
			candidates.append(get_room_door_world_position(room_id))
			candidates.append(get_room_spawn_world_position(room_id))
		_:
			candidates.append(get_room_spawn_world_position(room_id))
			candidates.append(get_room_door_world_position(room_id))
	return candidates

func _route_fallback_y(room_id: String) -> float:
	var safe_reference := _first_valid_route_world_position([
		get_room_spawn_world_position(room_id),
		get_room_door_world_position(room_id),
		get_service_exit_world_position(),
		get_service_elevator_world_position(_room_floor_index(room_id))
	])
	if _is_valid_route_world_position(safe_reference):
		return safe_reference.y
	return _default_camera_position().y

func _first_valid_route_world_position(candidates: Array) -> Vector2:
	for candidate in candidates:
		if candidate is Vector2 and _is_valid_route_world_position(candidate):
			return candidate
	return Vector2.INF

func _room_floor_index(room_id: String) -> int:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	return maxi(1, int(room.get("floor_index", 1)))

func _is_valid_route_world_position(position: Vector2) -> bool:
	return is_finite(position.x) and is_finite(position.y) and not position.is_equal_approx(Vector2.ZERO)

func _tenant_views_by_id() -> Dictionary:
	var result := {}
	var tree := get_tree()
	if tree == null:
		return result
	for node in tree.get_nodes_in_group(Tenant.TENANT_VIEW_GROUP):
		var tenant_view := node as Tenant
		if not _tenant_view_is_available(tenant_view):
			continue
		var tenant_id := _tenant_id_for_view(tenant_view)
		if tenant_id.is_empty():
			continue
		if not result.has(tenant_id):
			result[tenant_id] = []
		(result[tenant_id] as Array).append(tenant_view)
	return result

func _tenant_id_for_view(tenant_view: Tenant) -> String:
	if tenant_view.has_meta(Tenant.META_TENANT_ID):
		return str(tenant_view.get_meta(Tenant.META_TENANT_ID))
	return tenant_view.tenant_id

func _select_tenant_view_in_parent(candidates: Array, parent: Node) -> Tenant:
	if parent == null:
		return null
	for candidate in candidates:
		var tenant_view := candidate as Tenant
		if _tenant_view_is_available(tenant_view) and tenant_view.get_parent() == parent:
			return tenant_view
	return null

func _select_existing_tenant_view(candidates: Array) -> Tenant:
	for candidate in candidates:
		var tenant_view := candidate as Tenant
		if _tenant_view_is_available(tenant_view):
			return tenant_view
	return null

func _move_tenant_to_world_layer(tenant_view: Tenant) -> void:
	if tenant_view == null or tenant_view.get_parent() == tenant_world_layer:
		return
	var current_global_position := tenant_view.global_position
	var parent := tenant_view.get_parent()
	if parent != null:
		parent.remove_child(tenant_view)
	tenant_world_layer.add_child(tenant_view)
	tenant_view.global_position = current_global_position

func _queue_free_other_tenant_views(candidates: Array, kept: Tenant) -> void:
	for candidate in candidates:
		var tenant_view := candidate as Tenant
		if tenant_view == kept:
			continue
		_queue_free_tenant_view(tenant_view)

func _queue_free_tenant_views(candidates: Array) -> void:
	for candidate in candidates:
		_queue_free_tenant_view(candidate as Tenant)

func _queue_free_tenant_view(tenant_view: Tenant) -> void:
	if _tenant_view_is_available(tenant_view):
		tenant_view.queue_free()

func _tenant_view_is_available(tenant_view: Tenant) -> bool:
	return tenant_view != null and is_instance_valid(tenant_view) and not tenant_view.is_queued_for_deletion()

func _pan_camera(delta_world: Vector2) -> void:
	if world_camera == null:
		return
	_cancel_focus_tween()
	world_camera.position += delta_world
	_clamp_camera()

func _handle_mouse_button(event: InputEventMouseButton, screen_position_override: Vector2, input_mode: int) -> bool:
	var screen_position := _event_screen_position(event, screen_position_override)
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not event.pressed or _screen_position_blocks_camera(screen_position):
			return false
		zoom_by(0.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.08, screen_to_world_viewport_position(screen_position))
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if input_mode != CameraInputMode.NORMAL:
		is_dragging_view = false
		return false
	if event.pressed:
		if _screen_position_blocks_camera(screen_position):
			return false
		is_dragging_view = true
		return true
	is_dragging_view = false
	return true

func _handle_mouse_motion(event: InputEventMouseMotion, screen_position_override: Vector2, input_mode: int) -> bool:
	if input_mode != CameraInputMode.NORMAL or not is_dragging_view:
		return false
	var screen_position := _event_screen_position(event, screen_position_override)
	if _screen_position_blocks_camera(screen_position):
		is_dragging_view = false
		return false
	_pan_camera(-event.relative / maxf(zoom_scale * RENDER_PIXEL_SCALE, 0.001))
	return true

func _handle_screen_touch(event: InputEventScreenTouch, screen_position_override: Vector2, input_mode: int) -> bool:
	var screen_position := _event_screen_position(event, screen_position_override)
	if event.pressed:
		if _screen_position_blocks_camera(screen_position):
			return false
		_active_touch_points[event.index] = screen_position
		_refresh_pinch_reference()
		return input_mode == CameraInputMode.NORMAL or _active_touch_points.size() >= 2
	var had_touch := _active_touch_points.has(event.index)
	_active_touch_points.erase(event.index)
	_refresh_pinch_reference()
	return had_touch

func _handle_screen_drag(event: InputEventScreenDrag, screen_position_override: Vector2, input_mode: int) -> bool:
	var screen_position := _event_screen_position(event, screen_position_override)
	if not _active_touch_points.has(event.index):
		if input_mode == CameraInputMode.NORMAL and not _screen_position_blocks_camera(screen_position):
			_pan_camera(-event.relative / maxf(zoom_scale * RENDER_PIXEL_SCALE, 0.001))
			return true
		return false
	_active_touch_points[event.index] = screen_position
	if _active_touch_points.size() >= 2:
		_apply_touch_pinch()
		return true
	if input_mode == CameraInputMode.NORMAL:
		_pan_camera(-event.relative / maxf(zoom_scale * RENDER_PIXEL_SCALE, 0.001))
		return true
	return false

func _handle_magnify_gesture(event: InputEventMagnifyGesture, screen_position_override: Vector2) -> bool:
	var screen_position := _event_screen_position(event, screen_position_override)
	if _screen_position_blocks_camera(screen_position):
		return false
	zoom_by((event.factor - 1.0) * 0.8, screen_to_world_viewport_position(screen_position))
	return true

func _handle_pan_gesture(event: InputEventPanGesture, screen_position_override: Vector2, input_mode: int) -> bool:
	if input_mode == CameraInputMode.BLOCKED:
		return false
	if _screen_position_blocks_camera(_event_screen_position(event, screen_position_override)):
		return false
	_pan_camera(event.delta / maxf(zoom_scale * RENDER_PIXEL_SCALE, 0.001))
	return true

func _apply_touch_pinch() -> void:
	var metrics := _current_touch_metrics()
	var next_distance: float = metrics.get("distance", 0.0)
	var next_center: Vector2 = metrics.get("center", _pinch_center)
	if _pinch_distance >= TOUCH_PINCH_MIN_DISTANCE and next_distance >= TOUCH_PINCH_MIN_DISTANCE:
		var previous_center := _pinch_center
		var zoom_ratio := next_distance / maxf(_pinch_distance, 0.001)
		set_zoom(zoom_scale * zoom_ratio, screen_to_world_viewport_position(next_center))
		var center_delta := next_center - previous_center
		_pan_camera(-center_delta / maxf(zoom_scale * RENDER_PIXEL_SCALE, 0.001))
	_pinch_distance = next_distance
	_pinch_center = next_center

func _refresh_pinch_reference() -> void:
	if _active_touch_points.size() < 2:
		_pinch_distance = 0.0
		_pinch_center = Vector2.ZERO
		return
	var metrics := _current_touch_metrics()
	_pinch_distance = metrics.get("distance", 0.0)
	_pinch_center = metrics.get("center", Vector2.ZERO)

func _current_touch_metrics() -> Dictionary:
	var keys := _active_touch_points.keys()
	if keys.size() < 2:
		return {"center": Vector2.ZERO, "distance": 0.0}
	var first: Vector2 = _active_touch_points[keys[0]]
	var second: Vector2 = _active_touch_points[keys[1]]
	return {
		"center": (first + second) * 0.5,
		"distance": first.distance_to(second)
	}

func _event_screen_position(event: InputEvent, screen_position_override: Vector2) -> Vector2:
	if is_finite(screen_position_override.x) and is_finite(screen_position_override.y):
		return screen_position_override
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventGesture:
		return (event as InputEventGesture).position
	return _world_clip_screen_center()

func _screen_position_blocks_camera(screen_position: Vector2) -> bool:
	return not _contains_screen_position(screen_position) or _screen_position_over_hud(screen_position)

func _screen_position_over_hud(screen_position: Vector2) -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var ui_layer := tree.current_scene.get_node_or_null("CanvasLayer_UI")
	if ui_layer == null:
		return false
	for child in ui_layer.get_children():
		if child is Control:
			var control := child as Control
			if control.visible and control.get_global_rect().has_point(screen_position):
				return true
	return false

func _camera_input_mode() -> int:
	if UIManager.blocks_world_camera_input() or _has_blocking_panel():
		return CameraInputMode.BLOCKED
	return CameraInputMode.PLACEMENT if UIManager.is_furniture_placement_state() else CameraInputMode.NORMAL

func _has_blocking_panel() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var popup_layer := tree.current_scene.find_child("PopupLayer", true, false)
	return popup_layer != null and popup_layer.has_method("has_blocking_panel") and bool(popup_layer.call("has_blocking_panel"))

func _clear_camera_gesture_state() -> void:
	is_dragging_view = false
	_active_touch_points.clear()
	_pinch_distance = 0.0
	_pinch_center = Vector2.ZERO

func _camera_position_for_anchor(world_position: Vector2, viewport_position: Vector2) -> Vector2:
	return world_position - (viewport_position - _viewport_center()) / maxf(zoom_scale, 0.001)

func _screen_to_world(viewport_position: Vector2) -> Vector2:
	return world_camera.position + (viewport_position - _viewport_center()) / maxf(zoom_scale, 0.001)

func _world_to_viewport(world_position: Vector2) -> Vector2:
	return _viewport_center() + (world_position - world_camera.position) * maxf(zoom_scale, 0.001)

func _default_camera_position() -> Vector2:
	var visible_size: Vector2 = _visible_world_size()
	var default_bottom := world_base_size.y - _building_vertical_offset_pixels()
	return _clamped_camera_position(Vector2(world_base_size.x * 0.5, default_bottom - visible_size.y * 0.5))

func _apply_camera_limits() -> void:
	world_camera.limit_left = int(floor(camera_bounds.position.x))
	world_camera.limit_top = int(floor(camera_bounds.position.y))
	world_camera.limit_right = int(ceil(camera_bounds.end.x))
	world_camera.limit_bottom = int(ceil(camera_bounds.end.y))

func _clamp_camera() -> void:
	world_camera.position = _clamped_camera_position(world_camera.position)

func _clamped_camera_position(position: Vector2) -> Vector2:
	var half_visible: Vector2 = _visible_world_size() * 0.5
	var min_x: float = camera_bounds.position.x + half_visible.x
	var max_x: float = camera_bounds.end.x - half_visible.x
	var min_y: float = camera_bounds.position.y + half_visible.y
	var max_y: float = camera_bounds.end.y - half_visible.y
	var result: Vector2 = position
	result.x = camera_bounds.get_center().x if min_x > max_x else clampf(result.x, min_x, max_x)
	result.y = camera_bounds.get_center().y if min_y > max_y else clampf(result.y, min_y, max_y)
	return result

func _visible_world_size() -> Vector2:
	return _viewport_size() / maxf(zoom_scale, 0.001)

func _visible_world_left() -> float:
	if world_camera == null:
		return 0.0
	return world_camera.position.x - _visible_world_size().x * 0.5

func _tenant_route_offscreen_margin() -> float:
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("offscreen_margin")))

func _viewport_size() -> Vector2:
	if world_viewport == null:
		return size
	var current_size: Vector2 = Vector2(world_viewport.size)
	if current_size.x <= 1.0 or current_size.y <= 1.0:
		return size.max(Vector2.ONE)
	return current_size

func _viewport_center() -> Vector2:
	return _viewport_size() * 0.5

func _world_clip_screen_center() -> Vector2:
	if world_clip == null:
		return _viewport_center()
	return world_clip.get_global_rect().get_center()

func _ground_band_height() -> float:
	if scene_backdrop == null:
		return DEFAULT_GROUND_BAND_HEIGHT
	return maxf(1.0, scene_backdrop.ground_band_height)

func _building_vertical_offset_pixels() -> float:
	if scene_backdrop != null:
		return scene_backdrop.ground_offset_pixels
	return float(BUILDING_VERTICAL_OFFSET_TILES * ApartmentTileMap.TILE_SIZE)

func _world_size_for_content(building_world_size: Vector2) -> Vector2:
	var viewport_size := _viewport_size()
	var vertical_offset := _building_vertical_offset_pixels()
	var required_width := maxf(DEFAULT_MAP_SIZE.x, viewport_size.x)
	var required_height := maxf(DEFAULT_MAP_SIZE.y + vertical_offset, viewport_size.y)
	required_width = maxf(required_width, building_world_size.x + 48.0)
	required_height = maxf(required_height, building_world_size.y + _ground_band_height() + NORMAL_TOP_MIN + vertical_offset)
	return Vector2(required_width, required_height)

func _contains_screen_position(screen_position: Vector2) -> bool:
	if world_clip == null:
		return true
	return world_clip.get_global_rect().has_point(screen_position)

func _can_use_view_input() -> bool:
	return _camera_input_mode() != CameraInputMode.BLOCKED
