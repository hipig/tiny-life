extends Node

const SAVE_SCHEMA_VERSION := 8
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
	"sit": true,
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

const PUBLIC_AREA_DECOR_STATE_KEYS := [
	"target_id",
	"floor_index",
	"area_id",
	"wallpaper_id",
	"wall_style_id",
	"door_style_id"
]

const APARTMENT_DECOR_KEYS := [
	"service_core",
	"roof"
]

const SERVICE_CORE_DECOR_STATE_KEYS := [
	"wallpaper_id",
	"wall_style_id"
]

const ROOF_DECOR_STATE_KEYS := [
	"roof_style_id"
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
	"anchor_pos",
	"mirrored",
	"orientation"
]

const STATS_KEYS := [
	"furniture_placed_count",
	"tenant_recruited_count",
	"room_built_count",
	"offline_claimed_count"
]

const SAVE_KEYS := [
	"save_schema_version",
	"coins",
	"total_rent_per_minute",
	"apartment_level",
	"apartment_exp",
	"rooms",
	"public_area_decor",
	"apartment_decor",
	"tenants",
	"tasks",
	"stats",
	"last_save_timestamp"
]

var coins: int = 0
var total_rent_per_minute: float = 0.0
var apartment_level: int = 1
var apartment_exp: int = 0
var last_save_timestamp: int = 0

var rooms: Dictionary = {}
var public_area_decor: Dictionary = {}
var apartment_decor: Dictionary = {}
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
	last_save_timestamp = TimeManager.now_unix()
	rooms = _new_room_states()
	public_area_decor = _new_public_area_decor_states()
	apartment_decor = _new_apartment_decor_state()
	tenants = _new_tenant_states()
	tasks = _new_task_states()
	stats = {
		"furniture_placed_count": 0,
		"tenant_recruited_count": 0,
		"room_built_count": 0,
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

func space_decor_target(kind: String, id: String) -> Dictionary:
	return ConfigManager.build_space_decor_target(kind, id)

func get_space_decor_state(target_ref: Dictionary) -> Dictionary:
	var kind := str(target_ref.get("kind", "")).strip_edges()
	var target_id := str(target_ref.get("id", "")).strip_edges()
	match kind:
		ConfigManager.TARGET_ROOM:
			return get_room(target_id)
		ConfigManager.TARGET_PUBLIC_AREA:
			if not public_area_decor.has(target_id):
				push_error("Runtime state is missing public area decor '%s'." % target_id)
				return {}
			return public_area_decor[target_id]
		ConfigManager.TARGET_SERVICE_CORE:
			return apartment_decor.get(ConfigManager.TARGET_SERVICE_CORE, {})
		ConfigManager.TARGET_ROOF:
			return apartment_decor.get(ConfigManager.TARGET_ROOF, {})
		_:
			push_error("Unknown decor target kind '%s'." % kind)
			return {}

func get_space_decor_id(target_ref: Dictionary, category: String) -> String:
	var state := get_space_decor_state(target_ref)
	if state.is_empty():
		return ""
	return ConfigManager.get_space_decor_id(state, category)

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

func get_rooms_on_floor(floor_index: int) -> Array:
	var result: Array = []
	for room in rooms.values():
		var room_data: Dictionary = room
		if int(room_data["floor_index"]) == floor_index:
			result.append(room_data)
	return result

func get_unlocked_room_count_on_floor(floor_index: int) -> int:
	return get_unlocked_rooms_on_floor(floor_index).size()

func get_buildable_rooms_on_floor(floor_index: int) -> Array:
	var result: Array = []
	for room_config in ConfigManager.get_room_configs_for_floor(floor_index):
		var room_data: Dictionary = room_config
		if is_room_buildable(str(room_data["id"])):
			result.append(room_data)
	return result

func is_room_buildable(room_id: String) -> bool:
	if not rooms.has(room_id) or not ConfigManager.room_by_id.has(room_id):
		return false
	var room: Dictionary = rooms[room_id]
	if bool(room["unlocked"]):
		return false
	var room_config: Dictionary = ConfigManager.get_room_config(room_id)
	if apartment_level < int(room_config["required_apartment_level"]):
		return false
	return _lower_room_floors_complete(int(room_config["floor_index"]))

func is_floor_complete(floor_index: int) -> bool:
	var room_configs := ConfigManager.get_room_configs_for_floor(floor_index)
	if room_configs.is_empty():
		return bool(ConfigManager.get_floor_data(floor_index)["initial_built"])
	for room_config in room_configs:
		var data: Dictionary = room_config
		var room_id := str(data["id"])
		if not rooms.has(room_id) or not bool((rooms[room_id] as Dictionary)["unlocked"]):
			return false
	return true

func is_floor_visible(floor_index: int) -> bool:
	var floor_data := ConfigManager.get_floor_data(floor_index)
	var public_areas: Array = floor_data["public_areas"]
	if bool(floor_data["initial_built"]) or not public_areas.is_empty():
		return true
	for room_config in ConfigManager.get_room_configs_for_floor(floor_index):
		var data: Dictionary = room_config
		var room_id := str(data["id"])
		if rooms.has(room_id) and bool((rooms[room_id] as Dictionary)["unlocked"]):
			return true
		if is_room_buildable(room_id):
			return true
	return false

func get_highest_visible_floor() -> int:
	var result := 1
	for floor in ConfigManager.floors:
		var floor_data: Dictionary = floor
		var floor_index := int(floor_data["floor_index"])
		if is_floor_visible(floor_index):
			result = max(result, floor_index)
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

func apply_space_decor(target_ref: Dictionary, decor_id: String) -> bool:
	var item: Dictionary = ConfigManager.get_room_decor_item(decor_id)
	if item.is_empty():
		return false
	var kind := str(target_ref.get("kind", "")).strip_edges()
	var target_id := str(target_ref.get("id", "")).strip_edges()
	var category := str(item["category"]).strip_edges()
	var supported_categories := ConfigManager.supported_decor_categories_for_target(target_ref)
	_expect(supported_categories.has(category), "Decor target '%s:%s' does not support category '%s'." % [kind, target_id, category])
	var current_state := get_space_decor_state(target_ref)
	if current_state.is_empty():
		return false
	var field := ConfigManager.decor_state_field_for_category(category)
	if str(current_state.get(field, "")).strip_edges() == decor_id:
		return false
	match kind:
		ConfigManager.TARGET_ROOM:
			var room_state := current_state.duplicate(true)
			room_state[field] = decor_id
			rooms[target_id] = room_state
			GameEvents.room_decor_changed.emit(target_id, decor_id, category)
			GameEvents.room_updated.emit(target_id)
		ConfigManager.TARGET_PUBLIC_AREA:
			var public_area_state := current_state.duplicate(true)
			public_area_state[field] = decor_id
			public_area_decor[target_id] = public_area_state
		ConfigManager.TARGET_SERVICE_CORE:
			var service_core_state := current_state.duplicate(true)
			service_core_state[field] = decor_id
			apartment_decor[ConfigManager.TARGET_SERVICE_CORE] = service_core_state
		ConfigManager.TARGET_ROOF:
			var roof_state := current_state.duplicate(true)
			roof_state[field] = decor_id
			apartment_decor[ConfigManager.TARGET_ROOF] = roof_state
		_:
			push_error("Unknown decor target kind '%s'." % kind)
			return false
	GameEvents.decor_target_changed.emit(kind, target_id, decor_id, category)
	return true

func apply_room_decor(room_id: String, decor_id: String) -> bool:
	return apply_space_decor(space_decor_target(ConfigManager.TARGET_ROOM, room_id), decor_id)

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

func add_furniture_instance(room_id: String, furniture_id: String, anchor_pos: Array, mirrored := false, orientation := "default") -> Dictionary:
	if not rooms.has(room_id):
		push_error("Cannot add furniture to unknown room '%s'." % room_id)
		return {}
	var furniture_data := ConfigManager.get_furniture_data(furniture_id)
	var normalized_orientation := _normalize_furniture_orientation(furniture_id, furniture_data, orientation)
	var room: Dictionary = rooms[room_id]
	var instance: Dictionary = {
		"instance_id": "f_%d_%d" % [Time.get_ticks_msec(), randi_range(100, 999)],
		"furniture_id": furniture_id,
		"anchor_pos": anchor_pos,
		"mirrored": mirrored,
		"orientation": normalized_orientation
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
	_request_tenant_furniture_reaction(room_id, furniture_id)
	add_apartment_exp(5)
	return instance

func move_furniture_instance(room_id: String, instance_id: String, anchor_pos: Array, orientation := "default") -> bool:
	if not rooms.has(room_id):
		push_error("Cannot move furniture in unknown room '%s'." % room_id)
		return false
	var room: Dictionary = rooms[room_id]
	var list: Array = room["furniture_instances"]
	for i in range(list.size()):
		var instance_data: Dictionary = list[i]
		if str(instance_data["instance_id"]) == instance_id:
			var furniture_id := str(instance_data["furniture_id"])
			var furniture_data := ConfigManager.get_furniture_data(furniture_id)
			instance_data["anchor_pos"] = anchor_pos
			instance_data["orientation"] = _normalize_furniture_orientation(furniture_id, furniture_data, orientation)
			list[i] = instance_data
			room["furniture_instances"] = list
			rooms[room_id] = room
			GameEvents.furniture_moved.emit(room_id, furniture_id)
			GameEvents.room_updated.emit(room_id)
			return true
	return false

func _request_tenant_furniture_reaction(room_id: String, furniture_id: String) -> void:
	var room: Dictionary = rooms.get(room_id, {})
	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty() or not tenants.has(tenant_id):
		return
	var tenant: Dictionary = tenants[tenant_id]
	if str(tenant.get("presence_state", TENANT_PRESENCE_HOME)) != TENANT_PRESENCE_HOME:
		return
	var preferred := _tenant_prefers_furniture(tenant_id, furniture_id)
	react_to_new_furniture(tenant_id, furniture_id, preferred)
	GameEvents.tenant_furniture_reaction_requested.emit(tenant_id, room_id, furniture_id, "favorite" if preferred else "new_furniture")

func _tenant_prefers_furniture(tenant_id: String, furniture_id: String) -> bool:
	var tenant_data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var furniture_data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var favorite_tags: Array = tenant_data.get("favorite_tags", [])
	for tag in furniture_data.get("tags", []):
		if favorite_tags.has(str(tag)):
			return true
	return false

func _normalize_furniture_orientation(furniture_id: String, furniture_data: Dictionary, orientation: String) -> String:
	var normalized := orientation.strip_edges()
	if normalized.is_empty():
		normalized = str(furniture_data.get("default_orientation", FurniturePlacementRules.DEFAULT_ORIENTATION)).strip_edges()
	ConfigManager.get_furniture_orientation_data(furniture_id, normalized)
	return normalized

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

func build_room(room_id: String) -> bool:
	if not is_room_buildable(room_id):
		return false
	var room_config: Dictionary = ConfigManager.get_room_config(room_id)
	var cost: int = int(room_config["build_cost"])
	if not spend_coins(cost):
		return false
	var room: Dictionary = rooms[room_id]
	room["unlocked"] = true
	rooms[room_id] = room
	stats["room_built_count"] = int(stats["room_built_count"]) + 1
	var floor_index := int(room_config["floor_index"])
	GameEvents.room_built.emit(room_id, floor_index)
	GameEvents.room_unlocked.emit(room_id)
	GameEvents.room_updated.emit(room_id)
	TaskManager.notify_event("room_built", {"room_id": room_id, "floor_index": floor_index})
	add_apartment_exp(int(ConfigManager.get_economy_value("room_build_exp")))
	return true

func observe_tenant_behavior(tenant_id: String, behavior_key: String, satisfaction_delta := 1) -> void:
	if not tenants.has(tenant_id):
		push_error("Cannot observe behavior for unknown tenant '%s'." % tenant_id)
		return
	var tenant: Dictionary = tenants[tenant_id]
	var behavior := _normalize_tenant_behavior(behavior_key)
	tenant["current_need"] = behavior
	tenant["current_behavior"] = behavior
	tenant["satisfaction"] = clampi(int(tenant["satisfaction"]) + maxi(0, satisfaction_delta), 0, 100)
	tenants[tenant_id] = tenant
	GameEvents.tenant_behavior_changed.emit(tenant_id, behavior)
	GameEvents.tenant_behavior_observed.emit(tenant_id, behavior)
	GameEvents.tenant_satisfaction_changed.emit(tenant_id, int(tenant["satisfaction"]))
	TaskManager.notify_event("tenant_behavior_observed", {"tenant_id": tenant_id, "behavior": behavior})
	EconomyManager.recalculate_total_rent()

func react_to_new_furniture(tenant_id: String, furniture_id: String, preferred := false) -> void:
	if not tenants.has(tenant_id):
		push_error("Cannot react for unknown tenant '%s'." % tenant_id)
		return
	var tenant: Dictionary = tenants[tenant_id]
	tenant["current_need"] = ""
	tenant["current_behavior"] = "happy"
	var delta := 2 if preferred else 1
	tenant["satisfaction"] = clampi(int(tenant["satisfaction"]) + delta, 0, 100)
	tenants[tenant_id] = tenant
	GameEvents.tenant_behavior_changed.emit(tenant_id, "happy")
	GameEvents.tenant_satisfaction_changed.emit(tenant_id, int(tenant["satisfaction"]))
	EconomyManager.recalculate_total_rent()

func to_save_data() -> Dictionary:
	return {
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"coins": coins,
		"total_rent_per_minute": total_rent_per_minute,
		"apartment_level": apartment_level,
		"apartment_exp": apartment_exp,
		"rooms": rooms,
		"public_area_decor": public_area_decor,
		"apartment_decor": apartment_decor,
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
	last_save_timestamp = int(data["last_save_timestamp"])
	rooms = (data["rooms"] as Dictionary).duplicate(true)
	public_area_decor = (data["public_area_decor"] as Dictionary).duplicate(true)
	apartment_decor = (data["apartment_decor"] as Dictionary).duplicate(true)
	tenants = (data["tenants"] as Dictionary).duplicate(true)
	tasks = (data["tasks"] as Dictionary).duplicate(true)
	stats = (data["stats"] as Dictionary).duplicate(true)
	for room_id in rooms.keys():
		recalculate_room_stats(str(room_id))
	EconomyManager.recalculate_total_rent()
	GameEvents.coins_changed.emit(coins)
	GameEvents.apartment_level_changed.emit(apartment_level)
	GameEvents.state_loaded.emit()

func _lower_room_floors_complete(floor_index: int) -> bool:
	for floor in ConfigManager.floors:
		var floor_data: Dictionary = floor
		var lower_floor_index := int(floor_data["floor_index"])
		if lower_floor_index >= floor_index:
			continue
		if ConfigManager.get_room_configs_for_floor(lower_floor_index).is_empty():
			continue
		if not is_floor_complete(lower_floor_index):
			return false
	return true

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
			"unlocked": bool(room_data["initial_unlocked"]),
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

func _new_public_area_decor_states() -> Dictionary:
	var result := {}
	for floor in ConfigManager.floors:
		var floor_data: Dictionary = floor
		var floor_index := int(floor_data["floor_index"])
		for area_item in floor_data["public_areas"]:
			var area: Dictionary = area_item
			var target_id := ConfigManager.public_area_target_id(floor_index, str(area["id"]))
			result[target_id] = {
				"target_id": target_id,
				"floor_index": floor_index,
				"area_id": str(area["id"]),
				"wallpaper_id": str(area["default_wallpaper_id"]),
				"wall_style_id": str(area["default_wall_style_id"]),
				"door_style_id": str(area.get("default_door_style_id", "")).strip_edges()
			}
	return result

func _new_apartment_decor_state() -> Dictionary:
	var service_core_defaults := ConfigManager.apartment_service_core_defaults()
	return {
		ConfigManager.TARGET_SERVICE_CORE: {
			"wallpaper_id": str(service_core_defaults["wallpaper_id"]),
			"wall_style_id": str(service_core_defaults["wall_style_id"])
		},
		ConfigManager.TARGET_ROOF: {
			"roof_style_id": ConfigManager.apartment_roof_default_style_id()
		}
	}

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
	for numeric_key in ["coins", "total_rent_per_minute", "apartment_level", "apartment_exp", "last_save_timestamp"]:
		if not _is_number(data[numeric_key]):
			return "save field '%s' must be numeric" % numeric_key
	if not (data["rooms"] is Dictionary):
		return "save field 'rooms' must be a dictionary"
	if not (data["public_area_decor"] is Dictionary):
		return "save field 'public_area_decor' must be a dictionary"
	if not (data["apartment_decor"] is Dictionary):
		return "save field 'apartment_decor' must be a dictionary"
	if not (data["tenants"] is Dictionary):
		return "save field 'tenants' must be a dictionary"
	if not (data["tasks"] is Dictionary):
		return "save field 'tasks' must be a dictionary"
	if not (data["stats"] is Dictionary):
		return "save field 'stats' must be a dictionary"
	var rooms_error := _rooms_validation_error(data["rooms"])
	if not rooms_error.is_empty():
		return rooms_error
	var public_area_error := _public_area_decor_validation_error(data["public_area_decor"])
	if not public_area_error.is_empty():
		return public_area_error
	var apartment_decor_error := _apartment_decor_validation_error(data["apartment_decor"])
	if not apartment_decor_error.is_empty():
		return apartment_decor_error
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
		var decor_error := _decor_state_reference_error(str(room[str(pair[0])]), str(pair[1]), "room '%s' field '%s'" % [room_id, str(pair[0])])
		if not decor_error.is_empty():
			return decor_error
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

func _public_area_decor_validation_error(saved_public_area_decor: Dictionary) -> String:
	if saved_public_area_decor.size() != ConfigManager.public_area_by_target_id.size():
		return "public area decor count does not match config"
	var valid_ids := {}
	for target_id in ConfigManager.public_area_by_target_id.keys():
		valid_ids[target_id] = true
		if not saved_public_area_decor.has(target_id):
			return "missing public area decor '%s'" % str(target_id)
		var state: Variant = saved_public_area_decor[target_id]
		if not (state is Dictionary):
			return "public area decor '%s' must be a dictionary" % str(target_id)
		var state_error := _public_area_state_validation_error(str(target_id), state, ConfigManager.get_public_area_config(str(target_id)))
		if not state_error.is_empty():
			return state_error
	for target_id in saved_public_area_decor.keys():
		if not valid_ids.has(str(target_id)):
			return "unknown public area decor '%s'" % str(target_id)
	return ""

func _public_area_state_validation_error(target_id: String, state: Dictionary, area_config: Dictionary) -> String:
	var key_error := _dictionary_keys_error(state, PUBLIC_AREA_DECOR_STATE_KEYS, "public area '%s'" % target_id)
	if not key_error.is_empty():
		return key_error
	if str(state["target_id"]) != target_id:
		return "public area '%s' target_id does not match key" % target_id
	if not _is_number(state["floor_index"]) or int(state["floor_index"]) != int(area_config["floor_index"]):
		return "public area '%s' floor_index does not match current config" % target_id
	if str(state["area_id"]) != str(area_config["id"]):
		return "public area '%s' area_id does not match current config" % target_id
	for pair in [
		["wallpaper_id", ConfigManager.DECOR_WALLPAPER],
		["wall_style_id", ConfigManager.DECOR_WALL]
	]:
		var decor_error := _decor_state_reference_error(str(state[str(pair[0])]), str(pair[1]), "public area '%s' field '%s'" % [target_id, str(pair[0])])
		if not decor_error.is_empty():
			return decor_error
	var door_style_id := str(state["door_style_id"]).strip_edges()
	if bool(area_config["has_entrance_door"]):
		var door_error := _decor_state_reference_error(door_style_id, ConfigManager.DECOR_DOOR, "public area '%s' field 'door_style_id'" % target_id)
		if not door_error.is_empty():
			return door_error
	elif not door_style_id.is_empty():
		return "public area '%s' must not preserve door_style_id without an entrance door" % target_id
	return ""

func _apartment_decor_validation_error(saved_apartment_decor: Dictionary) -> String:
	var key_error := _dictionary_keys_error(saved_apartment_decor, APARTMENT_DECOR_KEYS, "apartment decor")
	if not key_error.is_empty():
		return key_error
	var service_core_state: Variant = saved_apartment_decor[ConfigManager.TARGET_SERVICE_CORE]
	if not (service_core_state is Dictionary):
		return "apartment decor service_core must be a dictionary"
	var service_key_error := _dictionary_keys_error(service_core_state, SERVICE_CORE_DECOR_STATE_KEYS, "apartment service_core decor")
	if not service_key_error.is_empty():
		return service_key_error
	for pair in [
		["wallpaper_id", ConfigManager.DECOR_WALLPAPER],
		["wall_style_id", ConfigManager.DECOR_WALL]
	]:
		var decor_error := _decor_state_reference_error(str((service_core_state as Dictionary)[str(pair[0])]), str(pair[1]), "apartment service_core field '%s'" % str(pair[0]))
		if not decor_error.is_empty():
			return decor_error
	var roof_state: Variant = saved_apartment_decor[ConfigManager.TARGET_ROOF]
	if not (roof_state is Dictionary):
		return "apartment decor roof must be a dictionary"
	var roof_key_error := _dictionary_keys_error(roof_state, ROOF_DECOR_STATE_KEYS, "apartment roof decor")
	if not roof_key_error.is_empty():
		return roof_key_error
	return _decor_state_reference_error(str((roof_state as Dictionary)["roof_style_id"]), ConfigManager.DECOR_ROOF, "apartment roof field 'roof_style_id'")

func _decor_state_reference_error(decor_id: String, category: String, context: String) -> String:
	if not ConfigManager.room_decor_by_id.has(decor_id):
		return "%s references unknown decor '%s'" % [context, decor_id]
	var item: Dictionary = ConfigManager.room_decor_by_id[decor_id]
	if str(item["category"]) != category:
		return "%s references decor in the wrong category" % context
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
	if not _is_number_array(instance["anchor_pos"], 2):
		return "room '%s' furniture anchor_pos must be [x, y]" % room_id
	if not (instance["mirrored"] is bool):
		return "room '%s' furniture mirrored must be bool" % room_id
	if not (instance["orientation"] is String) or str(instance["orientation"]).strip_edges().is_empty():
		return "room '%s' furniture orientation must be a non-empty string" % room_id
	var orientation := str(instance["orientation"]).strip_edges()
	if not ConfigManager.get_furniture_data(furniture_id).get("orientations", {}).has(orientation):
		return "room '%s' furniture '%s' uses unsupported orientation '%s'" % [room_id, furniture_id, orientation]
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
	return _is_number_array(value, size)

func _is_number_array(value: Variant, size: int) -> bool:
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
