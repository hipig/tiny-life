class_name TenantOverviewRow
extends PanelContainer

@onready var icon: TextureRect = $Row/Icon
@onready var title_label: Label = $Row/Texts/TitleLabel
@onready var detail_label: Label = $Row/Texts/DetailLabel

var title_template := ""
var detail_template := ""

func setup(tenant_id: String, tenant_state: Dictionary) -> void:
	_bind_scene_text()
	var room_id := str(tenant_state.get("room_id", ""))
	var tenant_data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var room: Dictionary = GameState.rooms.get(room_id, {})
	title_label.text = title_template % [
		str(tenant_data["name"]),
		str(tenant_data["job"])
	]
	detail_label.text = detail_template % [
		room.get("room_name", room_id),
		int(tenant_state.get("satisfaction", 0)),
		float(room.get("rent_per_minute", 0.0)),
		", ".join(tenant_data.get("favorite_tags", []))
	]

func _bind_scene_text() -> void:
	title_template = _template_text("TitleTemplate")
	detail_template = _template_text("DetailTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("TenantOverviewRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
