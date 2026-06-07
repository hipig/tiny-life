class_name ApartmentBuilding
extends VBoxContainer

const DEFAULT_SERVICE_CORE_WIDTH := 48.0
const DEFAULT_ROOM_WIDTH := 224.0
const DEFAULT_ROOM_HEIGHT := 88.0

@export_group("Scene Templates")
@export var floor_scene: PackedScene
@export var build_slot_scene: PackedScene

@export_group("Expandable Building Layout")
@export var service_core_width := DEFAULT_SERVICE_CORE_WIDTH
@export var default_room_size := Vector2(DEFAULT_ROOM_WIDTH, DEFAULT_ROOM_HEIGHT)

func refresh() -> void:
	UIPanelFactory.clear_children(self)
	for floor_index in range(_max_floor_index(), 0, -1):
		var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
		if floor_index <= GameState.highest_built_floor:
			var built_floor_scene := _scene_from_path(str(floor_data.get("floor_scene_path", "")), floor_scene)
			if built_floor_scene == null:
				push_error("ApartmentBuilding.tscn must assign a floor_scene template.")
				return
			var floor_view := built_floor_scene.instantiate()
			add_child(floor_view)
			floor_view.setup(floor_index, not _has_visible_next_build_slot())
		elif floor_index == GameState.highest_built_floor + 1:
			var next_build_slot_scene := _scene_from_path(str(floor_data.get("build_slot_scene_path", "")), build_slot_scene)
			if next_build_slot_scene == null:
				push_error("ApartmentBuilding.tscn must assign a build_slot_scene template.")
				return
			var build_slot := next_build_slot_scene.instantiate()
			add_child(build_slot)
			build_slot.setup(floor_index)
	var building_size := get_building_size()
	custom_minimum_size = building_size
	size = building_size
	update_minimum_size()

func get_building_size() -> Vector2:
	var width: float = service_core_width + default_room_size.x
	var height: float = 0.0
	for floor_index in range(_max_floor_index(), 0, -1):
		if floor_index <= GameState.highest_built_floor:
			var floor_size := _floor_size(floor_index)
			width = maxf(width, floor_size.x)
			height += floor_size.y
		elif floor_index == GameState.highest_built_floor + 1:
			var build_slot_size := _floor_size(floor_index)
			width = maxf(width, build_slot_size.x)
			height += build_slot_size.y
	return Vector2(width, maxf(height, default_room_size.y))

func find_room_node(room_id: String) -> Control:
	var expected_name := "Room_%s" % room_id
	var found := find_child(expected_name, true, false)
	if found is Control:
		return found as Control
	return null

func _max_floor_index() -> int:
	var max_floor: int = 1
	for floor in ConfigManager.floors:
		var floor_data: Dictionary = floor
		max_floor = maxi(max_floor, int(floor_data.get("floor_index", 1)))
	return max_floor

func _has_visible_next_build_slot() -> bool:
	var next_floor := GameState.highest_built_floor + 1
	var floor_data: Dictionary = ConfigManager.get_floor_data(next_floor)
	if floor_data.is_empty():
		return false
	var required_level := int(floor_data.get("required_apartment_level", 1))
	return GameState.apartment_level >= required_level

func _floor_size(floor_index: int) -> Vector2:
	var floor_height := default_room_size.y
	var floor_width := service_core_width
	var room_count := 0
	for room in ConfigManager.rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) != floor_index:
			continue
		if not _room_is_visible(room_data):
			continue
		var room_size := _room_size(room_data)
		floor_width += room_size.x
		floor_height = maxf(floor_height, room_size.y)
		room_count += 1
	if room_count == 0:
		var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
		var configured: Variant = floor_data.get("room_size", [])
		var slot_room_size := _vector2_from_array(configured, default_room_size)
		floor_width += slot_room_size.x
		floor_height = maxf(floor_height, slot_room_size.y)
	return Vector2(floor_width, floor_height)

func _room_size(room_data: Dictionary) -> Vector2:
	var room_id := str(room_data.get("id", ""))
	var runtime_room: Dictionary = GameState.rooms.get(room_id, {})
	var runtime_size: Variant = runtime_room.get("room_size", [])
	if runtime_size is Array and runtime_size.size() >= 2:
		return _vector2_from_array(runtime_size, default_room_size)
	return _vector2_from_array(room_data.get("room_size", []), default_room_size)

func _room_is_visible(room_data: Dictionary) -> bool:
	var room_id := str(room_data.get("id", ""))
	if room_id.is_empty():
		return false
	var runtime_room: Dictionary = GameState.rooms.get(room_id, {})
	if not runtime_room.is_empty():
		return bool(runtime_room.get("unlocked", false))
	return bool(room_data.get("initial_unlocked", true)) and int(room_data.get("floor_index", 0)) <= GameState.highest_built_floor

func _vector2_from_array(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

func _scene_from_path(path: String, fallback: PackedScene) -> PackedScene:
	if path.is_empty():
		return fallback
	var loaded := ResourceLoader.load(path) as PackedScene
	if loaded == null:
		push_warning("Building scene template could not be loaded: %s" % path)
		return fallback
	return loaded
