class_name RoomPanel
extends "res://scripts/ui/AppPanel.gd"

const ROOM_FURNITURE_ITEM_ROW_SCENE := preload("res://scenes/ui/RoomFurnitureItemRow.tscn")
const PANEL_ACTION_BUTTON_SCENE := preload("res://scenes/ui/PanelActionButton.tscn")

signal furniture_shop_requested(room_id: String)
signal tenant_recruit_requested(room_id: String)
signal tenant_view_requested(room_id: String)
signal move_furniture_requested(instance_id: String)
signal recycle_furniture_requested(instance_id: String)

var room_id := ""
var selected_tab := "furniture"
var tab_row: HBoxContainer
var overview_content: VBoxContainer
var furniture_content: VBoxContainer
var tenant_content: VBoxContainer
var score_card: StatCard
var rent_card: StatCard
var attribute_row: IconInfoRow
var add_furniture_button: PanelActionButton
var furniture_empty_row: IconInfoRow
var furniture_list_root: VBoxContainer
var tenant_empty_root: VBoxContainer
var tenant_occupied_root: VBoxContainer
var tenant_empty_row: IconInfoRow
var recruit_tenant_button: PanelActionButton
var tenant_stat_card: StatCard
var tenant_info_row: IconInfoRow
var view_tenant_button: PanelActionButton

var title_template := ""
var room_fallback_name := ""
var attribute_detail_template := ""
var tenant_stat_title_template := ""
var tenant_satisfaction_title_template := ""
var tenant_detail_template := ""
var rent_value_template := ""
var behavior_label_by_key := {}
var fallback_behavior_label := ""

func open(target_room_id: String, initial_tab := "furniture") -> void:
	room_id = target_room_id
	selected_tab = initial_tab
	_refresh()

func refresh() -> void:
	if not room_id.is_empty():
		_refresh()

func _refresh() -> void:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	_bind_scene_text()
	setup_panel(title_template % room.get("room_name", room_fallback_name), false)
	_bind_scene_nodes()
	_configure_tabs()
	_show_selected_content()
	match selected_tab:
		"furniture":
			_render_furniture_tab(room)
		"tenant":
			_render_tenant_tab(room)
		_:
			_render_overview_tab(room)

func _bind_scene_nodes() -> void:
	tab_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabRow") as HBoxContainer
	overview_content = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/OverviewContent") as VBoxContainer
	furniture_content = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/FurnitureContent") as VBoxContainer
	tenant_content = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/TenantContent") as VBoxContainer
	score_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/OverviewContent/OverviewStatsGrid/ScoreCard") as StatCard
	rent_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/OverviewContent/OverviewStatsGrid/RentCard") as StatCard
	attribute_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/OverviewContent/AttributeRow") as IconInfoRow
	add_furniture_button = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/FurnitureContent/AddFurnitureButton") as PanelActionButton
	furniture_empty_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/FurnitureContent/FurnitureEmptyRow") as IconInfoRow
	furniture_list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/FurnitureContent/FurnitureListRoot") as VBoxContainer
	tenant_empty_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/TenantContent/TenantEmptyRoot") as VBoxContainer
	tenant_occupied_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/TenantContent/TenantOccupiedRoot") as VBoxContainer
	tenant_empty_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/TenantContent/TenantEmptyRoot/TenantEmptyRow") as IconInfoRow
	recruit_tenant_button = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/TenantContent/TenantEmptyRoot/RecruitTenantButton") as PanelActionButton
	tenant_stat_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/TenantContent/TenantOccupiedRoot/TenantStatCard") as StatCard
	tenant_info_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/TenantContent/TenantOccupiedRoot/TenantInfoRow") as IconInfoRow
	view_tenant_button = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabContent/TenantContent/TenantOccupiedRoot/ViewTenantButton") as PanelActionButton
	if overview_content == null or furniture_content == null or tenant_content == null:
		push_error("RoomPanel.tscn must expose OverviewContent, FurnitureContent, and TenantContent.")
	if add_furniture_button != null and not add_furniture_button.action_requested.is_connected(_on_add_furniture_pressed):
		add_furniture_button.action_requested.connect(_on_add_furniture_pressed)
	if recruit_tenant_button != null and not recruit_tenant_button.action_requested.is_connected(_on_recruit_tenant_pressed):
		recruit_tenant_button.action_requested.connect(_on_recruit_tenant_pressed)
	if view_tenant_button != null and not view_tenant_button.action_requested.is_connected(_on_view_tenant_pressed):
		view_tenant_button.action_requested.connect(_on_view_tenant_pressed)

func _bind_scene_text() -> void:
	title_template = _template_text("TitleTemplate")
	room_fallback_name = _template_text("RoomFallbackName")
	attribute_detail_template = _template_text("AttributeDetailTemplate")
	tenant_stat_title_template = _template_text("TenantStatTitleTemplate")
	tenant_satisfaction_title_template = _template_text("TenantSatisfactionTitleTemplate")
	tenant_detail_template = _template_text("TenantDetailTemplate")
	rent_value_template = _template_text("RentValueTemplate")
	fallback_behavior_label = _template_text("FallbackBehaviorLabel")
	behavior_label_by_key = _behavior_labels_from_scene()

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("RoomPanel scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _behavior_labels_from_scene() -> Dictionary:
	var labels := {}
	var behavior_root := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/BehaviorLabels")
	if behavior_root == null:
		push_error("RoomPanel scene is missing TemplateText/BehaviorLabels.")
		return labels
	for child in behavior_root.get_children():
		if child is Label:
			var key := _behavior_label_key(child)
			if not key.is_empty():
				labels[key] = (child as Label).text
	return labels

func _behavior_label_key(node: Node) -> String:
	if not node.has_meta("behavior_key"):
		return ""
	return str(node.get_meta("behavior_key")).strip_edges()

func _configure_tabs() -> void:
	for node_name in ["FurnitureTab", "TenantTab", "OverviewTab"]:
		var tab_button := tab_row.get_node_or_null(node_name) as PanelTabButton
		if tab_button == null:
			continue
		if not tab_button.tab_selected.is_connected(_on_tab_pressed):
			tab_button.tab_selected.connect(_on_tab_pressed)
		tab_button.setup("", selected_tab == tab_button.tab_id)

func _show_selected_content() -> void:
	if overview_content != null:
		overview_content.visible = selected_tab == "overview"
	if furniture_content != null:
		furniture_content.visible = selected_tab == "furniture"
	if tenant_content != null:
		tenant_content.visible = selected_tab == "tenant"

func _render_overview_tab(room: Dictionary) -> void:
	score_card.set_value("%d" % int(room.get("score", 0)))
	rent_card.set_value(rent_value_template % float(room.get("rent_per_minute", 0.0)))
	attribute_row.set_detail(attribute_detail_template % [
		int(room.get("comfort", 0)),
		int(room.get("entertainment", 0)),
		int(room.get("hygiene", 0)),
		int(room.get("food", 0))
	])

func _render_furniture_tab(room: Dictionary) -> void:
	UIPanelFactory.clear_children(furniture_list_root)
	var list: Array = room.get("furniture_instances", [])
	furniture_empty_row.visible = list.is_empty()
	for instance in list:
		var instance_data: Dictionary = instance
		var data: Dictionary = ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		var row := ROOM_FURNITURE_ITEM_ROW_SCENE.instantiate() as RoomFurnitureItemRow
		furniture_list_root.add_child(row)
		row.setup(instance_data, data)
		row.move_requested.connect(_on_move_pressed)
		row.recycle_requested.connect(_on_recycle_pressed)

func _render_tenant_tab(room: Dictionary) -> void:
	var tenant_id := str(room.get("tenant_id", ""))
	tenant_empty_root.visible = tenant_id.is_empty()
	tenant_occupied_root.visible = not tenant_id.is_empty()
	if tenant_id.is_empty():
		return
	var data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var state: Dictionary = GameState.tenants.get(tenant_id, {})
	tenant_stat_card.set_title(tenant_stat_title_template % data.get("name", ""))
	tenant_stat_card.set_value(str(data.get("job", "")))
	tenant_info_row.set_title(tenant_satisfaction_title_template % int(state.get("satisfaction", 0)))
	tenant_info_row.set_detail(tenant_detail_template % [
		_behavior_label(str(state.get("current_behavior", ""))),
		float(room.get("rent_per_minute", 0.0))
	])

func _behavior_label(value: String) -> String:
	var key := ConfigManager.normalize_behavior_key(value, "")
	if behavior_label_by_key.has(key):
		return str(behavior_label_by_key.get(key))
	if not fallback_behavior_label.is_empty():
		return fallback_behavior_label
	return key

func _on_tab_pressed(tab: String) -> void:
	selected_tab = tab
	_refresh()

func _on_add_furniture_pressed() -> void:
	furniture_shop_requested.emit(room_id)

func _on_recruit_tenant_pressed() -> void:
	tenant_recruit_requested.emit(room_id)

func _on_view_tenant_pressed() -> void:
	tenant_view_requested.emit(room_id)

func _on_move_pressed(instance_id: String) -> void:
	move_furniture_requested.emit(instance_id)

func _on_recycle_pressed(instance_id: String) -> void:
	recycle_furniture_requested.emit(instance_id)
