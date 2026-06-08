extends Node

const DEFAULT_FRAME_TILES := [8, 4]
const DEFAULT_GRID_SIZE := [6, 3]
const SAVE_SCHEMA_VERSION := 2
const DEFAULT_TENANT_BEHAVIOR := "wander"
const RECRUITED_TENANT_BEHAVIOR := "recruited"
const IDLE_TENANT_BEHAVIOR := "idle"
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
	"happy": true
}

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
var save_needs_writeback := false

func _ready() -> void:
	reset_new_game()

func reset_new_game() -> void:
	coins = int(ConfigManager.get_economy_value("starting_coins", 800))
	total_rent_per_minute = 0.0
	apartment_level = 1
	apartment_exp = 0
	highest_built_floor = 1
	last_save_timestamp = TimeManager.now_unix()
	rooms = {}
	tenants = {}
	tasks = {}
	save_needs_writeback = false
	stats = {
		"furniture_placed_count": 0,
		"tenant_recruited_count": 0,
		"offline_claimed_count": 0
	}
	for floor in ConfigManager.floors:
		var floor_data: Dictionary = floor
		if bool(floor_data.get("initial_built", false)):
			highest_built_floor = max(highest_built_floor, int(floor_data.get("floor_index", 1)))
	for room_config in ConfigManager.rooms:
		var room_data: Dictionary = room_config
		var floor_index: int = int(room_data.get("floor_index", 1))
		var initially_unlocked := bool(room_data.get("initial_unlocked", true))
		rooms[room_data.get("id", "")] = {
			"id": room_data.get("id", ""),
			"floor_index": floor_index,
			"room_name": room_data.get("room_name", ""),
			"frame_tiles": _fixed_height_frame_tiles(_int_pair(room_data.get("frame_tiles", DEFAULT_FRAME_TILES), DEFAULT_FRAME_TILES)),
			"grid_size": _fixed_height_grid_size(_int_pair(room_data.get("grid_size", DEFAULT_GRID_SIZE), DEFAULT_GRID_SIZE)),
			"unlocked": initially_unlocked and floor_index <= highest_built_floor,
			"level": 1,
			"tenant_id": "",
			"furniture_instances": [],
			"score": 0,
			"comfort": 0,
			"entertainment": 0,
			"hygiene": 0,
			"food": 0,
			"rent_per_minute": 0.0
		}
	for tenant_config in ConfigManager.tenants:
		var tenant_data: Dictionary = tenant_config
		tenants[tenant_data.get("id", "")] = {
			"id": tenant_data.get("id", ""),
			"satisfaction": int(tenant_data.get("initial_satisfaction", 60)),
			"current_need": "",
			"current_behavior": DEFAULT_TENANT_BEHAVIOR,
			"room_id": ""
		}
	for task_config in ConfigManager.tasks:
		var task_data: Dictionary = task_config
		tasks[task_data.get("id", "")] = {
			"id": task_data.get("id", ""),
			"progress": 0,
			"completed": false,
			"claimed": false
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
		if apartment_exp < int(next_data.get("required_exp", 0)):
			break
		apartment_level += 1
		leveled = true
		GameEvents.apartment_level_changed.emit(apartment_level)
	if leveled:
		TaskManager.notify_event("apartment_level_reached", {"level": apartment_level})

func get_room(room_id: String) -> Dictionary:
	return rooms.get(room_id, {})

func get_unlocked_rooms() -> Array:
	var result: Array = []
	for room in rooms.values():
		if bool(room.get("unlocked", false)):
			result.append(room)
	return result

func get_unlocked_rooms_on_floor(floor_index: int) -> Array:
	var result: Array = []
	for room in rooms.values():
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) == floor_index and bool(room_data.get("unlocked", false)):
			result.append(room_data)
	return result

func unlock_room(room_id: String) -> bool:
	var room: Dictionary = rooms.get(room_id, {})
	if room.is_empty() or bool(room.get("unlocked", false)):
		return false
	room["unlocked"] = true
	rooms[room_id] = room
	GameEvents.room_unlocked.emit(room_id)
	GameEvents.room_updated.emit(room_id)
	return true

func upgrade_room_layout(room_id: String, frame_tiles: Array = [], grid_size: Array = []) -> bool:
	var room: Dictionary = rooms.get(room_id, {})
	if room.is_empty():
		return false
	if frame_tiles.size() >= 2:
		room["frame_tiles"] = _fixed_height_frame_tiles([int(frame_tiles[0]), int(frame_tiles[1])])
	if grid_size.size() >= 2:
		room["grid_size"] = _fixed_height_grid_size([int(grid_size[0]), int(grid_size[1])])
	rooms[room_id] = room
	GameEvents.room_layout_changed.emit(room_id)
	GameEvents.room_updated.emit(room_id)
	return true

func apply_room_layout_upgrade(room_id: String, target_level := 0) -> bool:
	var room: Dictionary = rooms.get(room_id, {})
	if room.is_empty():
		return false
	var next_level := target_level
	if next_level <= 0:
		next_level = int(room.get("level", 1)) + 1
	var upgrade: Dictionary = ConfigManager.get_room_layout_upgrade(room_id, next_level)
	if upgrade.is_empty():
		return false
	room["level"] = next_level
	rooms[room_id] = room
	return upgrade_room_layout(
		room_id,
		upgrade.get("frame_tiles", []),
		upgrade.get("grid_size", [])
	)

func recalculate_room_stats(room_id: String) -> void:
	if not rooms.has(room_id):
		return
	var room: Dictionary = rooms[room_id]
	var comfort := 0
	var entertainment := 0
	var hygiene := 0
	var food := 0
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		var furniture_data: Dictionary = ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		comfort += int(furniture_data.get("comfort", 0))
		entertainment += int(furniture_data.get("entertainment", 0))
		hygiene += int(furniture_data.get("hygiene", 0))
		food += int(furniture_data.get("food", 0))
	room["comfort"] = comfort
	room["entertainment"] = entertainment
	room["hygiene"] = hygiene
	room["food"] = food
	room["score"] = comfort + entertainment + hygiene + food
	rooms[room_id] = room
	GameEvents.room_updated.emit(room_id)

func add_furniture_instance(room_id: String, furniture_id: String, grid_pos: Array, mirrored := false) -> Dictionary:
	var room: Dictionary = rooms.get(room_id, {})
	if room.is_empty():
		return {}
	var instance: Dictionary = {
		"instance_id": "f_%d_%d" % [Time.get_ticks_msec(), randi_range(100, 999)],
		"furniture_id": furniture_id,
		"grid_pos": grid_pos,
		"mirrored": mirrored
	}
	var list: Array = room.get("furniture_instances", [])
	list.append(instance)
	room["furniture_instances"] = list
	rooms[room_id] = room
	stats["furniture_placed_count"] = int(stats.get("furniture_placed_count", 0)) + 1
	recalculate_room_stats(room_id)
	EconomyManager.recalculate_total_rent()
	GameEvents.furniture_placed.emit(room_id, furniture_id)
	TaskManager.notify_event("furniture_placed", {"room_id": room_id, "furniture_id": furniture_id})
	add_apartment_exp(5)
	return instance

func move_furniture_instance(room_id: String, instance_id: String, grid_pos: Array) -> bool:
	var room: Dictionary = rooms.get(room_id, {})
	var list: Array = room.get("furniture_instances", [])
	for i in range(list.size()):
		if str(list[i].get("instance_id", "")) == instance_id:
			list[i]["grid_pos"] = grid_pos
			room["furniture_instances"] = list
			rooms[room_id] = room
			GameEvents.furniture_moved.emit(room_id, str(list[i].get("furniture_id", "")))
			GameEvents.room_updated.emit(room_id)
			return true
	return false

func recycle_furniture_instance(room_id: String, instance_id: String) -> int:
	var room: Dictionary = rooms.get(room_id, {})
	var list: Array = room.get("furniture_instances", [])
	for i in range(list.size()):
		if str(list[i].get("instance_id", "")) == instance_id:
			var furniture_id := str(list[i].get("furniture_id", ""))
			var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
			var refund: int = int(float(data.get("price", 0)) * float(data.get("refund_rate", 0.5)))
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
	var room: Dictionary = rooms.get(room_id, {})
	if room.is_empty() or str(room.get("tenant_id", "")) != "":
		return false
	var tenant: Dictionary = tenants.get(tenant_id, {})
	if tenant.is_empty() or str(tenant.get("room_id", "")) != "":
		return false
	room["tenant_id"] = tenant_id
	tenant["room_id"] = room_id
	tenant["current_behavior"] = RECRUITED_TENANT_BEHAVIOR
	rooms[room_id] = room
	tenants[tenant_id] = tenant
	stats["tenant_recruited_count"] = int(stats.get("tenant_recruited_count", 0)) + 1
	recalculate_room_stats(room_id)
	EconomyManager.recalculate_total_rent()
	GameEvents.tenant_recruited.emit(tenant_id, room_id)
	TaskManager.notify_event("tenant_recruited", {"tenant_id": tenant_id, "room_id": room_id})
	add_apartment_exp(20)
	return true

func build_floor(floor_index: int) -> bool:
	var floor: Dictionary = ConfigManager.get_floor_data(floor_index)
	if floor.is_empty():
		return false
	if floor_index != highest_built_floor + 1:
		return false
	if apartment_level < int(floor.get("required_apartment_level", 1)):
		return false
	var cost: int = int(floor.get("build_cost", 0))
	if not spend_coins(cost):
		return false
	highest_built_floor = floor_index
	for room_id in rooms.keys():
		var room: Dictionary = rooms[room_id]
		var room_config: Dictionary = ConfigManager.get_room_config(str(room_id))
		var initially_unlocked := bool(room_config.get("initial_unlocked", true))
		if int(room.get("floor_index", 0)) <= highest_built_floor and initially_unlocked:
			room["unlocked"] = true
			rooms[room_id] = room
	GameEvents.floor_built.emit(floor_index)
	TaskManager.notify_event("floor_built", {"floor_index": floor_index})
	add_apartment_exp(50)
	return true

func observe_tenant_behavior(tenant_id: String, need: String) -> void:
	var tenant: Dictionary = tenants.get(tenant_id, {})
	if tenant.is_empty():
		return
	tenant["current_need"] = need
	tenant["current_behavior"] = _need_to_behavior_key(need)
	tenant["satisfaction"] = clampi(int(tenant.get("satisfaction", 60)) + 1, 0, 100)
	tenants[tenant_id] = tenant
	GameEvents.tenant_behavior_observed.emit(tenant_id, need)
	GameEvents.tenant_satisfaction_changed.emit(tenant_id, int(tenant["satisfaction"]))
	TaskManager.notify_event("tenant_behavior_observed", {"tenant_id": tenant_id, "behavior": need})
	EconomyManager.recalculate_total_rent()

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
			return DEFAULT_TENANT_BEHAVIOR

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
	if data.is_empty():
		return
	var saved_schema_version := int(data.get("save_schema_version", 0))
	save_needs_writeback = saved_schema_version < SAVE_SCHEMA_VERSION
	coins = int(data.get("coins", coins))
	total_rent_per_minute = float(data.get("total_rent_per_minute", total_rent_per_minute))
	apartment_level = int(data.get("apartment_level", apartment_level))
	apartment_exp = int(data.get("apartment_exp", apartment_exp))
	highest_built_floor = int(data.get("highest_built_floor", highest_built_floor))
	last_save_timestamp = int(data.get("last_save_timestamp", TimeManager.now_unix()))
	var saved_rooms: Variant = data.get("rooms", rooms)
	var saved_tenants: Variant = data.get("tenants", tenants)
	var saved_tasks: Variant = data.get("tasks", tasks)
	var saved_stats: Variant = data.get("stats", stats)
	if saved_rooms is Dictionary:
		rooms = saved_rooms
	if saved_tenants is Dictionary:
		tenants = saved_tenants
	if saved_tasks is Dictionary:
		tasks = saved_tasks
	if saved_stats is Dictionary:
		stats = saved_stats
	_ensure_runtime_defaults(saved_schema_version)
	for room_id in rooms.keys():
		recalculate_room_stats(str(room_id))
	EconomyManager.recalculate_total_rent()
	GameEvents.coins_changed.emit(coins)
	GameEvents.apartment_level_changed.emit(apartment_level)
	GameEvents.state_loaded.emit()

func _ensure_runtime_defaults(saved_schema_version := SAVE_SCHEMA_VERSION) -> void:
	if last_save_timestamp <= 0:
		last_save_timestamp = TimeManager.now_unix()
	_ensure_stats_defaults()
	var source_rooms := rooms
	var normalized_rooms := {}
	for room_config in ConfigManager.rooms:
		var room_data: Dictionary = room_config
		var room_id := str(room_data.get("id", ""))
		if room_id.is_empty():
			continue
		var room: Dictionary = source_rooms.get(room_id, {})
		var floor_index := int(room_data.get("floor_index", room.get("floor_index", 1)))
		var initially_unlocked := bool(room_data.get("initial_unlocked", true))
		var room_level := int(room.get("level", 1))
		if saved_schema_version < SAVE_SCHEMA_VERSION:
			room_level = 1
		var configured_layout := _configured_room_layout_for_level(room_data, room_level)
		normalized_rooms[room_id] = {
			"id": room_id,
			"floor_index": floor_index,
			"room_name": str(room_data.get("room_name", "")),
			"level": room_level,
			"frame_tiles": configured_layout.get("frame_tiles", DEFAULT_FRAME_TILES).duplicate(),
			"grid_size": configured_layout.get("grid_size", DEFAULT_GRID_SIZE).duplicate(),
			"unlocked": bool(room.get("unlocked", initially_unlocked and floor_index <= highest_built_floor)),
			"tenant_id": str(room.get("tenant_id", "")),
			"furniture_instances": room.get("furniture_instances", []),
			"score": int(room.get("score", 0)),
			"comfort": int(room.get("comfort", 0)),
			"entertainment": int(room.get("entertainment", 0)),
			"hygiene": int(room.get("hygiene", 0)),
			"food": int(room.get("food", 0)),
			"rent_per_minute": float(room.get("rent_per_minute", 0.0))
		}
	rooms = normalized_rooms
	for tenant_config in ConfigManager.tenants:
		var tenant_data: Dictionary = tenant_config
		var tenant_id := str(tenant_data.get("id", ""))
		if tenant_id.is_empty():
			continue
		var tenant: Dictionary = tenants.get(tenant_id, {})
		tenant["id"] = tenant_id
		tenant["satisfaction"] = int(tenant.get("satisfaction", int(tenant_data.get("initial_satisfaction", 60))))
		tenant["current_need"] = str(tenant.get("current_need", ""))
		tenant["current_behavior"] = _normalize_tenant_behavior(str(tenant.get("current_behavior", DEFAULT_TENANT_BEHAVIOR)))
		tenant["room_id"] = str(tenant.get("room_id", ""))
		if not tenant["room_id"].is_empty() and not rooms.has(tenant["room_id"]):
			tenant["room_id"] = ""
		tenants[tenant_id] = tenant
	for task_config in ConfigManager.tasks:
		var task_data: Dictionary = task_config
		var task_id := str(task_data.get("id", ""))
		if task_id.is_empty():
			continue
		var task: Dictionary = tasks.get(task_id, {})
		task["id"] = task_id
		task["progress"] = int(task.get("progress", 0))
		task["completed"] = bool(task.get("completed", false))
		task["claimed"] = bool(task.get("claimed", false))
		tasks[task_id] = task

func _ensure_stats_defaults() -> void:
	stats["furniture_placed_count"] = int(stats.get("furniture_placed_count", 0))
	stats["tenant_recruited_count"] = int(stats.get("tenant_recruited_count", 0))
	stats["offline_claimed_count"] = int(stats.get("offline_claimed_count", 0))

func _normalize_tenant_behavior(value: String) -> String:
	var key := ConfigManager.normalize_behavior_key(value, DEFAULT_TENANT_BEHAVIOR)
	if VALID_TENANT_BEHAVIORS.has(key):
		return key
	return DEFAULT_TENANT_BEHAVIOR

func _configured_room_layout_for_level(room_data: Dictionary, room_level: int) -> Dictionary:
	var frame_tiles := _fixed_height_frame_tiles(_int_pair(room_data.get("frame_tiles", DEFAULT_FRAME_TILES), DEFAULT_FRAME_TILES))
	var layout := {
		"frame_tiles": frame_tiles,
		"grid_size": _fixed_height_grid_size(_int_pair(room_data.get("grid_size", DEFAULT_GRID_SIZE), DEFAULT_GRID_SIZE))
	}
	for item in room_data.get("layout_upgrades", []):
		var upgrade: Dictionary = item
		if int(upgrade.get("level", 0)) > room_level:
			continue
		layout["frame_tiles"] = _fixed_height_frame_tiles(_int_pair(upgrade.get("frame_tiles", layout["frame_tiles"]), layout["frame_tiles"]))
		layout["grid_size"] = _fixed_height_grid_size(_int_pair(upgrade.get("grid_size", layout["grid_size"]), layout["grid_size"]))
	return layout

func _fixed_height_frame_tiles(value: Array) -> Array:
	if value.size() >= 2:
		return [maxi(4, int(value[0])), int(DEFAULT_FRAME_TILES[1])]
	return DEFAULT_FRAME_TILES.duplicate()

func _fixed_height_grid_size(value: Array) -> Array:
	if value.size() >= 2:
		return [maxi(1, int(value[0])), int(DEFAULT_GRID_SIZE[1])]
	return DEFAULT_GRID_SIZE.duplicate()

func _int_pair(value: Variant, fallback: Array) -> Array:
	if value is Array and value.size() >= 2:
		return [int(value[0]), int(value[1])]
	return fallback.duplicate()
