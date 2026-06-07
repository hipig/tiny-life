class_name ApartmentOverviewPanel
extends "res://scripts/ui/AppPanel.gd"

const FLOOR_OVERVIEW_ROW_SCENE := preload("res://scenes/ui/FloorOverviewRow.tscn")
const TENANT_OVERVIEW_ROW_SCENE := preload("res://scenes/ui/TenantOverviewRow.tscn")

var selected_tab := "overview"
var tab_row: HBoxContainer
var summary_grid: GridContainer
var upgrade_progress_card: ProgressCard
var list_root: VBoxContainer
var empty_tenant_row: IconInfoRow
var level_card: StatCard
var exp_card: StatCard
var rent_card: StatCard
var floor_card: StatCard
var room_card: StatCard
var tenant_card: StatCard
var satisfaction_card: StatCard
var next_goal_card: StatCard

var rent_value_template := ""
var floor_value_template := ""
var room_count_template := ""
var tenant_count_template := ""
var max_level_text := ""
var next_level_text_template := ""
var empty_satisfaction_text := ""

func open(initial_tab := "overview") -> void:
	selected_tab = initial_tab
	_refresh()

func _refresh() -> void:
	setup_panel("", false)
	_bind_scene_nodes()
	_bind_scene_text()
	_configure_tabs()
	_prepare_content_roots()
	match selected_tab:
		"floors":
			_build_floors_tab()
		"tenants":
			_build_tenants_tab()
		_:
			_build_summary_tab()

func _bind_scene_nodes() -> void:
	tab_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TabRow") as HBoxContainer
	summary_grid = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid") as GridContainer
	upgrade_progress_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/UpgradeProgressCard") as ProgressCard
	list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ListRoot") as VBoxContainer
	empty_tenant_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/EmptyTenantRow") as IconInfoRow
	level_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid/LevelCard") as StatCard
	exp_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid/ExpCard") as StatCard
	rent_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid/RentCard") as StatCard
	floor_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid/FloorCard") as StatCard
	room_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid/RoomCard") as StatCard
	tenant_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid/TenantCard") as StatCard
	satisfaction_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid/SatisfactionCard") as StatCard
	next_goal_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/SummaryGrid/NextGoalCard") as StatCard

func _bind_scene_text() -> void:
	rent_value_template = _template_text("RentValueTemplate")
	floor_value_template = _template_text("FloorValueTemplate")
	room_count_template = _template_text("RoomCountTemplate")
	tenant_count_template = _template_text("TenantCountTemplate")
	max_level_text = _template_text("MaxLevelText")
	next_level_text_template = _template_text("NextLevelTextTemplate")
	empty_satisfaction_text = _template_text("EmptySatisfactionText")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("ApartmentOverviewPanel scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _configure_tabs() -> void:
	for node_name in ["OverviewTab", "FloorsTab", "TenantsTab"]:
		var tab_button := tab_row.get_node_or_null(node_name) as PanelTabButton
		if tab_button == null:
			continue
		if not tab_button.tab_selected.is_connected(_on_tab_selected):
			tab_button.tab_selected.connect(_on_tab_selected)
		tab_button.setup("", selected_tab == tab_button.tab_id)

func _prepare_content_roots() -> void:
	summary_grid.visible = selected_tab == "overview"
	upgrade_progress_card.visible = selected_tab == "overview" and _next_level_ratio() >= 0.0
	list_root.visible = selected_tab != "overview"
	empty_tenant_row.visible = false
	UIPanelFactory.clear_children(list_root)

func _build_summary_tab() -> void:
	level_card.set_value("Lv.%d" % GameState.apartment_level)
	exp_card.set_value("%d" % GameState.apartment_exp)
	rent_card.set_value(rent_value_template % GameState.total_rent_per_minute)
	floor_card.set_value(floor_value_template % GameState.highest_built_floor)
	room_card.set_value(room_count_template % GameState.get_unlocked_rooms().size())
	tenant_card.set_value(tenant_count_template % _tenant_count())
	satisfaction_card.set_value(_average_satisfaction_text())
	next_goal_card.set_value(_next_level_text())
	var ratio := _next_level_ratio()
	if ratio >= 0.0:
		upgrade_progress_card.set_progress("%d%%" % int(round(ratio * 100.0)), ratio)

func _build_floors_tab() -> void:
	for floor_data in ConfigManager.floors:
		var floor: Dictionary = floor_data
		var row := FLOOR_OVERVIEW_ROW_SCENE.instantiate() as FloorOverviewRow
		list_root.add_child(row)
		row.setup(floor)

func _build_tenants_tab() -> void:
	var count := 0
	for tenant_id in GameState.tenants.keys():
		var tenant_state: Dictionary = GameState.tenants[tenant_id]
		var room_id := str(tenant_state.get("room_id", ""))
		if room_id.is_empty():
			continue
		count += 1
		var row := TENANT_OVERVIEW_ROW_SCENE.instantiate() as TenantOverviewRow
		list_root.add_child(row)
		row.setup(str(tenant_id), tenant_state)
	if count == 0:
		empty_tenant_row.visible = true

func _on_tab_selected(tab: String) -> void:
	selected_tab = tab
	_refresh()

func _next_level_ratio() -> float:
	var next_data: Dictionary = ConfigManager.get_level_data(GameState.apartment_level + 1)
	if next_data.is_empty():
		return -1.0
	var required_exp := float(next_data.get("required_exp", 0))
	if required_exp <= 0.0:
		return 1.0
	return clampf(float(GameState.apartment_exp) / required_exp, 0.0, 1.0)

func _next_level_text() -> String:
	var next_data: Dictionary = ConfigManager.get_level_data(GameState.apartment_level + 1)
	if next_data.is_empty():
		return max_level_text
	var required_exp: int = int(next_data.get("required_exp", 0))
	var remaining: int = maxi(0, required_exp - GameState.apartment_exp)
	return next_level_text_template % [GameState.apartment_level + 1, remaining]

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
		return empty_satisfaction_text
	return "%.1f" % (float(total) / float(count))

func _tenant_count() -> int:
	var count := 0
	for tenant in GameState.tenants.values():
		if not str(tenant.get("room_id", "")).is_empty():
			count += 1
	return count
