class_name RoomPanel
extends "res://scripts/ui/AppPanel.gd"

signal furniture_shop_requested(room_id: String)
signal tenant_recruit_requested(room_id: String)
signal tenant_view_requested(room_id: String)
signal move_furniture_requested(instance_id: String)
signal recycle_furniture_requested(instance_id: String)

var room_id := ""
var selected_tab := "furniture"

func open(target_room_id: String, initial_tab := "furniture") -> void:
	room_id = target_room_id
	selected_tab = initial_tab
	_refresh()

func refresh() -> void:
	if not room_id.is_empty():
		_refresh()

func _refresh() -> void:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	setup_panel("房间：%s" % room.get("room_name", ""))
	var tabs := HBoxContainer.new()
	content_root.add_child(tabs)
	_add_tab_button(tabs, "家具", "furniture")
	_add_tab_button(tabs, "租客", "tenant")
	_add_tab_button(tabs, "概览", "overview")

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content_root.add_child(content)
	match selected_tab:
		"furniture":
			_build_furniture_tab(content, room)
		"tenant":
			_build_tenant_tab(content, room)
		_:
			_build_overview_tab(content, room)

func _add_tab_button(parent: Control, text: String, tab: String) -> void:
	var button := Button.new()
	UIPanelFactory.style_button(button)
	button.text = text
	button.disabled = selected_tab == tab
	button.pressed.connect(_on_tab_pressed.bind(tab))
	parent.add_child(button)

func _build_overview_tab(parent: Control, room: Dictionary) -> void:
	parent.add_child(UIPanelFactory.make_label("评分：%d" % int(room.get("score", 0))))
	parent.add_child(UIPanelFactory.make_label("租金：%.1f / 分钟" % float(room.get("rent_per_minute", 0.0))))
	parent.add_child(UIPanelFactory.make_label("舒适 %d  娱乐 %d  卫生 %d  食物 %d" % [int(room.get("comfort", 0)), int(room.get("entertainment", 0)), int(room.get("hygiene", 0)), int(room.get("food", 0))]))

func _build_furniture_tab(parent: Control, room: Dictionary) -> void:
	var add_button := Button.new()
	UIPanelFactory.style_button(add_button)
	add_button.text = "添加家具"
	add_button.pressed.connect(func(): furniture_shop_requested.emit(room_id))
	parent.add_child(add_button)

	var list: Array = room.get("furniture_instances", [])
	if list.is_empty():
		parent.add_child(UIPanelFactory.make_label("当前没有家具。"))
	for instance in list:
		var instance_data: Dictionary = instance
		var data: Dictionary = ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)
		row.add_child(UIPanelFactory.make_label("%s  位置 %s" % [data.get("name", "家具"), str(instance_data.get("grid_pos", []))]))
		var instance_id := str(instance_data.get("instance_id", ""))
		var move := Button.new()
		UIPanelFactory.style_button(move)
		move.text = "移动"
		move.pressed.connect(_on_move_pressed.bind(instance_id))
		row.add_child(move)
		var recycle := Button.new()
		UIPanelFactory.style_button(recycle)
		recycle.text = "回收"
		recycle.pressed.connect(_on_recycle_pressed.bind(instance_id))
		row.add_child(recycle)

func _build_tenant_tab(parent: Control, room: Dictionary) -> void:
	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		parent.add_child(UIPanelFactory.make_label("当前无租客"))
		var recruit := Button.new()
		UIPanelFactory.style_button(recruit)
		recruit.text = "招募租客"
		recruit.pressed.connect(func(): tenant_recruit_requested.emit(room_id))
		parent.add_child(recruit)
		return
	var data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var state: Dictionary = GameState.tenants.get(tenant_id, {})
	parent.add_child(UIPanelFactory.make_label("租客：%s" % data.get("name", "")))
	parent.add_child(UIPanelFactory.make_label("职业：%s  性格：%s" % [data.get("job", ""), data.get("personality", "")]))
	parent.add_child(UIPanelFactory.make_label("满意度：%d  当前行为：%s" % [int(state.get("satisfaction", 0)), state.get("current_behavior", "")]))
	parent.add_child(UIPanelFactory.make_label("租金贡献：%.1f / 分钟" % float(room.get("rent_per_minute", 0.0))))
	var view := Button.new()
	UIPanelFactory.style_button(view)
	view.text = "查看租客"
	view.pressed.connect(func(): tenant_view_requested.emit(room_id))
	parent.add_child(view)

func _on_tab_pressed(tab: String) -> void:
	selected_tab = tab
	_refresh()

func _on_move_pressed(instance_id: String) -> void:
	move_furniture_requested.emit(instance_id)

func _on_recycle_pressed(instance_id: String) -> void:
	recycle_furniture_requested.emit(instance_id)
