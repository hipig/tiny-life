class_name TenantPanel
extends "res://scripts/ui/AppPanel.gd"

signal tenant_recruit_requested(tenant_id: String, room_id: String)

var room_id := ""
var mode := "view"
var selected_region_id := ""

func open(target_room_id: String, panel_mode: String) -> void:
	room_id = target_room_id
	mode = panel_mode
	selected_region_id = ""
	if mode == "recruit":
		_show_regions()
	else:
		_show_tenant_view()

func _show_regions() -> void:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	setup_panel("租客")
	if not str(room.get("tenant_id", "")).is_empty():
		add_text("当前房间已有租客，暂不能招募。")
		return
	add_text("选择寻找租客的区域")
	for region_data in ConfigManager.tenant_regions:
		var region: Dictionary = region_data
		var required_level := int(region.get("required_apartment_level", 1))
		var unlocked := GameState.apartment_level >= required_level
		var row := add_row()
		var detail := "%s  Lv.%d 解锁  承受等级：%s  上限 %.1f/分钟" % [
			region.get("name", "区域"),
			required_level,
			region.get("rent_tolerance_level", "普通"),
			float(region.get("max_rent_per_minute", 0.0))
		]
		if not unlocked:
			detail += "  未解锁"
		row.add_child(UIPanelFactory.make_label(detail))
		var button := Button.new()
		UIPanelFactory.style_button(button, Vector2(150, 52))
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.text = "寻找"
		button.disabled = not unlocked
		var region_id := str(region.get("id", ""))
		button.pressed.connect(_show_candidates.bind(region_id))
		row.add_child(button)

func _show_candidates(region_id: String) -> void:
	selected_region_id = region_id
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var region: Dictionary = ConfigManager.get_tenant_region_data(region_id)
	setup_panel("租客：%s" % region.get("name", "区域"))
	add_action_button("返回区域", _show_regions, Vector2(180, 52))
	add_text("租金承受：%s，上限 %.1f / 分钟" % [region.get("rent_tolerance_level", "普通"), float(region.get("max_rent_per_minute", 0.0))])
	var max_rent := float(region.get("max_rent_per_minute", 0.0))
	var shown := 0
	var application_count := int(region.get("application_count", ConfigManager.get_economy_value("recruit_application_count", 3)))
	for tenant_data in ConfigManager.get_region_candidate_tenants(region_id):
		var tenant_id := str(tenant_data.get("id", ""))
		var tenant_state: Dictionary = GameState.tenants.get(tenant_id, {})
		if str(tenant_state.get("room_id", "")) != "":
			continue
		if shown >= application_count:
			break
		shown += 1
		var expected_rent := EconomyManager.calculate_room_rent_for_tenant(room, tenant_id)
		var affordable := expected_rent <= max_rent
		var row := add_row()
		var text := "%s  %s  倍率 %.2f  承受等级：%s\n预计租金 %.1f/分钟  区域上限 %.1f/分钟\n偏好：%s" % [
			tenant_data.get("name", ""),
			tenant_data.get("job", ""),
			float(tenant_data.get("pay_multiplier", 1.0)),
			region.get("rent_tolerance_level", "普通"),
			expected_rent,
			max_rent,
			", ".join(tenant_data.get("favorite_tags", []))
		]
		if not affordable:
			text += "\n超出该区域租金承受上限"
		row.add_child(UIPanelFactory.make_label(text))
		var button := Button.new()
		UIPanelFactory.style_button(button, Vector2(140, 52))
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.text = "入住" if affordable else "租金过高"
		button.disabled = not affordable
		button.pressed.connect(_on_candidate_pressed.bind(tenant_id))
		row.add_child(button)
	if shown == 0:
		add_text("该区域暂无可招募租客。可在福利中刷新申请。")

func _show_tenant_view() -> void:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var tenant_id := str(room.get("tenant_id", ""))
	var data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var state: Dictionary = GameState.tenants.get(tenant_id, {})
	setup_panel("租客")
	add_text("%s / %s" % [data.get("name", ""), data.get("job", "")])
	add_text("满意度：%d" % int(state.get("satisfaction", 0)))
	add_text("当前行为：%s" % state.get("current_behavior", ""))
	add_text("偏好：%s" % ", ".join(data.get("favorite_tags", [])))

func _on_candidate_pressed(tenant_id: String) -> void:
	tenant_recruit_requested.emit(tenant_id, room_id)
