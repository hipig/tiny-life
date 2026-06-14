extends Node

const DECOR_WALLPAPER := "wallpaper"
const DECOR_WALL := "wall"
const DECOR_DOOR := "door"
const DECOR_ROOF := "roof"

const TARGET_ROOM := "room"
const TARGET_PUBLIC_AREA := "public_area"
const TARGET_SERVICE_CORE := "service_core"
const TARGET_ROOF := "roof"

const APARTMENT_SERVICE_CORE_TARGET_ID := "service_core"
const APARTMENT_ROOF_TARGET_ID := "roof"

const FURNITURE_ORIENTATION_FIXED := "fixed"
const FURNITURE_ORIENTATION_ROTATABLE := "rotatable"
const FURNITURE_ORIENTATION_DEFAULT := "default"
const FURNITURE_ORIENTATION_ROTATED := "rotated"

const ROOM_DECOR_CATEGORIES := [DECOR_WALLPAPER, DECOR_WALL, DECOR_DOOR]
const PUBLIC_AREA_DECOR_CATEGORIES := [DECOR_WALLPAPER, DECOR_WALL]
const SERVICE_CORE_DECOR_CATEGORIES := [DECOR_WALLPAPER, DECOR_WALL]
const ROOF_DECOR_CATEGORIES := [DECOR_ROOF]

const VALID_BEHAVIOR_KEYS := {
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

var furniture: Array = []
var tenants: Array = []
var tenant_regions: Array = []
var room_decor: Dictionary = {}
var apartment_visuals: Dictionary = {}
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
var public_area_by_target_id: Dictionary = {}
var room_by_id: Dictionary = {}
var rooms_by_floor_index: Dictionary = {}
var level_by_value: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	furniture = _load_required_array("res://data/furniture.json")
	tenants = _load_required_array("res://data/tenants.json")
	tenant_regions = _load_required_array("res://data/tenant_regions.json")
	room_decor = _load_required_dict("res://data/room_decor.json")
	apartment_visuals = _load_required_dict("res://data/apartment_visuals.json")
	rooms = _load_required_array("res://data/rooms.json")
	floors = _load_required_array("res://data/floors.json")
	tasks = _load_required_array("res://data/tasks.json")
	levels = _load_required_array("res://data/apartment_levels.json")
	economy = _load_required_dict("res://data/economy.json")
	ui_text = _load_required_dict("res://data/ui_text.json")
	behavior_aliases = _load_required_dict("res://data/behavior_aliases.json")
	platform_config = _load_required_dict("res://data/platform_config.json")
	_validate_all()
	_rebuild_indexes()

func get_furniture_data(id: String) -> Dictionary:
	return _required_dict_from_index(furniture_by_id, id, "Furniture")

func get_furniture_orientation_data(id: String, orientation := "") -> Dictionary:
	return furniture_orientation_data(get_furniture_data(id), orientation)

func furniture_orientation_data(furniture_data: Dictionary, orientation := "") -> Dictionary:
	var orientations := _require_dict(furniture_data, "orientations", "furniture '%s'" % str(furniture_data.get("id", "")))
	var selected := orientation.strip_edges()
	if selected.is_empty():
		selected = str(furniture_data["default_orientation"]).strip_edges()
	if not orientations.has(selected):
		_fail("Furniture '%s' does not support orientation '%s'." % [str(furniture_data.get("id", "")), selected])
		return {}
	var data: Variant = orientations[selected]
	_expect(data is Dictionary, "Furniture '%s' orientation '%s' must be a dictionary." % [str(furniture_data.get("id", "")), selected])
	return (data as Dictionary).duplicate(true)

func furniture_can_rotate(furniture_data: Dictionary) -> bool:
	return str(furniture_data.get("orientation_mode", "")).strip_edges() == FURNITURE_ORIENTATION_ROTATABLE

func next_furniture_orientation(furniture_data: Dictionary, orientation := "") -> String:
	if not furniture_can_rotate(furniture_data):
		return str(furniture_data["default_orientation"]).strip_edges()
	var current := orientation.strip_edges()
	if current.is_empty():
		current = str(furniture_data["default_orientation"]).strip_edges()
	return FURNITURE_ORIENTATION_DEFAULT if current == FURNITURE_ORIENTATION_ROTATED else FURNITURE_ORIENTATION_ROTATED

func get_tenant_data(id: String) -> Dictionary:
	return _required_dict_from_index(tenant_by_id, id, "Tenant")

func get_tenant_region_data(id: String) -> Dictionary:
	return _required_dict_from_index(tenant_region_by_id, id, "Tenant region")

func get_room_decor_item(id: String) -> Dictionary:
	return _required_dict_from_index(room_decor_by_id, id, "Room decor item")

func get_room_decor_items(category: String) -> Array:
	_expect(room_decor_by_category.has(category), "Unknown room decor category: %s" % category)
	return room_decor_by_category[category]

func get_space_decor_id(state: Dictionary, category: String) -> String:
	var field := decor_state_field_for_category(category)
	_expect(state.has(field), "Decor state is missing field '%s'." % field)
	return str(state[field]).strip_edges()

func get_room_decor_id(room: Dictionary, category: String) -> String:
	return get_space_decor_id(room, category)

func decor_state_field_for_category(category: String) -> String:
	match category:
		DECOR_WALLPAPER:
			return "wallpaper_id"
		DECOR_WALL:
			return "wall_style_id"
		DECOR_DOOR:
			return "door_style_id"
		DECOR_ROOF:
			return "roof_style_id"
		_:
			_fail("Unknown decor category: %s" % category)
			return ""

func room_decor_field_for_category(category: String) -> String:
	return decor_state_field_for_category(category)

func room_decor_default_field_for_category(category: String) -> String:
	match category:
		DECOR_WALLPAPER:
			return "default_wallpaper_id"
		DECOR_WALL:
			return "default_wall_style_id"
		DECOR_DOOR:
			return "default_door_style_id"
		_:
			_fail("Unknown room decor category: %s" % category)
			return ""

func tile_theme_from_decor_state(state: Dictionary) -> Dictionary:
	var theme := {}
	_merge_theme(theme, _wallpaper_theme_from_item(get_room_decor_item(get_space_decor_id(state, DECOR_WALLPAPER))))
	_merge_theme(theme, _wall_theme_from_item(get_room_decor_item(get_space_decor_id(state, DECOR_WALL))))
	return theme

func door_theme_from_decor_state(state: Dictionary) -> Dictionary:
	if not state.has(decor_state_field_for_category(DECOR_DOOR)):
		return {}
	var decor_id := str(state[decor_state_field_for_category(DECOR_DOOR)]).strip_edges()
	if decor_id.is_empty():
		return {}
	return get_room_decor_item(decor_id).duplicate(true)

func tile_theme_for_room(room: Dictionary) -> Dictionary:
	return tile_theme_from_decor_state(room)

func door_theme_for_room(room: Dictionary) -> Dictionary:
	return door_theme_from_decor_state(room)

func public_area_target_id(floor_index: int, area_id: String) -> String:
	return "%d:%s" % [floor_index, area_id.strip_edges()]

func get_public_area_config(target_id: String) -> Dictionary:
	return _required_dict_from_index(public_area_by_target_id, target_id, "Public area")

func build_space_decor_target(kind: String, id: String) -> Dictionary:
	var target_kind := kind.strip_edges()
	var target_id := id.strip_edges()
	match target_kind:
		TARGET_ROOM:
			var room_data := get_room_config(target_id)
			return {
				"kind": target_kind,
				"id": target_id,
				"title": str(room_data["room_name"]),
				"supported_categories": supported_decor_categories_for_target_kind(target_kind, room_data)
			}
		TARGET_PUBLIC_AREA:
			var public_area := get_public_area_config(target_id)
			return {
				"kind": target_kind,
				"id": target_id,
				"title": str(public_area["label"]),
				"supported_categories": supported_decor_categories_for_target_kind(target_kind, public_area)
			}
		TARGET_SERVICE_CORE:
			return {
				"kind": target_kind,
				"id": APARTMENT_SERVICE_CORE_TARGET_ID,
				"title": text("decor_target_service_core"),
				"supported_categories": supported_decor_categories_for_target_kind(target_kind)
			}
		TARGET_ROOF:
			return {
				"kind": target_kind,
				"id": APARTMENT_ROOF_TARGET_ID,
				"title": text("decor_target_roof"),
				"supported_categories": supported_decor_categories_for_target_kind(target_kind)
			}
		_:
			_fail("Unknown decor target kind: %s" % target_kind)
			return {}

func supported_decor_categories_for_target(target_ref: Dictionary) -> Array:
	if target_ref.has("supported_categories"):
		var configured: Variant = target_ref["supported_categories"]
		if configured is Array and not configured.is_empty():
			return (configured as Array).duplicate(true)
	var target_kind := str(target_ref.get("kind", "")).strip_edges()
	var target_id := str(target_ref.get("id", "")).strip_edges()
	match target_kind:
		TARGET_ROOM:
			return ROOM_DECOR_CATEGORIES.duplicate(true)
		TARGET_PUBLIC_AREA:
			return supported_decor_categories_for_target_kind(target_kind, get_public_area_config(target_id))
		TARGET_SERVICE_CORE:
			return SERVICE_CORE_DECOR_CATEGORIES.duplicate(true)
		TARGET_ROOF:
			return ROOF_DECOR_CATEGORIES.duplicate(true)
		_:
			_fail("Unknown decor target kind: %s" % target_kind)
			return []

func supported_decor_categories_for_target_kind(kind: String, target_config: Dictionary = {}) -> Array:
	match kind:
		TARGET_ROOM:
			return ROOM_DECOR_CATEGORIES.duplicate(true)
		TARGET_PUBLIC_AREA:
			var categories := PUBLIC_AREA_DECOR_CATEGORIES.duplicate(true)
			if bool(target_config.get("has_entrance_door", false)):
				categories.append(DECOR_DOOR)
			return categories
		TARGET_SERVICE_CORE:
			return SERVICE_CORE_DECOR_CATEGORIES.duplicate(true)
		TARGET_ROOF:
			return ROOF_DECOR_CATEGORIES.duplicate(true)
		_:
			_fail("Unknown decor target kind: %s" % kind)
			return []

func apartment_service_core_defaults() -> Dictionary:
	return _require_dict(apartment_visuals, "service_core_defaults", "apartment_visuals.json").duplicate(true)

func apartment_roof_layout() -> Dictionary:
	return _require_dict(apartment_visuals, "roof_theme", "apartment_visuals.json").duplicate(true)

func apartment_roof_default_style_id() -> String:
	return _require_string(_require_dict(apartment_visuals, "roof_theme", "apartment_visuals.json"), "default_roof_style_id", "apartment roof_theme")

func apartment_roof_theme_for_style(decor_id: String) -> Dictionary:
	var roof_theme := apartment_roof_layout()
	roof_theme.erase("default_roof_style_id")
	_merge_theme(roof_theme, _roof_theme_from_item(get_room_decor_item(decor_id)))
	return roof_theme

func apartment_roof_theme() -> Dictionary:
	return apartment_roof_theme_for_style(apartment_roof_default_style_id())

func get_unlocked_tenant_regions(apartment_level: int) -> Array:
	var result: Array = []
	for item in tenant_regions:
		var region_data: Dictionary = item
		if apartment_level >= int(region_data["required_apartment_level"]):
			result.append(region_data)
	return result

func get_region_candidate_tenants(region_id: String) -> Array:
	var region: Dictionary = get_tenant_region_data(region_id)
	var result: Array = []
	for tenant_id in region["tenant_ids"]:
		result.append(get_tenant_data(str(tenant_id)))
	return result

func refresh_tenant_applications() -> void:
	for i in range(tenant_regions.size()):
		var region: Dictionary = tenant_regions[i]
		var tenant_ids: Array = region["tenant_ids"].duplicate(true)
		tenant_ids.shuffle()
		region["tenant_ids"] = tenant_ids
		tenant_regions[i] = region
	_rebuild_indexes()

func get_floor_data(index: int) -> Dictionary:
	_expect(floor_by_index.has(index), "Unknown floor index: %d" % index)
	return floor_by_index[index]

func get_room_config(id: String) -> Dictionary:
	return _required_dict_from_index(room_by_id, id, "Room")

func get_room_configs_for_floor(floor_index: int) -> Array:
	_expect(rooms_by_floor_index.has(floor_index), "Unknown room floor index: %d" % floor_index)
	return rooms_by_floor_index[floor_index]

func get_room_layout_upgrade(room_id: String, target_level: int) -> Dictionary:
	for item in get_room_config(room_id)["layout_upgrades"]:
		var upgrade: Dictionary = item
		if int(upgrade["level"]) == target_level:
			return upgrade
	return {}

func get_level_data(level: int) -> Dictionary:
	if not level_by_value.has(level):
		return {}
	return level_by_value[level]

func get_economy_value(key: String) -> Variant:
	_expect(economy.has(key), "economy.json is missing key '%s'." % key)
	return economy[key]

func get_tenant_ai_value(key: String) -> Variant:
	var tenant_ai: Dictionary = _require_dict(economy, "tenant_ai", "economy.json")
	_expect(tenant_ai.has(key), "economy.json tenant_ai is missing key '%s'." % key)
	return tenant_ai[key]

func text(key: String) -> String:
	_expect(ui_text.has(key), "ui_text.json is missing key '%s'." % key)
	return str(ui_text[key])

func normalize_behavior_key(value: String) -> String:
	var key := value.strip_edges()
	_expect(not key.is_empty(), "Behavior key cannot be empty.")
	if behavior_aliases.has(key):
		key = str(behavior_aliases[key]).strip_edges()
	_expect(VALID_BEHAVIOR_KEYS.has(key), "Unknown behavior key '%s'." % key)
	return key

func furniture_with_tag(tag: String) -> Array:
	var result: Array = []
	for item in furniture:
		var data: Dictionary = item
		if tag in data["tags"]:
			result.append(data)
	return result

func _load_required_array(path: String) -> Array:
	var data: Variant = _load_required_json(path)
	_expect(data is Array, "Expected Array config at %s." % path)
	return data

func _load_required_dict(path: String) -> Dictionary:
	var data: Variant = _load_required_json(path)
	_expect(data is Dictionary, "Expected Dictionary config at %s." % path)
	return data

func _load_required_json(path: String) -> Variant:
	_expect(FileAccess.file_exists(path), "Config file does not exist: %s" % path)
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	_expect(error == OK, "Config parse failed for %s: %s" % [path, parser.get_error_message()])
	return parser.data

func _validate_all() -> void:
	_validate_behavior_aliases()
	_validate_ui_text()
	_validate_economy()
	_validate_platform_config()
	_validate_furniture()
	_validate_tenants()
	_validate_room_decor()
	_validate_apartment_visuals()
	_validate_floors()
	_validate_rooms()
	_validate_tenant_regions()
	_validate_tasks()
	_validate_levels()

func _validate_behavior_aliases() -> void:
	for key in behavior_aliases.keys():
		var alias := str(key).strip_edges()
		var canonical := str(behavior_aliases[key]).strip_edges()
		_expect(not alias.is_empty(), "behavior_aliases.json contains an empty alias key.")
		_expect(VALID_BEHAVIOR_KEYS.has(canonical), "behavior_aliases.json maps '%s' to unknown behavior '%s'." % [alias, canonical])

func _validate_ui_text() -> void:
	for key in ui_text.keys():
		_expect(not str(key).strip_edges().is_empty(), "ui_text.json contains an empty key.")
		_expect(ui_text[key] is String, "ui_text.json key '%s' must map to a string." % str(key))

func _validate_economy() -> void:
	for key in [
		"starting_coins",
		"base_rent",
		"score_rent_factor",
		"max_offline_seconds",
		"autosave_seconds",
		"coin_popup_interval",
		"recruit_application_count",
		"room_build_exp"
	]:
		_expect(economy.has(key), "economy.json is missing key '%s'." % key)
	var tenant_ai: Dictionary = _require_dict(economy, "tenant_ai", "economy.json")
	for key in [
		"away_chance",
		"away_seconds",
		"return_stagger_seconds",
		"route_speed",
		"door_animation_seconds",
		"door_open_idle_seconds",
		"elevator_animation_seconds",
		"elevator_idle_seconds",
		"elevator_open_show_progress",
		"elevator_close_hide_progress",
		"offscreen_margin"
	]:
		_expect(tenant_ai.has(key), "economy.json tenant_ai is missing key '%s'." % key)

func _validate_platform_config() -> void:
	_expect(platform_config.has("platform"), "platform_config.json is missing key 'platform'.")
	_expect(platform_config.has("rewarded_ads_enabled"), "platform_config.json is missing key 'rewarded_ads_enabled'.")

func _validate_furniture_orientations(data: Dictionary, furniture_id: String) -> void:
	var orientation_mode := _require_string(data, "orientation_mode", "furniture '%s'" % furniture_id)
	_expect(orientation_mode in [FURNITURE_ORIENTATION_FIXED, FURNITURE_ORIENTATION_ROTATABLE], "furniture '%s' orientation_mode is invalid." % furniture_id)
	var default_orientation := _require_string(data, "default_orientation", "furniture '%s'" % furniture_id)
	var orientations := _require_dict(data, "orientations", "furniture '%s'" % furniture_id)
	_expect(orientations.has(default_orientation), "furniture '%s' default_orientation must exist in orientations." % furniture_id)
	if orientation_mode == FURNITURE_ORIENTATION_ROTATABLE:
		_expect(not bool(data.get("wall_item", false)), "furniture '%s' wall items cannot be rotatable in v1." % furniture_id)
		_expect(orientations.has(FURNITURE_ORIENTATION_DEFAULT), "rotatable furniture '%s' must support default orientation." % furniture_id)
		_expect(orientations.has(FURNITURE_ORIENTATION_ROTATED), "rotatable furniture '%s' must support rotated orientation." % furniture_id)
	else:
		_expect(default_orientation == FURNITURE_ORIENTATION_DEFAULT, "fixed furniture '%s' default orientation must be default." % furniture_id)
	for orientation_key in orientations.keys():
		var orientation := str(orientation_key).strip_edges()
		_expect(not orientation.is_empty(), "furniture '%s' contains an empty orientation key." % furniture_id)
		var orientation_data := _require_dict(orientations, orientation, "furniture '%s' orientations" % furniture_id)
		_require_vector_array(orientation_data, "size", 2, "furniture '%s' orientation '%s'" % [furniture_id, orientation])
		_require_vector_array(orientation_data, "footprint", 2, "furniture '%s' orientation '%s'" % [furniture_id, orientation])
		_require_number(orientation_data, "rotation_degrees", "furniture '%s' orientation '%s'" % [furniture_id, orientation])
		_validate_asset_config(_require_dict(orientation_data, "asset", "furniture '%s' orientation '%s'" % [furniture_id, orientation]), "furniture '%s' orientation '%s' asset" % [furniture_id, orientation])

func _validate_furniture() -> void:
	var seen_ids := {}
	for item in furniture:
		_expect(item is Dictionary, "furniture.json entries must be dictionaries.")
		var data: Dictionary = item
		var furniture_id := _require_id(data, "furniture.json")
		_expect(not seen_ids.has(furniture_id), "Duplicate furniture id '%s'." % furniture_id)
		seen_ids[furniture_id] = true
		_require_string(data, "name", "furniture '%s'" % furniture_id)
		_require_string(data, "category", "furniture '%s'" % furniture_id)
		_require_number(data, "price", "furniture '%s'" % furniture_id)
		_require_number(data, "refund_rate", "furniture '%s'" % furniture_id)
		_validate_furniture_orientations(data, furniture_id)
		_require_number(data, "comfort", "furniture '%s'" % furniture_id)
		_require_number(data, "entertainment", "furniture '%s'" % furniture_id)
		_require_number(data, "hygiene", "furniture '%s'" % furniture_id)
		_require_number(data, "food", "furniture '%s'" % furniture_id)
		_require_string_array(data, "tags", "furniture '%s'" % furniture_id)
		_require_bool(data, "interactive", "furniture '%s'" % furniture_id)
		_require_bool(data, "requires_wall", "furniture '%s'" % furniture_id)
		_require_bool(data, "wall_item", "furniture '%s'" % furniture_id)
		var interaction := _require_dict(data, "interaction", "furniture '%s'" % furniture_id)
		if bool(data["interactive"]):
			_expect(VALID_BEHAVIOR_KEYS.has(_require_string(interaction, "behavior", "furniture '%s' interaction" % furniture_id)), "furniture '%s' interaction behavior must be a tenant behavior key." % furniture_id)
			_require_number(interaction, "duration", "furniture '%s' interaction" % furniture_id)
			_require_string(interaction, "bubble", "furniture '%s' interaction" % furniture_id)
			_require_string(interaction, "visual_effect", "furniture '%s' interaction" % furniture_id)
			_require_string(interaction, "floating_icon", "furniture '%s' interaction" % furniture_id)
			_require_number(interaction, "satisfaction_delta", "furniture '%s' interaction" % furniture_id)

func _validate_tenants() -> void:
	var seen_ids := {}
	for item in tenants:
		_expect(item is Dictionary, "tenants.json entries must be dictionaries.")
		var data: Dictionary = item
		var tenant_id := _require_id(data, "tenants.json")
		_expect(not seen_ids.has(tenant_id), "Duplicate tenant id '%s'." % tenant_id)
		seen_ids[tenant_id] = true
		_require_string(data, "name", "tenant '%s'" % tenant_id)
		_require_string(data, "job", "tenant '%s'" % tenant_id)
		_require_string(data, "personality", "tenant '%s'" % tenant_id)
		_require_string(data, "rarity", "tenant '%s'" % tenant_id)
		_require_number(data, "pay_multiplier", "tenant '%s'" % tenant_id)
		_require_number(data, "initial_satisfaction", "tenant '%s'" % tenant_id)
		_require_string_array(data, "favorite_tags", "tenant '%s'" % tenant_id)
		var asset := _require_dict(data, "asset", "tenant '%s' asset" % tenant_id)
		_validate_asset_config(asset, "tenant '%s' asset" % tenant_id)
		_expect(str(asset["type"]) == "spritesheet_animation", "tenant '%s' asset must use spritesheet_animation." % tenant_id)
		_require_vector_array(asset, "avatar_offset", 2, "tenant '%s' asset" % tenant_id)

func _validate_room_decor() -> void:
	var items := _require_array(room_decor, "items", "room_decor.json")
	var seen_ids := {}
	var categories := {}
	for item in items:
		_expect(item is Dictionary, "room_decor.json items must be dictionaries.")
		var data: Dictionary = item
		var decor_id := _require_id(data, "room_decor.json")
		_expect(not seen_ids.has(decor_id), "Duplicate room decor id '%s'." % decor_id)
		seen_ids[decor_id] = true
		var category := _require_string(data, "category", "room decor '%s'" % decor_id)
		_expect(category in [DECOR_WALLPAPER, DECOR_WALL, DECOR_DOOR, DECOR_ROOF], "Unknown room decor category '%s'." % category)
		categories[category] = true
		_require_string(data, "name", "room decor '%s'" % decor_id)
		_require_number(data, "price", "room decor '%s'" % decor_id)
		_validate_asset_config(_require_dict(data, "preview_asset", "room decor '%s' preview_asset" % decor_id), "room decor '%s' preview_asset" % decor_id)
		match category:
			DECOR_WALLPAPER:
				_validate_wallpaper_theme(_require_dict(data, "theme", "room decor '%s'" % decor_id), decor_id)
			DECOR_WALL:
				_validate_wall_theme(_require_dict(data, "theme", "room decor '%s'" % decor_id), decor_id)
			DECOR_DOOR:
				_validate_door_theme(data, decor_id)
			DECOR_ROOF:
				_validate_roof_style_theme(_require_dict(data, "theme", "room decor '%s'" % decor_id), decor_id)
	for required_category in [DECOR_WALLPAPER, DECOR_WALL, DECOR_DOOR, DECOR_ROOF]:
		_expect(categories.has(required_category), "room_decor.json must include category '%s'." % required_category)

func _validate_floors() -> void:
	var seen_indexes := {}
	for item in floors:
		_expect(item is Dictionary, "floors.json entries must be dictionaries.")
		var data: Dictionary = item
		var floor_index := int(_require_number(data, "floor_index", "floors.json"))
		_expect(not seen_indexes.has(floor_index), "Duplicate floor index %d." % floor_index)
		seen_indexes[floor_index] = true
		_require_string(data, "display_name", "floor %d" % floor_index)
		_require_string(data, "visual_role", "floor %d" % floor_index)
		_require_bool(data, "initial_built", "floor %d" % floor_index)
		_expect(not data.has("required_apartment_level"), "floor %d must not configure required_apartment_level; room config owns build gating." % floor_index)
		_expect(not data.has("build_cost"), "floor %d must not configure build_cost; room config owns build cost." % floor_index)
		_expect(not data.has("roof_asset"), "floor %d must not configure roof_asset; apartment_visuals.json owns the building roof." % floor_index)
		_expect(not data.has("roof_theme"), "floor %d must not configure roof_theme; apartment_visuals.json owns the building roof." % floor_index)
		_require_string(data, "service_label", "floor %d" % floor_index)
		_validate_asset_config(_require_dict(data, "floor_icon_asset", "floor %d" % floor_index), "floor %d floor_icon_asset" % floor_index)
		_validate_asset_config(_require_dict(data, "build_icon_asset", "floor %d build_icon_asset" % floor_index), "floor %d build_icon_asset" % floor_index)
		_expect(not data.has("floor_scene_path"), "floor %d must not configure runtime floor_scene_path." % floor_index)
		_expect(not data.has("build_slot_scene_path"), "floor %d must not configure runtime build_slot_scene_path." % floor_index)
		var public_areas := _require_array(data, "public_areas", "floor %d" % floor_index)
		var seen_area_ids := {}
		for entry in public_areas:
			_expect(entry is Dictionary, "floor %d public areas must be dictionaries." % floor_index)
			var area: Dictionary = entry
			var area_id := _require_id(area, "floor %d public area" % floor_index)
			_expect(not seen_area_ids.has(area_id), "floor %d has duplicate public area id '%s'." % [floor_index, area_id])
			seen_area_ids[area_id] = true
			_require_string(area, "label", "floor %d public area" % floor_index)
			_require_string(area, "layout_side", "floor %d public area" % floor_index)
			_require_bool(area, "has_entrance_door", "floor %d public area" % floor_index)
			_require_vector_array(area, "frame_tiles", 2, "floor %d public area" % floor_index)
			_expect(not area.has("public_area_scene_path"), "floor %d public area must not configure runtime public_area_scene_path." % floor_index)
			var wallpaper_id := _require_string(area, "default_wallpaper_id", "floor %d public area '%s'" % [floor_index, area_id])
			var wall_style_id := _require_string(area, "default_wall_style_id", "floor %d public area '%s'" % [floor_index, area_id])
			_expect(_room_decor_id_has_category(wallpaper_id, DECOR_WALLPAPER), "floor %d public area '%s' default_wallpaper_id must reference wallpaper decor." % [floor_index, area_id])
			_expect(_room_decor_id_has_category(wall_style_id, DECOR_WALL), "floor %d public area '%s' default_wall_style_id must reference wall decor." % [floor_index, area_id])
			var door_style_id := str(area.get("default_door_style_id", "")).strip_edges()
			if bool(area["has_entrance_door"]):
				_require_string(area, "door_side", "floor %d public area '%s'" % [floor_index, area_id])
				_require_bool(area, "door_mirrored", "floor %d public area '%s'" % [floor_index, area_id])
				_expect(not door_style_id.is_empty(), "floor %d public area '%s' must declare default_door_style_id when it has an entrance door." % [floor_index, area_id])
				_expect(_room_decor_id_has_category(door_style_id, DECOR_DOOR), "floor %d public area '%s' default_door_style_id must reference door decor." % [floor_index, area_id])
			else:
				_expect(door_style_id.is_empty(), "floor %d public area '%s' must not declare default_door_style_id without an entrance door." % [floor_index, area_id])

func _validate_rooms() -> void:
	var seen_ids := {}
	var valid_floor_indexes := {}
	for item in floors:
		var floor_data: Dictionary = item
		valid_floor_indexes[int(floor_data["floor_index"])] = true
	for item in rooms:
		_expect(item is Dictionary, "rooms.json entries must be dictionaries.")
		var data: Dictionary = item
		var room_id := _require_id(data, "rooms.json")
		_expect(not seen_ids.has(room_id), "Duplicate room id '%s'." % room_id)
		seen_ids[room_id] = true
		var floor_index := int(_require_number(data, "floor_index", "room '%s'" % room_id))
		_expect(valid_floor_indexes.has(floor_index), "room '%s' references unknown floor %d." % [room_id, floor_index])
		_require_string(data, "room_name", "room '%s'" % room_id)
		_require_string(data, "layout_side", "room '%s'" % room_id)
		_require_string(data, "door_side", "room '%s'" % room_id)
		_require_bool(data, "door_mirrored", "room '%s'" % room_id)
		_require_vector_array(data, "door_visual_offset", 2, "room '%s'" % room_id)
		_require_bool(data, "initial_unlocked", "room '%s'" % room_id)
		_require_number(data, "required_apartment_level", "room '%s'" % room_id)
		_require_number(data, "build_cost", "room '%s'" % room_id)
		_expect(not data.has("room_scene_path"), "room '%s' must not configure runtime room_scene_path." % room_id)
		_require_vector_array(data, "frame_tiles", 2, "room '%s'" % room_id)
		_require_vector_array(data, "grid_size", 2, "room '%s'" % room_id)
		var wallpaper_id := _require_string(data, "default_wallpaper_id", "room '%s'" % room_id)
		var wall_style_id := _require_string(data, "default_wall_style_id", "room '%s'" % room_id)
		var door_style_id := _require_string(data, "default_door_style_id", "room '%s'" % room_id)
		_expect(_room_decor_id_has_category(wallpaper_id, DECOR_WALLPAPER), "room '%s' default_wallpaper_id must reference wallpaper decor." % room_id)
		_expect(_room_decor_id_has_category(wall_style_id, DECOR_WALL), "room '%s' default_wall_style_id must reference wall decor." % room_id)
		_expect(_room_decor_id_has_category(door_style_id, DECOR_DOOR), "room '%s' default_door_style_id must reference door decor." % room_id)
		var upgrades := _require_array(data, "layout_upgrades", "room '%s'" % room_id)
		_expect(not upgrades.is_empty(), "room '%s' must declare at least one layout upgrade." % room_id)
		for upgrade in upgrades:
			_expect(upgrade is Dictionary, "room '%s' layout_upgrades must be dictionaries." % room_id)
			var layout_upgrade: Dictionary = upgrade
			_require_number(layout_upgrade, "level", "room '%s' layout upgrade" % room_id)
			_require_vector_array(layout_upgrade, "frame_tiles", 2, "room '%s' layout upgrade" % room_id)
			_require_vector_array(layout_upgrade, "grid_size", 2, "room '%s' layout upgrade" % room_id)

func _validate_apartment_visuals() -> void:
	var roof_layout := _require_dict(apartment_visuals, "roof_theme", "apartment_visuals.json")
	_validate_apartment_roof_layout(roof_layout, "apartment roof_theme")
	var service_core_defaults := _require_dict(apartment_visuals, "service_core_defaults", "apartment_visuals.json")
	var service_wallpaper_id := _require_string(service_core_defaults, "wallpaper_id", "apartment service_core_defaults")
	var service_wall_style_id := _require_string(service_core_defaults, "wall_style_id", "apartment service_core_defaults")
	_expect(_room_decor_id_has_category(service_wallpaper_id, DECOR_WALLPAPER), "apartment service_core_defaults wallpaper_id must reference wallpaper decor.")
	_expect(_room_decor_id_has_category(service_wall_style_id, DECOR_WALL), "apartment service_core_defaults wall_style_id must reference wall decor.")

func _validate_tenant_regions() -> void:
	var seen_ids := {}
	for item in tenant_regions:
		_expect(item is Dictionary, "tenant_regions.json entries must be dictionaries.")
		var data: Dictionary = item
		var region_id := _require_id(data, "tenant_regions.json")
		_expect(not seen_ids.has(region_id), "Duplicate tenant region id '%s'." % region_id)
		seen_ids[region_id] = true
		_require_string(data, "name", "tenant region '%s'" % region_id)
		_require_number(data, "required_apartment_level", "tenant region '%s'" % region_id)
		_require_string(data, "rent_tolerance_level", "tenant region '%s'" % region_id)
		_require_number(data, "max_rent_per_minute", "tenant region '%s'" % region_id)
		_require_number(data, "application_count", "tenant region '%s'" % region_id)
		var tenant_ids := _require_array(data, "tenant_ids", "tenant region '%s'" % region_id)
		_expect(not tenant_ids.is_empty(), "tenant region '%s' must reference at least one tenant id." % region_id)
		for tenant_id in tenant_ids:
			_expect(_tenant_id_exists(str(tenant_id)), "tenant region '%s' references unknown tenant '%s'." % [region_id, str(tenant_id)])

func _validate_tasks() -> void:
	var seen_ids := {}
	for item in tasks:
		_expect(item is Dictionary, "tasks.json entries must be dictionaries.")
		var data: Dictionary = item
		var task_id := _require_id(data, "tasks.json")
		_expect(not seen_ids.has(task_id), "Duplicate task id '%s'." % task_id)
		seen_ids[task_id] = true
		_require_string(data, "title", "task '%s'" % task_id)
		_require_string(data, "description", "task '%s'" % task_id)
		_require_string(data, "type", "task '%s'" % task_id)
		_require_number(data, "target_value", "task '%s'" % task_id)
		_require_number(data, "reward_coins", "task '%s'" % task_id)
		_require_number(data, "reward_exp", "task '%s'" % task_id)

func _validate_levels() -> void:
	var previous_level := 0
	var previous_required_exp := -1
	for item in levels:
		_expect(item is Dictionary, "apartment_levels.json entries must be dictionaries.")
		var data: Dictionary = item
		var level := int(_require_number(data, "level", "apartment_levels.json"))
		var required_exp := int(_require_number(data, "required_exp", "apartment_levels.json"))
		_expect(level > previous_level, "apartment_levels.json levels must be strictly increasing.")
		_expect(required_exp >= previous_required_exp, "apartment_levels.json required_exp must be non-decreasing.")
		previous_level = level
		previous_required_exp = required_exp

func _rebuild_indexes() -> void:
	furniture_by_id.clear()
	for item in furniture:
		var furniture_data: Dictionary = item
		furniture_by_id[str(furniture_data["id"])] = furniture_data

	tenant_by_id.clear()
	for item in tenants:
		var tenant_data: Dictionary = item
		tenant_by_id[str(tenant_data["id"])] = tenant_data

	tenant_region_by_id.clear()
	for item in tenant_regions:
		var region_data: Dictionary = item
		tenant_region_by_id[str(region_data["id"])] = region_data

	room_decor_by_id.clear()
	room_decor_by_category.clear()
	room_decor_items = room_decor["items"]
	for item in room_decor_items:
		var decor_data: Dictionary = item
		var decor_id := str(decor_data["id"])
		var category := str(decor_data["category"])
		room_decor_by_id[decor_id] = decor_data
		if not room_decor_by_category.has(category):
			room_decor_by_category[category] = []
		room_decor_by_category[category].append(decor_data)

	floor_by_index.clear()
	public_area_by_target_id.clear()
	for item in floors:
		var floor_data: Dictionary = item
		var floor_index := int(floor_data["floor_index"])
		floor_by_index[floor_index] = floor_data
		for area_item in floor_data["public_areas"]:
			var public_area: Dictionary = area_item
			var target_id := public_area_target_id(floor_index, str(public_area["id"]))
			var indexed_area := public_area.duplicate(true)
			indexed_area["floor_index"] = floor_index
			indexed_area["target_id"] = target_id
			public_area_by_target_id[target_id] = indexed_area

	room_by_id.clear()
	rooms_by_floor_index.clear()
	for item in rooms:
		var room_data: Dictionary = item
		var room_id := str(room_data["id"])
		var floor_index := int(room_data["floor_index"])
		room_by_id[room_id] = room_data
		if not rooms_by_floor_index.has(floor_index):
			rooms_by_floor_index[floor_index] = []
		rooms_by_floor_index[floor_index].append(room_data)
	for floor_data in floors:
		var floor_index := int((floor_data as Dictionary)["floor_index"])
		if not rooms_by_floor_index.has(floor_index):
			rooms_by_floor_index[floor_index] = []

	level_by_value.clear()
	for item in levels:
		var level_data: Dictionary = item
		level_by_value[int(level_data["level"])] = level_data

func _validate_wallpaper_theme(theme: Dictionary, decor_id: String) -> void:
	_require_number(theme, "wallpaper_source_id", "wallpaper theme '%s'" % decor_id)
	var pattern := _require_dict(theme, "wallpaper_pattern", "wallpaper theme '%s'" % decor_id)
	for row_key in ["top", "middle", "bottom"]:
		_require_vector_array(pattern, row_key, 2, "wallpaper theme '%s'" % decor_id, true)

func _validate_wall_theme(theme: Dictionary, decor_id: String) -> void:
	_require_number(theme, "wall_body_source_id", "wall theme '%s'" % decor_id)
	for key in [
		"body_top_left_corner_tile",
		"body_top_right_corner_tile",
		"body_bottom_left_corner_tile",
		"body_bottom_right_corner_tile"
	]:
		_require_vector_array(theme, key, 2, "wall theme '%s'" % decor_id)
	for key in [
		"body_top_edge_tiles",
		"body_left_edge_tiles",
		"body_left_door_edge_tiles",
		"body_right_door_edge_tiles",
		"body_right_edge_tiles",
		"body_bottom_edge_tiles"
	]:
		_require_vector_array(theme, key, 2, "wall theme '%s'" % decor_id, true)

func _validate_roof_style_theme(theme: Dictionary, decor_id: String) -> void:
	_require_number(theme, "wall_edge_source_id", "roof theme '%s'" % decor_id)
	_require_vector_array(theme, "roof_left_tile", 2, "roof theme '%s'" % decor_id)
	_require_vector_array(theme, "roof_tiles", 2, "roof theme '%s'" % decor_id, true)
	_require_vector_array(theme, "roof_right_tile", 2, "roof theme '%s'" % decor_id)

func _validate_apartment_roof_layout(theme: Dictionary, context: String) -> void:
	var roof_style_id := _require_string(theme, "default_roof_style_id", context)
	_expect(_room_decor_id_has_category(roof_style_id, DECOR_ROOF), "%s default_roof_style_id must reference roof decor." % context)
	_expect(int(_require_number(theme, "total_width_tiles", context)) > 0, "%s total_width_tiles must be greater than 0." % context)
	_require_vector_array(theme, "offset_pixels", 2, context)

func _validate_door_theme(data: Dictionary, decor_id: String) -> void:
	var door_asset := _require_dict(data, "door_asset", "door decor '%s'" % decor_id)
	_validate_asset_config(door_asset, "door decor '%s' door_asset" % decor_id)
	var animations := _require_dict(door_asset, "animations", "door decor '%s' door_asset" % decor_id)
	for animation_name in ["default", "open", "close"]:
		_expect(animations.has(animation_name), "door decor '%s' door_asset must declare '%s' animation." % [decor_id, animation_name])
	_require_vector_array(data, "sprite_offset", 2, "door decor '%s'" % decor_id)
	_require_number(data, "closed_frame", "door decor '%s'" % decor_id)
	_require_number(data, "open_frame", "door decor '%s'" % decor_id)

func _validate_asset_config(asset: Dictionary, context: String) -> void:
	var asset_type := _require_string(asset, "type", context)
	match asset_type:
		"single_sprite":
			_require_texture_path(asset, context)
		"atlas_region":
			_require_texture_path(asset, context)
			_require_vector_array(asset, "region", 4, context)
		"spritesheet_frame":
			_require_texture_path(asset, context)
			_require_vector_array(asset, "frame_size", 2, context)
			_expect(asset.has("frame") or asset.has("region"), "%s must declare frame or region." % context)
		"spritesheet_animation":
			_require_texture_path(asset, context)
			_require_vector_array(asset, "frame_size", 2, context)
			_require_string(asset, "default_animation", context)
			var animations := _require_dict(asset, "animations", context)
			_expect(not animations.is_empty(), "%s must declare animations." % context)
		_:
			_fail("%s uses unsupported asset type '%s'." % [context, asset_type])

func _room_decor_id_has_category(decor_id: String, category: String) -> bool:
	for item in room_decor["items"]:
		var decor_data: Dictionary = item
		if str(decor_data["id"]) == decor_id and str(decor_data["category"]) == category:
			return true
	return false

func _tenant_id_exists(tenant_id: String) -> bool:
	for item in tenants:
		var tenant_data: Dictionary = item
		if str(tenant_data["id"]) == tenant_id:
			return true
	return false

func _required_dict_from_index(index: Dictionary, id: String, label: String) -> Dictionary:
	_expect(index.has(id), "%s '%s' was not found in config." % [label, id])
	return index[id]

func _wallpaper_theme_from_item(item: Dictionary) -> Dictionary:
	return _require_dict(item, "theme", "wallpaper decor")

func _wall_theme_from_item(item: Dictionary) -> Dictionary:
	return _require_dict(item, "theme", "wall decor")

func _roof_theme_from_item(item: Dictionary) -> Dictionary:
	return _require_dict(item, "theme", "roof decor")

func _merge_theme(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = source[key]

func _require_id(data: Dictionary, context: String) -> String:
	return _require_string(data, "id", context)

func _require_string(data: Dictionary, key: String, context: String) -> String:
	_expect(data.has(key), "%s is missing key '%s'." % [context, key])
	var value := str(data[key]).strip_edges()
	_expect(not value.is_empty(), "%s key '%s' cannot be empty." % [context, key])
	return value

func _require_number(data: Dictionary, key: String, context: String) -> float:
	_expect(data.has(key), "%s is missing key '%s'." % [context, key])
	var value: Variant = data[key]
	_expect(value is int or value is float, "%s key '%s' must be numeric." % [context, key])
	return float(value)

func _require_bool(data: Dictionary, key: String, context: String) -> bool:
	_expect(data.has(key), "%s is missing key '%s'." % [context, key])
	_expect(data[key] is bool, "%s key '%s' must be bool." % [context, key])
	return bool(data[key])

func _require_dict(data: Dictionary, key: String, context: String) -> Dictionary:
	_expect(data.has(key), "%s is missing key '%s'." % [context, key])
	_expect(data[key] is Dictionary, "%s key '%s' must be a dictionary." % [context, key])
	return data[key]

func _require_array(data: Dictionary, key: String, context: String) -> Array:
	_expect(data.has(key), "%s is missing key '%s'." % [context, key])
	_expect(data[key] is Array, "%s key '%s' must be an array." % [context, key])
	return data[key]

func _require_string_array(data: Dictionary, key: String, context: String) -> Array:
	var list := _require_array(data, key, context)
	for item in list:
		_expect(item is String and not str(item).strip_edges().is_empty(), "%s key '%s' must contain non-empty strings." % [context, key])
	return list

func _require_vector_array(data: Dictionary, key: String, entry_size: int, context: String, nested := false) -> Array:
	var list := _require_array(data, key, context)
	_expect(not list.is_empty(), "%s key '%s' cannot be empty." % [context, key])
	if nested:
		for item in list:
			_expect(item is Array and item.size() >= entry_size, "%s key '%s' entries must be arrays of size %d." % [context, key, entry_size])
	else:
		_expect(list.size() >= entry_size, "%s key '%s' must have at least %d entries." % [context, key, entry_size])
	return list

func _require_texture_path(asset: Dictionary, context: String) -> void:
	var path := _require_string(asset, "texture", context)
	_expect(FileAccess.file_exists(path), "%s texture does not exist: %s" % [context, path])

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)

func _fail(message: String) -> void:
	push_error(message)
	assert(false, message)
