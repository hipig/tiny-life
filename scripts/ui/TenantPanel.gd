class_name TenantPanel
extends "res://scripts/ui/AppPanel.gd"

const ICON_ACTION_ROW_SCENE := preload("res://scenes/ui/IconActionRow.tscn")

signal tenant_recruit_requested(tenant_id: String, room_id: String)

var room_id := ""
var mode := "view"
var selected_region_id := ""
var region_content: VBoxContainer
var candidate_content: VBoxContainer
var tenant_view_content: VBoxContainer
var occupied_room_row: IconInfoRow
var region_intro_row: IconInfoRow
var region_list_root: VBoxContainer
var back_to_regions_button: PanelActionButton
var rent_limit_row: IconInfoRow
var candidate_list_root: VBoxContainer
var candidate_empty_row: IconInfoRow
var tenant_stat_card: StatCard
var tenant_info_row: IconInfoRow

var panel_title := ""
var candidates_title_template := ""
var fallback_region_name := ""
var fallback_tolerance_level := ""
var region_detail_template := ""
var region_locked_suffix := ""
var region_action_text := ""
var rent_limit_title_template := ""
var rent_limit_detail_template := ""
var candidate_title_template := ""
var candidate_detail_template := ""
var candidate_over_limit_suffix := ""
var candidate_action_text := ""
var candidate_blocked_text := ""
var tenant_stat_title_template := ""
var tenant_stat_value_template := ""
var tenant_behavior_title_template := ""
var tenant_preference_detail_template := ""
var behavior_label_by_key := {}
var fallback_behavior_label := ""

func open(target_room_id: String, panel_mode: String) -> void:
	room_id = target_room_id
	mode = panel_mode
	selected_region_id = ""
	_bind_scene_text()
	if mode == "recruit":
		_show_regions()
	else:
		_show_tenant_view()

func refresh() -> void:
	_bind_scene_text()
	if mode == "recruit":
		if selected_region_id.is_empty():
			_show_regions()
		else:
			_show_candidates(selected_region_id)
		return
	_show_tenant_view()

func _show_regions() -> void:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	setup_panel(panel_title, false)
	_bind_scene_nodes()
	_show_content("regions")
	UIPanelFactory.clear_children(region_list_root)
	if not str(room.get("tenant_id", "")).is_empty():
		occupied_room_row.visible = true
		region_intro_row.visible = false
		return
	occupied_room_row.visible = false
	region_intro_row.visible = true
	for region_data in ConfigManager.tenant_regions:
		var region: Dictionary = region_data
		var required_level := int(region.get("required_apartment_level", 1))
		var unlocked := GameState.apartment_level >= required_level
		var action_row := ICON_ACTION_ROW_SCENE.instantiate() as IconActionRow
		region_list_root.add_child(action_row)
		action_row.setup(
			"Mail.png",
			str(region.get("name", fallback_region_name)),
			region_detail_template % [
			required_level,
			region.get("rent_tolerance_level", fallback_tolerance_level),
			float(region.get("max_rent_per_minute", 0.0)),
			"" if unlocked else region_locked_suffix
			],
			region_action_text,
			"white" if unlocked else "grey",
			UIPanelFactory.ButtonSkin.GREEN if unlocked else UIPanelFactory.ButtonSkin.GREY,
			not unlocked
		)
		var region_id := str(region.get("id", ""))
		action_row.action_requested.connect(_show_candidates.bind(region_id))

func _show_candidates(region_id: String) -> void:
	selected_region_id = region_id
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var region: Dictionary = ConfigManager.get_tenant_region_data(region_id)
	setup_panel(candidates_title_template % region.get("name", fallback_region_name), false)
	_bind_scene_nodes()
	_show_content("candidates")
	UIPanelFactory.clear_children(candidate_list_root)
	candidate_empty_row.visible = false
	rent_limit_row.set_title(rent_limit_title_template % region.get("rent_tolerance_level", fallback_tolerance_level))
	rent_limit_row.set_detail(rent_limit_detail_template % float(region.get("max_rent_per_minute", 0.0)))
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
		var row := ICON_ACTION_ROW_SCENE.instantiate() as IconActionRow
		candidate_list_root.add_child(row)
		row.setup("Population.png", candidate_title_template % [
			tenant_data.get("name", ""),
			tenant_data.get("job", "")
		], candidate_detail_template % [
			float(tenant_data.get("pay_multiplier", 1.0)),
			region.get("rent_tolerance_level", fallback_tolerance_level),
			expected_rent,
			max_rent,
			", ".join(tenant_data.get("favorite_tags", [])),
			"" if affordable else candidate_over_limit_suffix
		], candidate_action_text if affordable else candidate_blocked_text, "white" if affordable else "grey", UIPanelFactory.ButtonSkin.GREEN if affordable else UIPanelFactory.ButtonSkin.GREY, not affordable)
		row.action_requested.connect(_on_candidate_pressed.bind(tenant_id))
	if shown == 0:
		candidate_empty_row.visible = true

func _show_tenant_view() -> void:
	var room: Dictionary = GameState.rooms.get(room_id, {})
	var tenant_id := str(room.get("tenant_id", ""))
	var data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var state: Dictionary = GameState.tenants.get(tenant_id, {})
	setup_panel(panel_title, false)
	_bind_scene_nodes()
	_show_content("view")
	tenant_stat_card.set_title(tenant_stat_title_template % [data.get("name", ""), data.get("job", "")])
	tenant_stat_card.set_value(tenant_stat_value_template % int(state.get("satisfaction", 0)))
	tenant_info_row.set_title(tenant_behavior_title_template % _behavior_label(str(state.get("current_behavior", ""))))
	tenant_info_row.set_detail(tenant_preference_detail_template % ", ".join(data.get("favorite_tags", [])))

func _behavior_label(value: String) -> String:
	var key := ConfigManager.normalize_behavior_key(value, "")
	if behavior_label_by_key.has(key):
		return str(behavior_label_by_key.get(key))
	if not fallback_behavior_label.is_empty():
		return fallback_behavior_label
	return key

func _bind_scene_nodes() -> void:
	region_content = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/RegionContent") as VBoxContainer
	candidate_content = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/CandidateContent") as VBoxContainer
	tenant_view_content = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TenantViewContent") as VBoxContainer
	occupied_room_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/RegionContent/OccupiedRoomRow") as IconInfoRow
	region_intro_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/RegionContent/RegionIntroRow") as IconInfoRow
	region_list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/RegionContent/RegionListRoot") as VBoxContainer
	back_to_regions_button = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/CandidateContent/BackToRegionsButton") as PanelActionButton
	rent_limit_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/CandidateContent/RentLimitRow") as IconInfoRow
	candidate_list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/CandidateContent/CandidateListRoot") as VBoxContainer
	candidate_empty_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/CandidateContent/CandidateEmptyRow") as IconInfoRow
	tenant_stat_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TenantViewContent/TenantStatCard") as StatCard
	tenant_info_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TenantViewContent/TenantInfoRow") as IconInfoRow
	if region_content == null or candidate_content == null or tenant_view_content == null:
		push_error("TenantPanel.tscn must expose RegionContent, CandidateContent, and TenantViewContent.")
	if back_to_regions_button != null and not back_to_regions_button.action_requested.is_connected(_show_regions):
		back_to_regions_button.action_requested.connect(_show_regions)

func _bind_scene_text() -> void:
	panel_title = _template_text("PanelTitle")
	candidates_title_template = _template_text("CandidatesTitleTemplate")
	fallback_region_name = _template_text("FallbackRegionName")
	fallback_tolerance_level = _template_text("FallbackToleranceLevel")
	region_detail_template = _template_text("RegionDetailTemplate")
	region_locked_suffix = _template_text("RegionLockedSuffix")
	region_action_text = _template_text("RegionActionText")
	rent_limit_title_template = _template_text("RentLimitTitleTemplate")
	rent_limit_detail_template = _template_text("RentLimitDetailTemplate")
	candidate_title_template = _template_text("CandidateTitleTemplate")
	candidate_detail_template = _template_text("CandidateDetailTemplate")
	candidate_over_limit_suffix = _template_text("CandidateOverLimitSuffix")
	candidate_action_text = _template_text("CandidateActionText")
	candidate_blocked_text = _template_text("CandidateBlockedText")
	tenant_stat_title_template = _template_text("TenantStatTitleTemplate")
	tenant_stat_value_template = _template_text("TenantStatValueTemplate")
	tenant_behavior_title_template = _template_text("TenantBehaviorTitleTemplate")
	tenant_preference_detail_template = _template_text("TenantPreferenceDetailTemplate")
	fallback_behavior_label = _template_text("FallbackBehaviorLabel")
	behavior_label_by_key = _behavior_labels_from_scene()

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("TenantPanel scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _behavior_labels_from_scene() -> Dictionary:
	var labels := {}
	var behavior_root := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/BehaviorLabels")
	if behavior_root == null:
		push_error("TenantPanel scene is missing TemplateText/BehaviorLabels.")
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

func _show_content(content_name: String) -> void:
	if region_content != null:
		region_content.visible = content_name == "regions"
	if candidate_content != null:
		candidate_content.visible = content_name == "candidates"
	if tenant_view_content != null:
		tenant_view_content.visible = content_name == "view"

func _on_candidate_pressed(tenant_id: String) -> void:
	tenant_recruit_requested.emit(tenant_id, room_id)
