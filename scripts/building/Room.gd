extends Button

const DEFAULT_ROOM_WIDTH := 224.0
const DEFAULT_ROOM_HEIGHT := 88.0

const META_TENANT_SCENE_PATH := &"tenant_scene_path"
const META_FURNITURE_SCENE_PATH := &"furniture_scene_path"
const META_DEFAULT_ROOM_SIZE := &"default_room_size"
const META_DEFAULT_GRID_RECT := &"default_grid_rect"
const META_WALL_INSET := &"wall_inset"
const META_FLOOR_HEIGHT := &"floor_height"
const META_TENANT_OFFSET := &"tenant_offset"
const META_ROOF_HEIGHT := &"roof_height"

var tenant_scene: PackedScene
var furniture_scene: PackedScene
var default_room_size := Vector2(DEFAULT_ROOM_WIDTH, DEFAULT_ROOM_HEIGHT)
var default_grid_rect := Rect2(21.0, 24.0, 187.0, 40.0)
var wall_inset := 9.0
var floor_height := 22.0
var tenant_offset := Vector2(166.0, 37.0)
var roof_height := 13.0
var fallback_room_name := ""
var rent_badge_template := ""

var room_id := ""
var show_roof_eaves := false
var room_shell: RoomShell
var visual_layer: Control
var placement_grid_layer: Control
var placement_active := false
var placement_furniture_id := ""
var placement_grid_pos: Array = [0, 0]
var placement_ignored_instance_id := ""

func _ready() -> void:
	_bind_scene_config()
	custom_minimum_size = _room_size()
	clip_contents = true
	clip_text = true
	text = ""
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_ensure_shell()
	if not room_id.is_empty():
		_rebuild()

func setup(id: String, has_roof_eaves := false) -> void:
	room_id = id
	show_roof_eaves = has_roof_eaves
	if is_inside_tree():
		_rebuild()

func _rebuild() -> void:
	_bind_scene_config()
	_ensure_shell()
	if room_shell == null:
		return
	text = ""
	custom_minimum_size = _room_size()
	size = custom_minimum_size
	var room: Dictionary = GameState.rooms.get(room_id, {})
	room_shell.apply_layout(size, wall_inset, floor_height, roof_height)
	room_shell.clear_dynamic_views()
	room_shell.set_roof_visible(show_roof_eaves)
	_apply_room_badges(room)
	_bind_visual_layer(room)
	_bind_placement_grid_layer()

func _ensure_shell() -> void:
	room_shell = get_node_or_null("RoomShell") as RoomShell
	if room_shell == null:
		push_error("Room.tscn must expose a RoomShell child.")

func _apply_room_badges(room: Dictionary) -> void:
	var room_name := str(room.get("room_name", "")).strip_edges()
	room_shell.name_badge.text = room_name if not room_name.is_empty() else fallback_room_name
	if rent_badge_template.is_empty():
		room_shell.rent_badge.text = ""
	else:
		room_shell.rent_badge.text = rent_badge_template % [int(room.get("score", 0)), float(room.get("rent_per_minute", 0.0))]

func _bind_visual_layer(room: Dictionary) -> void:
	visual_layer = room_shell.visual_layer
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		_add_furniture_view(instance_data, room)

	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		return
	if tenant_scene == null:
		push_error("Room.tscn must assign a tenant_scene template.")
		return
	var tenant_view := tenant_scene.instantiate()
	tenant_view.name = "Tenant_%s" % tenant_id
	tenant_view.position = _tenant_position()
	visual_layer.add_child(tenant_view)
	tenant_view.setup(tenant_id, room_id)

func _bind_placement_grid_layer() -> void:
	placement_grid_layer = room_shell.placement_grid_layer
	if not placement_grid_layer.draw.is_connected(_draw_placement_grid):
		placement_grid_layer.draw.connect(_draw_placement_grid)
	placement_grid_layer.visible = placement_active

func show_placement_grid(active: bool, target_furniture_id := "", target_grid_pos := [0, 0], ignored_instance_id := "") -> void:
	placement_active = active
	placement_furniture_id = target_furniture_id
	placement_grid_pos = target_grid_pos
	placement_ignored_instance_id = ignored_instance_id
	if placement_grid_layer != null:
		placement_grid_layer.visible = active
		placement_grid_layer.queue_redraw()

func global_position_to_grid(viewport_position: Vector2) -> Array:
	var local := get_global_transform().affine_inverse() * viewport_position
	var rect := _grid_rect()
	if not rect.has_point(local):
		return []
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var room_grid: Array = room.get("grid_size", [8, 5])
	var columns := maxi(1, int(room_grid[0]))
	var rows := maxi(1, int(room_grid[1]))
	var gx := clampi(int(floor((local.x - rect.position.x) / (rect.size.x / float(columns)))), 0, columns - 1)
	var gy := clampi(int(floor((local.y - rect.position.y) / (rect.size.y / float(rows)))), 0, rows - 1)
	return [gx, gy]

func get_preview_size(furniture_id: String) -> Vector2:
	var furniture_data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	return _furniture_visual_size(furniture_data)

func get_preview_position(furniture_id: String, target_grid_pos: Array) -> Vector2:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var furniture_data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var visual_size := _furniture_visual_size(furniture_data)
	return _furniture_position({"grid_pos": target_grid_pos}, furniture_data, room, visual_size)

func _add_furniture_view(instance_data: Dictionary, room: Dictionary) -> void:
	var furniture_id := str(instance_data.get("furniture_id", ""))
	var furniture_data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	if furniture_data.is_empty():
		return
	if furniture_scene == null:
		push_error("Room.tscn must assign a furniture_scene template.")
		return
	var furniture_view := furniture_scene.instantiate()
	furniture_view.name = "Furniture_%s" % str(instance_data.get("instance_id", furniture_id))
	visual_layer.add_child(furniture_view)
	var view_data := instance_data.duplicate()
	view_data["room_id"] = room_id
	furniture_view.setup(view_data)
	var visual_size := _furniture_visual_size(furniture_data)
	furniture_view.custom_minimum_size = visual_size
	furniture_view.size = visual_size
	furniture_view.position = _furniture_position(instance_data, furniture_data, room, visual_size)
	var grid_pos: Array = instance_data.get("grid_pos", [0, 0])
	furniture_view.z_index = 8 + int(grid_pos[1])

func _furniture_visual_size(furniture_data: Dictionary) -> Vector2:
	var asset_size := _asset_region_size(furniture_data.get("asset", {}))
	var grid_size: Array = furniture_data.get("size", [1, 1])
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var room_grid: Array = room.get("grid_size", [8, 5])
	var rect := _grid_rect()
	var cell_x := rect.size.x / maxf(1.0, float(room_grid[0]))
	var cell_y := rect.size.y / maxf(1.0, float(room_grid[1]))
	var max_width := maxf(16.0, float(grid_size[0]) * cell_x * 1.05)
	var max_height := maxf(15.0, float(grid_size[1]) * cell_y * 1.8)
	if bool(furniture_data.get("wall_item", false)):
		max_width = maxf(14.0, float(grid_size[0]) * cell_x * 0.85)
		max_height = maxf(12.0, float(grid_size[1]) * cell_y * 1.15)
	if asset_size == Vector2.ZERO:
		return Vector2(max_width, max_height)
	var scale := minf(max_width / asset_size.x, max_height / asset_size.y)
	scale = clampf(scale, 0.9, 2.0)
	return Vector2(
		maxf(12.0, asset_size.x * scale),
		maxf(10.0, asset_size.y * scale)
	)

func _furniture_position(instance_data: Dictionary, furniture_data: Dictionary, room: Dictionary, visual_size: Vector2) -> Vector2:
	var grid_pos: Array = instance_data.get("grid_pos", [0, 0])
	var rect := _grid_rect()
	var columns := maxf(1.0, float(room.get("grid_size", [8, 5])[0]))
	var rows := maxf(1.0, float(room.get("grid_size", [8, 5])[1]))
	var gx := clampf(float(grid_pos[0]), 0.0, columns - 1.0)
	var gy := clampf(float(grid_pos[1]), 0.0, rows - 1.0)
	var cell_x := rect.size.x / columns
	var cell_y := rect.size.y / rows
	var x := rect.position.x + gx * cell_x + maxf(0.0, (cell_x - visual_size.x) * 0.5)
	if bool(furniture_data.get("wall_item", false)):
		var wall_y := rect.position.y + gy * minf(cell_y, 20.0)
		return Vector2(x, wall_y)
	var floor_y := rect.position.y + rect.size.y - visual_size.y - 2.0 + gy * 2.0
	return Vector2(x, floor_y)

func _grid_rect() -> Rect2:
	var runtime_room: Dictionary = GameState.rooms.get(room_id, {})
	var runtime_rect: Variant = runtime_room.get("grid_rect", [])
	if runtime_rect is Array and runtime_rect.size() >= 4:
		return Rect2(float(runtime_rect[0]), float(runtime_rect[1]), float(runtime_rect[2]), float(runtime_rect[3]))
	var room_config: Dictionary = ConfigManager.get_room_config(room_id)
	var configured_rect: Variant = room_config.get("grid_rect", [])
	if configured_rect is Array and configured_rect.size() >= 4:
		return Rect2(float(configured_rect[0]), float(configured_rect[1]), float(configured_rect[2]), float(configured_rect[3]))
	var room_size := _room_size()
	var base := Rect2(wall_inset + 12.0, 24.0, room_size.x - wall_inset * 3.0 - 12.0, room_size.y - floor_height - 26.0)
	if room_config.is_empty():
		return default_grid_rect
	return base

func _draw_placement_grid() -> void:
	if not placement_active or placement_grid_layer == null:
		return
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var grid_size: Array = room.get("grid_size", [8, 5])
	var columns := maxi(1, int(grid_size[0]))
	var rows := maxi(1, int(grid_size[1]))
	var rect := _grid_rect()
	var cell := Vector2(rect.size.x / float(columns), rect.size.y / float(rows))
	for y in range(rows):
		for x in range(columns):
			var grid := [x, y]
			var cell_rect := Rect2(rect.position + Vector2(float(x) * cell.x, float(y) * cell.y), cell - Vector2(2, 2))
			var valid := FurniturePlacementRules.can_place_furniture(room_id, placement_furniture_id, grid, placement_ignored_instance_id)
			var color := Color(0.33, 0.9, 0.45, 0.11) if valid else Color(0.95, 0.18, 0.18, 0.12)
			var border := Color(0.33, 0.9, 0.45, 0.72) if valid else Color(0.95, 0.18, 0.18, 0.58)
			placement_grid_layer.draw_rect(cell_rect, color, true)
			placement_grid_layer.draw_rect(cell_rect, border, false, 1.5)
	if placement_grid_pos.size() >= 2:
		var selected_rect := Rect2(
			rect.position + Vector2(float(placement_grid_pos[0]) * cell.x, float(placement_grid_pos[1]) * cell.y),
			cell - Vector2(2, 2)
		)
		placement_grid_layer.draw_rect(selected_rect, Color("#fff4dc"), false, 3.0)

func _room_size() -> Vector2:
	var runtime_room: Dictionary = GameState.rooms.get(room_id, {})
	var runtime_size: Variant = runtime_room.get("room_size", [])
	if runtime_size is Array and runtime_size.size() >= 2:
		return _vector2_from_array(runtime_size, default_room_size)
	var room_config: Dictionary = ConfigManager.get_room_config(room_id)
	return _vector2_from_array(room_config.get("room_size", [default_room_size.x, default_room_size.y]), default_room_size)

func _tenant_position() -> Vector2:
	var room_size := _room_size()
	return Vector2(
		minf(tenant_offset.x, room_size.x - 42.0),
		minf(tenant_offset.y, room_size.y - 48.0)
	)

func _vector2_from_array(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

func _asset_region_size(asset: Dictionary) -> Vector2:
	var asset_type := str(asset.get("type", ""))
	if asset_type == "atlas_region":
		var region: Array = asset.get("region", [])
		if region.size() >= 4:
			return Vector2(float(region[2]), float(region[3]))
	if asset_type == "single_sprite":
		var texture := load(str(asset.get("texture", ""))) as Texture2D
		if texture != null:
			return Vector2(texture.get_width(), texture.get_height())
	return Vector2.ZERO

func _bind_scene_config() -> void:
	var config := get_node_or_null("SceneConfig")
	if config == null:
		push_error("Room.tscn must expose a SceneConfig node.")
		return
	tenant_scene = _scene_from_path(_scene_meta_text(config, META_TENANT_SCENE_PATH), tenant_scene)
	furniture_scene = _scene_from_path(_scene_meta_text(config, META_FURNITURE_SCENE_PATH), furniture_scene)
	default_room_size = _scene_meta_vector2(config, META_DEFAULT_ROOM_SIZE, Vector2(DEFAULT_ROOM_WIDTH, DEFAULT_ROOM_HEIGHT))
	default_grid_rect = _scene_meta_rect2(config, META_DEFAULT_GRID_RECT, Rect2(21.0, 24.0, 187.0, 40.0))
	wall_inset = _scene_meta_float(config, META_WALL_INSET, 9.0)
	floor_height = _scene_meta_float(config, META_FLOOR_HEIGHT, 22.0)
	tenant_offset = _scene_meta_vector2(config, META_TENANT_OFFSET, Vector2(166.0, 37.0))
	roof_height = _scene_meta_float(config, META_ROOF_HEIGHT, 13.0)
	fallback_room_name = _template_text("FallbackRoomName")
	rent_badge_template = _template_text("RentBadgeTemplate")

func _scene_from_path(path: String, fallback: PackedScene) -> PackedScene:
	if path.is_empty():
		return fallback
	var loaded := ResourceLoader.load(path) as PackedScene
	if loaded == null:
		push_warning("Room scene template could not be loaded: %s" % path)
		return fallback
	return loaded

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("Room scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _scene_meta_text(node: Node, meta_key: StringName) -> String:
	if node == null or not node.has_meta(meta_key):
		return ""
	return str(node.get_meta(meta_key)).strip_edges()

func _scene_meta_float(node: Node, meta_key: StringName, fallback: float) -> float:
	if node == null or not node.has_meta(meta_key):
		return fallback
	return float(node.get_meta(meta_key))

func _scene_meta_vector2(node: Node, meta_key: StringName, fallback: Vector2) -> Vector2:
	if node == null or not node.has_meta(meta_key):
		return fallback
	var value: Variant = node.get_meta(meta_key)
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

func _scene_meta_rect2(node: Node, meta_key: StringName, fallback: Rect2) -> Rect2:
	if node == null or not node.has_meta(meta_key):
		return fallback
	var value: Variant = node.get_meta(meta_key)
	if value is Rect2:
		return value
	if value is Array and value.size() >= 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return fallback

func _on_pressed() -> void:
	if UIManager.current_state != UIManager.UIState.NORMAL and UIManager.current_state != UIManager.UIState.ROOM_PANEL:
		return
	if not room_id.is_empty():
		UIManager.open_room_panel(room_id)
