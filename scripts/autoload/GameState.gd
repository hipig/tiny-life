extends Node

const SAVE_SCHEMA_VERSION := 3
const DEFAULT_TENANT_BEHAVIOR := "wander"
const RECRUITED_TENANT_BEHAVIOR := "recruited"
const IDLE_TENANT_BEHAVIOR := "idle"
const LEAVING_TENANT_BEHAVIOR := "leaving"
const AWAY_TENANT_BEHAVIOR := "away"
const RETURNING_TENANT_BEHAVIOR := "returning"
const TENANT_PRESENCE_HOME := "home"
const TENANT_PRESENCE_LEAVING := "leaving"
const TENANT_PRESENCE_AWAY := "away"
const TENANT_PRESENCE_RETURNING := "returning"

const VALID_TENANT_BEHAVIORS := {
	"wander": true,
	"recruited": true,
	"idle": true,
	"sleep": true,
	"eat": true,
	"entertainment": true,
	"clean": true,
	"study": true,
	"relax": true,
	"happy": true,
	"leaving": true,
	"away": true,
	"returning": true
}

const VALID_TENANT_PRESENCE := {
	"home": true,
	"leaving": true,
	"away": true,
	"returning": true
}

const ROOM_STATE_KEYS := [
	"id",
	"floor_index",
	"room_name",
	"layout_side",
	"door_side",
	"door_mirrored",
	"door_visual_offset",
	"level",
	"frame_tiles",
	"grid_size",
	"wallpaper_id",
	"wall_style_id",
	"door_style_id",
	"unlocked",
	"tenant_id",
	"furniture_instances",
	"score",
	"comfort",
	"entertainment",
	"hygiene",
	"food",
	"rent_per_minute"
]

const TENANT_STATE_KEYS := [
	"id",
	"satisfaction",
	"current_need",
	"current_behavior",
	"room_id",
	"presence_state",
	"away_until_timestamp",
	"presence_target_room_id"
]

const TASK_STATE_KEYS := [
	"id",
	"progress",
	"completed",
	"claimed"
]

const FURNITURE_INSTANCE_KEYS := [
	"instance_id",
	"furniture_id",
	"grid_pos",
	"mirrored"
]

const STATS_KEYS := [
	"furniture_placed_count",
	"tenant_recruited_count",
	"offline_claimed_count"
]

const SAVE_KEYS := [
	"save_schema_version",
	"coins",
	"total_rent_per_minute",
	"apartment_level",
	"apartment_exp",
	"highest_built_floor",
	"rooms",
	"tenants",
	"tasks",
	"stats",
	"last_save_timestamp"
]

var coins: int = 0
var total_rent_per_minute: float = 0.0
var apartment_level: int = 1
var apartment_exp: int = 0
var highest_built_floor: int = 1
var last_save_timestamp: int = 0

var rooms: Dictionary = {}
var tenants: Dictionary = {}
var tasks: Dictionary = {}
var stats: Dictionary = {}

func _ready() -> void:
	reset_new_game()

func reset_new_game() -> void:
	coins = int(ConfigManager.get_economy_value("starting_coins"))
	total_rent_per_minute = 0.0
	apartment_level = 1
	apartment_exp = 0
	highest_built_floor = _initial_highest_built_floor()
	last_save_timestamp = TimeManager.now_unix()
	rooms = _new_room_states()
	tenants = _new_tenant_states()
	tasks = _new_task_states()
	stats = {
		"furniture_placed_count": 0,
		"tenant_recruited_count": 0,
		"offline_claimed_count": 0
	}

func add_coins(amount: int, source := "generic") -> void:
	if amount == 0:
		return
	coins = max(0, coins + amount)
	GameEvents.coins_changed.emit(coins)
	if amount > 0:
		GameEvents.coin_gain_batched.emit(amount)
		GameEvents.coin_gain_recorded.emit(amount, source)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	GameEvents.coins_changed.emit(coins)
	return true

func add_apartment_exp(amount: int) -> void:
	if amount <= 0:
		return
	apartment_exp += amount
	check_level_up()

func check_level_up() -> void:
	var leveled := false
	while true:
		var next_data: Dictionary = ConfigManager.get_level_data(apartment_level + 1)
		if next_data.is_empty():
			break
		if apartment_exp < int(next_data["required_exp"]):
			break
		apartment_level += 1
		leveled = true
		GameEvents.apartment_level_changed.emit(apartment_level)
	if leveled:
		TaskManager.notify_event("apartment_level_reached", {"level": apartment_level})

func get_room(room_id: String) -> Dictionary:
	if not rooms.has(room_id):
		push_error("Runtime state is missing room '%s'." % room_id)
		return {}
	return rooms[room_id]

func get_unlocked_rooms() -> Array:
	var result: Array = []
	for room in rooms.values():
		var room_data: Dictionary = room
		if bool(room_data["unlocked"]):
			result.append(room_data)
	return result

func get_unlocked_rooms_on_floor(floor_index: int) -> Array:
	var result: Array = []
	for room in rooms.values():
		var room_data: Dictionary = room
		if int(room_data["floor_index"]) == floor_index and bool(room_data["unlocked"]):
			result.append(room_data)
	return result

func unlock_room(room_id: String) -> bool:
	if not rooms.has(room_id):
		push_error("Cannot unlock unknown room '%s'." % room_id)
		return false
	var room: Dictionary = rooms[room_id]
	if bool(room["unlocked"]):
		return false
	room["unlocked"] = true
	rooms[room_id] = room
	GameEvents.room_unlocked.emit(room_id)
	GameEvents.room_updated.emit(room_id)
	return true

func upgrade_room_layout(room_id: String, frame_tiles: Array = [], grid_size: Array = []) -> bool:
	if not rooms.has(room_id):
		push_error("Cannot upgrade unknown room '%s'." % room_id)
		return false
	if frame_tiles.size() < 2 or grid_size.size() < 2:
		push_error("Room layout upgrade for '%s' must provide frame_tiles and grid_size." % room_id)
		return false
	var room: Dictionary = rooms[room_id]
	room["frame_tiles"] = [maxi(2, int(frame_tiles[0])), int(frame_tiles[1])]
	room["grid_size"] = [maxi(1, int(grid_size[0])), int(grid_size[1])]
	rooms[room_id] = room
	GameEvents.room_layout_changed.emit(room_id)
	GameEvents.room_updated.emit(room_id)
	return true

func apply_room_layout_upgrade(room_id: String, target_level := 0) -> bool:
	if not rooms.has(room_id):
		push_error("Cannot upgrade unknown room '%s'." % room_id)
		return false
	var room: Dictionary = rooms[room_id]
	var next_level := target_level
	if next_level <= 0:
		next_level = int(room["level"]) + 1
	var upgrade: Dictionary = ConfigManager.get_room_layout_upgrade(room_id, next_level)
	if upgrade.is_empty():
		return false
	room["level"] = next_level
	rooms[room_id] = room
	return upgrade_room_layout(
		room_id,
		upgrade["frame_tiles"],
		upgrade["grid_size"]
	)

func apply_room_decor(room_id: String, decor_id: String) -> bool:
	if not rooms.has(room_id):
		push_error("Cannot apply decor to unknown room '%s'." % room_id)
		return false
	var room: Dictionary = rooms[room_id]
	var item: Dictionary = ConfigManager.get_room_decor_item(decor_id)
	var category := str(item["category"]).strip_edges()
	var field := ConfigManager.room_decor_field_for_category(category)
	if str(room[field]) == decor_id:
		return false
	room[field] = decor_id
	rooms[room_id] = room
	GameEvents.room_decor_changed.emit(room_id, decor_id, category)
	GameEvents.room_updated.emit(room_id)
	return true

func recalculate_room_stats(room_id: String) -> void:
	if not rooms.has(room_id):
		push_error("Cannot recalculate unknown room '%s'." % room_id)
		return
	var room: Dictionary = rooms[room_id]
	var comfort := 0
	var entertainment := 0
	var hygiene := 0
	var food := 0
	for instance in room["furniture_instances"]:
		var instance_data: Dictionary = instance
		var furniture_data: Dictionary = ConfigManager.get_furniture_data(str(instance_data["furniture_id"]))
		comfort += int(furniture_data["comfort"])
		entertainment += int(furniture_data["entertainment"])
		hygiene += int(furniture_data["hygiene"])
		food += int(furniture_data["food"])
	room["comfort"] = comfort
	room["entertainment"] = entertainment
	room["hygiene"] = hygiene
	room["food"] = food
	room["score"] = comfort + entertainment + hygiene + food
	rooms[room_id] = room
	GameEvents.room_updated.emit(room_id)

func add_furniture_instance(room_id: String, furniture_id: String, grid_pos: Array, mirrored := false) -> Dictionary:
	if not rooms.has(room_id):
		push_error("Cannot add furniture to unknown room '%s'." % room_id)
		return {}
	ConfigManager.get_furniture_data(furniture_id)
	var room: Dictionary = rooms[room_id]
	var instance: Dictionary = {
		"instance_id": "f_%d_%d" % [Time.get_ticks_msec(), randi_range(100, 999)],
		"furniture_id": furniture_id,
		"grid_pos": grid_pos,
		"mirrored": mirrored
	}
	var list: Array = room["furniture_instances"]
	list.append(instance)
	room["furniture_instances"] = list
	rooms[room_id] = room
	stats["furniture_placed_count"] = int(stats["furniture_placed_count"]) + 1
	recalculate_room_stats(room_id)
	EconomyManager.recalculate_total_rent()
	GameEvents.furniture_placed.emit(room_id, furniture_id)
	TaskManager.notify_event("furniture_placed", {"room_id": room_id, "furniture_id": furniture_id})
	add_apartment_exp(5)
	return instance

func move_furniture_instance(room_id: String, instance_id: String, grid_pos: Array) -> bool:
	if not rooms.has(room_id):
		push_error("Cannot move furniture in unknown room '%s'." % room_id)
		return false
	var room: Dictionary = rooms[room_id]
	var list: Array = room["furniture_instances"]
	for i in range(list.size()):
		var instance_data: Dictionary = list[i]
		if str(instance_data["instance_id"]) == instance_id:
			instance_data["grid_pos"] = grid_pos
			list[i] = instance_data
			room["furniture_instances"] = list
			rooms[room_id] = room
			GameEvents.furniture_moved.emit(room_id, str(instance_data["furniture_id"]))
			GameEvents.room_updated.emit(room_id)
			return true
	return false

func recycle_furniture_instance(room_id: String, instance_id: String) -> int:
	if not rooms.has(room_id):
		push_error("Cannot recycle furniture in unknown room '%s'." % room_id)
		return 0
	var room: Dictionary = rooms[room_id]
	var list: Array = room["furniture_instances"]
	for i in range(list.size()):
		var instance_data: Dictionary = list[i]
		if str(instance_data["instance_id"]) == instance_id:
			var furniture_id := str(instance_data["furniture_id"])
			var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
			var refund: int = int(float(data["price"]) * float(data["refund_rate"]))
			list.remove_at(i)
			room["furniture_instances"] = list
			rooms[room_id] = room
			add_coins(refund, "furniture_recycle")
			recalculate_room_stats(room_id)
			EconomyManager.recalculate_total_rent()
			GameEvents.furniture_recycled.emit(room_id, furniture_id)
			TaskManager.notify_event("furniture_recycled", {"room_id": room_id, "furniture_id": furniture_id})
			return refund
	return 0

func recruit_tenant(room_id: String, tenant_id: String) -> bool:
	if not rooms.has(room_id):
		push_error("Cannot recruit into unknown room '%s'." % room_id)
		return false
	if not tenants.has(tenant_id):
		push_error("Cannot recruit unknown tenant '%s'." % tenant_id)
		return false
	var room: Dictionary = rooms[room_id]
	var tenant: Dictionary = tenants[tenant_id]
	if str(room["tenant_id"]) != "" or str(tenant["room_id"]) != "":
		return false
	room["tenant_id"] = tenant_id
	tenant["room_id"] = room_id
	tenant["current_behavior"] = RECRUITED_TENANT_BEHAVIOR
	rooms[room_id] = room
	tenants[tenant_id] = tenant
	stats["tenant_recruited_count"] = int(stats["tenant_recruited_count"]) + 1
	recalculate_room_stats(room_id)
	EconomyManager.recalculate_total_rent()
	GameEvents.tenant_recruited.emit(tenant_id, room_id)
	TaskManager.notify_event("tenant_recruited", {"tenant_id": tenant_id, "room_id": room_id})
	add_apartment_exp(20)
	return true

func set_tenant_behavior(tenant_id: String, behavior_key: String) -> void:
	if not tenants.has(tenant_id):
		push_error("Cannot set behavior for unknown tenant '%s'." % tenant_id)
		return
	var tenant: Dictionary = tenants[tenant_id]
	var behavior := _normalize_tenant_behavior(behavior_key)
	if str(tenant["current_behavior"]) == behavior and str(tenant["current_need"]).is_empty():
		return
	tenant["current_need"] = ""
	tenant["current_behavior"] = behavior
	tenants[tenant_id] = tenant
	GameEvents.tenant_behavior_changed.emit(tenant_id, behavior)

func set_tenant_presence(tenant_id: String, presence_state: String, away_until_timestamp := 0, target_room_id := "") -> void:
	if not tenants.has(tenant_id):
		push_error("Cannot set presence for unknown tenant '%s'." % tenant_id)
		return
	var tenant: Dictionary = tenants[tenant_id]
	var presence := _normalize_tenant_presence(presence_state)
	var behavior := _behavior_for_presence(presence)
	tenant["presence_state"] = presence
	tenant["away_until_timestamp"] = maxi(0, away_until_timestamp)
	tenant["presence_target_room_id"] = target_room_id
	if not behavior.is_empty():
		tenant["current_need"] = ""
		tenant["current_behavior"] = behavior
	if presence == TENANT_PRESENCE_HOME:
		tenant["away_until_timestamp"] = 0
		tenant["presence_target_room_id"] = ""
	tenants[tenant_id] = tenant
	GameEvents.tenant_presence_changed.emit(tenant_id, presence)
	if not behavior.is_empty():
		GameEvents.tenant_behavior_changed.emit(tenant_id, behavior)

func build_floor(floor_index: int) -> bool:
	var floor: Dictionary = ConfigManager.get_floor_data(floor_index)
	if floor_index != highest_built_floor + 1:
		return false
	if apartment_level < int(floor["required_apartment_level"]):
		return false
	var cost: int = int(floor["build_cost"])
	if not spend_coins(cost):
		return false
	highest_built_floor = floor_index
	for room_id in rooms.keys():
		var room: Dictionary = rooms[room_id]
		var room_config: Dictionary = ConfigManager.get_room_config(str(room_id))
		if int(room["floor_index"]) <= highest_built_floor and bool(room_config["initial_unlocked"]):
			room["unlocked"] = true
			rooms[room_id] = room
	GameEvents.floor_built.emit(floor_index)
	TaskManager.notify_event("floor_built", {"floor_index": floor_index})
	add_apartment_exp(50)
	return true

func observe_tenant_behavior(tenant_id: String, need: String) -> void:
	if not tenants.has(tenant_id):
		push_error("Cannot observe behavior for unknown tenant '%s'." % tenant_id)
		return
	var tenant: Dictionary = tenants[tenant_id]
	var behavior := _need_to_behavior_key(need)
	tenant["current_need"] = need
	tenant["current_behavior"] = behavior
	tenant["satisfaction"] = clampi(int(tenant["satisfaction"]) + 1, 0, 100)
	tenants[tenant_id] = tenant
	GameEvents.tenant_behavior_changed.emit(tenant_id, behavior)
	GameEvents.tenant_behavior_observed.emit(tenant_id, need)
	GameEvents.tenant_satisfaction_changed.emit(tenant_id, int(tenant["satisfaction"]))
	TaskManager.notify_event("tenant_behavior_observed", {"tenant_id": tenant_id, "behavior": need})
	EconomyManager.recalculate_total_rent()

func to_save_data() -> Dictionary:
	return {
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"coins": coins,
		"total_rent_per_minute": total_rent_per_minute,
		"apartment_level": apartment_level,
		"apartment_exp": apartment_exp,
		"highest_built_floor": highest_built_floor,
		"rooms": rooms,
		"tenants": tenants,
		"tasks": tasks,
		"stats": stats,
		"last_save_timestamp": TimeManager.now_unix()
	}

func from_save_data(data: Dictionary) -> void:
	var validation_error := _save_validation_error(data)
	if not validation_error.is_empty():
		push_error("Save data rejected: %s. Resetting to current defaults." % validation_error)
		reset_new_game()
		EconomyManager.recalculate_total_rent()
		GameEvents.coins_changed.emit(coins)
		GameEvents.apartment_level_changed.emit(apartment_level)
		GameEvents.state_loaded.emit()
		return
	coins = int(data["coins"])
	total_rent_per_minute = float(data["total_rent_per_minute"])
	apartment_level = int(data["apartment_level"])
	apartment_exp = int(data["apartment_exp"])
	highest_built_floor = int(data["highest_built_floor"])
	last_save_timestamp = int(data["last_save_timestamp"])
	rooms = (data["rooms"] as Dictionary).duplicate(true)
	tenants = (data["tenants"] as Dictionary).duplicate(true)
	tasks = (data["tasks"] as Dictionary).duplicate(true)
	stats = (data["stats"] as Dictionary).duplicate(true)
	for room_id in rooms.keys():
		recalculate_room_stats(str(room_id))
	EconomyManager.recalculate_total_rent()
	GameEvents.coins_changed.emit(coins)
	GameEvents.apartment_level_changed.emit(apartment_level)
	GameEvents.state_loaded.emit()

func _initial_highest_built_floor() -> int:
	var result := 1
	for floor in ConfigManager.floors:
		var floor_data: Dictionary = floor
		if bool(floor_data["initial_built"]):
			result = max(result, int(floor_data["floor_index"]))
	return result

func _new_room_states() -> Dictionary:
	var result := {}
	for room_config in ConfigManager.rooms:
		var room_data: Dictionary = room_config
		var floor_index: int = int(room_data["floor_index"])
		var layout := _room_layout_for_level(room_data, 1)
		result[str(room_data["id"])] = {
			"id": str(room_data["id"]),
			"floor_index": floor_index,
			"room_name": str(room_data["room_name"]),
			"layout_side": str(room_data["layout_side"]),
			"door_side": str(room_data["door_side"]),
			"door_mirrored": bool(room_data["door_mirrored"]),
			"door_visual_offset": room_data["door_visual_offset"].duplicate(true),
			"level": 1,
			"frame_tiles": layout["frame_tiles"],
			"grid_size": layout["grid_size"],
			"wallpaper_id": str(room_data["default_wallpaper_id"]),
			"wall_style_id": str(room_data["default_wall_style_id"]),
			"door_style_id": str(room_data["default_door_style_id"]),
			"unlocked": bool(room_data["initial_unlocked"]) and floor_index <= highest_built_floor,
			"tenant_id": "",
			"furniture_instances": [],
			"score": 0,
			"comfort": 0,
			"entertainment": 0,
			"hygiene": 0,
			"food": 0,
			"rent_per_minute": 0.0
		}
	return result

func _new_tenant_states() -> Dictionary:
	var result := {}
	for tenant_config in ConfigManager.tenants:
		var tenant_data: Dictionary = tenant_config
		result[str(tenant_data["id"])] = {
			"id": str(tenant_data["id"]),
			"satisfaction": int(tenant_data["initial_satisfaction"]),
			"current_need": "",
			"current_behavior": DEFAULT_TENANT_BEHAVIOR,
			"room_id": "",
			"presence_state": TENANT_PRESENCE_HOME,
			"away_until_timestamp": 0,
			"presence_target_room_id": ""
		}
	return result

func _new_task_states() -> Dictionary:
	var result := {}
	for task_config in ConfigManager.tasks:
		var task_data: Dictionary = task_config
		result[str(task_data["id"])] = {
			"id": str(task_data["id"]),
			"progress": 0,
			"completed": false,
			"claimed": false
		}
	return result

func _room_layout_for_level(room_data: Dictionary, room_level: int) -> Dictionary:
	var layout := {
		"frame_tiles": [maxi(2, int(room_data["frame_tiles"][0])), int(room_data["frame_tiles"][1])],
		"grid_size": [maxi(1, int(room_data["grid_size"][0])), int(room_data["grid_size"][1])]
	}
	for item in room_data["layout_upgrades"]:
		var upgrade: Dictionary = item
		if int(upgrade["level"]) > room_level:
			continue
		layout["frame_tiles"] = [maxi(2, int(upgrade["frame_tiles"][0])), int(upgrade["frame_tiles"][1])]
		layout["grid_size"] = [maxi(1, int(upgrade["grid_size"][0])), int(upgrade["grid_size"][1])]
	return layout

func _need_to_behavior_key(need: String) -> String:
	match need:
		"energy":
			return "sleep"
		"hunger":
			return "eat"
		"entertainment":
			return "entertainment"
		"hygiene":
			return "clean"
		"study":
			return "study"
		"comfort":
			return "relax"
		_:
			_fail("Unknown tenant need '%s'." % need)
			return DEFAULT_TENANT_BEHAVIOR

func _normalize_tenant_behavior(value: String) -> String:
	var key := ConfigManager.normalize_behavior_key(value)
	_expect(VALID_TENANT_BEHAVIORS.has(key), "Unknown tenant behavior '%s'." % key)
	return key

func _normalize_tenant_presence(value: String) -> String:
	var key := value.strip_edges()
	_expect(VALID_TENANT_PRESENCE.has(key), "Unknown tenant presence '%s'." % key)
	return key

func _behavior_for_presence(presence_state: String) -> String:
	match presence_state:
		TENANT_PRESENCE_LEAVING:
			return LEAVING_TENANT_BEHAVIOR
		TENANT_PRESENCE_AWAY:
			return AWAY_TENANT_BEHAVIOR
		TENANT_PRESENCE_RETURNING:
			return RETURNING_TENANT_BEHAVIOR
		_:
			return ""

func _save_validation_error(data: Dictionary) -> String:
	var key_error := _dictionary_keys_error(data, SAVE_KEYS, "save data")
	if not key_error.is_empty():
		return key_error
	if not _is_number(data["save_schema_version"]) or int(data["save_schema_version"]) != SAVE_SCHEMA_VERSION:
		return "schema version must be %d" % SAVE_SCHEMA_VERSION
	for numeric_key in ["coins", "total_rent_per_minute", "apartment_level", "apartment_exp", "highest_built_floor", "last_save_timestamp"]:
		if not _is_number(data[numeric_key]):
			return "save field '%s' must be numeric" % numeric_key
	if not (data["rooms"] is Dictionary):
		return "save field 'rooms' must be a dictionary"
	if not (data["tenants"] is Dictionary):
		return "save field 'tenants' must be a dictionary"
	if not (data["tasks"] is Dictionary):
		return "save field 'tasks' must be a dictionary"
	if not (data["stats"] is Dictionary):
		return "save field 'stats' must be a dictionary"
	var rooms_error := _rooms_validation_error(data["rooms"])
	if not rooms_error.is_empty():
		return rooms_error
	var tenants_error := _tenants_validation_error(data["tenants"], data["rooms"])
	if not tenants_error.is_empty():
		return tenants_error
	var tasks_error := _tasks_validation_error(data["tasks"])
	if not tasks_error.is_empty():
		return tasks_error
	var stats_error := _dictionary_keys_error(data["stats"], STATS_KEYS, "save stats")
	if not stats_error.is_empty():
		return stats_error
	for stat_key in STATS_KEYS:
		if not _is_number((data["stats"] as Dictionary)[stat_key]):
			return "save stat '%s' must be numeric" % stat_key
	return _room_tenant_links_error(data["rooms"], data["tenants"])

func _rooms_validation_error(saved_rooms: Dictionary) -> String:
	if saved_rooms.size() != ConfigManager.rooms.size():
		return "room count does not match config"
	var valid_ids := {}
	for room_config in ConfigManager.rooms:
		var room_data: Dictionary = room_config
		var room_id := str(room_data["id"])
		valid_ids[room_id] = true
		if not saved_rooms.has(room_id):
			return "missing room state '%s'" % room_id
		var room: Variant = saved_rooms[room_id]
		if not (room is Dictionary):
			return "room state '%s' must be a dictionary" % room_id
		var room_error := _room_validation_error(room_id, room, room_data)
		if not room_error.is_empty():
			return room_error
	for room_id in saved_rooms.keys():
		if not valid_ids.has(str(room_id)):
			return "unknown room state '%s'" % str(room_id)
	return ""

func _room_validation_error(room_id: String, room: Dictionary, room_config: Dictionary) -> String:
	var key_error := _dictionary_keys_error(room, ROOM_STATE_KEYS, "room '%s'" % room_id)
	if not key_error.is_empty():
		return key_error
	if str(room["id"]) != room_id:
		return "room '%s' id field does not match key" % room_id
	for key in ["floor_index", "room_name", "layout_side", "door_side", "door_mirrored", "door_visual_offset"]:
		if not _values_match(room[key], room_config[key]):
			return "room '%s' field '%s' does not match current config" % [room_id, key]
	if not _is_number(room["level"]):
		return "room '%s' level must be numeric" % room_id
	var layout := _room_layout_for_level(room_config, int(room["level"]))
	if not _int_arrays_equal(room["frame_tiles"], layout["frame_tiles"]):
		return "room '%s' frame_tiles do not match current config level" % room_id
	if not _int_arrays_equal(room["grid_size"], layout["grid_size"]):
		return "room '%s' grid_size do not match current config level" % room_id
	for pair in [
		["wallpaper_id", ConfigManager.DECOR_WALLPAPER],
		["wall_style_id", ConfigManager.DECOR_WALL],
		["door_style_id", ConfigManager.DECOR_DOOR]
	]:
		var decor_id := str(room[str(pair[0])])
		if not ConfigManager.room_decor_by_id.has(decor_id):
			return "room '%s' field '%s' references unknown decor '%s'" % [room_id, str(pair[0]), decor_id]
		var item: Dictionary = ConfigManager.room_decor_by_id[decor_id]
		if str(item["category"]) != str(pair[1]):
			return "room '%s' field '%s' references decor in the wrong category" % [room_id, str(pair[0])]
	if not (room["unlocked"] is bool):
		return "room '%s' unlocked must be bool" % room_id
	if not (room["tenant_id"] is String):
		return "room '%s' tenant_id must be a string" % room_id
	if not (room["furniture_instances"] is Array):
		return "room '%s' furniture_instances must be an array" % room_id
	for instance in room["furniture_instances"]:
		if not (instance is Dictionary):
			return "room '%s' furniture instance must be a dictionary" % room_id
		var instance_error := _furniture_instance_validation_error(room_id, instance)
		if not instance_error.is_empty():
			return instance_error
	for numeric_key in ["score", "comfort", "entertainment", "hygiene", "food", "rent_per_minute"]:
		if not _is_number(room[numeric_key]):
			return "room '%s' field '%s' must be numeric" % [room_id, numeric_key]
	return ""

func _furniture_instance_validation_error(room_id: String, instance: Dictionary) -> String:
	var key_error := _dictionary_keys_error(instance, FURNITURE_INSTANCE_KEYS, "room '%s' furniture instance" % room_id)
	if not key_error.is_empty():
		return key_error
	if not (instance["instance_id"] is String) or str(instance["instance_id"]).strip_edges().is_empty():
		return "room '%s' furniture instance_id cannot be empty" % room_id
	var furniture_id := str(instance["furniture_id"])
	if not ConfigManager.furniture_by_id.has(furniture_id):
		return "room '%s' furniture references unknown furniture '%s'" % [room_id, furniture_id]
	if not _is_int_array(instance["grid_pos"], 2):
		return "room '%s' furniture grid_pos must be [x, y]" % room_id
	if not (instance["mirrored"] is bool):
		return "room '%s' furniture mirrored must be bool" % room_id
	return ""

func _tenants_validation_error(saved_tenants: Dictionary, saved_rooms: Dictionary) -> String:
	if saved_tenants.size() != ConfigManager.tenants.size():
		return "tenant count does not match config"
	var valid_ids := {}
	for tenant_config in ConfigManager.tenants:
		var tenant_data: Dictionary = tenant_config
		var tenant_id := str(tenant_data["id"])
		valid_ids[tenant_id] = true
		if not saved_tenants.has(tenant_id):
			return "missing tenant state '%s'" % tenant_id
		var tenant: Variant = saved_tenants[tenant_id]
		if not (tenant is Dictionary):
			return "tenant state '%s' must be a dictionary" % tenant_id
		var tenant_error := _tenant_validation_error(tenant_id, tenant, saved_rooms)
		if not tenant_error.is_empty():
			return tenant_error
	for tenant_id in saved_tenants.keys():
		if not valid_ids.has(str(tenant_id)):
			return "unknown tenant state '%s'" % str(tenant_id)
	return ""

func _tenant_validation_error(tenant_id: String, tenant: Dictionary, saved_rooms: Dictionary) -> String:
	var key_error := _dictionary_keys_error(tenant, TENANT_STATE_KEYS, "tenant '%s'" % tenant_id)
	if not key_error.is_empty():
		return key_error
	if str(tenant["id"]) != tenant_id:
		return "tenant '%s' id field does not match key" % tenant_id
	if not _is_number(tenant["satisfaction"]):
		return "tenant '%s' satisfaction must be numeric" % tenant_id
	for string_key in ["current_need", "current_behavior", "room_id", "presence_state", "presence_target_room_id"]:
		if not (tenant[string_key] is String):
			return "tenant '%s' field '%s' must be a string" % [tenant_id, string_key]
	if not VALID_TENANT_BEHAVIORS.has(str(tenant["current_behavior"])):
		return "tenant '%s' current_behavior is unknown" % tenant_id
	if not VALID_TENANT_PRESENCE.has(str(tenant["presence_state"])):
		return "tenant '%s' presence_state is unknown" % tenant_id
	if not _is_number(tenant["away_until_timestamp"]):
		return "tenant '%s' away_until_timestamp must be numeric" % tenant_id
	var room_id := str(tenant["room_id"])
	if not room_id.is_empty() and not saved_rooms.has(room_id):
		return "tenant '%s' references unknown room '%s'" % [tenant_id, room_id]
	return ""

func _tasks_validation_error(saved_tasks: Dictionary) -> String:
	if saved_tasks.size() != ConfigManager.tasks.size():
		return "task count does not match config"
	for task_config in ConfigManager.tasks:
		var task_data: Dictionary = task_config
		var task_id := str(task_data["id"])
		if not saved_tasks.has(task_id):
			return "missing task state '%s'" % task_id
		var task: Variant = saved_tasks[task_id]
		if not (task is Dictionary):
			return "task state '%s' must be a dictionary" % task_id
		var key_error := _dictionary_keys_error(task, TASK_STATE_KEYS, "task '%s'" % task_id)
		if not key_error.is_empty():
			return key_error
		if str(task["id"]) != task_id:
			return "task '%s' id field does not match key" % task_id
		if not _is_number(task["progress"]):
			return "task '%s' progress must be numeric" % task_id
		if not (task["completed"] is bool) or not (task["claimed"] is bool):
			return "task '%s' completed/claimed must be bool" % task_id
	return ""

func _room_tenant_links_error(saved_rooms: Dictionary, saved_tenants: Dictionary) -> String:
	for room_id in saved_rooms.keys():
		var room: Dictionary = saved_rooms[room_id]
		var tenant_id := str(room["tenant_id"])
		if tenant_id.is_empty():
			continue
		if not saved_tenants.has(tenant_id):
			return "room '%s' references unknown tenant '%s'" % [str(room_id), tenant_id]
		var tenant: Dictionary = saved_tenants[tenant_id]
		if str(tenant["room_id"]) != str(room_id):
			return "room '%s' tenant link does not match tenant '%s'" % [str(room_id), tenant_id]
	for tenant_id in saved_tenants.keys():
		var tenant: Dictionary = saved_tenants[tenant_id]
		var room_id := str(tenant["room_id"])
		if room_id.is_empty():
			continue
		var room: Dictionary = saved_rooms[room_id]
		if str(room["tenant_id"]) != str(tenant_id):
			return "tenant '%s' room link does not match room '%s'" % [str(tenant_id), room_id]
	return ""

func _dictionary_keys_error(data: Dictionary, expected_keys: Array, context: String) -> String:
	if data.size() != expected_keys.size():
		return "%s key count must be %d" % [context, expected_keys.size()]
	for key in expected_keys:
		if not data.has(key):
			return "%s is missing key '%s'" % [context, str(key)]
	for key in data.keys():
		if not expected_keys.has(str(key)):
			return "%s has unknown key '%s'" % [context, str(key)]
	return ""

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _is_int_array(value: Variant, size: int) -> bool:
	if not (value is Array) or value.size() < size:
		return false
	for index in range(size):
		if not _is_number(value[index]):
			return false
	return true

func _int_arrays_equal(left: Variant, right: Variant) -> bool:
	if not _is_int_array(left, 2) or not _is_int_array(right, 2):
		return false
	return int(left[0]) == int(right[0]) and int(left[1]) == int(right[1])

func _values_match(left: Variant, right: Variant) -> bool:
	if left is Array and right is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _values_match(left[index], right[index]):
				return false
		return true
	return left == right

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)

func _fail(message: String) -> void:
	push_error(message)
	assert(false, message)
