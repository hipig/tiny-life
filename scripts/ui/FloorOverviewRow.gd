class_name FloorOverviewRow
extends PanelContainer

@onready var icon: TextureRect = $Row/Icon
@onready var title_label: Label = $Row/Texts/TitleLabel
@onready var detail_label: Label = $Row/Texts/DetailLabel

var detail_template := ""
var built_state_text := ""
var buildable_state_text := ""
var locked_state_template := ""

func setup(floor: Dictionary) -> void:
	_bind_scene_text()
	var floor_index := int(floor.get("floor_index", 0))
	var stats := _floor_stats(floor_index)
	var state_text := _floor_state_text(floor)
	title_label.text = str(floor.get("display_name", "%dF" % floor_index))
	detail_label.text = detail_template % [
		state_text,
		int(floor.get("build_cost", 0)),
		int(stats.get("rooms", 0)),
		int(stats.get("tenants", 0)),
		float(stats.get("rent", 0.0))
	]

func _floor_stats(floor_index: int) -> Dictionary:
	var rooms := 0
	var tenants := 0
	var rent := 0.0
	for room in GameState.rooms.values():
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) != floor_index:
			continue
		rooms += 1
		if not str(room_data.get("tenant_id", "")).is_empty():
			tenants += 1
		rent += float(room_data.get("rent_per_minute", 0.0))
	return {"rooms": rooms, "tenants": tenants, "rent": rent}

func _floor_state_text(floor: Dictionary) -> String:
	var floor_index := int(floor.get("floor_index", 0))
	var required_level := int(floor.get("required_apartment_level", 1))
	if floor_index <= GameState.highest_built_floor:
		return built_state_text
	if floor_index == GameState.highest_built_floor + 1 and GameState.apartment_level >= required_level:
		return buildable_state_text
	return locked_state_template % required_level

func _bind_scene_text() -> void:
	detail_template = _template_text("DetailTemplate")
	built_state_text = _template_text("BuiltStateText")
	buildable_state_text = _template_text("BuildableStateText")
	locked_state_template = _template_text("LockedStateTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("FloorOverviewRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
