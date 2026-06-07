@tool
extends McpTestSuite

var economy: Dictionary = {}
var furniture: Array = []
var tenants: Array = []
var regions: Array = []
var rooms: Array = []
var floors: Array = []

func suite_name() -> String:
	return "economy_regions"

func setup() -> void:
	economy = _load_json_dict("res://data/economy.json")
	furniture = _load_json_array("res://data/furniture.json")
	tenants = _load_json_array("res://data/tenants.json")
	regions = _load_json_array("res://data/tenant_regions.json")
	rooms = _load_json_array("res://data/rooms.json")
	floors = _load_json_array("res://data/floors.json")

func test_empty_rooms_have_no_auto_income() -> void:
	var rent: float = _calculate_room_rent("", 0, 60)
	var before: int = 800
	var coins_after_tick: int = before + int(floor(rent / 60.0 * 60.0))
	assert_eq(rent, 0.0, "empty rooms should not produce rent")
	assert_eq(coins_after_tick, before, "empty rooms should not add coins")

func test_auto_income_uses_integer_buffer() -> void:
	var rent: float = _calculate_room_rent("tenant_student_01", 0, 60)
	var coin_buffer: float = rent / 60.0 * 60.0
	assert_eq(int(coin_buffer), int(floor(rent)), "60 seconds should add floor(total rent) integer coins")
	assert_true(coin_buffer - float(int(coin_buffer)) < 1.0, "fractional income should stay below one coin")

func test_tenant_regions_unlock_by_apartment_level() -> void:
	var lv1_ids: Array = _unlocked_region_ids(1)
	var lv2_ids: Array = _unlocked_region_ids(2)
	assert_contains(lv1_ids, "region_affordable", "Lv.1 should unlock the starter region")
	assert_false(lv1_ids.has("region_digital"), "Lv.1 should not unlock the digital region")
	assert_contains(lv2_ids, "region_digital", "Lv.2 should unlock the digital region")

func test_region_candidate_tenants_come_from_region_config() -> void:
	var candidate_ids: Array = _region_tenant_ids("region_affordable")
	assert_contains(candidate_ids, "tenant_student_01", "affordable region should include student")
	assert_contains(candidate_ids, "tenant_elder_01", "affordable region should include elder")
	assert_false(candidate_ids.has("tenant_worker_01"), "affordable region should not include worker")

func test_initial_building_starts_with_one_room_and_second_floor_build_slot() -> void:
	var first_floor := _floor_data(1)
	var second_floor := _floor_data(2)
	assert_true(bool(first_floor.get("initial_built", false)), "first floor should be built at new-game start")
	assert_eq(str(first_floor.get("display_name", "")), "1F", "first floor should present as a real apartment floor")
	assert_eq(_room_ids_on_floor(1).size(), 1, "first floor should start with exactly one room")
	assert_false(bool(second_floor.get("initial_built", true)), "second floor should start as a build slot")
	assert_eq(int(second_floor.get("required_apartment_level", 0)), 1, "second floor build slot should be visible at Lv.1")
	assert_true(int(second_floor.get("build_cost", 0)) > 0, "second floor build slot should have a construction cost")

func test_main_ui_panel_scenes_are_split_out() -> void:
	for path in _panel_scene_paths():
		assert_true(ResourceLoader.exists(path), "%s should exist as a split UI scene" % path)

func test_main_ui_panel_scenes_are_loadable() -> void:
	for path in _panel_scene_paths():
		var scene := ResourceLoader.load(path) as PackedScene
		assert_true(scene != null, "%s should load as a PackedScene" % path)
		if scene == null:
			continue
		var node := scene.instantiate()
		assert_true(node is PanelContainer, "%s should instantiate as a panel" % path)
		node.queue_free()

func test_modular_support_scenes_are_split_out_and_loadable() -> void:
	for path in _support_scene_paths():
		assert_true(ResourceLoader.exists(path), "%s should exist as a modular support scene" % path)
		var scene := ResourceLoader.load(path) as PackedScene
		assert_true(scene != null, "%s should load as a PackedScene" % path)
		if scene == null:
			continue
		var node := scene.instantiate()
		assert_true(node != null, "%s should instantiate" % path)
		node.queue_free()

func test_main_uses_popup_layer_scene_for_feedback() -> void:
	var main_source := FileAccess.get_file_as_string("res://scenes/main/Main.gd")
	var main_scene := FileAccess.get_file_as_string("res://scenes/main/Main.tscn")
	assert_true(main_scene.contains("res://scenes/ui/PopupLayer.tscn"), "Main scene should compose the PopupLayer scene")
	assert_false(main_source.contains("CanvasLayer.new()"), "Main should not build the popup CanvasLayer by hand")

func test_main_scene_composes_primary_child_scenes() -> void:
	var main_scene := FileAccess.get_file_as_string("res://scenes/main/Main.tscn")
	var main_source := FileAccess.get_file_as_string("res://scenes/main/Main.gd")
	var menu_source := FileAccess.get_file_as_string("res://scripts/ui/FloatingMenu.gd")
	var menu_scene := FileAccess.get_file_as_string("res://scenes/ui/FloatingMenu.tscn")
	assert_true(main_scene.contains("res://scenes/ui/TopStatusBar.tscn"), "Main scene should instance TopStatusBar")
	assert_true(main_scene.contains("res://scenes/building/BuildingView.tscn"), "Main scene should instance BuildingView")
	assert_true(main_scene.contains("res://scenes/ui/FloatingMenu.tscn"), "Main scene should instance FloatingMenu")
	assert_true(main_scene.contains("CanvasLayer_UI"), "Top bar and right menu should live on a floating UI layer")
	assert_false(main_scene.contains("AppRoot"), "Main should not put the building and HUD in one layout container")
	assert_false(main_scene.contains("MainRow"), "Floating menu should not consume building-view width")
	assert_false(main_source.contains("set_anchors_preset"), "Main should not set fixed UI anchors at runtime")
	assert_false(main_source.contains("offset_left"), "Main should not set fixed UI offsets at runtime")
	assert_false(main_source.contains("custom_minimum_size = Vector2.ZERO"), "Main should keep root layout in Main.tscn")
	assert_true(main_scene.contains("offset_left = -52.0"), "Floating menu should stay narrow on the 360px viewport")
	assert_false(menu_source.contains("style_icon_button"), "Floating menu should keep icon-button skin in the editable scene")
	assert_true(menu_scene.contains("custom_minimum_size = Vector2(44, 42)"), "Floating menu tap targets should fit the 360px viewport")
	assert_true(menu_scene.contains("icons/Clipboard.png"), "Floating menu should configure icon resources in the scene")

func test_ui_scenes_are_editor_authored_for_360_viewport() -> void:
	var app_base_scene := FileAccess.get_file_as_string("res://scenes/ui/AppPanelBase.tscn")
	var app_panel_source := FileAccess.get_file_as_string("res://scripts/ui/AppPanel.gd")
	var top_scene := FileAccess.get_file_as_string("res://scenes/ui/TopStatusBar.tscn")
	var menu_scene := FileAccess.get_file_as_string("res://scenes/ui/FloatingMenu.tscn")
	var menu_source := FileAccess.get_file_as_string("res://scripts/ui/FloatingMenu.gd")
	var placement_scene := FileAccess.get_file_as_string("res://scenes/ui/PlacementOverlay.tscn")
	var placement_source := FileAccess.get_file_as_string("res://scripts/ui/PlacementOverlay.gd")
	var furniture_controls_scene := FileAccess.get_file_as_string("res://scenes/furniture/FurnitureFloatingControls.tscn")
	var icon_row_scene := FileAccess.get_file_as_string("res://scenes/ui/IconInfoRow.tscn")
	var stat_card_scene := FileAccess.get_file_as_string("res://scenes/ui/StatCard.tscn")
	var progress_card_scene := FileAccess.get_file_as_string("res://scenes/ui/ProgressCard.tscn")
	var progress_card_source := FileAccess.get_file_as_string("res://scripts/ui/ProgressCard.gd")
	var task_item_row_scene := FileAccess.get_file_as_string("res://scenes/ui/TaskItemRow.tscn")
	var task_item_row_source := FileAccess.get_file_as_string("res://scripts/ui/TaskItemRow.gd")
	var furniture_shop_item_row_scene := FileAccess.get_file_as_string("res://scenes/ui/FurnitureShopItemRow.tscn")
	var furniture_shop_item_row_source := FileAccess.get_file_as_string("res://scripts/ui/FurnitureShopItemRow.gd")
	var room_furniture_item_row_scene := FileAccess.get_file_as_string("res://scenes/ui/RoomFurnitureItemRow.tscn")
	var room_furniture_item_row_source := FileAccess.get_file_as_string("res://scripts/ui/RoomFurnitureItemRow.gd")
	var rent_room_row_scene := FileAccess.get_file_as_string("res://scenes/ui/RentRoomRow.tscn")
	var rent_room_row_source := FileAccess.get_file_as_string("res://scripts/ui/RentRoomRow.gd")
	var floor_overview_row_scene := FileAccess.get_file_as_string("res://scenes/ui/FloorOverviewRow.tscn")
	var floor_overview_row_source := FileAccess.get_file_as_string("res://scripts/ui/FloorOverviewRow.gd")
	var tenant_overview_row_scene := FileAccess.get_file_as_string("res://scenes/ui/TenantOverviewRow.tscn")
	var tenant_overview_row_source := FileAccess.get_file_as_string("res://scripts/ui/TenantOverviewRow.gd")
	var tab_button_scene := FileAccess.get_file_as_string("res://scenes/ui/PanelTabButton.tscn")
	var tab_button_source := FileAccess.get_file_as_string("res://scripts/ui/PanelTabButton.gd")
	var action_button_scene := FileAccess.get_file_as_string("res://scenes/ui/PanelActionButton.tscn")
	var action_button_source := FileAccess.get_file_as_string("res://scripts/ui/PanelActionButton.gd")
	var room_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/RoomPanel.tscn")
	var room_panel_source := FileAccess.get_file_as_string("res://scripts/ui/RoomPanel.gd")
	var shop_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/FurnitureShopPanel.tscn")
	var shop_panel_source := FileAccess.get_file_as_string("res://scripts/ui/FurnitureShopPanel.gd")
	var tenant_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/TenantPanel.tscn")
	var tenant_panel_source := FileAccess.get_file_as_string("res://scripts/ui/TenantPanel.gd")
	var overview_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/ApartmentOverviewPanel.tscn")
	var overview_panel_source := FileAccess.get_file_as_string("res://scripts/ui/ApartmentOverviewPanel.gd")
	var build_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/BuildConfirmPopup.tscn")
	var build_panel_source := FileAccess.get_file_as_string("res://scripts/ui/BuildConfirmPopup.gd")
	var income_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/IncomeDetailPanel.tscn")
	var income_panel_source := FileAccess.get_file_as_string("res://scripts/ui/IncomeDetailPanel.gd")
	var rent_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/RentDetailPanel.tscn")
	var rent_panel_source := FileAccess.get_file_as_string("res://scripts/ui/RentDetailPanel.gd")
	var recycle_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/RecycleConfirmPopup.tscn")
	var recycle_panel_source := FileAccess.get_file_as_string("res://scripts/ui/RecycleConfirmPopup.gd")
	var task_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/TaskPanel.tscn")
	var reward_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/RewardPanel.tscn")
	var reward_panel_source := FileAccess.get_file_as_string("res://scripts/ui/RewardPanel.gd")
	var settings_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/SettingsPanel.tscn")
	var settings_panel_source := FileAccess.get_file_as_string("res://scripts/ui/SettingsPanel.gd")
	var offline_panel_scene := FileAccess.get_file_as_string("res://scenes/ui/OfflineRewardPopup.tscn")
	var offline_panel_source := FileAccess.get_file_as_string("res://scripts/ui/OfflineRewardPopup.gd")
	var factory_source := FileAccess.get_file_as_string("res://scripts/ui/UIPanelFactory.gd")
	assert_true(app_base_scene.contains("PanelBox"), "App panels should expose their structure in an editable base scene")
	assert_true(app_base_scene.contains("TitleLabel"), "AppPanelBase should expose the title label")
	assert_true(app_base_scene.contains("CloseButton"), "AppPanelBase should expose the close button")
	assert_true(app_base_scene.contains("ContentRoot"), "AppPanelBase should expose the content container")
	assert_true(app_panel_source.contains("get_node_or_null(\"PanelBox/Header/TitleLabel\")"), "AppPanel should bind editor-authored nodes first")
	assert_true(app_panel_source.contains("func setup_panel(title := \"\", clear_existing := false)"), "AppPanel should preserve editor-authored titles when no runtime title is supplied")
	assert_false(app_panel_source.contains("func use_center_popup"), "Center-popup layout should be authored in each .tscn scene")
	assert_false(app_panel_source.contains("func use_bottom_sheet"), "Bottom-sheet layout should be authored in each .tscn scene")
	assert_false(app_panel_source.contains("set_anchors_preset"), "AppPanel should not set fixed panel anchors in script")
	assert_false(app_panel_source.contains("offset_left"), "AppPanel should not set fixed panel offsets in script")
	for path in _app_panel_scene_paths():
		var scene_source := FileAccess.get_file_as_string(path)
		assert_true(scene_source.contains("res://scenes/ui/AppPanelBase.tscn"), "%s should inherit the editable AppPanelBase scene" % path)
		assert_true(scene_source.contains("custom_minimum_size = Vector2"), "%s should configure its preview size in the scene" % path)
		assert_true(scene_source.contains("anchors_preset = "), "%s should configure its panel anchors in the scene" % path)
	assert_true(top_scene.contains("LevelButton"), "TopStatusBar should expose its level button in the scene")
	assert_true(top_scene.contains("CoinButton"), "TopStatusBar should expose its coin button in the scene")
	assert_true(top_scene.contains("RentButton"), "TopStatusBar should expose its rent button in the scene")
	assert_true(menu_scene.contains("TaskButton"), "FloatingMenu should expose task button in the scene")
	assert_true(menu_scene.contains("ZoomInButton"), "FloatingMenu should expose zoom-in button in the scene")
	assert_true(menu_scene.contains("custom_minimum_size = Vector2(46, 0)"), "FloatingMenu should be sized for a 360px viewport")
	assert_true(menu_scene.contains("[node name=\"ZoomTooltipTemplate\" type=\"Label\""), "FloatingMenu should keep zoom tooltip templates as scene labels")
	assert_false(menu_source.contains("@export"), "FloatingMenu should not require script exports for editor-authored tooltip templates")
	assert_false(menu_source.contains("Zoom %.0f"), "FloatingMenu should not keep zoom tooltip templates in script fallbacks")
	assert_true(placement_scene.contains("PlacementControls"), "Placement overlay should expose its bottom controls in the scene")
	assert_true(placement_scene.contains("ConfirmButton"), "Placement overlay should expose confirm button in the scene")
	assert_true(placement_source.contains("get_node_or_null(\"PlacementControls\")"), "Placement overlay should bind editor-authored controls first")
	assert_true(placement_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "Placement overlay should keep dynamic text templates as scene nodes")
	assert_true(placement_scene.contains("[node name=\"PlaceConfirmText\" type=\"Label\""), "Placement overlay should keep confirm text as a scene label")
	assert_false(placement_source.contains("@export"), "Placement overlay should not require script exports for editor-authored text templates")
	assert_false(placement_source.contains("确认摆放并扣金币"), "Placement overlay should not hard-code confirm copy in script")
	assert_true(furniture_controls_scene.contains("ConfirmButton"), "Furniture floating controls should expose confirm button in the scene")
	assert_true(furniture_controls_scene.contains("CancelButton"), "Furniture floating controls should expose cancel button in the scene")
	assert_true(icon_row_scene.contains("TitleLabel"), "Repeated icon-info rows should live in a reusable scene")
	assert_true(icon_row_scene.contains("DetailLabel"), "IconInfoRow should expose detail text in the scene")
	assert_true(stat_card_scene.contains("ValueLabel"), "StatCard should expose value text in a reusable scene")
	assert_true(progress_card_scene.contains("ProgressBar"), "ProgressCard should expose its scene-authored progress bar")
	assert_true(progress_card_scene.contains("[node name=\"TitleTemplate\" type=\"Label\""), "ProgressCard should keep title templates as scene labels")
	assert_true(progress_card_scene.contains("[node name=\"FallbackTitle\" type=\"Label\""), "ProgressCard should keep fallback title copy in the scene")
	assert_false(progress_card_source.contains("@export"), "ProgressCard should not require script exports for editor-authored text templates")
	assert_false(progress_card_source.contains("\"Progress\""), "ProgressCard should not keep display fallback copy in script")
	assert_true(task_item_row_scene.contains("DescriptionLabel"), "TaskItemRow should expose task description in a reusable scene")
	assert_true(task_item_row_scene.contains("RewardLabel"), "TaskItemRow should expose rewards in a reusable scene")
	assert_true(task_item_row_scene.contains("ProgressBar"), "TaskItemRow should expose its scene-authored progress bar")
	assert_true(task_item_row_scene.contains("[node name=\"CompletedText\" type=\"Label\""), "TaskItemRow should keep completion copy as a scene label")
	assert_true(task_item_row_scene.contains("[node name=\"RewardTextTemplate\" type=\"Label\""), "TaskItemRow should keep reward templates as scene labels")
	assert_false(task_item_row_source.contains("@export"), "TaskItemRow should not require script exports for editor-authored text templates")
	assert_false(task_item_row_source.contains("%d/%d"), "TaskItemRow should not keep progress templates in script fallbacks")
	assert_false(task_item_row_source.contains("奖励："), "TaskItemRow should not keep reward copy in script fallbacks")
	assert_true(furniture_shop_item_row_scene.contains("PlaceButton"), "FurnitureShopItemRow should expose its place button in a reusable scene")
	assert_true(furniture_shop_item_row_scene.contains("[node name=\"ItemTextTemplate\" type=\"Label\""), "FurnitureShopItemRow should keep item text templates as scene labels")
	assert_true(furniture_shop_item_row_scene.contains("[node name=\"PlaceInsufficientText\" type=\"Label\""), "FurnitureShopItemRow should keep disabled button text as a scene label")
	assert_false(furniture_shop_item_row_source.contains("@export"), "FurnitureShopItemRow should not require script exports for editor-authored text templates")
	assert_false(furniture_shop_item_row_source.contains("%s %d"), "FurnitureShopItemRow should not keep item text templates in script fallbacks")
	assert_false(furniture_shop_item_row_source.contains("Not enough"), "FurnitureShopItemRow should not keep disabled button copy in script fallbacks")
	assert_true(room_furniture_item_row_scene.contains("MoveButton"), "RoomFurnitureItemRow should expose its move button in a reusable scene")
	assert_true(room_furniture_item_row_scene.contains("RecycleButton"), "RoomFurnitureItemRow should expose its recycle button in a reusable scene")
	assert_true(room_furniture_item_row_scene.contains("[node name=\"ItemTextTemplate\" type=\"Label\""), "RoomFurnitureItemRow should keep item text templates as scene labels")
	assert_true(room_furniture_item_row_scene.contains("[node name=\"FallbackFurnitureName\" type=\"Label\""), "RoomFurnitureItemRow should keep fallback furniture name in the scene")
	assert_false(room_furniture_item_row_source.contains("@export"), "RoomFurnitureItemRow should not require script exports for editor-authored text templates")
	assert_false(room_furniture_item_row_source.contains("位置"), "RoomFurnitureItemRow should not keep position copy in script fallbacks")
	assert_true(rent_room_row_scene.contains("TitleLabel"), "RentRoomRow should expose rent room title in a reusable scene")
	assert_true(rent_room_row_scene.contains("DetailLabel"), "RentRoomRow should expose rent room details in a reusable scene")
	assert_true(rent_room_row_scene.contains("[node name=\"EmptyTitleTemplate\" type=\"Label\""), "RentRoomRow should keep empty room title templates as scene labels")
	assert_true(rent_room_row_scene.contains("[node name=\"OccupiedTitleTemplate\" type=\"Label\""), "RentRoomRow should keep occupied room title templates as scene labels")
	assert_true(rent_room_row_scene.contains("[node name=\"DetailTemplate\" type=\"Label\""), "RentRoomRow should keep rent breakdown templates as scene labels")
	assert_false(rent_room_row_source.contains("@export"), "RentRoomRow should not require script exports for editor-authored text templates")
	assert_false(rent_room_row_source.contains("不产生租金"), "RentRoomRow should not keep empty detail copy in script fallbacks")
	assert_true(floor_overview_row_scene.contains("DetailLabel"), "FloorOverviewRow should expose floor details in a reusable scene")
	assert_true(floor_overview_row_scene.contains("[node name=\"DetailTemplate\" type=\"Label\""), "FloorOverviewRow should keep detail templates as scene labels")
	assert_true(floor_overview_row_scene.contains("[node name=\"BuiltStateText\" type=\"Label\""), "FloorOverviewRow should keep state labels in the scene")
	assert_false(floor_overview_row_source.contains("@export"), "FloorOverviewRow should not require script exports for editor-authored text templates")
	assert_false(floor_overview_row_source.contains("Lv.%d"), "FloorOverviewRow should not keep locked-state templates in script fallbacks")
	assert_true(tenant_overview_row_scene.contains("DetailLabel"), "TenantOverviewRow should expose tenant details in a reusable scene")
	assert_true(tenant_overview_row_scene.contains("[node name=\"TitleTemplate\" type=\"Label\""), "TenantOverviewRow should keep title templates as scene labels")
	assert_true(tenant_overview_row_scene.contains("[node name=\"DetailTemplate\" type=\"Label\""), "TenantOverviewRow should keep detail templates as scene labels")
	assert_false(tenant_overview_row_source.contains("@export"), "TenantOverviewRow should not require script exports for editor-authored text templates")
	assert_false(tenant_overview_row_source.contains("房间："), "TenantOverviewRow should not keep detail copy in script fallbacks")
	assert_true(tab_button_scene.contains("PanelTabButton"), "Panel tabs should be reusable button scenes")
	assert_false(tab_button_source.contains("@export"), "PanelTabButton should not require script exports for scene-authored tab ids")
	assert_true(action_button_scene.contains("PanelActionButton"), "Panel command buttons should be reusable scene nodes")
	assert_false(action_button_source.contains("custom_minimum_size ="), "PanelActionButton size should be authored per scene, not passed from parent scripts")
	assert_true(room_panel_scene.contains("TabRow"), "RoomPanel should expose its tab row in the scene")
	assert_true(room_panel_scene.contains("TabContent"), "RoomPanel should expose its tab content container")
	assert_true(room_panel_scene.contains("OverviewContent"), "RoomPanel should expose an editor-authored overview tab page")
	assert_true(room_panel_scene.contains("FurnitureContent"), "RoomPanel should expose an editor-authored furniture tab page")
	assert_true(room_panel_scene.contains("TenantContent"), "RoomPanel should expose an editor-authored tenant tab page")
	assert_true(room_panel_scene.contains("AddFurnitureButton"), "RoomPanel should expose its add-furniture button in the scene")
	assert_true(room_panel_scene.contains("RecruitTenantButton"), "RoomPanel should expose its recruit button in the scene")
	assert_true(room_panel_scene.contains("text = \"家具\""), "RoomPanel tabs should preview fixed labels in the scene")
	assert_true(room_panel_scene.contains("metadata/tab_id = \"furniture\""), "RoomPanel tab ids should be scene metadata")
	assert_true(room_panel_scene.contains("text = \"当前没有家具\""), "RoomPanel empty states should preview fixed copy in the scene")
	assert_true(room_panel_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "RoomPanel should keep dynamic text templates as scene nodes")
	assert_true(room_panel_scene.contains("[node name=\"TitleTemplate\" type=\"Label\""), "RoomPanel should keep dynamic title templates as scene labels")
	assert_true(room_panel_scene.contains("[node name=\"BehaviorLabels\" type=\"Control\""), "RoomPanel should keep behavior display labels in the editable scene")
	assert_true(room_panel_scene.contains("metadata/behavior_key = \"wander\""), "RoomPanel behavior labels should be keyed through scene metadata")
	assert_false(room_panel_source.contains("@export"), "RoomPanel should not require script exports for editor-authored text templates")
	assert_false(room_panel_source.contains("behavior_label_by_key = {"), "RoomPanel should not hide behavior display labels in script")
	assert_false(room_panel_source.contains("房间：%s"), "RoomPanel should not hard-code fixed title templates in script")
	assert_false(room_panel_source.contains("添加家具"), "RoomPanel should not hard-code fixed button copy in script")
	assert_true(shop_panel_scene.contains("ListRoot"), "FurnitureShopPanel should expose its list root")
	assert_true(shop_panel_scene.contains("[node name=\"TitleTemplate\" type=\"Label\""), "FurnitureShopPanel should keep title templates as scene labels")
	assert_true(shop_panel_scene.contains("[node name=\"FallbackRoomName\" type=\"Label\""), "FurnitureShopPanel should keep fallback room names as scene labels")
	assert_false(shop_panel_source.contains("@export"), "FurnitureShopPanel should not require script exports for editor-authored text templates")
	assert_false(shop_panel_source.contains("为 %s 添加家具"), "FurnitureShopPanel should not hide title templates in script")
	assert_true(tenant_panel_scene.contains("RegionContent"), "TenantPanel should expose its region selection content")
	assert_true(tenant_panel_scene.contains("CandidateContent"), "TenantPanel should expose its candidate content")
	assert_true(tenant_panel_scene.contains("TenantViewContent"), "TenantPanel should expose its tenant view content")
	assert_true(tenant_panel_scene.contains("BackToRegionsButton"), "TenantPanel should expose its back button in the scene")
	assert_true(tenant_panel_scene.contains("text = \"选择寻找租客的区域\""), "TenantPanel should preview region intro copy in the scene")
	assert_true(tenant_panel_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "TenantPanel should keep dynamic text templates as scene nodes")
	assert_true(tenant_panel_scene.contains("[node name=\"CandidateDetailTemplate\" type=\"Label\""), "TenantPanel should keep candidate row templates as scene labels")
	assert_true(tenant_panel_scene.contains("text = \"倍率 %.2f"), "TenantPanel should preview candidate row templates in the scene")
	assert_true(tenant_panel_scene.contains("[node name=\"BehaviorLabels\" type=\"Control\""), "TenantPanel should keep behavior display labels in the editable scene")
	assert_true(tenant_panel_scene.contains("metadata/behavior_key = \"wander\""), "TenantPanel behavior labels should be keyed through scene metadata")
	assert_false(tenant_panel_source.contains("@export"), "TenantPanel should not require script exports for editor-authored text templates")
	assert_false(tenant_panel_source.contains("选择寻找租客的区域"), "TenantPanel should not hard-code region intro copy in script")
	assert_false(tenant_panel_source.contains("租金过高"), "TenantPanel should not hard-code candidate button copy in script")
	assert_false(tenant_panel_source.contains("behavior_label_by_key = {"), "TenantPanel should not hide behavior display labels in script")
	assert_true(overview_panel_scene.contains("SummaryGrid"), "ApartmentOverviewPanel should expose its summary grid")
	assert_true(overview_panel_scene.contains("ListRoot"), "ApartmentOverviewPanel should expose its list root")
	assert_true(overview_panel_scene.contains("EmptyTenantRow"), "ApartmentOverviewPanel should expose its empty tenant state")
	assert_true(overview_panel_scene.contains("text = \"公寓总览\""), "ApartmentOverviewPanel should preview its title in the scene")
	assert_true(overview_panel_scene.contains("text = \"楼层\""), "ApartmentOverviewPanel should preview tab labels in the scene")
	assert_true(overview_panel_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "ApartmentOverviewPanel should keep dynamic text templates as scene nodes")
	assert_true(overview_panel_scene.contains("[node name=\"RentValueTemplate\" type=\"Label\""), "ApartmentOverviewPanel should expose rent value formatting as a scene label")
	assert_true(overview_panel_scene.contains("text = \"Lv.%d 还需 %d 经验\""), "ApartmentOverviewPanel should keep next-level templates in the scene")
	assert_false(overview_panel_source.contains("@export"), "ApartmentOverviewPanel should not require script exports for editor-authored text templates")
	assert_false(overview_panel_source.contains("Lv.%d 还需"), "ApartmentOverviewPanel should not hide next-level templates in script")
	assert_true(build_panel_scene.contains("StatsGrid"), "BuildConfirmPopup should expose its stat grid")
	assert_true(build_panel_scene.contains("CostCard"), "BuildConfirmPopup should expose cost card in the scene")
	assert_true(build_panel_scene.contains("StatusRow"), "BuildConfirmPopup should expose build status row in the scene")
	assert_true(build_panel_scene.contains("[node name=\"TitleTemplate\" type=\"Label\""), "BuildConfirmPopup should keep title templates as scene labels")
	assert_true(build_panel_scene.contains("text = \"需要金币\""), "BuildConfirmPopup should preview fixed card titles in the scene")
	assert_true(build_panel_scene.contains("[node name=\"CanBuildTitle\" type=\"Label\""), "BuildConfirmPopup should keep buildable-state copy as a scene label")
	assert_true(build_panel_scene.contains("[node name=\"InsufficientTitle\" type=\"Label\""), "BuildConfirmPopup should keep locked-state copy as a scene label")
	assert_true(build_panel_scene.contains("[node name=\"InsufficientDetailTemplate\" type=\"Label\""), "BuildConfirmPopup should keep locked-state detail templates as scene labels")
	assert_false(build_panel_source.contains("@export"), "BuildConfirmPopup should not require script exports for editor-authored text templates")
	assert_false(build_panel_source.contains("setup_panel(\"建造第"), "BuildConfirmPopup should not hide title templates in script")
	assert_false(build_panel_source.contains("cost_card.setup(\"需要金币\""), "BuildConfirmPopup should not hide fixed stat titles in script")
	assert_false(build_panel_source.contains("金币不足"), "BuildConfirmPopup should not hide locked-state copy in script")
	assert_false(build_panel_source.contains("可以建造"), "BuildConfirmPopup should not hide buildable-state copy in script")
	assert_true(income_panel_scene.contains("StatsGrid"), "IncomeDetailPanel should expose its stat grid")
	assert_true(income_panel_scene.contains("CoinCard"), "IncomeDetailPanel should expose its fixed coin card")
	assert_true(income_panel_scene.contains("NextIncomeRow"), "IncomeDetailPanel should expose its fixed next-income row")
	assert_true(income_panel_scene.contains("text = \"收益详情\""), "IncomeDetailPanel should preview its title in the scene")
	assert_true(income_panel_scene.contains("text = \"当前金币\""), "IncomeDetailPanel should preview fixed card titles in the scene")
	assert_true(income_panel_scene.contains("text = \"自动租金只按整数金币入账，小数会继续留在缓冲中。\""), "IncomeDetailPanel should preview fixed explanatory text in the scene")
	assert_true(income_panel_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "IncomeDetailPanel should keep dynamic text templates as scene nodes")
	assert_true(income_panel_scene.contains("[node name=\"OfflineCapTitlePrefix\" type=\"Label\""), "IncomeDetailPanel should expose offline cap title prefix as a scene label")
	assert_true(income_panel_scene.contains("text = \"离线收益上限：\""), "IncomeDetailPanel should keep static title prefixes in the scene")
	assert_true(income_panel_scene.contains("[node name=\"NextIncomeTickTemplate\" type=\"Label\""), "IncomeDetailPanel should expose next-income template as a scene label")
	assert_true(income_panel_scene.contains("text = \"约 %.1f 秒后入账下 1 个整数金币\""), "IncomeDetailPanel should keep dynamic explanation templates in the scene")
	assert_false(income_panel_source.contains("setup_panel(\"收益详情\""), "IncomeDetailPanel should not overwrite the editor-authored panel title")
	assert_false(income_panel_source.contains("coin_card.setup(\"当前金币\""), "IncomeDetailPanel should not hide fixed stat titles in script")
	assert_false(income_panel_source.contains("自动租金只按整数金币入账"), "IncomeDetailPanel should not hide fixed explanatory text in script")
	assert_false(income_panel_source.contains("约 %.1f 秒后"), "IncomeDetailPanel should not hide dynamic explanation templates in script")
	assert_false(income_panel_source.contains("@export"), "IncomeDetailPanel should not require script exports for editor-authored text templates")
	assert_true(rent_panel_scene.contains("ListRoot"), "RentDetailPanel should expose its list root")
	assert_true(rent_panel_scene.contains("TotalRentCard"), "RentDetailPanel should expose the total rent card")
	assert_true(rent_panel_scene.contains("text = \"租金构成\""), "RentDetailPanel should preview its title in the scene")
	assert_true(rent_panel_scene.contains("[node name=\"RentValueTemplate\" type=\"Label\""), "RentDetailPanel should keep rent formatting as a scene label")
	assert_true(rent_panel_scene.contains("text = \"%.1f / 分钟\""), "RentDetailPanel should keep rent value templates in the scene")
	assert_false(rent_panel_source.contains("@export"), "RentDetailPanel should not require script exports for editor-authored text templates")
	assert_true(recycle_panel_scene.contains("MessageLabel"), "RecycleConfirmPopup should expose its message text")
	assert_true(recycle_panel_scene.contains("ConfirmButton"), "RecycleConfirmPopup should expose its confirm button")
	assert_true(recycle_panel_scene.contains("[node name=\"MessageTemplate\" type=\"Label\""), "RecycleConfirmPopup should keep message templates as scene labels")
	assert_true(recycle_panel_scene.contains("[node name=\"RefundTemplate\" type=\"Label\""), "RecycleConfirmPopup should keep refund templates as scene labels")
	assert_false(recycle_panel_source.contains("@export"), "RecycleConfirmPopup should not require script exports for editor-authored text templates")
	assert_false(recycle_panel_source.contains("确认回收 %s"), "RecycleConfirmPopup should not hide message templates in script")
	assert_false(recycle_panel_source.contains("将返还 %d"), "RecycleConfirmPopup should not hide refund templates in script")
	assert_true(task_panel_scene.contains("TaskListRoot"), "TaskPanel should expose its task list root")
	assert_true(task_panel_scene.contains("EmptyTaskRow"), "TaskPanel should expose its empty task state")
	assert_true(task_panel_scene.contains("text = \"当前没有进行中的任务\""), "TaskPanel should preview empty-state copy in the scene")
	assert_true(reward_panel_scene.contains("ListRoot"), "RewardPanel should expose its list root")
	assert_true(reward_panel_scene.contains("OfflineIncomeCard"), "RewardPanel should expose its offline income card")
	assert_true(reward_panel_scene.contains("TenantRefreshRow"), "RewardPanel should expose its tenant refresh description row")
	assert_true(reward_panel_scene.contains("OfflineClaimButton"), "RewardPanel should expose its claim button")
	assert_true(reward_panel_scene.contains("text = \"福利\""), "RewardPanel should preview its title in the scene")
	assert_true(reward_panel_scene.contains("text = \"领取离线收益\""), "RewardPanel should preview fixed button copy in the scene")
	assert_true(reward_panel_scene.contains("[node name=\"OfflineIncomeValueTemplate\" type=\"Label\""), "RewardPanel should keep offline income value templates as scene labels")
	assert_false(reward_panel_source.contains("@export"), "RewardPanel should not require script exports for editor-authored text templates")
	assert_false(reward_panel_source.contains("领取离线收益"), "RewardPanel should not hard-code fixed button copy in script")
	assert_true(settings_panel_scene.contains("SfxRow"), "SettingsPanel should expose its sound row")
	assert_true(settings_panel_scene.contains("PrivacyRow"), "SettingsPanel should expose its policy row")
	assert_true(settings_panel_scene.contains("SaveButton"), "SettingsPanel should expose its save button")
	assert_true(settings_panel_scene.contains("ResetButton"), "SettingsPanel should expose its reset button")
	assert_true(settings_panel_scene.contains("text = \"设置\""), "SettingsPanel should preview its title in the scene")
	assert_true(settings_panel_scene.contains("text = \"音效\""), "SettingsPanel should preview fixed row copy in the scene")
	assert_false(settings_panel_source.contains("音效"), "SettingsPanel should not hard-code fixed row copy in script")
	assert_true(offline_panel_scene.contains("OfflineInfoRow"), "OfflineRewardPopup should expose its offline info row")
	assert_true(offline_panel_scene.contains("AmountCard"), "OfflineRewardPopup should expose its amount card")
	assert_true(offline_panel_scene.contains("ClaimButton"), "OfflineRewardPopup should expose its claim button")
	assert_true(offline_panel_scene.contains("DoubleClaimButton"), "OfflineRewardPopup should expose its double-claim button")
	assert_true(offline_panel_scene.contains("[node name=\"OfflineDurationTitleTemplate\" type=\"Label\""), "OfflineRewardPopup should keep dynamic duration templates as scene labels")
	assert_false(offline_panel_source.contains("@export"), "OfflineRewardPopup should not require script exports for editor-authored text templates")
	assert_true(offline_panel_scene.contains("text = \"看广告双倍领取\""), "OfflineRewardPopup should preview fixed button copy in the scene")
	assert_false(offline_panel_source.contains("你离线了"), "OfflineRewardPopup should not hard-code duration templates in script")
	assert_false(offline_panel_source.contains("看广告双倍领取"), "OfflineRewardPopup should not hard-code button copy in script")
	assert_false(factory_source.contains(".instantiate()"), "UIPanelFactory should not instantiate UI structure")
	assert_false(factory_source.contains("preload(\"res://scenes/ui/"), "UIPanelFactory should not hide reusable UI scenes behind generic add helpers")
	assert_false(factory_source.contains("func make_panel"), "UIPanelFactory should not build panel skeletons in code")
	assert_false(factory_source.contains("func add_button"), "UIPanelFactory should not create command buttons in code")
	assert_false(factory_source.contains("func add_stat_card"), "UIPanelFactory should not create stat cards in code")
	assert_false(factory_source.contains("func add_icon_row"), "UIPanelFactory should not create info rows in code")
	assert_false(factory_source.contains("func add_progress_card"), "UIPanelFactory should not create progress cards in code")

func test_ui_scripts_do_not_build_control_skeletons() -> void:
	var forbidden_tokens := [
		"Button.new(",
		"Label.new(",
		"PanelContainer.new(",
		"HBoxContainer.new(",
		"VBoxContainer.new(",
		"GridContainer.new(",
		"TextureRect.new(",
		"ScrollContainer.new(",
		"ColorRect.new("
	]
	for path in _presentation_script_paths():
		var source := FileAccess.get_file_as_string(path)
		for token in forbidden_tokens:
			assert_false(source.contains(token), "%s should not build UI skeletons with %s" % [path, token])

func test_ui_scripts_do_not_hide_fixed_layout_or_style() -> void:
	var forbidden_tokens := [
		"StyleBox",
		"add_theme_",
		"theme_override",
		"set_anchors",
		"anchor_left",
		"anchor_top",
		"anchor_right",
		"anchor_bottom",
		"offset_left",
		"offset_top",
		"offset_right",
		"offset_bottom",
		"custom_minimum_size",
		".position =",
		".size =",
		"stretch_mode",
		"mouse_filter",
		"focus_mode",
		"pivot_offset"
	]
	var allowed_tokens_by_path := {
		"res://scripts/ui/PlacementOverlay.gd": [
			"custom_minimum_size",
			".position =",
			".size ="
		]
	}
	for path in _presentation_script_paths():
		var source := FileAccess.get_file_as_string(path)
		var allowed_tokens: Array = allowed_tokens_by_path.get(path, [])
		for token in forbidden_tokens:
			if allowed_tokens.has(token):
				continue
			assert_false(source.contains(token), "%s should keep fixed UI layout/style in .tscn, not script token %s" % [path, token])

func test_project_rules_require_editor_authored_ui() -> void:
	var technical_rules := FileAccess.get_file_as_string("res://.agents/rules/technical.md")
	var trd := FileAccess.get_file_as_string("res://docs/TRD.md")
	var data_rules := FileAccess.get_file_as_string("res://.agents/rules/data-config.md")
	var tilemap_plan := FileAccess.get_file_as_string("res://docs/APARTMENT_TILEMAP_MIGRATION.md")
	assert_true(technical_rules.contains("UI 层必须在 `.tscn` 中搭建"), "technical rules should require editor-authored UI")
	assert_true(technical_rules.contains("禁止在 UI 脚本中用 `Button.new()`"), "technical rules should forbid scripted UI skeletons")
	assert_true(technical_rules.contains("固定 `StyleBox`"), "technical rules should forbid fixed UI skins in scripts")
	assert_true(trd.contains("UI 层以编辑器所见即所得为准"), "TRD should document WYSIWYG UI workflow")
	assert_true(data_rules.contains("固定 UI 结构、默认按钮文案、面板标题"), "data-config rules should allow fixed preview copy in .tscn")
	assert_true(data_rules.contains("GDScript 不应硬编码固定中文 UI 文案"), "data-config rules should keep fixed copy out of scripts")
	assert_true(data_rules.contains("data/behavior_aliases.json"), "data rules should include behavior alias compatibility config")
	assert_true(trd.contains("公寓主体应改为 TileMap / TileMapLayer 优先"), "TRD should track the apartment TileMap migration")
	assert_true(trd.contains("docs/APARTMENT_TILEMAP_MIGRATION.md"), "TRD should link the apartment TileMap migration plan")
	assert_true(trd.contains("behavior_aliases.json"), "TRD should list the behavior alias config file")
	assert_true(tilemap_plan.contains("目标状态"), "Apartment TileMap migration plan should define the target state")
	assert_true(tilemap_plan.contains("验收标准"), "Apartment TileMap migration plan should define acceptance criteria")

func test_building_view_uses_backgrounds_atlas_for_scene_backdrop() -> void:
	var building_scene := FileAccess.get_file_as_string("res://scenes/building/BuildingView.tscn")
	var backdrop_scene := FileAccess.get_file_as_string("res://scenes/building/SceneBackdrop.tscn")
	var backdrop_source := FileAccess.get_file_as_string("res://scripts/building/SceneBackdrop.gd")
	var tileset_source := FileAccess.get_file_as_string("res://tilesets/background_tileset.tres")
	var tileset := ResourceLoader.load("res://tilesets/background_tileset.tres") as TileSet
	var atlas_source := tileset.get_source(0) as TileSetAtlasSource
	assert_true(building_scene.contains("res://scenes/building/SceneBackdrop.tscn"), "BuildingView should instance the independent backdrop scene")
	assert_true(building_scene.contains("res://scenes/building/ApartmentBuilding.tscn"), "BuildingView should instance the independent apartment scene")
	assert_true(backdrop_scene.contains("Backgrounds.png"), "Backdrop nodes should draw from Pixel Spaces Backgrounds.png")
	assert_true(backdrop_scene.contains("res://tilesets/background_tileset.tres"), "Backdrop TileMapLayers should share the internal background TileSet resource")
	assert_true(tileset_source.contains("res://assets/pixel_spaces/tileset/Backgrounds.png"), "Background TileSet should reference the external Pixel Spaces texture")
	assert_eq(tileset.tile_size, Vector2i(16, 16), "Background TileSet should use 16x16 tile cells")
	assert_eq(atlas_source.texture_region_size, Vector2i(16, 16), "Background atlas source should use 16x16 atlas cells")
	assert_false(tileset_source.contains("tile_size = Vector2i(1, 1)"), "Background TileSet should not use 1x1 tiles")
	assert_false(tileset_source.contains("tile_size = Vector2i(42, 32)"), "Background TileSet should not use non-grid tile sizes")
	assert_false(tileset_source.contains("texture_region_size = Vector2i(1, 1)"), "Background atlas source should not use 1x1 atlas regions")
	assert_false(tileset_source.contains("texture_region_size = Vector2i(42, 32)"), "Background atlas source should not use non-grid atlas regions")
	assert_false(tileset_source.contains("texture_region_size = Vector2i(16, 112)"), "Sky slice should not be stored as the TileSet atlas region size")
	assert_true(tileset_source.contains("size_in_atlas"), "Background TileSet should preserve the configured multi-cell atlas tiles")
	assert_true(backdrop_scene.contains("Cloud_01"), "Cloud sprites should be editor-authored children, not generated by SceneBackdrop")
	assert_true(backdrop_scene.contains("repeat_size = Vector2(360, 0)"), "Cloud parallax should repeat horizontally on the 360px design canvas")
	assert_true(backdrop_scene.contains("scale = Vector2(1.5, 1.5)"), "Cloud scale should be authored in the scene for the 360x640 design canvas")
	for node_name in ["WorldClip", "WorldViewport", "WorldRoot", "SceneBackdrop", "ApartmentBuilding", "WorldCamera"]:
		assert_true(building_scene.contains("name=\"%s\"" % node_name), "BuildingView should expose %s in the editable scene tree" % node_name)
	for node_name in ["SkySprite", "Tiles", "MountainTileMap", "BackgroundBuildingTileMap", "TreeTileMap", "GroundTileMap", "CloudParallax"]:
		assert_true(backdrop_scene.contains("name=\"%s\"" % node_name), "SceneBackdrop should expose %s in the editable scene tree" % node_name)
	assert_true(backdrop_scene.contains("type=\"TileMapLayer\""), "Backdrop scenery should be built with TileMapLayer nodes")
	assert_true(backdrop_scene.contains("type=\"Sprite2D\""), "Sky should be a stretched Sprite2D because the source sky is not tilemap-friendly")
	assert_true(backdrop_scene.contains("type=\"Parallax2D\""), "Clouds should live in a Parallax2D node")
	assert_false(building_scene.contains("ViewportSkyFill"), "BuildingView should not hide map gaps with a viewport fill node")
	assert_false(building_scene.contains("GroundColor"), "Ground should be a tile layer, not a fallback ColorRect")
	assert_false(building_scene.contains("SkyBackground"), "BuildingView should not use a flat sky ColorRect fallback")
	assert_false(building_scene.contains("GroundBand"), "BuildingView should not use a flat ground ColorRect fallback")
	assert_false(backdrop_scene.contains("AtlasTexture_"), "SceneBackdrop should not store per-slice AtlasTexture resources")
	assert_false(backdrop_scene.contains("TileSetAtlasSource_"), "SceneBackdrop should not embed generated TileSet atlas sources")
	assert_false(backdrop_scene.contains("scroll_offset"), "SceneBackdrop should not persist runtime cloud drift")
	assert_false(backdrop_scene.contains("GrassDetailTileMap"), "Ground should stay to the single bottom TileMapLayer")
	assert_false(backdrop_source.contains("@tool"), "Backdrop should not run editor-time generation over manual TileMap edits")
	assert_false(backdrop_source.contains("TileSet.new"), "Backdrop should not create TileSets at runtime")
	assert_false(backdrop_source.contains("TileSetAtlasSource.new"), "Backdrop should not slice atlas sources at runtime")
	assert_false(backdrop_source.contains("set_cell"), "Backdrop should not paint TileMap cells at runtime")
	assert_false(backdrop_source.contains(".clear()"), "Backdrop should not clear manually painted TileMap cells at runtime")
	assert_false(backdrop_source.contains("set_map_size"), "Backdrop coverage should come from the project viewport and editable scene nodes")
	assert_false(backdrop_source.contains("map_size"), "Backdrop should not resize editor-authored sky or TileMap layers at runtime")
	assert_false(backdrop_source.contains("_apply_sky"), "SkySprite should be configured in the editor")
	assert_false(backdrop_source.contains("_rebuild_clouds"), "Cloud sprites should be configured in the editor")
	assert_false(backdrop_source.contains("Sprite2D.new"), "SceneBackdrop should not generate cloud sprites at runtime")
	assert_false(backdrop_source.contains("scroll_offset"), "SceneBackdrop should not drift manually positioned clouds into the ground")
	assert_false(backdrop_source.contains("_paint_tile_layers"), "Backdrop should not auto-generate scenery TileMap layers")
	assert_false(backdrop_source.contains("auto_generate_tilemaps"), "Backdrop should leave all TileMap painting to the editor")
	assert_false(backdrop_source.contains("get_tile_size_in_atlas"), "Backdrop should not inspect atlas stamps for runtime placement")
	assert_false(backdrop_source.contains("sky_tile_texture"), "Sky should use a simple region on SkySprite instead of exported AtlasTexture slices")
	assert_false(backdrop_source.contains("ground_tile_texture"), "Ground should use shared TileSet atlas coordinates")
	assert_false(backdrop_source.contains("mountain_scale"), "Backdrop should not scale TileMap scenery layers")
	assert_false(backdrop_source.contains("layer.scale"), "Backdrop should not adjust TileMapLayer scale")
	assert_false(backdrop_source.contains("layer.position"), "Backdrop should not adjust TileMapLayer position")
	assert_false(backdrop_source.contains("@export var cloud_slices"), "Backdrop should not hide atlas slices in script arrays")
	assert_false(backdrop_source.contains("draw_texture_rect"), "Backdrop should not custom-draw atlas layers")
	assert_true(backdrop_source.contains("ground_rows"), "Ground should be constrained to at most three 16px rows")

func test_floor_and_room_visuals_use_building_atlases() -> void:
	var floor_source := FileAccess.get_file_as_string("res://scripts/building/Floor.gd")
	var service_source := FileAccess.get_file_as_string("res://scripts/building/FloorServiceCore.gd")
	var room_source := FileAccess.get_file_as_string("res://scripts/building/Room.gd")
	var floor_scene := FileAccess.get_file_as_string("res://scenes/building/Floor.tscn")
	var floor_service_scene := FileAccess.get_file_as_string("res://scenes/building/FloorServiceCore.tscn")
	var service_tilemap_scene := FileAccess.get_file_as_string("res://scenes/building/ServiceCoreTileMap.tscn")
	var room_scene := FileAccess.get_file_as_string("res://scenes/building/Room.tscn")
	var room_shell_scene := FileAccess.get_file_as_string("res://scenes/building/RoomShell.tscn")
	var room_shell_source := FileAccess.get_file_as_string("res://scripts/building/RoomShell.gd")
	var apartment_tilemap_scene := FileAccess.get_file_as_string("res://scenes/building/ApartmentTileMap.tscn")
	var apartment_tileset_source := FileAccess.get_file_as_string("res://tilesets/apartment_tileset.tres")
	var apartment_tileset := ResourceLoader.load("res://tilesets/apartment_tileset.tres") as TileSet
	var floor_counts := {}
	for room in rooms:
		var room_data: Dictionary = room
		var floor_index := int(room_data.get("floor_index", 0))
		floor_counts[floor_index] = int(floor_counts.get(floor_index, 0)) + 1
		assert_true(ResourceLoader.exists(str(room_data.get("room_scene_path", ""))), "%s should configure a loadable room scene template" % room_data.get("id", ""))
		assert_true(_asset_texture_exists(room_data.get("infrastructure_asset", {})), "%s should use Infrastructure.png for its room frame" % room_data.get("id", ""))
		assert_true(room_data.has("room_size"), "%s should expose room_size for future expansion" % room_data.get("id", ""))
		assert_true(room_data.has("grid_rect"), "%s should expose grid_rect for future placement upgrades" % room_data.get("id", ""))
	for floor_index in floor_counts.keys():
		assert_eq(int(floor_counts[floor_index]), 1, "%dF should have one MVP room" % int(floor_index))
	assert_true(floor_scene.contains("FloorServiceCore.tscn"), "Each floor should expose a left-side door/elevator service core scene")
	assert_true(floor_scene.contains("room_scene = ExtResource"), "Floor should assign the editable Room template in Floor.tscn")
	assert_true(floor_service_scene.contains("ServiceCoreTileMap.tscn"), "FloorServiceCore should compose an editable TileMap template")
	assert_true(service_tilemap_scene.contains("res://tilesets/apartment_tileset.tres"), "ServiceCoreTileMap should share the internal apartment TileSet")
	for layer_name in ["WallTileMap", "FloorTileMap", "InfrastructureTileMap", "RoofTileMap", "ConstructionTileMap"]:
		assert_true(service_tilemap_scene.contains("name=\"%s\" type=\"TileMapLayer\"" % layer_name), "ServiceCoreTileMap should expose %s for editor painting" % layer_name)
	assert_true(floor_service_scene.contains("FloorLabel"), "FloorServiceCore should expose its floor label in the scene")
	assert_true(floor_service_scene.contains("theme_override_font_sizes/font_size = 9"), "Floor label style should be editor-authored")
	assert_true(floor_source.contains("get_node_or_null(\"FloorServiceCore\")"), "Floor should bind the scene-authored service core node")
	assert_true(floor_source.contains("room_scene_path"), "Floor should allow room config to select an editor-authored room scene template")
	assert_true(floor_source.contains("_scene_from_path"), "Floor should load configured room templates with scene default fallback")
	assert_false(floor_source.contains("FLOOR_SERVICE_CORE_SCENE"), "Floor should not instantiate the service-core scene as a fallback")
	assert_false(floor_source.contains("preload(\"res://scenes/building/Room.tscn\")"), "Floor should not hide the room template in script")
	assert_false(floor_source.contains("apply_asset_to_texture_rect"), "Floor service-core visuals should be editor-painted TileMaps")
	assert_false(floor_source.contains("AtlasTexture.new"), "Floor should not create atlas slices for service-core visuals")
	assert_false(service_source.contains("TextureRect"), "FloorServiceCore should not depend on scripted texture slices")
	assert_false(service_source.contains("ColorRect"), "FloorServiceCore should not depend on scripted color fallbacks")
	assert_false(service_source.contains("add_theme_"), "FloorServiceCore should not hide fixed label styling in script")
	assert_true(room_scene.contains("RoomShell.tscn"), "Room should compose its editable shell scene")
	assert_true(room_scene.contains("tenant_scene = ExtResource"), "Room should assign the editable tenant child scene in Room.tscn")
	assert_true(room_scene.contains("furniture_scene = ExtResource"), "Room should assign the editable furniture child scene in Room.tscn")
	assert_true(room_scene.contains("StyleBoxFlat_room_normal"), "Room button skin should be editor-authored")
	assert_true(room_scene.contains("fallback_room_name = \"房间\""), "Room fallback display text should be authored in Room.tscn")
	assert_true(room_scene.contains("rent_badge_template = \"评分 %d  租金 %.1f\""), "Room rent badge template should be authored in Room.tscn")
	assert_true(room_shell_scene.contains("ApartmentTileMap.tscn"), "Room shell should compose the editable apartment TileMap template")
	assert_true(room_shell_scene.contains("text = \"房间\""), "Room name badge should be previewable in RoomShell.tscn")
	assert_true(room_shell_scene.contains("text = \"评分 0  租金 0\""), "Room rent badge should be previewable in RoomShell.tscn")
	assert_true(room_shell_scene.contains("anchor_left = 1.0"), "Room rent badge should use editor-authored right anchoring")
	assert_true(room_shell_scene.contains("theme_override_font_sizes/font_size = 9"), "Room name badge style should be editor-authored")
	assert_true(room_shell_scene.contains("theme_override_font_sizes/font_size = 8"), "Room rent badge style should be editor-authored")
	assert_true(apartment_tilemap_scene.contains("res://tilesets/apartment_tileset.tres"), "ApartmentTileMap should share the internal apartment TileSet")
	for layer_name in ["WallTileMap", "FloorTileMap", "InfrastructureTileMap", "RoofTileMap", "ConstructionTileMap"]:
		assert_true(apartment_tilemap_scene.contains("name=\"%s\" type=\"TileMapLayer\"" % layer_name), "ApartmentTileMap should expose %s for editor painting" % layer_name)
	assert_true(apartment_tileset != null, "Apartment TileSet should load")
	if apartment_tileset != null:
		assert_eq(apartment_tileset.tile_size, Vector2i(16, 16), "Apartment TileSet should use 16x16 tile cells")
		assert_eq((apartment_tileset.get_source(0) as TileSetAtlasSource).texture_region_size, Vector2i(16, 16), "Infrastructure atlas source should use 16x16 atlas cells")
		assert_eq((apartment_tileset.get_source(1) as TileSetAtlasSource).texture_region_size, Vector2i(16, 16), "Wallpaper atlas source should use 16x16 atlas cells")
	assert_true(apartment_tileset_source.contains("Infrastructure.png"), "Apartment TileSet should reference the infrastructure atlas")
	assert_true(apartment_tileset_source.contains("Wallpaper Tilesets.png"), "Apartment TileSet should reference the wallpaper atlas")
	assert_false(room_source.contains("StyleBoxFlat.new"), "Room should not create fixed button skins in script")
	assert_false(room_source.contains("add_theme_"), "Room should not hide fixed badge styling in script")
	assert_false(room_source.contains("评分"), "Room should not hard-code badge copy in script")
	assert_false(room_source.contains("租金"), "Room should not hard-code badge copy in script")
	assert_false(room_source.contains("\"房间\""), "Room fallback display copy should stay in Room.tscn")
	assert_false(room_source.contains("@export var infrastructure_texture"), "Room body visuals should move to TileMap instead of inspector texture slices")
	assert_false(room_source.contains("preload(\"res://scenes/tenant/Tenant.tscn\")"), "Room should not hide tenant child templates in script")
	assert_false(room_source.contains("preload(\"res://scenes/furniture/Furniture.tscn\")"), "Room should not hide furniture child templates in script")
	assert_false(room_shell_source.contains("rent_badge.position"), "Room rent badge position should be authored by anchors in RoomShell.tscn")
	assert_false(room_shell_scene.contains("RoomInfrastructure"), "Room shell should not keep old TextureRect infrastructure body")
	assert_false(room_shell_scene.contains("WallBase"), "Room shell should not keep old ColorRect wall body")
	assert_false(room_shell_scene.contains("FloorBase"), "Room shell should not keep old ColorRect floor body")
	assert_false(room_shell_scene.contains("RoofEaves"), "Room shell should not keep old TextureRect roof body")
	assert_false(floor_service_scene.contains("ServiceInfrastructure"), "Service core should not keep old TextureRect infrastructure body")
	assert_false(floor_service_scene.contains("DoorOrElevator"), "Service core should not keep old TextureRect door/elevator body")
	assert_false(floor_service_scene.contains("ServiceShade"), "Service core should not keep old ColorRect shade fallback")
	assert_true(room_source.contains("room.get(\"room_size\""), "Room rendering should support runtime room-size upgrades")
	assert_true(room_source.contains("tenant_view.setup(tenant_id, room_id)"), "Room should bind tenant scene instances to their room")
	assert_true(room_source.contains("_furniture_position"), "Furniture should be positioned inside the room instead of listed as thumbnails")

func test_room_layout_upgrades_are_config_driven_and_future_rooms_can_stay_hidden() -> void:
	var config_source := FileAccess.get_file_as_string("res://scripts/autoload/ConfigManager.gd")
	var state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	var floor_source := FileAccess.get_file_as_string("res://scripts/building/Floor.gd")
	var building_source := FileAccess.get_file_as_string("res://scripts/building/ApartmentBuilding.gd")
	for room in rooms:
		var room_data: Dictionary = room
		assert_true(room_data.has("room_scene_path"), "%s should expose room_scene_path for TileMap template selection" % room_data.get("id", ""))
		assert_true(room_data.has("layout_upgrades"), "%s should expose layout_upgrades for room expansion" % room_data.get("id", ""))
		assert_true(room_data.get("layout_upgrades", []).size() > 0, "%s should have at least one room layout upgrade template" % room_data.get("id", ""))
	assert_true(config_source.contains("get_room_layout_upgrade"), "ConfigManager should expose room layout upgrade lookup")
	assert_true(state_source.contains("apply_room_layout_upgrade"), "GameState should apply room layout upgrades without hardcoding sizes")
	assert_true(state_source.contains("unlock_room"), "GameState should expose a future room unlock path")
	assert_true(floor_source.contains("_room_is_visible"), "Floor rendering should hide future configured rooms until unlocked")
	assert_true(building_source.contains("_room_is_visible"), "Building sizing should hide future configured rooms until unlocked")
	for floor in floors:
		var floor_data: Dictionary = floor
		assert_true(floor_data.has("floor_scene_path"), "%dF should expose floor_scene_path for TileMap template selection" % int(floor_data.get("floor_index", 0)))
		assert_true(floor_data.has("build_slot_scene_path"), "%dF should expose build_slot_scene_path for construction template selection" % int(floor_data.get("floor_index", 0)))

func test_saved_room_layouts_are_normalized_to_current_config() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	assert_true(state_source.contains("_configured_room_layout_for_level"), "Save compatibility should derive room layout from current config and room level")
	assert_true(state_source.contains("room[\"room_size\"] = configured_layout.get"), "Saved room_size should be normalized instead of blindly trusting legacy saves")
	assert_true(state_source.contains("room[\"grid_rect\"] = configured_layout.get"), "Saved grid_rect should be normalized to the current viewport layout")
	assert_false(state_source.contains("[448, 176]"), "Old 720px-era room-size fallback should not survive in GameState")

func test_build_slots_match_apartment_floor_visual_structure() -> void:
	var building_source := FileAccess.get_file_as_string("res://scripts/building/ApartmentBuilding.gd")
	var slot_source := FileAccess.get_file_as_string("res://scripts/building/BuildSlot.gd")
	var building_scene := FileAccess.get_file_as_string("res://scenes/building/ApartmentBuilding.tscn")
	var slot_scene := FileAccess.get_file_as_string("res://scenes/building/BuildSlot.tscn")
	var slot_shell_scene := FileAccess.get_file_as_string("res://scenes/building/BuildSlotShell.tscn")
	var slot_shell_source := FileAccess.get_file_as_string("res://scripts/building/BuildSlotShell.gd")
	for floor in floors:
		var floor_data: Dictionary = floor
		assert_true(ResourceLoader.exists(str(floor_data.get("floor_scene_path", ""))), "%dF should configure a loadable floor scene template" % int(floor_data.get("floor_index", 0)))
		assert_true(ResourceLoader.exists(str(floor_data.get("build_slot_scene_path", ""))), "%dF should configure a loadable build-slot scene template" % int(floor_data.get("floor_index", 0)))
	assert_true(slot_scene.contains("BuildSlotShell.tscn"), "Build slots should compose the editable shell scene")
	assert_true(slot_scene.contains("StyleBoxFlat_slot_normal"), "Build slot button skin should be editor-authored")
	assert_true(slot_scene.contains("locked_label_template = \"%s  Lv.%d 解锁\""), "Build slot locked label template should be authored in BuildSlot.tscn")
	assert_true(slot_scene.contains("buildable_label_template = \"%s  待修建  金币 %d\""), "Build slot buildable label template should be authored in BuildSlot.tscn")
	assert_true(building_scene.contains("theme_override_constants/separation = 0"), "ApartmentBuilding spacing should be configured in the scene")
	assert_true(building_scene.contains("floor_scene = ExtResource"), "ApartmentBuilding should assign the editable Floor template in ApartmentBuilding.tscn")
	assert_true(building_scene.contains("build_slot_scene = ExtResource"), "ApartmentBuilding should assign the editable BuildSlot template in ApartmentBuilding.tscn")
	assert_true(building_source.contains("floor_scene_path"), "ApartmentBuilding should allow floor config to select an editor-authored floor scene template")
	assert_true(building_source.contains("build_slot_scene_path"), "ApartmentBuilding should allow floor config to select an editor-authored build-slot template")
	assert_true(building_source.contains("_scene_from_path"), "ApartmentBuilding should load configured templates with scene default fallback")
	assert_true(slot_shell_scene.contains("BuildServiceCore"), "Build slots should keep the left door/elevator service area")
	assert_true(slot_shell_scene.contains("BuildRoomShell"), "Build slots should draw the right-side unbuilt room shell")
	assert_true(slot_shell_scene.contains("name=\"BuildSlotShell\" type=\"HBoxContainer\""), "Build slot shell should lay out service and room areas in the editable scene")
	assert_true(slot_shell_scene.contains("ApartmentTileMap.tscn"), "Build slots should reuse the editable apartment TileMap template")
	assert_true(slot_shell_scene.contains("ServiceCoreTileMap.tscn"), "Build slots should reuse the editable service-core TileMap template")
	assert_true(slot_shell_scene.contains("theme_override_font_sizes/font_size = 10"), "Build slot label style should be editor-authored")
	assert_true(slot_shell_scene.contains("text = \"待修建\""), "Build slot label should be previewable in BuildSlotShell.tscn")
	assert_false(slot_shell_scene.contains("BuildRoomInfrastructure"), "Build slots should not keep old TextureRect infrastructure body")
	assert_false(slot_shell_scene.contains("BuildServiceInfrastructure"), "Build slots should not keep old TextureRect service infrastructure body")
	assert_false(slot_shell_scene.contains("BuildDoorOrElevator"), "Build slots should not keep old TextureRect door/elevator body")
	assert_false(slot_shell_scene.contains("ConstructionCloth"), "Build slots should not keep old TextureRect construction cloth")
	assert_false(slot_shell_scene.contains("TrafficCone"), "Build slots should not keep old TextureRect traffic cones")
	assert_false(slot_shell_scene.contains("BuildRoofEaves"), "Build slots should not keep old TextureRect roof")
	assert_false(slot_shell_scene.contains("BuildSlotScrim"), "Build slots should not keep old ColorRect construction fallback")
	assert_false(slot_source.contains("@export var construction_cloth_texture"), "Construction cloth should move to the editor-painted TileMap")
	assert_false(slot_source.contains("@export var roof_texture"), "Build-slot roof should move to the editor-painted TileMap")
	assert_false(slot_source.contains("apply_asset_to_texture_rect"), "BuildSlot should not patch building visuals from scripts")
	assert_false(slot_source.contains("AtlasTexture.new"), "BuildSlot should not create atlas slices for building visuals")
	assert_false(slot_shell_source.contains("service_core.position"), "BuildSlotShell should not hand-position the service core at runtime")
	assert_false(slot_shell_source.contains("room_shell.position"), "BuildSlotShell should not hand-position the room shell at runtime")
	assert_false(slot_source.contains("StyleBoxFlat.new"), "BuildSlot should not create fixed button skins in script")
	assert_false(slot_source.contains("add_theme_"), "BuildSlot should not hide fixed label styling in script")
	assert_false(slot_source.contains("待修建"), "BuildSlot should not hard-code build-state copy in script")
	assert_false(slot_source.contains("金币"), "BuildSlot should not hard-code build-cost copy in script")
	assert_false(slot_source.contains("解锁"), "BuildSlot should not hard-code locked-state copy in script")
	assert_false(slot_source.contains("UIPanelFactory.style_button"), "Build slots should not look like a menu button")
	assert_false(building_source.contains("preload(\"res://scenes/building/Floor.tscn\")"), "ApartmentBuilding should not hide floor templates in script")
	assert_false(building_source.contains("preload(\"res://scenes/building/BuildSlot.tscn\")"), "ApartmentBuilding should not hide build-slot templates in script")
	assert_true(building_source.contains("_has_visible_next_build_slot"), "Top built room should not duplicate roof/eaves below a visible build slot")
	assert_true(building_source.contains("_floor_size"), "Build slots should reserve configurable floor heights")

func test_placement_overlay_is_scene_based_not_grid_panel() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/PlacementOverlay.gd")
	var overlay_scene := FileAccess.get_file_as_string("res://scenes/ui/PlacementOverlay.tscn")
	var room_source := FileAccess.get_file_as_string("res://scripts/building/Room.gd")
	var popup_source := FileAccess.get_file_as_string("res://scripts/ui/PopupLayer.gd")
	var main_source := FileAccess.get_file_as_string("res://scenes/main/Main.gd")
	assert_true(overlay_scene.contains("[node name=\"PlacementOverlay\" type=\"Control\"]"), "placement overlay should be transparent Control, not a blocking panel root")
	assert_true(overlay_scene.contains("[node name=\"PlaceTitlePrefix\" type=\"Label\""), "placement overlay state text should be authored in the scene")
	assert_true(overlay_scene.contains("[node name=\"MoveConfirmText\" type=\"Label\""), "placement move confirm text should be authored in the scene")
	assert_true(overlay_scene.contains("点房间内的格子调整位置"), "placement hint copy should be previewable in the scene")
	assert_false(overlay_source.contains("extends \"res://scripts/ui/AppPanel.gd\""), "placement should not open as a full blocking AppPanel")
	assert_false(overlay_source.contains("GridContainer.new()"), "placement should not use a separate grid-selection panel")
	assert_false(overlay_source.contains("set_anchors_preset"), "placement overlay should keep its full-rect layout in the scene")
	assert_false(overlay_source.contains("_fill_parent"), "placement overlay should not repair fixed layout at runtime")
	assert_false(overlay_source.contains("点房间内的格子调整位置"), "placement hint copy should not be hidden in script")
	assert_true(overlay_source.contains("show_placement_grid"), "placement should drive the target room grid overlay")
	assert_true(room_source.contains("global_position_to_grid"), "Room should translate scene taps into placement grid cells")
	assert_true(room_source.contains("get_preview_position"), "Room should provide scene preview positions")
	assert_true(room_source.contains("UIManager.current_state != UIManager.UIState.NORMAL"), "Room clicks should not steal placement-state input")
	assert_true(popup_source.contains("open_overlay"), "PopupLayer should support transparent placement overlays")
	assert_true(main_source.contains("popup_layer.open_overlay(PLACEMENT_OVERLAY_SCENE)"), "Main should open placement through the scene overlay path")
	assert_true(main_source.contains("building_view.focus_room(room_id)"), "Main should focus the target room before scene placement")
	assert_true(main_source.contains("building_view.clear_focus()"), "Main should restore building focus after placement")

func test_room_flow_panels_are_bottom_sheets() -> void:
	var app_panel_source := FileAccess.get_file_as_string("res://scripts/ui/AppPanel.gd")
	assert_false(app_panel_source.contains("func use_bottom_sheet"), "AppPanel should not position flow panels at runtime")
	for path in [
		"res://scenes/ui/RoomPanel.tscn",
		"res://scenes/ui/FurnitureShopPanel.tscn",
		"res://scenes/ui/TenantPanel.tscn",
		"res://scenes/ui/BuildConfirmPopup.tscn"
	]:
		var scene_source := FileAccess.get_file_as_string(path)
		assert_true(scene_source.contains("anchors_preset = 12"), "%s should keep the apartment visible as an editor-authored bottom sheet" % path)
		assert_true(scene_source.contains("anchor_top = 1.0"), "%s should anchor to the bottom edge in the scene" % path)
		assert_true(scene_source.contains("offset_bottom = -10.0"), "%s should keep its bottom margin in the scene" % path)
	for path in [
		"res://scenes/ui/OfflineRewardPopup.tscn",
		"res://scenes/ui/RecycleConfirmPopup.tscn"
	]:
		var scene_source := FileAccess.get_file_as_string(path)
		assert_true(scene_source.contains("anchors_preset = 8"), "%s should keep centered popup layout in the scene" % path)

func test_furniture_in_room_supports_scene_long_press_move() -> void:
	var furniture_scene := FileAccess.get_file_as_string("res://scenes/furniture/Furniture.tscn")
	var preview_scene := FileAccess.get_file_as_string("res://scenes/furniture/FurniturePreview.tscn")
	var furniture_source := FileAccess.get_file_as_string("res://scripts/furniture/Furniture.gd")
	var preview_source := FileAccess.get_file_as_string("res://scripts/furniture/FurniturePreview.gd")
	var room_source := FileAccess.get_file_as_string("res://scripts/building/Room.gd")
	assert_true(furniture_source.contains("LONG_PRESS_SECONDS"), "Furniture should expose a long-press operation affordance")
	assert_true(furniture_source.contains("UIManager.start_move_existing"), "Long-pressing furniture in the room should enter move mode")
	assert_true(furniture_scene.contains("mouse_filter = 0"), "Furniture input priority should be authored in Furniture.tscn")
	assert_true(furniture_scene.contains("stretch_mode = 5"), "Furniture texture stretch should be authored in Furniture.tscn")
	assert_true(furniture_scene.contains("pivot_offset = Vector2(13, 13)"), "Furniture pivot should be authored in Furniture.tscn")
	assert_true(furniture_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "Furniture fallback tooltip copy should be authored as scene text")
	assert_true(furniture_scene.contains("[node name=\"FallbackFurnitureName\" type=\"Label\""), "Furniture should expose fallback tooltip text in Furniture.tscn")
	assert_true(preview_scene.contains("pivot_offset = Vector2(28, 28)"), "FurniturePreview pivot should be authored in FurniturePreview.tscn")
	assert_false(furniture_source.contains("@export"), "Furniture should not require script exports for scene-authored presentation")
	assert_false(preview_source.contains("@export"), "FurniturePreview should not require script exports for scene-authored presentation")
	assert_false(furniture_source.contains("override_configured_asset"), "Furniture should use configured asset data instead of script-level visual overrides")
	assert_false(preview_source.contains("override_configured_asset"), "FurniturePreview should use configured asset data instead of script-level visual overrides")
	assert_false(furniture_source.contains("custom_minimum_size ="), "Furniture fixed size should stay in Furniture.tscn")
	assert_false(furniture_source.contains("stretch_mode ="), "Furniture stretch mode should stay in Furniture.tscn")
	assert_false(furniture_source.contains("pivot_offset ="), "Furniture pivot should stay in Furniture.tscn")
	assert_false(furniture_source.contains("\"家具\""), "Furniture fallback tooltip copy should not be hard-coded in script")
	assert_true(room_source.contains("view_data[\"room_id\"] = room_id"), "Room should bind furniture visuals back to their room")
	assert_true(room_source.contains("_asset_region_size"), "Furniture visuals should preserve atlas-region proportions")

func test_tenant_uses_need_bubble_scene_and_animation_placeholder() -> void:
	var tenant_scene := FileAccess.get_file_as_string("res://scenes/tenant/Tenant.tscn")
	var tenant_source := FileAccess.get_file_as_string("res://scripts/tenant/Tenant.gd")
	var room_source := FileAccess.get_file_as_string("res://scripts/building/Room.gd")
	var need_bubble_scene := FileAccess.get_file_as_string("res://scenes/tenant/NeedBubble.tscn")
	var need_bubble_source := FileAccess.get_file_as_string("res://scripts/tenant/NeedBubble.gd")
	var emote_scene := FileAccess.get_file_as_string("res://scenes/tenant/TenantEmote.tscn")
	var emote_source := FileAccess.get_file_as_string("res://scripts/tenant/TenantEmote.gd")
	assert_true(tenant_scene.contains("AnimatedSprite2D"), "Tenant should reserve AnimatedSprite2D for future spritesheets")
	assert_true(tenant_scene.contains("NeedBubble.tscn"), "Tenant should instance the reusable NeedBubble scene")
	assert_true(tenant_scene.contains("custom_minimum_size = Vector2(64, 92)"), "Tenant preview size should be authored in Tenant.tscn")
	assert_true(tenant_scene.contains("mouse_filter = 0"), "Tenant click priority should be authored in Tenant.tscn")
	assert_true(tenant_scene.contains("focus_mode = 2"), "Tenant focus behavior should be authored in Tenant.tscn")
	assert_true(tenant_scene.contains("position = Vector2(20, 76)"), "Tenant avatar position should be authored in Tenant.tscn")
	assert_true(tenant_scene.contains("scale = Vector2(1.5, 1.5)"), "Tenant avatar scale should be authored in Tenant.tscn")
	assert_true(tenant_scene.contains("custom_minimum_size = Vector2(36, 48)"), "Tenant fallback visual size should be authored in Tenant.tscn")
	assert_true(tenant_scene.contains("sprite_frames = SubResource"), "Tenant avatar frames should be prebuilt on AvatarSprite in Tenant.tscn")
	assert_true(tenant_scene.contains("\"name\": &\"walk\""), "Tenant.tscn should prebuild a walk animation on AvatarSprite")
	assert_true(tenant_scene.contains("BehaviorAnimationMap"), "Tenant behavior-to-animation bindings should be authored in Tenant.tscn")
	assert_true(tenant_scene.contains("metadata/default_avatar_animation = \"idle\""), "Tenant default avatar animation should be scene metadata")
	assert_true(tenant_scene.contains("metadata/avatar_animation = \"walk\""), "Tenant walk animation binding should be scene metadata")
	assert_true(tenant_scene.contains("metadata/moves = true"), "Tenant wander movement should be scene-authored behavior metadata")
	assert_true(need_bubble_scene.contains("[node name=\"NeedBubble\" type=\"Control\"]"), "NeedBubble should be a previewable Control scene")
	assert_true(need_bubble_scene.contains("BubbleAnimation\" type=\"AnimatedSprite2D\""), "NeedBubble should reserve an AnimatedSprite2D bubble node")
	assert_true(need_bubble_scene.contains("IconRoot"), "NeedBubble should expose an icon root in the scene")
	assert_true(need_bubble_scene.contains("SleepIcon"), "NeedBubble should expose behavior icon nodes in the scene")
	assert_true(need_bubble_scene.contains("metadata/behavior_key = \"sleep\""), "NeedBubble behavior icons should be bound through scene metadata")
	assert_true(need_bubble_scene.contains("metadata/behavior_keys = \"relax,happy\""), "NeedBubble shared icons should be bound through scene metadata")
	assert_true(emote_scene.contains("[node name=\"TenantEmote\" type=\"Control\"]"), "TenantEmote should be a previewable Control scene")
	assert_true(emote_scene.contains("EmoteAnimation\" type=\"AnimatedSprite2D\""), "TenantEmote should reserve an AnimatedSprite2D emote node")
	assert_true(emote_scene.contains("IconRoot"), "TenantEmote should expose an icon root in the scene")
	assert_true(emote_scene.contains("HappyIcon"), "TenantEmote should expose emote icon nodes in the scene")
	assert_true(emote_scene.contains("metadata/emote_key = \"happy\""), "TenantEmote icons should be bound through scene metadata")
	assert_true(tenant_source.contains("need_bubble.show_behavior"), "Tenant behavior bubble should be delegated to NeedBubble")
	assert_true(tenant_source.contains("UIManager.open_tenant_panel"), "Clicking an in-room tenant should open tenant context")
	assert_true(tenant_source.contains("_play_avatar_animation"), "Tenant should actively play the behavior animation")
	assert_true(tenant_source.contains("GameEvents.tenant_behavior_observed.connect"), "Tenant animation should refresh when behavior changes")
	assert_false(tenant_scene.contains("behavior_animation_map = {"), "Tenant.tscn should not keep script-exported behavior animation config")
	assert_false(tenant_source.contains("BEHAVIOR_ANIMATION"), "Tenant behavior animation bindings should stay in Tenant.tscn metadata")
	assert_false(tenant_source.contains("@export"), "Tenant should not expose avatar frame or animation config in script")
	assert_false(tenant_source.contains("AssetResolver"), "Tenant should not rebuild AvatarSprite frames from data at runtime")
	assert_false(tenant_source.contains("_avatar_asset_from_config"), "Tenant should rely on scene-authored AvatarSprite frames")
	assert_false(tenant_source.contains("_frame_entries"), "Tenant should not generate animation frame entries in script")
	assert_false(tenant_source.contains("@export var avatar_scale"), "Tenant fixed avatar scale should stay in Tenant.tscn")
	assert_false(tenant_source.contains("set_avatar_scale"), "Rooms should not tune tenant visual layout at runtime")
	assert_false(tenant_source.contains("custom_minimum_size ="), "Tenant fixed size should stay in Tenant.tscn")
	assert_false(tenant_source.contains("mouse_filter ="), "Tenant mouse filtering should stay in Tenant.tscn")
	assert_false(tenant_source.contains("focus_mode ="), "Tenant focus mode should stay in Tenant.tscn")
	assert_false(tenant_source.contains("need_bubble.position"), "NeedBubble placement should stay in NeedBubble.tscn")
	assert_false(tenant_source.contains("睡觉"), "Tenant behavior labels should not be hard-coded in script")
	assert_false(need_bubble_scene.contains("bubble_text_by_behavior = {"), "NeedBubble should use scene-authored icon nodes instead of exported text dictionaries")
	assert_false(need_bubble_source.contains("@export"), "NeedBubble should not require script-level exported bubble text configuration")
	assert_false(need_bubble_source.contains("BEHAVIOR_ICON_NODE"), "NeedBubble behavior icon bindings should stay in scene metadata")
	assert_false(need_bubble_source.contains("BUBBLE_ANIMATION"), "NeedBubble animation selection should stay on the AnimatedSprite2D node")
	assert_false(need_bubble_source.contains("睡觉"), "NeedBubble should not keep display behavior names in script")
	assert_false(need_bubble_source.contains("学习/工作"), "NeedBubble display text should stay in NeedBubble.tscn")
	assert_false(emote_scene.contains("[node name=\"TenantEmote\" type=\"Label\"]"), "TenantEmote should not be a text-only label scene")
	assert_false(emote_source.contains("extends Label"), "TenantEmote should not render text directly")
	assert_false(emote_source.contains("@export"), "TenantEmote should not require script-level exported visual configuration")
	assert_false(emote_source.contains("EMOTE_ICON_NODE"), "TenantEmote icon bindings should stay in scene metadata")
	assert_false(emote_source.contains("EMOTE_ANIMATION"), "TenantEmote animation selection should stay on the AnimatedSprite2D node")
	assert_false(room_source.contains("set_avatar_scale"), "Room should only position tenant scenes, not rewrite their internal visual layout")
	assert_false(need_bubble_source.contains("mouse_filter ="), "NeedBubble fixed interaction settings should stay in NeedBubble.tscn")
	assert_false(emote_source.contains("mouse_filter ="), "TenantEmote fixed interaction settings should stay in TenantEmote.tscn")

func test_tenant_behavior_state_uses_keys_with_alias_config() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	var main_source := FileAccess.get_file_as_string("res://scenes/main/Main.gd")
	var config_source := FileAccess.get_file_as_string("res://scripts/autoload/ConfigManager.gd")
	var alias_config := FileAccess.get_file_as_string("res://data/behavior_aliases.json")
	assert_true(config_source.contains("behavior_aliases"), "ConfigManager should load behavior aliases for old save compatibility")
	assert_true(alias_config.contains("\"睡觉\": \"sleep\""), "Behavior aliases should migrate old display labels to behavior keys")
	assert_true(game_state_source.contains("DEFAULT_TENANT_BEHAVIOR := \"wander\""), "GameState should store behavior keys, not display labels")
	assert_true(game_state_source.contains("_need_to_behavior_key"), "Need updates should resolve to behavior keys")
	assert_true(main_source.contains("GameState.IDLE_TENANT_BEHAVIOR"), "Main AI fallback should set a behavior key")
	assert_false(game_state_source.contains("\"闲逛\""), "GameState should not hard-code display behavior labels")
	assert_false(game_state_source.contains("\"入住\""), "GameState should not hard-code recruited display labels")
	assert_false(main_source.contains("\"发呆\""), "Main should not write display behavior labels into state")

func test_coin_gain_sources_are_wired_to_recorded_signal() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	var top_bar_source := FileAccess.get_file_as_string("res://scripts/ui/TopStatusBar.gd")
	assert_true(game_state_source.contains("coin_gain_recorded.emit(amount, source)"), "coin gains should emit a source-aware signal")
	assert_true(top_bar_source.contains("source == \"auto_income\""), "top bar popup should only merge automatic income")

func test_region_rent_limit_blocks_expensive_candidates() -> void:
	var affordable_region := _region_data("region_affordable")
	var expected_rent: float = _calculate_room_rent("tenant_student_01", 100, 60)
	assert_true(expected_rent > float(affordable_region.get("max_rent_per_minute", 0.0)), "starter region should reject candidates whose expected rent exceeds its cap")

func test_building_view_zoom_uses_map_root() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/building/BuildingView.tscn")
	var script_text := FileAccess.get_file_as_string("res://scripts/building/BuildingView.gd")
	assert_true(scene_text.contains("WorldClip"), "BuildingView should clip a fixed map viewport")
	assert_true(scene_text.contains("SubViewportContainer"), "BuildingView should render the world in a dedicated viewport")
	assert_true(scene_text.contains("SubViewport"), "BuildingView should keep camera transforms inside the world viewport")
	assert_true(scene_text.contains("Camera2D"), "BuildingView should use Camera2D for map zoom and pan")
	assert_true(scene_text.contains("WorldRoot"), "BuildingView should keep backdrop and apartment under a shared world root")
	assert_true(scene_text.contains("stretch = true"), "SubViewportContainer should fill the BuildingView area")
	assert_true(scene_text.contains("stretch_shrink = 1"), "BuildingView should not add another scale layer over the project viewport")
	assert_true(scene_text.contains("mouse_filter = 1"), "BuildingView input pass-through should be authored in the scene")
	assert_true(scene_text.contains("size = Vector2i(360, 640)"), "BuildingView should preview the same 360x640 logical viewport as the project")
	assert_true(script_text.contains("world_camera.zoom"), "Zoom buttons and gestures should update Camera2D.zoom")
	assert_true(script_text.contains("world_root.scale = Vector2.ONE"), "WorldRoot should stay unscaled while Camera2D handles zoom")
	assert_false(script_text.contains("mouse_filter ="), "BuildingView should keep fixed mouse filtering in the scene")
	assert_false(script_text.contains("world_clip.stretch ="), "BuildingView should keep SubViewportContainer stretch in the scene")
	assert_false(script_text.contains("world_clip.stretch_shrink ="), "BuildingView should keep SubViewportContainer stretch shrink in the scene")
	assert_false(script_text.contains("world_root.scale = Vector2.ONE * zoom_scale"), "BuildingView should not zoom by scaling the world root")
	assert_false(script_text.contains("building_root.scale = Vector2.ONE * zoom_scale"), "building should not zoom independently from the background")
	assert_false(scene_text.contains("ScrollContainer"), "BuildingView should pan the map root instead of relying on a UI scroll container")
	assert_true(script_text.contains("DEFAULT_MAP_SIZE: Vector2 = Vector2(360.0, 640.0)"), "Backdrop coverage should be calculated in the 360x640 logical design canvas")
	assert_true(script_text.contains("RENDER_PIXEL_SCALE: float = 1.0"), "Screen-to-world input should stay aligned with the 360x640 world coverage")
	assert_true(script_text.contains("APARTMENT_WORLD_SCALE: float = 1.0"), "Apartment art should share the same design-canvas coordinate system as the background")
	assert_false(script_text.contains("_sync_viewport_size"), "BuildingView should not resize the SubViewport at runtime")
	assert_false(script_text.contains("world_viewport.size ="), "BuildingView should keep SubViewport coverage authored in the scene")
	assert_false(script_text.contains("_calculate_world_base_size"), "BuildingView should not dynamically expand map coverage to fit content")
	assert_true(script_text.contains("world_base_size = DEFAULT_MAP_SIZE"), "BuildingView camera bounds should use the fixed project-sized map coverage")
	assert_true(script_text.contains("_pan_camera"), "BuildingView should pan through the camera")
	assert_true(script_text.contains("screen_to_world_position"), "Placement should convert overlay screen taps through the camera")

func test_pixel_space_assets_are_configured_for_mvp_surfaces() -> void:
	var project_settings := FileAccess.get_file_as_string("res://project.godot")
	assert_true(project_settings.contains("textures/canvas_textures/default_texture_filter=0"), "pixel art should use nearest filtering by default")
	assert_true(project_settings.contains("window/size/viewport_width=360"), "Project should use a 360px logical portrait design width for 16px pixel art")
	assert_true(project_settings.contains("window/size/viewport_height=640"), "Project should use a 640px logical portrait design height for 16px pixel art")
	assert_true(project_settings.contains("window/size/window_width_override=720"), "Desktop preview should open at 2x portrait width")
	assert_true(project_settings.contains("window/size/window_height_override=1280"), "Desktop preview should open at 2x portrait height")
	assert_true(project_settings.contains("window/stretch/mode=\"viewport\""), "Pixel art should be upscaled from the logical viewport instead of resizing nodes")
	assert_true(project_settings.contains("window/stretch/aspect=\"keep_width\""), "Mobile portrait scaling should keep the design width so world art does not shrink on tall screens")
	for item in furniture:
		var furniture_data: Dictionary = item
		assert_false(str(furniture_data.get("asset", {}).get("type", "placeholder")) == "placeholder", "%s should use a Pixel Spaces visual asset" % furniture_data.get("id", ""))
		assert_true(_asset_texture_exists(furniture_data.get("asset", {})), "%s furniture asset texture should exist" % furniture_data.get("id", ""))
	for tenant in tenants:
		var tenant_data: Dictionary = tenant
		var asset: Dictionary = tenant_data.get("asset", {})
		assert_eq(str(asset.get("type", "")), "spritesheet_animation", "%s should use sprite animations" % tenant_data.get("id", ""))
		assert_true(_asset_texture_exists(asset), "%s tenant spritesheet should exist" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("move"), "%s should expose move animation" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("idle"), "%s should expose idle animation" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("jump"), "%s should expose jump animation" % tenant_data.get("id", ""))
	for room in rooms:
		var room_data: Dictionary = room
		assert_true(_asset_texture_exists(room_data.get("wall_asset", {})), "%s wall asset should exist" % room_data.get("id", ""))
		assert_true(_asset_texture_exists(room_data.get("floor_asset", {})), "%s floor asset should exist" % room_data.get("id", ""))
	for floor in floors:
		var floor_data: Dictionary = floor
		assert_true(_asset_texture_exists(floor_data.get("floor_icon_asset", {})), "%dF icon asset should exist" % int(floor_data.get("floor_index", 0)))
		assert_true(_asset_texture_exists(floor_data.get("build_icon_asset", {})), "%dF build icon should exist" % int(floor_data.get("floor_index", 0)))
	var ui_scenes := FileAccess.get_file_as_string("res://scenes/ui/FloatingMenu.tscn") + FileAccess.get_file_as_string("res://scenes/ui/TopStatusBar.tscn")
	assert_true(ui_scenes.contains("res://assets/pixel_spaces/icons/"), "core UI scenes should reference Pixel Spaces icons")

func _panel_scene_paths() -> Array[String]:
	return [
		"res://scenes/ui/RoomPanel.tscn",
		"res://scenes/ui/FurnitureShopPanel.tscn",
		"res://scenes/ui/TenantPanel.tscn",
		"res://scenes/ui/BuildConfirmPopup.tscn",
		"res://scenes/ui/ApartmentOverviewPanel.tscn",
		"res://scenes/ui/IncomeDetailPanel.tscn",
		"res://scenes/ui/RentDetailPanel.tscn",
		"res://scenes/ui/TaskPanel.tscn",
		"res://scenes/ui/RewardPanel.tscn",
		"res://scenes/ui/SettingsPanel.tscn",
		"res://scenes/ui/OfflineRewardPopup.tscn"
	]

func _app_panel_scene_paths() -> Array[String]:
	return [
		"res://scenes/ui/RoomPanel.tscn",
		"res://scenes/ui/FurnitureShopPanel.tscn",
		"res://scenes/ui/TenantPanel.tscn",
		"res://scenes/ui/BuildConfirmPopup.tscn",
		"res://scenes/ui/ApartmentOverviewPanel.tscn",
		"res://scenes/ui/IncomeDetailPanel.tscn",
		"res://scenes/ui/RentDetailPanel.tscn",
		"res://scenes/ui/TaskPanel.tscn",
		"res://scenes/ui/RewardPanel.tscn",
		"res://scenes/ui/SettingsPanel.tscn",
		"res://scenes/ui/OfflineRewardPopup.tscn",
		"res://scenes/ui/RecycleConfirmPopup.tscn"
	]

func _support_scene_paths() -> Array[String]:
	return [
		"res://scenes/ui/PlacementOverlay.tscn",
		"res://scenes/ui/PopupLayer.tscn",
		"res://scenes/effects/FloatingCoinText.tscn",
		"res://scenes/furniture/FurniturePreview.tscn",
		"res://scenes/furniture/FurnitureFloatingControls.tscn",
		"res://scenes/tenant/Tenant.tscn",
		"res://scenes/tenant/NeedBubble.tscn",
		"res://scenes/tenant/TenantEmote.tscn",
		"res://scenes/ui/ProgressCard.tscn",
		"res://scenes/ui/TaskItemRow.tscn",
		"res://scenes/ui/FurnitureShopItemRow.tscn",
		"res://scenes/ui/RoomFurnitureItemRow.tscn",
		"res://scenes/ui/RentRoomRow.tscn",
		"res://scenes/ui/FloorOverviewRow.tscn",
		"res://scenes/ui/TenantOverviewRow.tscn"
	]

func _ui_script_paths() -> Array[String]:
	return [
		"res://scripts/ui/AppPanel.gd",
		"res://scripts/ui/ApartmentOverviewPanel.gd",
		"res://scripts/ui/BuildConfirmPopup.gd",
		"res://scripts/ui/FloatingMenu.gd",
		"res://scripts/ui/FurnitureShopItemRow.gd",
		"res://scripts/ui/FurnitureShopPanel.gd",
		"res://scripts/ui/FloorOverviewRow.gd",
		"res://scripts/ui/IconActionRow.gd",
		"res://scripts/ui/IconInfoRow.gd",
		"res://scripts/ui/IncomeDetailPanel.gd",
		"res://scripts/ui/OfflineRewardPopup.gd",
		"res://scripts/ui/PanelActionButton.gd",
		"res://scripts/ui/PanelTabButton.gd",
		"res://scripts/ui/PlacementOverlay.gd",
		"res://scripts/ui/PopupLayer.gd",
		"res://scripts/ui/ProgressCard.gd",
		"res://scripts/ui/RecycleConfirmPopup.gd",
		"res://scripts/ui/RentDetailPanel.gd",
		"res://scripts/ui/RentRoomRow.gd",
		"res://scripts/ui/RewardPanel.gd",
		"res://scripts/ui/RoomFurnitureItemRow.gd",
		"res://scripts/ui/RoomPanel.gd",
		"res://scripts/ui/SettingsPanel.gd",
		"res://scripts/ui/StatCard.gd",
		"res://scripts/ui/TaskPanel.gd",
		"res://scripts/ui/TaskItemRow.gd",
		"res://scripts/ui/TenantPanel.gd",
		"res://scripts/ui/TenantOverviewRow.gd",
		"res://scripts/ui/TopStatusBar.gd",
		"res://scripts/ui/UIPanelFactory.gd"
	]

func _presentation_script_paths() -> Array[String]:
	var paths := _ui_script_paths()
	paths.append_array([
		"res://scripts/effects/FloatingCoinText.gd",
		"res://scripts/furniture/Furniture.gd",
		"res://scripts/furniture/FurniturePreview.gd",
		"res://scripts/tenant/Tenant.gd",
		"res://scripts/tenant/NeedBubble.gd",
		"res://scripts/tenant/TenantEmote.gd"
	])
	return paths

func _calculate_room_rent(tenant_id: String, score: int, satisfaction: int) -> float:
	if tenant_id.is_empty():
		return 0.0
	var tenant: Dictionary = _tenant_data(tenant_id)
	var base_rent: float = float(economy.get("base_rent", 10.0))
	var score_factor: float = float(economy.get("score_rent_factor", 0.5))
	return (base_rent + float(score) * score_factor) * float(tenant.get("pay_multiplier", 1.0)) * _satisfaction_multiplier(satisfaction)

func _satisfaction_multiplier(value: int) -> float:
	if value <= 30:
		return 0.7
	if value <= 60:
		return 1.0
	if value <= 80:
		return 1.15
	return 1.3

func _tenant_data(tenant_id: String) -> Dictionary:
	for tenant in tenants:
		var tenant_data: Dictionary = tenant
		if str(tenant_data.get("id", "")) == tenant_id:
			return tenant_data
	return {}

func _unlocked_region_ids(apartment_level: int) -> Array:
	var ids: Array = []
	for region in regions:
		var region_data: Dictionary = region
		if apartment_level >= int(region_data.get("required_apartment_level", 1)):
			ids.append(str(region_data.get("id", "")))
	return ids

func _region_tenant_ids(region_id: String) -> Array:
	for region in regions:
		var region_data: Dictionary = region
		if str(region_data.get("id", "")) == region_id:
			return region_data.get("tenant_ids", [])
	return []

func _region_data(region_id: String) -> Dictionary:
	for region in regions:
		var region_data: Dictionary = region
		if str(region_data.get("id", "")) == region_id:
			return region_data
	return {}

func _floor_data(floor_index: int) -> Dictionary:
	for floor in floors:
		var floor_data: Dictionary = floor
		if int(floor_data.get("floor_index", 0)) == floor_index:
			return floor_data
	return {}

func _room_ids_on_floor(floor_index: int) -> Array:
	var ids: Array = []
	for room in rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) == floor_index:
			ids.append(str(room_data.get("id", "")))
	return ids

func _asset_texture_exists(asset: Dictionary) -> bool:
	var path := str(asset.get("texture", ""))
	return not path.is_empty() and FileAccess.file_exists(path)

func _load_json_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

func _load_json_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
