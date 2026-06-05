extends Node

var furniture: Array = []
var tenants: Array = []
var rooms: Array = []
var floors: Array = []
var tasks: Array = []
var levels: Array = []
var economy: Dictionary = {}
var ui_text: Dictionary = {}
var platform_config: Dictionary = {}

var furniture_by_id: Dictionary = {}
var tenant_by_id: Dictionary = {}
var floor_by_index: Dictionary = {}
var room_by_id: Dictionary = {}
var level_by_value: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	furniture = _load_json_array("res://data/furniture.json")
	tenants = _load_json_array("res://data/tenants.json")
	rooms = _load_json_array("res://data/rooms.json")
	floors = _load_json_array("res://data/floors.json")
	tasks = _load_json_array("res://data/tasks.json")
	levels = _load_json_array("res://data/apartment_levels.json")
	economy = _load_json_dict("res://data/economy.json")
	ui_text = _load_json_dict("res://data/ui_text.json")
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
		push_warning("配置不存在: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("配置解析失败: %s" % path)
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

func get_floor_data(index: int) -> Dictionary:
	return floor_by_index.get(index, {})

func get_room_config(id: String) -> Dictionary:
	return room_by_id.get(id, {})

func get_level_data(level: int) -> Dictionary:
	return level_by_value.get(level, {})

func get_economy_value(key: String, default_value: Variant) -> Variant:
	return economy.get(key, default_value)

func text(key: String, fallback := "") -> String:
	return str(ui_text.get(key, fallback))

func furniture_with_tag(tag: String) -> Array:
	var result: Array = []
	for item in furniture:
		var data: Dictionary = item
		if tag in data.get("tags", []):
			result.append(data)
	return result
