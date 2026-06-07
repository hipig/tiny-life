class_name RentRoomRow
extends PanelContainer

@onready var icon: TextureRect = $Row/Icon
@onready var title_label: Label = $Row/Texts/TitleLabel
@onready var detail_label: Label = $Row/Texts/DetailLabel

var empty_title_template := ""
var empty_detail_text := ""
var occupied_title_template := ""
var detail_template := ""
var fallback_tenant_name := ""

func setup(room: Dictionary) -> void:
	_bind_scene_text()
	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		AssetResolver.apply_asset_to_texture_rect(icon, UIPanelFactory.icon_asset("Package.png"), Color("#fff4dc"), Vector2i(16, 16))
		title_label.text = empty_title_template % room.get("room_name", "")
		detail_label.text = empty_detail_text
	else:
		var tenant_data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
		var breakdown: Dictionary = EconomyManager.get_room_rent_breakdown(room)
		AssetResolver.apply_asset_to_texture_rect(icon, UIPanelFactory.icon_asset("Properties.png"), Color("#fff4dc"), Vector2i(16, 16))
		title_label.text = occupied_title_template % [
			room.get("room_name", ""),
			float(breakdown.get("rent", 0.0))
		]
		detail_label.text = detail_template % [
			float(breakdown.get("base_rent", 0.0)),
			float(breakdown.get("score_part", 0.0)),
			tenant_data.get("name", fallback_tenant_name),
			float(breakdown.get("pay_multiplier", 1.0)),
			float(breakdown.get("satisfaction_multiplier", 1.0))
		]

func _bind_scene_text() -> void:
	empty_title_template = _template_text("EmptyTitleTemplate")
	empty_detail_text = _template_text("EmptyDetailText")
	occupied_title_template = _template_text("OccupiedTitleTemplate")
	detail_template = _template_text("DetailTemplate")
	fallback_tenant_name = _template_text("FallbackTenantName")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("RentRoomRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
