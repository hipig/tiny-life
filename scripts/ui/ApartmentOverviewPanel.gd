class_name ApartmentOverviewPanel
extends "res://scripts/ui/AppPanel.gd"

var selected_tab := "overview"

func open(initial_tab := "overview") -> void:
	selected_tab = initial_tab
	_refresh()

func _refresh() -> void:
	setup_panel("公寓总览")
	var tabs := HBoxContainer.new()
	content_root.add_child(tabs)
	_add_tab_button(tabs, "概览", "overview")
	_add_tab_button(tabs, "楼层", "floors")
	_add_tab_button(tabs, "租客", "tenants")
	match selected_tab:
		"floors":
			_build_floors_tab()
		"tenants":
			_build_tenants_tab()
		_:
			_build_summary_tab()

func _add_tab_button(parent: Control, text: String, tab: String) -> void:
	var button := Button.new()
	UIPanelFactory.style_button(button)
	button.text = text
	button.disabled = selected_tab == tab
	button.pressed.connect(func():
		selected_tab = tab
		_refresh()
	)
	parent.add_child(button)

func _build_summary_tab() -> void:
	add_text("等级：Lv.%d  经验：%d" % [GameState.apartment_level, GameState.apartment_exp])
	add_text("下一级目标：%s" % _next_level_text())
	add_text("总租金：%.1f / 分钟" % GameState.total_rent_per_minute)
	add_text("房间数量：%d  入住人数：%d" % [GameState.get_unlocked_rooms().size(), _tenant_count()])
	add_text("平均满意度：%s" % _average_satisfaction_text())
	add_text("已建最高楼层：%d" % GameState.highest_built_floor)

func _build_floors_tab() -> void:
	for floor_data in ConfigManager.floors:
		var floor: Dictionary = floor_data
		var floor_index := int(floor.get("floor_index", 0))
		var stats := _floor_stats(floor_index)
		add_text("%s：%s  建造费 %d\n房间 %d 间，入住 %d 人，本层租金 %.1f / 分钟" % [
			floor.get("display_name", "%dF" % floor_index),
			_floor_state_text(floor),
			int(floor.get("build_cost", 0)),
			int(stats.get("rooms", 0)),
			int(stats.get("tenants", 0)),
			float(stats.get("rent", 0.0))
		])

func _build_tenants_tab() -> void:
	var count := 0
	for tenant_id in GameState.tenants.keys():
		var tenant_state: Dictionary = GameState.tenants[tenant_id]
		var room_id := str(tenant_state.get("room_id", ""))
		if room_id.is_empty():
			continue
		count += 1
		var tenant_data: Dictionary = ConfigManager.get_tenant_data(str(tenant_id))
		var room: Dictionary = GameState.rooms.get(room_id, {})
		add_text("%s  %s\n房间：%s  满意度：%d  租金贡献 %.1f / 分钟" % [
			tenant_data.get("name", "租客"),
			tenant_data.get("job", ""),
			room.get("room_name", room_id),
			int(tenant_state.get("satisfaction", 0)),
			float(room.get("rent_per_minute", 0.0))
		])
	if count == 0:
		add_text("当前还没有租客入住。")

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
		return "已建成"
	if floor_index == GameState.highest_built_floor + 1 and GameState.apartment_level >= required_level:
		return "可建造"
	return "Lv.%d 解锁" % required_level

func _next_level_text() -> String:
	var next_data: Dictionary = ConfigManager.get_level_data(GameState.apartment_level + 1)
	if next_data.is_empty():
		return "已达到当前最高等级"
	var required_exp: int = int(next_data.get("required_exp", 0))
	var remaining: int = maxi(0, required_exp - GameState.apartment_exp)
	return "Lv.%d 还需 %d 经验" % [GameState.apartment_level + 1, remaining]

func _average_satisfaction_text() -> String:
	var total := 0
	var count := 0
	for tenant in GameState.tenants.values():
		var tenant_state: Dictionary = tenant
		if str(tenant_state.get("room_id", "")).is_empty():
			continue
		total += int(tenant_state.get("satisfaction", 0))
		count += 1
	if count == 0:
		return "暂无租客"
	return "%.1f" % (float(total) / float(count))

func _tenant_count() -> int:
	var count := 0
	for tenant in GameState.tenants.values():
		if not str(tenant.get("room_id", "")).is_empty():
			count += 1
	return count
