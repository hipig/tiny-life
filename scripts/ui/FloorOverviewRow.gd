class_name FloorOverviewRow
extends PanelContainer

@onready var icon: TextureRect = $Row/Icon
@onready var title_label: Label = $Row/Texts/TitleLabel
@onready var detail_label: Label = $Row/Texts/DetailLabel

var detail_template := ""
var built_state_text := ""
var buildable_state_template := ""
var partial_state_text := ""
var locked_state_template := ""
var blocked_state_text := ""
var public_state_text := ""

func setup(floor: Dictionary) -> void:
	_bind_scene_text()
	var floor_index := int(floor.get("floor_index", 0))
	var stats := _floor_stats(floor_index)
	var state_text := _floor_state_text(floor, stats)
	title_label.text = str(floor.get("display_name", "%dF" % floor_index))
	detail_label.text = detail_template % [
		state_text,
		int(stats.get("built_rooms", 0)),
		int(stats.get("total_rooms", 0)),
		int(stats.get("buildable_cost", 0)),
		int(stats.get("tenants", 0)),
		float(stats.get("rent", 0.0))
	]

func _floor_stats(floor_index: int) -> Dictionary:
	var total_rooms := ConfigManager.get_room_configs_for_floor(floor_index).size()
	var built_rooms := 0
	var tenants := 0
	var rent := 0.0
	for room in GameState.rooms.values():
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) != floor_index:
			continue
		if bool(room_data.get("unlocked", false)):
			built_rooms += 1
		if not str(room_data.get("tenant_id", "")).is_empty():
			tenants += 1
		rent += float(room_data.get("rent_per_minute", 0.0))
	var buildable_count := 0
	var buildable_cost := 0
	for room_config in GameState.get_buildable_rooms_on_floor(floor_index):
		var data: Dictionary = room_config
		buildable_count += 1
		buildable_cost += int(data.get("build_cost", 0))
	return {
		"total_rooms": total_rooms,
		"built_rooms": built_rooms,
		"buildable_count": buildable_count,
		"buildable_cost": buildable_cost,
		"tenants": tenants,
		"rent": rent
	}

func _floor_state_text(floor: Dictionary, stats: Dictionary) -> String:
	var floor_index := int(floor.get("floor_index", 0))
	var total_rooms := int(stats.get("total_rooms", 0))
	if total_rooms == 0:
		return public_state_text
	var built_rooms := int(stats.get("built_rooms", 0))
	if built_rooms >= total_rooms:
		return built_state_text
	var buildable_count := int(stats.get("buildable_count", 0))
	if buildable_count > 0:
		return buildable_state_template % buildable_count
	if built_rooms > 0:
		return partial_state_text
	var required_level := _minimum_required_level(floor_index)
	if GameState.apartment_level < required_level:
		return locked_state_template % required_level
	return blocked_state_text

func _minimum_required_level(floor_index: int) -> int:
	var result := 1
	var first := true
	for room_config in ConfigManager.get_room_configs_for_floor(floor_index):
		var data: Dictionary = room_config
		var required_level := int(data.get("required_apartment_level", 1))
		if first:
			result = required_level
			first = false
		else:
			result = mini(result, required_level)
	return result

func _bind_scene_text() -> void:
	detail_template = _template_text("DetailTemplate")
	built_state_text = _template_text("BuiltStateText")
	buildable_state_template = _template_text("BuildableStateTemplate")
	partial_state_text = _template_text("PartialStateText")
	locked_state_template = _template_text("LockedStateTemplate")
	blocked_state_text = _template_text("BlockedStateText")
	public_state_text = _template_text("PublicStateText")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("FloorOverviewRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
