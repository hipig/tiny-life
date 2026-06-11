extends Node

const TILE_SIZE := 16
const DECOR_WALLPAPER := "wallpaper"
const DECOR_WALL := "wall"
const DECOR_DOOR := "door"

var furniture: Array = []
var tenants: Array = []
var tenant_regions: Array = []
var room_decor: Dictionary = {}
var room_decor_items: Array = []
var rooms: Array = []
var floors: Array = []
var tasks: Array = []
var levels: Array = []
var economy: Dictionary = {}
var ui_text: Dictionary = {}
var behavior_aliases: Dictionary = {}
var platform_config: Dictionary = {}

var furniture_by_id: Dictionary = {}
var tenant_by_id: Dictionary = {}
var tenant_region_by_id: Dictionary = {}
var room_decor_by_id: Dictionary = {}
var room_decor_by_category: Dictionary = {}
var floor_by_index: Dictionary = {}
var room_by_id: Dictionary = {}
var level_by_value: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	furniture = _load_json_array("res://data/furniture.json")
	tenants = _load_json_array("res://data/tenants.json")
	tenant_regions = _load_json_array("res://data/tenant_regions.json")
	room_decor = _load_json_dict("res://data/room_decor.json")
	rooms = _load_json_array("res://data/rooms.json")
	floors = _load_json_array("res://data/floors.json")
	tasks = _load_json_array("res://data/tasks.json")
	levels = _load_json_array("res://data/apartment_levels.json")
	economy = _load_json_dict("res://data/economy.json")
	ui_text = _load_json_dict("res://data/ui_text.json")
	behavior_aliases = _load_json_dict("res://data/behavior_aliases.json")
	platform_config = _load_json_dict("res://data/platform_config.json")
	_rebuild_indexes()

func _load_json_array(path: String) -> Array:
	var data: Variant = _load_json(path)
	return data if data is Array else []

func _load_json_dict(path: String) -> Dictionary:
	var data: Variant = _load_json(path)
	return data if data is Dictionary else {}

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Config file does not exist: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Config parse failed: %s" % path)
	return parsed

func _rebuild_indexes() -> void:
	furniture_by_id.clear()
	for item in furniture:
		var furniture_data: Dictionary = item
		furniture_by_id[furniture_data.get("id", "")] = furniture_data
	tenant_by_id.clear()
	for item in tenants:
		var tenant_data: Dictionary = item
		tenant_by_id[tenant_data.get("id", "")] = tenant_data
	tenant_region_by_id.clear()
	for item in tenant_regions:
		var region_data: Dictionary = item
		tenant_region_by_id[region_data.get("id", "")] = region_data
	_rebuild_room_decor_indexes()
	floor_by_index.clear()
	for item in floors:
		var floor_data: Dictionary = item
		floor_by_index[int(floor_data.get("floor_index", 0))] = floor_data
	room_by_id.clear()
	for item in rooms:
		var room_data: Dictionary = item
		room_by_id[room_data.get("id", "")] = room_data
	level_by_value.clear()
	for item in levels:
		var level_data: Dictionary = item
		level_by_value[int(level_data.get("level", 0))] = level_data

func get_furniture_data(id: String) -> Dictionary:
	return furniture_by_id.get(id, {})

func get_tenant_data(id: String) -> Dictionary:
	return tenant_by_id.get(id, {})

func get_tenant_region_data(id: String) -> Dictionary:
	return tenant_region_by_id.get(id, {})

func get_room_decor_item(id: String) -> Dictionary:
	return room_decor_by_id.get(id, {})

func get_room_decor_items(category: String) -> Array:
	return room_decor_by_category.get(category, [])

func get_room_decor_id(room: Dictionary, category: String) -> String:
	var field := _room_decor_field_for_category(category)
	if not field.is_empty():
		var runtime_id := str(room.get(field, "")).strip_edges()
		if not runtime_id.is_empty():
			return runtime_id
	var room_config := get_room_config(str(room.get("id", "")))
	var default_field := _room_decor_default_field_for_category(category)
	if default_field.is_empty():
		return ""
	return str(room_config.get(default_field, "")).strip_edges()

func tile_theme_for_room(room: Dictionary) -> Dictionary:
	var theme := {}
	_merge_theme(theme, _wall_theme_from_item(get_room_decor_item(get_room_decor_id(room, DECOR_WALL))))
	_merge_theme(theme, _wallpaper_theme_from_item(get_room_decor_item(get_room_decor_id(room, DECOR_WALLPAPER))))
	return theme

func door_theme_for_room(room: Dictionary) -> Dictionary:
	var item := get_room_decor_item(get_room_decor_id(room, DECOR_DOOR))
	return item.duplicate(true) if not item.is_empty() else {}

func room_decor_field_for_category(category: String) -> String:
	return _room_decor_field_for_category(category)

func room_decor_default_field_for_category(category: String) -> String:
	return _room_decor_default_field_for_category(category)

func get_unlocked_tenant_regions(apartment_level: int) -> Array:
	var result: Array = []
	for item in tenant_regions:
		var region_data: Dictionary = item
		if apartment_level >= int(region_data.get("required_apartment_level", 1)):
			result.append(region_data)
	return result

func get_region_candidate_tenants(region_id: String) -> Array:
	var region: Dictionary = get_tenant_region_data(region_id)
	if region.is_empty():
		return []
	var result: Array = []
	for tenant_id in region.get("tenant_ids", []):
		var tenant_data: Dictionary = get_tenant_data(str(tenant_id))
		if not tenant_data.is_empty():
			result.append(tenant_data)
	return result

func refresh_tenant_applications() -> void:
	for i in range(tenant_regions.size()):
		var region: Dictionary = tenant_regions[i]
		var tenant_ids: Array = region.get("tenant_ids", []).duplicate(true)
		tenant_ids.shuffle()
		region["tenant_ids"] = tenant_ids
		tenant_regions[i] = region
	_rebuild_indexes()

func get_floor_data(index: int) -> Dictionary:
	return floor_by_index.get(index, {})

func get_room_config(id: String) -> Dictionary:
	return room_by_id.get(id, {})

func get_room_configs_for_floor(floor_index: int) -> Array:
	var result: Array = []
	for item in rooms:
		var room_data: Dictionary = item
		if int(room_data.get("floor_index", 0)) == floor_index:
			result.append(room_data)
	return result

func get_room_layout_upgrade(room_id: String, target_level: int) -> Dictionary:
	var room_data := get_room_config(room_id)
	for item in room_data.get("layout_upgrades", []):
		var upgrade: Dictionary = item
		if int(upgrade.get("level", 0)) == target_level:
			return upgrade
	return {}

func get_level_data(level: int) -> Dictionary:
	return level_by_value.get(level, {})

func get_economy_value(key: String, default_value: Variant) -> Variant:
	return economy.get(key, default_value)

func get_tenant_ai_value(key: String, default_value: Variant) -> Variant:
	var tenant_ai: Dictionary = economy.get("tenant_ai", {})
	return tenant_ai.get(key, default_value)

func text(key: String, fallback := "") -> String:
	return str(ui_text.get(key, fallback))

func normalize_behavior_key(value: String, fallback := "") -> String:
	if value.is_empty():
		return fallback
	return str(behavior_aliases.get(value, value))

func furniture_with_tag(tag: String) -> Array:
	var result: Array = []
	for item in furniture:
		var data: Dictionary = item
		if tag in data.get("tags", []):
			result.append(data)
	return result

func _rebuild_room_decor_indexes() -> void:
	room_decor_by_id.clear()
	room_decor_by_category.clear()
	var raw_items: Variant = room_decor.get("items", [])
	room_decor_items = raw_items if raw_items is Array else []
	for item in room_decor_items:
		var decor_data: Dictionary = item
		var decor_id := str(decor_data.get("id", "")).strip_edges()
		if decor_id.is_empty():
			continue
		room_decor_by_id[decor_id] = decor_data
		var category := str(decor_data.get("category", "")).strip_edges()
		if category.is_empty():
			continue
		var list: Array = room_decor_by_category.get(category, [])
		list.append(decor_data)
		room_decor_by_category[category] = list

func _room_decor_field_for_category(category: String) -> String:
	match category:
		DECOR_WALLPAPER:
			return "wallpaper_id"
		DECOR_WALL:
			return "wall_style_id"
		DECOR_DOOR:
			return "door_style_id"
		_:
			return ""

func _room_decor_default_field_for_category(category: String) -> String:
	match category:
		DECOR_WALLPAPER:
			return "default_wallpaper_id"
		DECOR_WALL:
			return "default_wall_style_id"
		DECOR_DOOR:
			return "default_door_style_id"
		_:
			return ""

func _wallpaper_theme_from_item(item: Dictionary) -> Dictionary:
	var theme := {}
	var region := _array_from_config(item.get("wallpaper_region", []))
	if region.size() >= 4:
		var origin := _region_tile_origin(region)
		var columns := maxi(1, int(int(region[2]) / TILE_SIZE))
		var rows := maxi(1, int(int(region[3]) / TILE_SIZE))
		theme["wallpaper_source_id"] = int(item.get("wallpaper_source_id", 2))
		theme["wallpaper_pattern"] = {
			"top": _tile_row(origin.x, origin.y, columns),
			"middle": _tile_row(origin.x, origin.y + mini(1, rows - 1), columns),
			"bottom": _tile_row(origin.x, origin.y + maxi(0, rows - 1), columns)
		}
	var explicit_theme: Variant = item.get("theme", {})
	if explicit_theme is Dictionary:
		_merge_theme(theme, explicit_theme)
	return theme

func _wall_theme_from_item(item: Dictionary) -> Dictionary:
	var theme := {}
	var region := _array_from_config(item.get("wall_region", []))
	if region.size() >= 4:
		var origin := _region_tile_origin(region)
		theme["wall_body_source_id"] = int(item.get("wall_body_source_id", 0))
		theme["body_top_left_corner_tile"] = [origin.x, origin.y]
		theme["body_top_edge_tiles"] = [[origin.x + 2, origin.y]]
		theme["body_top_right_corner_tile"] = [origin.x + 4, origin.y]
		theme["body_left_edge_tiles"] = [[origin.x, origin.y + 1]]
		theme["body_left_door_edge_tiles"] = [[origin.x + 1, origin.y + 1]]
		theme["body_right_door_edge_tiles"] = [[origin.x + 3, origin.y + 1]]
		theme["body_right_edge_tiles"] = [[origin.x + 4, origin.y + 1]]
		theme["body_bottom_left_corner_tile"] = [origin.x, origin.y + 2]
		theme["body_bottom_edge_tiles"] = [[origin.x + 1, origin.y + 2], [origin.x + 2, origin.y + 2], [origin.x + 3, origin.y + 2]]
		theme["body_bottom_right_corner_tile"] = [origin.x + 4, origin.y + 2]
	var explicit_theme: Variant = item.get("theme", {})
	if explicit_theme is Dictionary:
		_merge_theme(theme, explicit_theme)
	return theme

func _merge_theme(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = source[key]

func _region_tile_origin(region: Array) -> Vector2i:
	return Vector2i(int(int(region[0]) / TILE_SIZE), int(int(region[1]) / TILE_SIZE))

func _tile_row(origin_x: int, y: int, columns: int) -> Array:
	var result := []
	for x in range(columns):
		result.append([origin_x + x, y])
	return result

func _array_from_config(value: Variant) -> Array:
	return value if value is Array else []
