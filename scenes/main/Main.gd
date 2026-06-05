extends Control

const ROOM_WIDTH := 250.0
const ROOM_HEIGHT := 130.0

var top_bar: HBoxContainer
var building_scroll: ScrollContainer
var building_root: VBoxContainer
var panel_layer: CanvasLayer
var toast_label: Label
var coin_popup_label: Label
var selected_room_id := ""
var selected_tab := "furniture"
var placing_furniture_id := ""
var moving_instance_id := ""
var placement_grid_pos: Array = [0, 0]
var tenant_ai_timer := 0.0
var coin_popup_pending := 0
var coin_popup_timer := 0.0
var zoom_scale := 1.0
var app_root: VBoxContainer
var is_dragging_view := false

func _ready() -> void:
	_build_layout()
	_connect_events()
	_refresh_all()

func _process(delta: float) -> void:
	tenant_ai_timer += delta
	if tenant_ai_timer >= 5.0:
		tenant_ai_timer = 0.0
		_tick_tenant_ai()
	coin_popup_timer += delta
	if coin_popup_timer >= float(ConfigManager.get_economy_value("coin_popup_interval", 6.0)):
		coin_popup_timer = 0.0
		if coin_popup_pending > 0:
			coin_popup_label.text = "+%d" % coin_popup_pending
			coin_popup_label.visible = true
			coin_popup_pending = 0
			await get_tree().create_timer(1.3).timeout
			coin_popup_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_change_zoom((event.factor - 1.0) * 0.8)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_zoom(0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_zoom(-0.08)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_view = event.pressed and _can_drag_building_view()
	elif event is InputEventMouseMotion and is_dragging_view and building_scroll != null:
		building_scroll.scroll_horizontal -= int(event.relative.x)
		building_scroll.scroll_vertical -= int(event.relative.y)
	elif event is InputEventPanGesture and building_scroll != null:
		building_scroll.scroll_horizontal += int(event.delta.x)
		building_scroll.scroll_vertical += int(event.delta.y)

func _build_layout() -> void:
	custom_minimum_size = Vector2.ZERO
	var background := ColorRect.new()
	background.color = Color("#f3e7c4")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	app_root = VBoxContainer.new()
	app_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	app_root.custom_minimum_size = Vector2(720, 1280)
	app_root.size = Vector2(720, 1280)
	app_root.add_theme_constant_override("separation", 8)
	add_child(app_root)

	top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 70)
	top_bar.add_theme_constant_override("separation", 8)
	app_root.add_child(top_bar)

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 8)
	app_root.add_child(main_row)

	building_scroll = ScrollContainer.new()
	building_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(building_scroll)

	building_root = VBoxContainer.new()
	building_root.name = "BuildingRoot"
	building_root.add_theme_constant_override("separation", 10)
	building_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	building_scroll.add_child(building_root)

	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(116, 0)
	menu.add_theme_constant_override("separation", 10)
	main_row.add_child(menu)
	_add_menu_button(menu, "任务", UIManager.open_task_panel)
	_add_menu_button(menu, "福利", UIManager.open_reward_panel)
	_add_menu_button(menu, "设置", UIManager.open_settings_panel)
	_add_menu_button(menu, "放大", func(): _change_zoom(0.1))
	_add_menu_button(menu, "缩小", func(): _change_zoom(-0.1))

	panel_layer = CanvasLayer.new()
	add_child(panel_layer)

	toast_label = Label.new()
	toast_label.visible = false
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 24)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	toast_label.add_theme_constant_override("shadow_offset_x", 2)
	toast_label.add_theme_constant_override("shadow_offset_y", 2)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.position.y = -160
	panel_layer.add_child(toast_label)

	coin_popup_label = Label.new()
	coin_popup_label.visible = false
	coin_popup_label.add_theme_font_size_override("font_size", 30)
	coin_popup_label.add_theme_color_override("font_color", Color("#2b9348"))
	coin_popup_label.position = Vector2(310, 70)
	panel_layer.add_child(coin_popup_label)

func _connect_events() -> void:
	GameEvents.coins_changed.connect(func(_value): _refresh_top_bar())
	GameEvents.rent_changed.connect(_on_rent_changed)
	GameEvents.apartment_level_changed.connect(_on_apartment_level_changed)
	GameEvents.room_updated.connect(_on_room_updated)
	GameEvents.furniture_placed.connect(func(_room_id, _furniture_id): _refresh_building())
	GameEvents.furniture_moved.connect(func(_room_id, _furniture_id): _refresh_building())
	GameEvents.furniture_recycled.connect(func(_room_id, _furniture_id): _refresh_building())
	GameEvents.tenant_recruited.connect(func(_tenant_id, _room_id): _refresh_building())
	GameEvents.task_updated.connect(func(_task_id): pass)
	GameEvents.task_completed.connect(func(task_id): _show_toast("任务完成：%s" % _task_title(task_id)))
	GameEvents.coin_gain_batched.connect(_on_coin_gain_batched)
	GameEvents.toast_requested.connect(_show_toast)
	GameEvents.state_loaded.connect(_refresh_all)
	GameEvents.offline_income_ready.connect(_show_offline_reward)
	UIManager.room_panel_requested.connect(_show_room_panel)
	UIManager.furniture_shop_requested.connect(_show_furniture_shop)
	UIManager.tenant_panel_requested.connect(_show_tenant_panel)
	UIManager.build_confirm_requested.connect(_show_build_confirm)
	UIManager.panel_requested.connect(_show_named_panel)
	UIManager.placement_requested.connect(_show_new_placement)
	UIManager.move_existing_requested.connect(_show_move_existing)

func _refresh_all() -> void:
	_refresh_top_bar()
	_refresh_building()

func _on_rent_changed(_value: float) -> void:
	_refresh_top_bar()
	_refresh_building()

func _on_apartment_level_changed(_level: int) -> void:
	_refresh_top_bar()
	_refresh_building()

func _on_room_updated(_room_id: String) -> void:
	_refresh_building()
	_refresh_room_panel_if_open()

func _on_coin_gain_batched(amount: int) -> void:
	coin_popup_pending += amount

func _refresh_top_bar() -> void:
	_clear_children(top_bar)
	var level_button := Button.new()
	_style_button(level_button)
	level_button.text = "公寓 Lv.%d" % GameState.apartment_level
	level_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_button.pressed.connect(UIManager.open_apartment_overview)
	top_bar.add_child(level_button)

	var coin_button := Button.new()
	_style_button(coin_button)
	coin_button.text = "金币 %d" % GameState.coins
	coin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coin_button.pressed.connect(UIManager.open_income_detail)
	top_bar.add_child(coin_button)

	var rent_button := Button.new()
	_style_button(rent_button)
	rent_button.text = "租金 %.1f/分钟" % GameState.total_rent_per_minute
	rent_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rent_button.pressed.connect(UIManager.open_rent_detail)
	top_bar.add_child(rent_button)

func _refresh_building() -> void:
	if building_root == null:
		return
	_clear_children(building_root)
	building_root.scale = Vector2.ONE * zoom_scale
	for floor_index in range(6, 0, -1):
		if floor_index <= GameState.highest_built_floor:
			_add_floor_row(floor_index)
		elif floor_index == GameState.highest_built_floor + 1:
			_add_build_slot(floor_index)

func _add_floor_row(floor_index: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	building_root.add_child(row)
	var label := Label.new()
	label.text = "%dF" % floor_index
	label.custom_minimum_size = Vector2(44, ROOM_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	for room in ConfigManager.rooms:
		if int(room.get("floor_index", 0)) == floor_index:
			_add_room_card(row, str(room.get("id", "")))

func _add_room_card(parent: Control, room_id: String) -> void:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var button := Button.new()
	_style_button(button)
	button.custom_minimum_size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
	button.text = _room_card_text(room)
	button.clip_text = true
	button.pressed.connect(func(): UIManager.open_room_panel(room_id))
	parent.add_child(button)

func _room_card_text(room: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(str(room.get("room_name", "")))
	lines.append("评分 %d  租金 %.1f" % [int(room.get("score", 0)), float(room.get("rent_per_minute", 0.0))])
	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		lines.append("空房")
	else:
		var tenant_data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
		var tenant_state: Dictionary = GameState.tenants.get(tenant_id, {})
		lines.append("%s：%s" % [tenant_data.get("name", "租客"), tenant_state.get("current_behavior", "闲逛")])
	var furniture_names: Array[String] = []
	for instance in room.get("furniture_instances", []):
		furniture_names.append(str(ConfigManager.get_furniture_data(str(instance.get("furniture_id", ""))).get("name", "家具")))
	lines.append("家具：" + (", ".join(furniture_names) if furniture_names.size() > 0 else "无"))
	return "\n".join(lines)

func _add_build_slot(floor_index: int) -> void:
	var floor: Dictionary = ConfigManager.get_floor_data(floor_index)
	if floor.is_empty():
		return
	if GameState.apartment_level < int(floor.get("required_apartment_level", 1)):
		var locked := Label.new()
		locked.text = "第 %d 层 Lv.%d 解锁" % [floor_index, int(floor.get("required_apartment_level", 1))]
		locked.custom_minimum_size = Vector2(560, 80)
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		building_root.add_child(locked)
		return
	var button := Button.new()
	_style_button(button)
	button.text = "可建造第 %d 层  需要金币 %d" % [floor_index, int(floor.get("build_cost", 0))]
	button.custom_minimum_size = Vector2(560, 90)
	button.pressed.connect(func(): UIManager.open_build_confirm(floor_index))
	building_root.add_child(button)

func _show_room_panel(room_id: String) -> void:
	selected_room_id = room_id
	selected_tab = "furniture"
	_rebuild_room_panel()

func _rebuild_room_panel() -> void:
	_clear_panel_layer_panels()
	var room: Dictionary = GameState.rooms.get(selected_room_id, {})
	var panel := _make_panel("房间：%s" % room.get("room_name", ""))
	var tabs := HBoxContainer.new()
	panel.add_child(tabs)
	_add_tab_button(tabs, "家具", "furniture")
	_add_tab_button(tabs, "租客", "tenant")
	_add_tab_button(tabs, "概览", "overview")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	match selected_tab:
		"furniture":
			_build_room_furniture_tab(content, room)
		"tenant":
			_build_room_tenant_tab(content, room)
		_:
			_build_room_overview_tab(content, room)

func _add_tab_button(parent: Control, text: String, tab: String) -> void:
	var button := Button.new()
	_style_button(button)
	button.text = text
	button.disabled = selected_tab == tab
	button.pressed.connect(func():
		selected_tab = tab
		_rebuild_room_panel()
	)
	parent.add_child(button)

func _build_room_overview_tab(parent: Control, room: Dictionary) -> void:
	parent.add_child(_label("评分：%d" % int(room.get("score", 0))))
	parent.add_child(_label("租金：%.1f / 分钟" % float(room.get("rent_per_minute", 0.0))))
	parent.add_child(_label("舒适 %d  娱乐 %d  卫生 %d  食物 %d" % [int(room.get("comfort", 0)), int(room.get("entertainment", 0)), int(room.get("hygiene", 0)), int(room.get("food", 0))]))

func _build_room_furniture_tab(parent: Control, room: Dictionary) -> void:
	var add_button := Button.new()
	_style_button(add_button)
	add_button.text = "添加家具"
	add_button.pressed.connect(func(): UIManager.open_furniture_shop(selected_room_id))
	parent.add_child(add_button)
	var list: Array = room.get("furniture_instances", [])
	if list.is_empty():
		parent.add_child(_label("当前没有家具。"))
	for instance in list:
		var instance_data: Dictionary = instance
		var data: Dictionary = ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		var row := HBoxContainer.new()
		parent.add_child(row)
		row.add_child(_label("%s  位置 %s" % [data.get("name", "家具"), str(instance_data.get("grid_pos", []))]))
		var move := Button.new()
		_style_button(move)
		move.text = "移动"
		move.pressed.connect(_on_move_furniture_pressed.bind(str(instance_data.get("instance_id", ""))))
		row.add_child(move)
		var recycle := Button.new()
		_style_button(recycle)
		recycle.text = "回收"
		recycle.pressed.connect(_on_recycle_furniture_pressed.bind(str(instance_data.get("instance_id", ""))))
		row.add_child(recycle)

func _build_room_tenant_tab(parent: Control, room: Dictionary) -> void:
	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		parent.add_child(_label("当前无租客"))
		var recruit := Button.new()
		_style_button(recruit)
		recruit.text = "招募租客"
		recruit.pressed.connect(func(): UIManager.open_tenant_panel_for_recruit(selected_room_id))
		parent.add_child(recruit)
		return
	var data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var state: Dictionary = GameState.tenants.get(tenant_id, {})
	parent.add_child(_label("租客：%s" % data.get("name", "")))
	parent.add_child(_label("职业：%s  性格：%s" % [data.get("job", ""), data.get("personality", "")]))
	parent.add_child(_label("满意度：%d  当前行为：%s" % [int(state.get("satisfaction", 0)), state.get("current_behavior", "")]))
	var view := Button.new()
	_style_button(view)
	view.text = "查看租客"
	view.pressed.connect(func(): UIManager.open_tenant_panel(selected_room_id))
	parent.add_child(view)

func _show_furniture_shop(room_id: String) -> void:
	selected_room_id = room_id
	_clear_panel_layer_panels()
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var panel := _make_panel("为 %s 添加家具" % room.get("room_name", "房间"))
	var categories := {}
	for item in ConfigManager.furniture:
		categories[item.get("category", "其他")] = true
	for item in ConfigManager.furniture:
		var row := HBoxContainer.new()
		panel.add_child(row)
		row.add_child(_label("%s  %d 金币  评分 +%d" % [item.get("name", ""), int(item.get("price", 0)), _furniture_score(item)]))
		var place := Button.new()
		_style_button(place)
		place.text = "摆放" if GameState.coins >= int(item.get("price", 0)) else "金币不足"
		place.disabled = GameState.coins < int(item.get("price", 0))
		place.pressed.connect(_on_shop_place_pressed.bind(str(item.get("id", "")), room_id))
		row.add_child(place)

func _show_new_placement(furniture_id: String, room_id: String) -> void:
	placing_furniture_id = furniture_id
	selected_room_id = room_id
	moving_instance_id = ""
	placement_grid_pos = [0, 0]
	_show_placement_panel(false)

func _show_move_existing(room_id: String, instance_id: String) -> void:
	selected_room_id = room_id
	moving_instance_id = instance_id
	var room: Dictionary = GameState.rooms.get(room_id, {})
	for instance in room.get("furniture_instances", []):
		if str(instance.get("instance_id", "")) == instance_id:
			placing_furniture_id = str(instance.get("furniture_id", ""))
			placement_grid_pos = instance.get("grid_pos", [0, 0])
			break
	_show_placement_panel(true)

func _show_placement_panel(is_move: bool) -> void:
	_clear_panel_layer_panels()
	var data: Dictionary = ConfigManager.get_furniture_data(placing_furniture_id)
	var room: Dictionary = GameState.rooms.get(selected_room_id, {})
	var grid_size: Array = room.get("grid_size", [8, 5])
	var panel := _make_panel(("移动 " if is_move else "摆放 ") + str(data.get("name", "家具")))
	panel.add_child(_label("选择网格位置。绿色为合法，红色为不可摆放。"))
	var grid := GridContainer.new()
	grid.columns = int(grid_size[0])
	panel.add_child(grid)
	for y in range(int(grid_size[1])):
		for x in range(int(grid_size[0])):
			var cell := Button.new()
			_style_button(cell, Vector2(48, 42))
			cell.text = "%d,%d" % [x, y]
			var valid := _can_place_furniture(selected_room_id, placing_furniture_id, [x, y], moving_instance_id)
			cell.modulate = Color("#9be7a1") if valid else Color("#f4a3a3")
			cell.disabled = not valid
			cell.pressed.connect(_on_placement_cell_pressed.bind(x, y, is_move))
			if placement_grid_pos == [x, y]:
				cell.text = "✓"
			grid.add_child(cell)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var confirm := Button.new()
	_style_button(confirm, Vector2(260, 56))
	confirm.text = "确认移动" if is_move else "确认摆放并扣金币"
	confirm.disabled = not _can_place_furniture(selected_room_id, placing_furniture_id, placement_grid_pos, moving_instance_id)
	confirm.pressed.connect(func():
		if is_move:
			_confirm_move()
		else:
			_confirm_new_placement()
	)
	row.add_child(confirm)
	var cancel := Button.new()
	_style_button(cancel, Vector2(140, 56))
	cancel.text = "取消"
	cancel.pressed.connect(func():
		UIManager.open_room_panel(selected_room_id)
	)
	row.add_child(cancel)

func _confirm_new_placement() -> void:
	var data: Dictionary = ConfigManager.get_furniture_data(placing_furniture_id)
	var price := int(data.get("price", 0))
	if not GameState.spend_coins(price):
		_show_toast("金币不足")
		return
	GameState.add_furniture_instance(selected_room_id, placing_furniture_id, placement_grid_pos)
	SaveManager.save_game()
	_show_toast("已摆放 %s" % data.get("name", "家具"))
	UIManager.open_room_panel(selected_room_id)

func _on_move_furniture_pressed(instance_id: String) -> void:
	UIManager.start_move_existing(selected_room_id, instance_id)

func _on_recycle_furniture_pressed(instance_id: String) -> void:
	_confirm_recycle(selected_room_id, instance_id)

func _on_shop_place_pressed(furniture_id: String, room_id: String) -> void:
	UIManager.start_new_furniture_placement(furniture_id, room_id)

func _on_placement_cell_pressed(x: int, y: int, is_move: bool) -> void:
	placement_grid_pos = [x, y]
	_show_placement_panel(is_move)

func _confirm_move() -> void:
	if GameState.move_furniture_instance(selected_room_id, moving_instance_id, placement_grid_pos):
		SaveManager.save_game()
		_show_toast("家具已移动")
	UIManager.open_room_panel(selected_room_id)

func _confirm_recycle(room_id: String, instance_id: String) -> void:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var furniture_id := ""
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		if str(instance_data.get("instance_id", "")) == instance_id:
			furniture_id = str(instance_data.get("furniture_id", ""))
			break
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var refund: int = int(float(data.get("price", 0)) * float(data.get("refund_rate", 0.5)))
	_clear_panel_layer_panels()
	var panel := _make_panel("确认回收")
	panel.add_child(_label("确认回收 %s？" % data.get("name", "家具")))
	panel.add_child(_label("将返还 %d 金币。" % refund))
	var row := HBoxContainer.new()
	panel.add_child(row)
	var confirm := Button.new()
	_style_button(confirm, Vector2(220, 56))
	confirm.text = "确认回收"
	confirm.pressed.connect(_do_recycle.bind(room_id, instance_id))
	row.add_child(confirm)
	var cancel := Button.new()
	_style_button(cancel, Vector2(160, 56))
	cancel.text = "取消"
	cancel.pressed.connect(func(): UIManager.open_room_panel(room_id))
	row.add_child(cancel)

func _do_recycle(room_id: String, instance_id: String) -> void:
	var refund: int = GameState.recycle_furniture_instance(room_id, instance_id)
	if refund > 0:
		SaveManager.save_game()
		_show_toast("回收成功，返还 %d 金币" % refund)
	UIManager.open_room_panel(room_id)

func _can_place_furniture(room_id: String, furniture_id: String, grid_pos: Array, ignored_instance_id := "") -> bool:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var grid_size: Array = room.get("grid_size", [8, 5])
	var size: Array = data.get("size", [1, 1])
	var gx := int(grid_pos[0])
	var gy := int(grid_pos[1])
	var w := int(size[0])
	var h := int(size[1])
	if gx < 0 or gy < 0 or gx + w > int(grid_size[0]) or gy + h > int(grid_size[1]):
		return false
	if bool(data.get("requires_wall", false)) and gy != 0:
		return false
	var door_cells := [[int(grid_size[0]) - 1, int(grid_size[1]) - 1]]
	for yy in range(gy, gy + h):
		for xx in range(gx, gx + w):
			if [xx, yy] in door_cells:
				return false
	for instance in room.get("furniture_instances", []):
		if str(instance.get("instance_id", "")) == ignored_instance_id:
			continue
		var instance_data: Dictionary = instance
		var other_data: Dictionary = ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		var other_pos: Array = instance_data.get("grid_pos", [0, 0])
		var other_size: Array = other_data.get("size", [1, 1])
		if _rects_overlap(gx, gy, w, h, int(other_pos[0]), int(other_pos[1]), int(other_size[0]), int(other_size[1])):
			return false
	return true

func _rects_overlap(ax: int, ay: int, aw: int, ah: int, bx: int, by: int, bw: int, bh: int) -> bool:
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by

func _show_tenant_panel(room_id: String, mode: String) -> void:
	selected_room_id = room_id
	_clear_panel_layer_panels()
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var panel := _make_panel("租客")
	if mode == "recruit":
		panel.add_child(_label("选择申请入住的租客"))
		var count := 0
		for tenant_data in ConfigManager.tenants:
			var tenant_id := str(tenant_data.get("id", ""))
			var tenant_state: Dictionary = GameState.tenants.get(tenant_id, {})
			if str(tenant_state.get("room_id", "")) != "":
				continue
			count += 1
			if count > int(ConfigManager.get_economy_value("recruit_application_count", 3)):
				break
			var row := HBoxContainer.new()
			panel.add_child(row)
			row.add_child(_label("%s  %s  倍率 %.2f  喜欢：%s" % [tenant_data.get("name", ""), tenant_data.get("job", ""), float(tenant_data.get("pay_multiplier", 1.0)), ", ".join(tenant_data.get("favorite_tags", []))]))
			var button := Button.new()
			_style_button(button)
			button.text = "入住"
			button.pressed.connect(_on_recruit_tenant_pressed.bind(tenant_id, room_id))
			row.add_child(button)
		if count == 0:
			panel.add_child(_label("暂无可招募租客。可在福利中刷新申请。"))
	else:
		var tenant_id := str(room.get("tenant_id", ""))
		var data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
		var state: Dictionary = GameState.tenants.get(tenant_id, {})
		panel.add_child(_label("%s / %s" % [data.get("name", ""), data.get("job", "")]))
		panel.add_child(_label("满意度：%d" % int(state.get("satisfaction", 0))))
		panel.add_child(_label("当前行为：%s" % state.get("current_behavior", "")))
		panel.add_child(_label("偏好：%s" % ", ".join(data.get("favorite_tags", []))))

func _on_recruit_tenant_pressed(tenant_id: String, room_id: String) -> void:
	if GameState.recruit_tenant(room_id, tenant_id):
		SaveManager.save_game()
		_show_toast("租客已入住")
	UIManager.open_room_panel(room_id)

func _show_build_confirm(floor_index: int) -> void:
	_clear_panel_layer_panels()
	var floor: Dictionary = ConfigManager.get_floor_data(floor_index)
	var cost := int(floor.get("build_cost", 0))
	var panel := _make_panel("建造第 %d 层" % floor_index)
	panel.add_child(_label("需要金币：%d" % cost))
	panel.add_child(_label("当前金币：%d" % GameState.coins))
	if GameState.coins < cost:
		panel.add_child(_label("还差：%d" % (cost - GameState.coins)))
	var confirm := Button.new()
	_style_button(confirm)
	confirm.text = "确认建造"
	confirm.disabled = GameState.coins < cost
	confirm.pressed.connect(func():
		if GameState.build_floor(floor_index):
			SaveManager.save_game()
			_show_toast("第 %d 层已建成" % floor_index)
			UIManager.return_to_normal()
			_clear_panel_layer_panels()
			_refresh_building()
	)
	panel.add_child(confirm)

func _show_named_panel(panel_name: String) -> void:
	_clear_panel_layer_panels()
	match panel_name:
		"apartment_overview":
			var panel := _make_panel("公寓总览")
			panel.add_child(_label("等级：Lv.%d  经验：%d" % [GameState.apartment_level, GameState.apartment_exp]))
			panel.add_child(_label("总租金：%.1f / 分钟" % GameState.total_rent_per_minute))
			panel.add_child(_label("房间数量：%d  入住人数：%d" % [GameState.get_unlocked_rooms().size(), _tenant_count()]))
			panel.add_child(_label("已建最高楼层：%d" % GameState.highest_built_floor))
		"income_detail":
			var panel := _make_panel("收益详情")
			panel.add_child(_label("当前金币：%d" % GameState.coins))
			panel.add_child(_label("每分钟收益：%.1f" % GameState.total_rent_per_minute))
			panel.add_child(_label("离线收益上限：4 小时"))
		"rent_detail":
			var panel := _make_panel("租金构成")
			for room in GameState.get_unlocked_rooms():
				panel.add_child(_label("%s：%.1f / 分钟" % [room.get("room_name", ""), float(room.get("rent_per_minute", 0.0))]))
		"task":
			_show_task_panel()
		"reward":
			_show_reward_panel()
		"settings":
			_show_settings_panel()

func _show_task_panel() -> void:
	var panel := _make_panel("任务")
	for task in TaskManager.get_active_tasks():
		var target := int(task.get("target_value", 1))
		var progress: int = min(int(task.get("progress", 0)), target)
		var status := "完成" if bool(task.get("completed", false)) else "%d/%d" % [progress, target]
		panel.add_child(_label("%s  [%s]\n%s" % [task.get("title", ""), status, task.get("description", "")]))

func _show_reward_panel() -> void:
	var panel := _make_panel("福利")
	var offline: Dictionary = EconomyManager.calculate_offline_income()
	panel.add_child(_label("当前可领取离线收益：%d" % int(offline.get("amount", 0))))
	var claim := Button.new()
	_style_button(claim, Vector2(260, 56))
	claim.text = "领取离线收益"
	claim.pressed.connect(func():
		var amount: int = EconomyManager.claim_offline_income(false)
		_show_toast("领取 %d 金币" % amount)
		_show_reward_panel()
	)
	panel.add_child(claim)
	var double := Button.new()
	_style_button(double, Vector2(260, 56))
	double.text = "看广告双倍领取"
	double.pressed.connect(func():
		AdManager.show_rewarded_ad("offline_double", func(success):
			if success:
				var amount: int = EconomyManager.claim_offline_income(true)
				_show_toast("双倍领取 %d 金币" % amount)
				_show_reward_panel()
		)
	)
	panel.add_child(double)
	var refresh := Button.new()
	_style_button(refresh, Vector2(260, 56))
	refresh.text = "看广告刷新租客申请"
	refresh.pressed.connect(func():
		AdManager.show_rewarded_ad("refresh_tenants", func(success):
			if success:
				ConfigManager.tenants.shuffle()
				_show_toast("租客申请已刷新")
		)
	)
	panel.add_child(refresh)

func _show_settings_panel() -> void:
	var panel := _make_panel("设置")
	panel.add_child(_label("音效：开"))
	panel.add_child(_label("音乐：开"))
	panel.add_child(_label("语言：中文"))
	panel.add_child(_label("画质：移动端"))
	panel.add_child(_label("隐私 / 用户协议：占位入口"))
	var save := Button.new()
	_style_button(save)
	save.text = "立即存档"
	save.pressed.connect(_on_save_pressed)
	panel.add_child(save)
	var reset := Button.new()
	_style_button(reset)
	reset.text = "重置数据"
	reset.pressed.connect(_on_reset_pressed)
	panel.add_child(reset)

func _on_save_pressed() -> void:
	SaveManager.save_game()
	_show_toast("已存档")

func _on_reset_pressed() -> void:
	SaveManager.delete_save_and_restart()
	_clear_panel_layer_panels()
	_refresh_all()
	_show_toast("已重置")

func _show_offline_reward(amount: int, seconds: int) -> void:
	_clear_panel_layer_panels()
	var panel := _make_panel("离线收益")
	panel.add_child(_label("你离线了 %s" % TimeManager.format_duration(seconds)))
	panel.add_child(_label("获得金币：%d" % amount))
	var claim := Button.new()
	_style_button(claim, Vector2(260, 56))
	claim.text = "领取"
	claim.pressed.connect(func():
		var got: int = EconomyManager.claim_offline_income(false)
		_show_toast("领取 %d 金币" % got)
		_clear_panel_layer_panels()
	)
	panel.add_child(claim)
	var double := Button.new()
	_style_button(double, Vector2(260, 56))
	double.text = "看广告双倍领取"
	double.pressed.connect(func():
		AdManager.show_rewarded_ad("offline_double", func(success):
			if success:
				var got: int = EconomyManager.claim_offline_income(true)
				_show_toast("双倍领取 %d 金币" % got)
				_clear_panel_layer_panels()
		)
	)
	panel.add_child(double)

func _tick_tenant_ai() -> void:
	for tenant_id in GameState.tenants.keys():
		var tenant: Dictionary = GameState.tenants[tenant_id]
		var room_id := str(tenant.get("room_id", ""))
		if room_id.is_empty():
			continue
		var room: Dictionary = GameState.rooms.get(room_id, {})
		var needs: Array[String] = []
		for instance in room.get("furniture_instances", []):
			var instance_data: Dictionary = instance
			var data: Dictionary = ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
			var interaction: Dictionary = data.get("interaction", {})
			var need := str(interaction.get("need", ""))
			if not need.is_empty():
				needs.append(need)
		if needs.is_empty():
			tenant["current_behavior"] = "发呆"
			GameState.tenants[tenant_id] = tenant
		else:
			GameState.observe_tenant_behavior(str(tenant_id), needs.pick_random())
	_refresh_building()

func _make_panel(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "ActivePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 92
	panel.offset_right = -24
	panel.offset_bottom = -40
	panel_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close := Button.new()
	_style_button(close, Vector2(76, 44))
	close.text = "关闭"
	close.pressed.connect(func():
		_clear_panel_layer_panels()
		UIManager.return_to_normal()
	)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.custom_minimum_size = Vector2(620, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content

func _add_menu_button(parent: Control, text: String, callable: Callable) -> void:
	var button := Button.new()
	_style_button(button, Vector2(104, 62))
	button.text = text
	button.custom_minimum_size = Vector2(104, 62)
	button.pressed.connect(callable)
	parent.add_child(button)

func _style_button(button: Button, min_size := Vector2(120, 48)) -> void:
	button.custom_minimum_size = min_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	return label

func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	await get_tree().create_timer(1.6).timeout
	toast_label.visible = false

func _change_zoom(delta: float) -> void:
	zoom_scale = clampf(zoom_scale + delta, 0.7, 1.4)
	_refresh_building()

func _can_drag_building_view() -> bool:
	if panel_layer == null:
		return false
	for child in panel_layer.get_children():
		if child is PanelContainer:
			return false
	return true

func _furniture_score(data: Dictionary) -> int:
	return int(data.get("comfort", 0)) + int(data.get("entertainment", 0)) + int(data.get("hygiene", 0)) + int(data.get("food", 0))

func _tenant_count() -> int:
	var count := 0
	for tenant in GameState.tenants.values():
		if not str(tenant.get("room_id", "")).is_empty():
			count += 1
	return count

func _task_title(task_id: String) -> String:
	for task in ConfigManager.tasks:
		if str(task.get("id", "")) == task_id:
			return str(task.get("title", task_id))
	return task_id

func _refresh_room_panel_if_open() -> void:
	if UIManager.current_state == UIManager.UIState.ROOM_PANEL and not selected_room_id.is_empty():
		_rebuild_room_panel()

func _clear_panel_layer_panels() -> void:
	for child in panel_layer.get_children():
		if child is PanelContainer:
			panel_layer.remove_child(child)
			child.queue_free()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
