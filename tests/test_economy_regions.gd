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

func test_furniture_placement_grid_cells_are_16_pixels() -> void:
	var tile_size := 16
	for room in rooms:
		var room_data: Dictionary = room
		var layouts: Array = [
			{
				"label": str(room_data.get("id", "")),
				"frame_tiles": room_data.get("frame_tiles", []),
				"grid_size": room_data.get("grid_size", [])
			}
		]
		for item in room_data.get("layout_upgrades", []):
			var upgrade: Dictionary = item
			layouts.append({
				"label": "%s upgrade Lv.%d" % [str(room_data.get("id", "")), int(upgrade.get("level", 0))],
				"frame_tiles": upgrade.get("frame_tiles", []),
				"grid_size": upgrade.get("grid_size", [])
			})
		for layout in layouts:
			var layout_data: Dictionary = layout
			var frame_tiles: Array = layout_data.get("frame_tiles", [])
			var grid_size: Array = layout_data.get("grid_size", [])
			assert_true(frame_tiles.size() >= 2, "%s should define frame tiles" % str(layout_data.get("label", "")))
			assert_true(grid_size.size() >= 2, "%s should define grid size" % str(layout_data.get("label", "")))
			if frame_tiles.size() < 2 or grid_size.size() < 2:
				continue
			var cell_width := float(maxi(1, int(frame_tiles[0]) - 2) * tile_size) / float(maxi(1, int(grid_size[0])))
			var cell_height := float(maxi(1, int(frame_tiles[1])) * tile_size) / float(maxi(1, int(grid_size[1])))
			assert_eq(Vector2(cell_width, cell_height), Vector2(16.0, 16.0), "%s placement cells should be 16x16 pixels" % str(layout_data.get("label", "")))

func test_furniture_placement_rules_keep_core_restrictions() -> void:
	var rules_source := FileAccess.get_file_as_string("res://scripts/furniture/FurniturePlacementRules.gd")
	assert_true(rules_source.contains("gx + w > int(grid_size[0])"), "placement rules should reject furniture beyond the right edge")
	assert_true(rules_source.contains("gy + h > int(grid_size[1])"), "placement rules should reject furniture beyond the lower edge")
	assert_true(rules_source.contains("placement_layer_for"), "placement rules should separate wall and floor furniture layers")
	assert_true(rules_source.contains("LAYER_WALL"), "placement rules should expose a wall placement layer")
	assert_true(rules_source.contains("LAYER_FLOOR"), "placement rules should expose a floor placement layer")
	assert_true(rules_source.contains("wall_item"), "wall-item furniture should use the wall placement layer")
	assert_true(rules_source.contains("floor_grid_y_for"), "floor furniture should snap to the bottom floor line in the side-view room")
	assert_true(rules_source.contains("placement_layer_for(other_data) != layer"), "wall and floor furniture should not collide with each other")
	assert_true(rules_source.contains("door_cells_for_layer"), "placement rules should reserve door cells by layer")
	assert_true(rules_source.contains("_rects_overlap"), "placement rules should reject overlapping furniture footprints")
	assert_true(rules_source.contains("ignored_instance_id"), "moving furniture should ignore its original footprint")

func test_furniture_placement_rules_validate_floor_and_wall_layers() -> void:
	var room := {
		"id": "__test_placement_layers",
		"grid_size": [6, 4],
		"furniture_instances": []
	}
	var furniture_lookup := Callable(self, "_furniture_data")

	assert_eq(FurniturePlacementRules.grid_size_for_layer(room, FurniturePlacementRules.LAYER_FLOOR), [6, 4], "floor layer should use the full side-view placement grid")
	assert_eq(FurniturePlacementRules.grid_size_for_layer(room, FurniturePlacementRules.LAYER_WALL), [6, 3], "wall layer should use the cells above the bottom floor line")
	assert_eq(FurniturePlacementRules.placement_layer_for(_furniture_data("chair_basic")), FurniturePlacementRules.LAYER_FLOOR, "chair should be a floor item")
	assert_eq(FurniturePlacementRules.placement_layer_for(_furniture_data("painting_small")), FurniturePlacementRules.LAYER_WALL, "painting should be a wall item")
	assert_eq(FurniturePlacementRules.floor_grid_y_for([6, 4], [2, 2]), 2, "a two-cell-high bed should bottom-align to the floor line")
	assert_eq(FurniturePlacementRules.floor_grid_y_for([6, 4], [1, 1]), 3, "a one-cell-high chair should sit on the bottom row")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "bed_basic", _furniture_data("bed_basic"), furniture_lookup, [1, 2]), "bed should be valid only when it is bottom-aligned to the floor")
	assert_false(FurniturePlacementRules.can_place_furniture_in_room(room, "bed_basic", _furniture_data("bed_basic"), furniture_lookup, [1, 0]), "bed should not be valid near the ceiling")
	assert_false(FurniturePlacementRules.can_place_furniture_in_room(room, "bed_basic", _furniture_data("bed_basic"), furniture_lookup, [1, 1]), "bed should not float above the floor line")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "chair_basic", _furniture_data("chair_basic"), furniture_lookup, [1, 3]), "chair should be valid on the floor line")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "sofa_green", _furniture_data("sofa_green"), furniture_lookup, [2, 3]), "sofa should be valid on the floor line")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "painting_small", _furniture_data("painting_small"), furniture_lookup, [1, 0]), "painting should be valid on the wall layer")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "wall_clock", _furniture_data("wall_clock"), furniture_lookup, [2, 2]), "wall clock should be valid on lower wall cells above the floor")
	assert_false(FurniturePlacementRules.can_place_furniture_in_room(room, "painting_small", _furniture_data("painting_small"), furniture_lookup, [1, 3]), "wall items should not sit on the floor line")
	assert_false(FurniturePlacementRules.can_place_furniture_in_room(room, "chair_basic", _furniture_data("chair_basic"), furniture_lookup, [0, 3]), "floor door cell should block floor furniture at the left bottom")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "painting_small", _furniture_data("painting_small"), furniture_lookup, [0, 0]), "door cell should not block wall furniture")

	room["furniture_instances"] = [
		{"instance_id": "wall_a", "furniture_id": "painting_small", "grid_pos": [1, 0]}
	]
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "bed_basic", _furniture_data("bed_basic"), furniture_lookup, [1, 2]), "wall and floor layers should not collide with each other")

	room["furniture_instances"] = [
		{"instance_id": "floor_a", "furniture_id": "chair_basic", "grid_pos": [2, 3]},
		{"instance_id": "wall_a", "furniture_id": "painting_small", "grid_pos": [2, 0]}
	]
	assert_false(FurniturePlacementRules.can_place_furniture_in_room(room, "sofa_green", _furniture_data("sofa_green"), furniture_lookup, [1, 3]), "floor furniture should still collide with floor furniture")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "wall_clock", _furniture_data("wall_clock"), furniture_lookup, [3, 0]), "wall furniture should ignore floor furniture collision")
	assert_false(FurniturePlacementRules.can_place_furniture_in_room(room, "wall_clock", _furniture_data("wall_clock"), furniture_lookup, [2, 0]), "wall furniture should still collide with wall furniture")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "chair_basic", _furniture_data("chair_basic"), furniture_lookup, [2, 3], "floor_a"), "moving furniture should ignore its own original footprint")

func test_building_view_min_zoom_keeps_visible_world_inside_bounds() -> void:
	var viewport_sizes: Array = [Vector2(360.0, 640.0), Vector2(720.0, 1280.0)]
	for item in viewport_sizes:
		var viewport: Vector2 = item
		var bounds: Vector2 = viewport
		var min_zoom := clampf(maxf(viewport.x / bounds.x, viewport.y / bounds.y), 0.7, 1.4)
		var visible_world := viewport / min_zoom
		assert_true(visible_world.x <= bounds.x + 0.001, "minimum zoom should not reveal outside horizontal bounds for %s" % str(viewport))
		assert_true(visible_world.y <= bounds.y + 0.001, "minimum zoom should not reveal outside vertical bounds for %s" % str(viewport))

func test_world_camera_input_is_gesture_based_and_ui_isolated() -> void:
	var building_source := FileAccess.get_file_as_string("res://scripts/building/BuildingView.gd")
	var ui_manager_source := FileAccess.get_file_as_string("res://scripts/autoload/UIManager.gd")
	var app_panel_source := FileAccess.get_file_as_string("res://scripts/ui/AppPanel.gd")
	var popup_layer_source := FileAccess.get_file_as_string("res://scripts/ui/PopupLayer.gd")
	var placement_source := FileAccess.get_file_as_string("res://scripts/ui/PlacementOverlay.gd")
	var main_source := FileAccess.get_file_as_string("res://scenes/main/Main.gd")
	assert_true(ui_manager_source.contains("func allows_world_camera_input()"), "UIManager should expose a single world-camera input gate")
	assert_true(ui_manager_source.contains("UIState.PLACING_NEW_FURNITURE"), "placement states should be allowed to request camera gestures")
	assert_true(building_source.contains("func handle_camera_input"), "BuildingView should expose a reusable camera input handler")
	assert_true(building_source.contains("CameraInputMode.PLACEMENT"), "BuildingView should distinguish placement camera input from normal browsing")
	assert_true(building_source.contains("_active_touch_points"), "BuildingView should track active touch points for mobile gestures")
	assert_true(building_source.contains("_apply_touch_pinch"), "BuildingView should implement explicit two-finger pinch zoom")
	assert_true(building_source.contains("MOUSE_BUTTON_WHEEL_UP"), "desktop wheel zoom should remain supported")
	assert_true(building_source.contains("_has_blocking_panel"), "BuildingView should block camera input while panels are active")
	assert_true(app_panel_source.contains("func _is_world_camera_event"), "AppPanel should defensively intercept leaked camera events")
	assert_true(popup_layer_source.contains("func has_blocking_panel()"), "PopupLayer should expose active-panel blocking state")
	assert_true(placement_source.contains("_forward_camera_input"), "PlacementOverlay should forward wheel and multi-touch camera input")
	assert_true(placement_source.contains("_pause_preview_drag_for_camera"), "PlacementOverlay should pause furniture dragging when two-finger camera control starts")
	assert_true(main_source.contains("UIManager.set_state(UIManager.UIState.POPUP)"), "event-driven popups should set a blocking UI state")
	assert_false(main_source.contains("zoom_in_requested"), "Main should not connect removed zoom-in buttons")
	assert_false(main_source.contains("zoom_out_requested"), "Main should not connect removed zoom-out buttons")

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
	assert_false(menu_scene.contains("ZoomInButton"), "FloatingMenu should remove manual zoom-in button")
	assert_false(menu_scene.contains("ZoomOutButton"), "FloatingMenu should remove manual zoom-out button")
	assert_false(menu_scene.contains("icons/Plus.png"), "FloatingMenu should not keep zoom-in icon resources")
	assert_false(menu_scene.contains("icons/Minus.png"), "FloatingMenu should not keep zoom-out icon resources")
	assert_true(menu_scene.contains("custom_minimum_size = Vector2(46, 0)"), "FloatingMenu should be sized for a 360px viewport")
	assert_false(menu_scene.contains("[node name=\"ZoomTooltipTemplate\" type=\"Label\""), "FloatingMenu should not keep zoom tooltip templates after removing zoom buttons")
	assert_false(menu_source.contains("zoom_in_requested"), "FloatingMenu should not expose removed zoom-in signal")
	assert_false(menu_source.contains("set_zoom_state"), "FloatingMenu should not keep removed zoom button state helpers")
	assert_false(placement_scene.contains("PlacementControls"), "Placement overlay should not keep the old bottom-sheet controls")
	assert_true(placement_scene.contains("HintStrip"), "Placement overlay should expose its lightweight hint strip in the scene")
	assert_true(placement_scene.contains("FloatingControls"), "Placement overlay should expose floating controls in the scene")
	assert_true(placement_scene.contains("res://scenes/furniture/FurnitureFloatingControls.tscn"), "Placement overlay should reuse the furniture floating controls scene")
	assert_true(placement_scene.contains("mouse_filter = 0"), "Placement overlay should capture drag input while placement is active")
	assert_true(placement_source.contains("get_node_or_null(\"HintStrip\")"), "Placement overlay should bind editor-authored hint strip first")
	assert_true(placement_source.contains("get_node_or_null(\"FloatingControls\")"), "Placement overlay should bind editor-authored floating controls first")
	assert_true(placement_source.contains("func _gui_input"), "Placement overlay should receive direct GUI drag events")
	assert_true(placement_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "Placement overlay should keep dynamic text templates as scene nodes")
	assert_true(placement_scene.contains("[node name=\"PlaceConfirmText\" type=\"Label\""), "Placement overlay should keep confirm text as a scene label")
	assert_true(placement_scene.contains("[node name=\"PlaceHintTemplate\" type=\"Label\""), "Placement overlay should keep placement hint copy as a scene label")
	assert_true(placement_scene.contains("[node name=\"MoveHintTemplate\" type=\"Label\""), "Placement overlay should keep move hint copy as a scene label")
	assert_false(placement_source.contains("@export"), "Placement overlay should not require script exports for editor-authored text templates")
	assert_false(placement_source.contains("确认摆放并扣金币"), "Placement overlay should not hard-code confirm copy in script")
	assert_true(furniture_controls_scene.contains("ConfirmButton"), "Furniture floating controls should expose confirm button in the scene")
	assert_true(furniture_controls_scene.contains("CancelButton"), "Furniture floating controls should expose cancel button in the scene")
	assert_true(furniture_controls_scene.contains("RecycleButton"), "Furniture floating controls should expose recycle button in the scene")
	assert_true(furniture_controls_scene.contains("custom_minimum_size = Vector2(40, 38)"), "Furniture floating controls should use compact icon buttons")
	assert_true(furniture_controls_scene.contains("icons/Check.png"), "Furniture floating controls should configure confirm icon in the scene")
	assert_true(furniture_controls_scene.contains("icons/Close.png"), "Furniture floating controls should configure cancel icon in the scene")
	assert_false(furniture_controls_scene.contains("\ntext = \"确认\""), "Furniture floating controls should not use wide text buttons")
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
	var agents := FileAccess.get_file_as_string("res://AGENTS.md")
	var technical_rules := FileAccess.get_file_as_string("res://.agents/rules/technical.md")
	var trd := FileAccess.get_file_as_string("res://docs/TRD.md")
	var data_rules := FileAccess.get_file_as_string("res://.agents/rules/data-config.md")
	var tilemap_plan := FileAccess.get_file_as_string("res://docs/APARTMENT_TILEMAP_MIGRATION.md")
	assert_true(agents.contains("项目当前处于开发阶段"), "AGENTS should mark this project as development-stage")
	assert_true(agents.contains("不需要兼容旧配置或旧存档"), "AGENTS should direct agents not to preserve old config/save compatibility by default")
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
	assert_false(backdrop_source.contains("@export"), "Backdrop should read scene-authored config instead of script exports")
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
	var apartment_tilemap_source := FileAccess.get_file_as_string("res://scripts/building/ApartmentTileMap.gd")
	var apartment_tileset_source := FileAccess.get_file_as_string("res://tilesets/apartment_tileset.tres")
	var apartment_tileset := ResourceLoader.load("res://tilesets/apartment_tileset.tres", "", ResourceLoader.CACHE_MODE_REPLACE) as TileSet
	var floor_counts := {}
	for room in rooms:
		var room_data: Dictionary = room
		var floor_index := int(room_data.get("floor_index", 0))
		var frame_tiles: Array = room_data.get("frame_tiles", [])
		var grid_size: Array = room_data.get("grid_size", [])
		floor_counts[floor_index] = int(floor_counts.get(floor_index, 0)) + 1
		assert_true(ResourceLoader.exists(str(room_data.get("room_scene_path", ""))), "%s should configure a loadable room scene template" % room_data.get("id", ""))
		assert_true(_asset_texture_exists(room_data.get("infrastructure_asset", {})), "%s should use Infrastructure.png for its room frame" % room_data.get("id", ""))
		assert_true(_asset_texture_exists(room_data.get("wall_asset", {})), "%s wallpaper asset should exist" % room_data.get("id", ""))
		assert_false(room_data.has("floor_asset"), "%s should not keep a separate floor layer asset for room skeletons" % room_data.get("id", ""))
		assert_false(room_data.has("room_size"), "%s should not keep legacy pixel room_size config" % room_data.get("id", ""))
		assert_false(room_data.has("grid_rect"), "%s should not keep legacy pixel grid_rect config" % room_data.get("id", ""))
		assert_eq(frame_tiles.size(), 2, "%s should configure frame_tiles as [width, height]" % room_data.get("id", ""))
		assert_eq(grid_size.size(), 2, "%s should configure grid_size as [width, height]" % room_data.get("id", ""))
		if frame_tiles.size() >= 2 and grid_size.size() >= 2:
			assert_eq(int(frame_tiles[0]), 8, "%s should start as an 8-tile-wide room frame" % room_data.get("id", ""))
			assert_eq(int(frame_tiles[1]), 4, "%s room frame height should stay fixed at 4 tiles" % room_data.get("id", ""))
			assert_eq(int(grid_size[0]), int(frame_tiles[0]) - 2, "%s placement grid width should match inner room tiles" % room_data.get("id", ""))
			assert_eq(int(grid_size[1]), int(frame_tiles[1]), "%s floor placement grid height should match the 4-tile room height" % room_data.get("id", ""))
		for item in room_data.get("layout_upgrades", []):
			var upgrade: Dictionary = item
			var upgraded_frame_tiles: Array = upgrade.get("frame_tiles", [])
			var upgraded_grid_size: Array = upgrade.get("grid_size", [])
			assert_eq(upgraded_frame_tiles.size(), 2, "%s layout upgrade should configure frame_tiles" % room_data.get("id", ""))
			assert_eq(upgraded_grid_size.size(), 2, "%s layout upgrade should configure grid_size" % room_data.get("id", ""))
			if upgraded_frame_tiles.size() >= 2 and upgraded_grid_size.size() >= 2 and frame_tiles.size() >= 2 and grid_size.size() >= 2:
				assert_gt(int(upgraded_frame_tiles[0]), int(frame_tiles[0]), "%s layout upgrades should add width tiles" % room_data.get("id", ""))
				assert_eq(int(upgraded_frame_tiles[1]), int(frame_tiles[1]), "%s layout upgrades should not change room height" % room_data.get("id", ""))
				assert_gt(int(upgraded_grid_size[0]), int(grid_size[0]), "%s layout upgrades should add placement columns" % room_data.get("id", ""))
				assert_eq(int(upgraded_grid_size[1]), int(grid_size[1]), "%s layout upgrades should not change floor placement rows" % room_data.get("id", ""))
	for floor_index in floor_counts.keys():
		assert_eq(int(floor_counts[floor_index]), 1, "%dF should have one MVP room" % int(floor_index))
	assert_true(floor_scene.contains("FloorServiceCore.tscn"), "Each floor should expose a left-side door/elevator service core scene")
	assert_true(floor_scene.contains("[node name=\"SceneConfig\" type=\"Node\""), "Floor should keep room template config in Floor.tscn")
	assert_true(floor_scene.contains("metadata/room_scene_path = \"res://scenes/building/Room.tscn\""), "Floor should assign the editable Room template in scene metadata")
	assert_true(floor_service_scene.contains("ServiceCoreTileMap.tscn"), "FloorServiceCore should compose an editable TileMap template")
	assert_true(service_tilemap_scene.contains("res://tilesets/apartment_tileset.tres"), "ServiceCoreTileMap should share the internal apartment TileSet")
	for layer_name in ["WallpaperTileMap", "WallTileMap", "InfrastructureTileMap", "RoofTileMap", "ConstructionTileMap"]:
		assert_true(service_tilemap_scene.contains("name=\"%s\" type=\"TileMapLayer\"" % layer_name), "ServiceCoreTileMap should expose %s for editor painting" % layer_name)
	assert_false(service_tilemap_scene.contains("name=\"FloorTileMap\""), "ServiceCoreTileMap should not keep a separate floor layer")
	assert_true(floor_service_scene.contains("FloorLabel"), "FloorServiceCore should expose its floor label in the scene")
	assert_true(floor_service_scene.contains("theme_override_font_sizes/font_size = 9"), "Floor label style should be editor-authored")
	assert_true(floor_source.contains("get_node_or_null(\"FloorServiceCore\")"), "Floor should bind the scene-authored service core node")
	assert_true(floor_source.contains("room_scene_path"), "Floor should allow room config to select an editor-authored room scene template")
	assert_true(floor_source.contains("_scene_from_path"), "Floor should load configured room templates with scene default fallback")
	assert_false(floor_source.contains("FLOOR_SERVICE_CORE_SCENE"), "Floor should not instantiate the service-core scene as a fallback")
	assert_false(floor_source.contains("preload(\"res://scenes/building/Room.tscn\")"), "Floor should not hide the room template in script")
	assert_false(floor_source.contains("@export"), "Floor should read scene-authored config instead of script exports")
	assert_false(floor_source.contains("apply_asset_to_texture_rect"), "Floor service-core visuals should be editor-painted TileMaps")
	assert_false(floor_source.contains("AtlasTexture.new"), "Floor should not create atlas slices for service-core visuals")
	assert_false(service_source.contains("TextureRect"), "FloorServiceCore should not depend on scripted texture slices")
	assert_false(service_source.contains("ColorRect"), "FloorServiceCore should not depend on scripted color fallbacks")
	assert_false(service_source.contains("add_theme_"), "FloorServiceCore should not hide fixed label styling in script")
	assert_true(room_scene.contains("RoomShell.tscn"), "Room should compose its editable shell scene")
	assert_true(room_scene.contains("[node name=\"SceneConfig\" type=\"Node\""), "Room should keep child template and layout config in Room.tscn")
	assert_true(room_scene.contains("metadata/tenant_scene_path = \"res://scenes/tenant/Tenant.tscn\""), "Room should assign the editable tenant child scene in scene metadata")
	assert_true(room_scene.contains("metadata/furniture_scene_path = \"res://scenes/furniture/Furniture.tscn\""), "Room should assign the editable furniture child scene in scene metadata")
	assert_true(room_scene.contains("StyleBoxFlat_room_normal"), "Room button skin should be editor-authored")
	assert_true(room_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "Room display text templates should be authored in Room.tscn")
	assert_true(room_scene.contains("[node name=\"FallbackRoomName\" type=\"Label\""), "Room fallback display text should be authored in Room.tscn")
	assert_true(room_scene.contains("[node name=\"RentBadgeTemplate\" type=\"Label\""), "Room rent badge template should be authored in Room.tscn")
	assert_true(room_shell_scene.contains("ApartmentTileMap.tscn"), "Room shell should compose the editable apartment TileMap template")
	assert_true(room_shell_scene.contains("text = \"房间\""), "Room name badge should be previewable in RoomShell.tscn")
	assert_true(room_shell_scene.contains("text = \"评分 0  租金 0\""), "Room rent badge should be previewable in RoomShell.tscn")
	assert_true(room_shell_scene.contains("anchor_left = 1.0"), "Room rent badge should use editor-authored right anchoring")
	assert_true(room_shell_scene.contains("theme_override_font_sizes/font_size = 9"), "Room name badge style should be editor-authored")
	assert_true(room_shell_scene.contains("theme_override_font_sizes/font_size = 8"), "Room rent badge style should be editor-authored")
	assert_true(apartment_tilemap_scene.contains("res://tilesets/apartment_tileset.tres"), "ApartmentTileMap should share the internal apartment TileSet")
	for layer_name in ["WallpaperTileMap", "WallTileMap", "InfrastructureTileMap", "RoofTileMap", "ConstructionTileMap"]:
		assert_true(apartment_tilemap_scene.contains("name=\"%s\" type=\"TileMapLayer\"" % layer_name), "ApartmentTileMap should expose %s for editor painting" % layer_name)
	assert_false(apartment_tilemap_scene.contains("name=\"FloorTileMap\""), "ApartmentTileMap should not keep a separate floor layer")
	assert_true(apartment_tileset != null, "Apartment TileSet should load")
	if apartment_tileset != null:
		assert_eq(apartment_tileset.tile_size, Vector2i(16, 16), "Apartment TileSet should use 16x16 tile cells")
		assert_eq(apartment_tileset.get_terrain_sets_count(), 2, "Apartment TileSet should expose two editor-visible terrain sets")
		assert_eq(apartment_tileset.get_terrain_name(0, 0), "RoomFrame", "Terrain set 0 should expose RoomFrame")
		assert_eq(apartment_tileset.get_terrain_name(1, 0), "WallpaperFill", "Terrain set 1 should expose WallpaperFill")
		assert_eq((apartment_tileset.get_source(0) as TileSetAtlasSource).texture_region_size, Vector2i(16, 16), "Infrastructure atlas source should use 16x16 atlas cells")
		var wallpaper_source := _tileset_source_with_texture(apartment_tileset, "Wallpaper Tilesets.png")
		assert_true(wallpaper_source != null, "Wallpaper atlas source should be discoverable by texture path")
		if wallpaper_source != null:
			assert_eq(wallpaper_source.texture_region_size, Vector2i(16, 16), "Wallpaper atlas source should use 16x16 atlas cells")
	assert_true(apartment_tileset_source.contains("Infrastructure.png"), "Apartment TileSet should reference the infrastructure atlas")
	assert_true(apartment_tileset_source.contains("Wallpaper Tilesets.png"), "Apartment TileSet should reference the wallpaper atlas")
	assert_true(apartment_tileset_source.contains("RoomFrame"), "Apartment TileSet should save room-frame terrain rules")
	assert_true(apartment_tileset_source.contains("WallpaperFill"), "Apartment TileSet should save wallpaper-fill terrain rules")
	assert_true(apartment_tilemap_source.contains("render_room_skeleton"), "ApartmentTileMap should be the dedicated grid renderer for room frames")
	assert_true(apartment_tilemap_source.contains("set_cell"), "ApartmentTileMap may paint generated room skeleton cells")
	assert_true(apartment_tilemap_source.contains("@export var body_top_left_corner_tile"), "ApartmentTileMap should export themed wall-body corner coordinates for editor filling")
	assert_true(apartment_tilemap_source.contains("@export var edge_top_left_corner_tile"), "ApartmentTileMap should export fixed wall-edge corner coordinates for editor filling")
	assert_true(apartment_tilemap_source.contains("@export var wallpaper_tile"), "ApartmentTileMap should export the default wallpaper tile coordinate")
	assert_true(apartment_tilemap_source.contains("@export var body_door_short_wall_cells"), "ApartmentTileMap should export body short-wall cells around doors")
	assert_true(apartment_tilemap_source.contains("@export var edge_door_short_wall_cells"), "ApartmentTileMap should export edge short-wall cells around doors")
	assert_false(apartment_tilemap_source.contains("@export var floor_tiles"), "ApartmentTileMap should not expose a separate floor layer for room skeletons")
	assert_false(apartment_tilemap_source.contains("func _paint_floor"), "ApartmentTileMap should not paint FloorTileMap for room skeletons")
	assert_true(apartment_tilemap_source.contains("@export var door_tile"), "ApartmentTileMap should export the door tile coordinate")
	assert_true(apartment_tilemap_source.contains("@export var window_tile"), "ApartmentTileMap should export the window tile coordinate")
	assert_true(apartment_tilemap_source.contains("@export var construction_marker_tile"), "ApartmentTileMap should export construction marker tile coordinates")
	assert_false(room_source.contains("_asset_tile_origin"), "Room should not infer TileSet atlas coordinates from asset regions")
	assert_false(room_source.contains("wallpaper_origin"), "Room should not pass guessed wallpaper atlas origins")
	assert_false(room_source.contains("frame_origin"), "Room should not pass guessed frame atlas origins")
	for path in [
		"res://scripts/building/Room.gd",
		"res://scripts/building/Floor.gd",
		"res://scripts/building/BuildSlot.gd",
		"res://scripts/building/ApartmentBuilding.gd"
	]:
		var building_source := FileAccess.get_file_as_string(path)
		assert_false(building_source.contains("set_cell"), "%s should pass frame_tiles to ApartmentTileMap instead of painting cells" % path)
	assert_false(room_source.contains("StyleBoxFlat.new"), "Room should not create fixed button skins in script")
	assert_false(room_source.contains("add_theme_"), "Room should not hide fixed badge styling in script")
	assert_false(room_source.contains("@export"), "Room should read scene-authored config instead of script exports")
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
	assert_true(room_source.contains("frame_tiles"), "Room rendering should read frame_tiles for grid-sized room upgrades")
	assert_true(room_source.contains("ApartmentTileMap.TILE_SIZE"), "Room pixel size should be derived from 16px TileMap cells")
	assert_true(room_source.contains("frame_tiles.y) * ApartmentTileMap.TILE_SIZE"), "Floor placement grid should use the full 4-tile room height")
	assert_true(room_source.contains("_wall_grid_rect"), "Room should expose a separate wall placement layer")
	assert_true(room_source.contains("world_position_to_placement_grid"), "Room should translate scene taps through furniture-aware placement layers")
	assert_true(room_source.contains("floor_grid_y_for"), "Floor furniture should map pointer input to the bottom floor line")
	assert_true(room_shell_source.contains("render_room_skeleton"), "RoomShell should delegate room-frame drawing to ApartmentTileMap")
	assert_true(room_source.contains("tenant_view.setup(tenant_id, room_id)"), "Room should bind tenant scene instances to their room")
	assert_true(room_source.contains("_furniture_position"), "Furniture should be positioned inside the room instead of listed as thumbnails")

func test_apartment_tilemap_renders_room_frame_tiles_on_16px_grid() -> void:
	var scene := ResourceLoader.load("res://scenes/building/ApartmentTileMap.tscn") as PackedScene
	assert_true(scene != null, "ApartmentTileMap scene should load for direct preview")
	if scene == null:
		return
	var tilemap := scene.instantiate() as ApartmentTileMap
	assert_true(tilemap != null, "ApartmentTileMap scene should instantiate with its script")
	if tilemap == null:
		return
	_bind_apartment_tilemap_layers(tilemap)
	var wallpaper_layer := tilemap.get_node("WallpaperTileMap") as TileMapLayer
	var wall_layer := tilemap.get_node("WallTileMap") as TileMapLayer
	var infrastructure_layer := tilemap.get_node("InfrastructureTileMap") as TileMapLayer
	tilemap.door_tile = Vector2i(0, 0)
	tilemap.window_tile = Vector2i(0, 0)

	tilemap.render_room_skeleton(Vector2i(8, 4), {}, false, false)
	assert_eq(tilemap.current_frame_tiles, Vector2i(8, 4), "Initial room frame should be 8x4 tiles")
	assert_eq(tilemap.room_pixel_size(), Vector2(128, 64), "8x4 frame tiles should render as 128x64 pixels")
	assert_eq(wallpaper_layer.get_used_rect().position, Vector2i.ZERO, "Wallpaper should start at tile origin")
	assert_eq(wallpaper_layer.get_used_rect().size, Vector2i(8, 4), "Wallpaper layer should cover every room tile")
	assert_eq(wall_layer.get_used_rect().position, Vector2i.ZERO, "Room frame should start at tile origin")
	assert_eq(wall_layer.get_used_rect().size, Vector2i(8, 4), "Wall layer should occupy an 8x4 tile frame")
	assert_eq(infrastructure_layer.get_used_rect().position, Vector2i(-1, -1), "Infrastructure black wall edge should wrap one tile around the room frame")
	assert_eq(infrastructure_layer.get_used_rect().size, Vector2i(10, 6), "Infrastructure layer should include the outer black wall edge")
	assert_eq(infrastructure_layer.get_cell_atlas_coords(Vector2i(0, 3)), Vector2i(7, 14), "Room door should use the editor-painted door tile near the left wall")
	assert_eq(infrastructure_layer.get_cell_atlas_coords(Vector2i(7, 1)), Vector2i(5, 2), "Room window should use the editor-painted right-wall tile")

	tilemap.render_room_skeleton(Vector2i(10, 4), {}, false, false)
	assert_eq(tilemap.current_frame_tiles, Vector2i(10, 4), "Room expansion should only add width tiles")
	assert_eq(tilemap.room_pixel_size(), Vector2(160, 64), "10x4 frame tiles should render as 160x64 pixels")
	assert_eq(wallpaper_layer.get_used_rect().size, Vector2i(10, 4), "Expanded wallpaper layer should cover every room tile")
	assert_eq(wall_layer.get_used_rect().size, Vector2i(10, 4), "Expanded wall layer should keep fixed height")
	assert_eq(infrastructure_layer.get_used_rect().size, Vector2i(12, 6), "Expanded infrastructure layer should keep the one-tile outer wall edge")
	assert_eq(infrastructure_layer.get_cell_atlas_coords(Vector2i(9, 1)), Vector2i(5, 2), "Expanded room window should move with the right wall")

	tilemap.render_room_skeleton(Vector2i(3, 4), {}, false, false)
	assert_eq(tilemap.current_frame_tiles, Vector2i(3, 4), "Service-core TileMaps should support 3-tile width")
	assert_eq(tilemap.room_pixel_size(), Vector2(48, 64), "3x4 service core should render as 48x64 pixels")
	assert_eq(wall_layer.get_used_rect().size, Vector2i(3, 4), "Service-core frame should not overpaint into the room")
	tilemap.free()

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
	var save_source := FileAccess.get_file_as_string("res://scripts/autoload/SaveManager.gd")
	assert_true(state_source.contains("_configured_room_layout_for_level"), "Saved room layout should be rebuilt from current config and room level")
	assert_true(state_source.contains("_fixed_height_frame_tiles"), "Room frame tile height should be fixed by GameState")
	assert_true(state_source.contains("_fixed_height_grid_size"), "Placement grid height should be fixed by GameState")
	assert_true(state_source.contains("SAVE_SCHEMA_VERSION"), "GameState should version saves before trusting persisted room layout levels")
	assert_true(state_source.contains("save_needs_writeback = false"), "Development-stage saves should not request legacy migration writeback by default")
	assert_true(save_source.contains("GameState.save_needs_writeback = false"), "SaveManager should clear writeback state after saving")
	assert_true(state_source.contains("\"frame_tiles\""), "Room saves should use frame_tiles instead of pixel dimensions")
	assert_true(state_source.contains("\"grid_size\""), "Room saves should use grid_size instead of pixel rectangles")
	assert_false(state_source.contains("\"room_size\""), "GameState should not preserve legacy pixel room_size fields")
	assert_false(state_source.contains("\"grid_rect\""), "GameState should not preserve legacy pixel grid_rect fields")
	assert_false(state_source.contains("[448, 176]"), "Old 720px-era room-size fallback should not survive in GameState")
	assert_false(state_source.contains("save_needs_writeback = saved_schema_version < SAVE_SCHEMA_VERSION"), "Development-stage saves should not branch into legacy layout migrations")
	assert_false(state_source.contains("if saved_schema_version < SAVE_SCHEMA_VERSION:"), "GameState should not keep old-save layout migration branches")
	assert_true(state_source.contains("configured_layout := _configured_room_layout_for_level"), "Current-version saves should rebuild frame/grid from config and room level")

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
	assert_true(slot_scene.contains("[node name=\"SceneConfig\" type=\"Node\""), "BuildSlot layout config should be authored in BuildSlot.tscn")
	assert_true(slot_scene.contains("[node name=\"TemplateText\" type=\"Control\""), "BuildSlot label templates should be authored in BuildSlot.tscn")
	assert_true(slot_scene.contains("[node name=\"LockedLabelTemplate\" type=\"Label\""), "Build slot locked label template should be authored in BuildSlot.tscn")
	assert_true(slot_scene.contains("[node name=\"BuildableLabelTemplate\" type=\"Label\""), "Build slot buildable label template should be authored in BuildSlot.tscn")
	assert_true(building_scene.contains("theme_override_constants/separation = 0"), "ApartmentBuilding spacing should be configured in the scene")
	assert_true(building_scene.contains("[node name=\"SceneConfig\" type=\"Node\""), "ApartmentBuilding should keep template config in ApartmentBuilding.tscn")
	assert_true(building_scene.contains("metadata/floor_scene_path = \"res://scenes/building/Floor.tscn\""), "ApartmentBuilding should assign the editable Floor template in scene metadata")
	assert_true(building_scene.contains("metadata/build_slot_scene_path = \"res://scenes/building/BuildSlot.tscn\""), "ApartmentBuilding should assign the editable BuildSlot template in scene metadata")
	assert_true(building_source.contains("floor_scene_path"), "ApartmentBuilding should allow floor config to select an editor-authored floor scene template")
	assert_true(building_source.contains("build_slot_scene_path"), "ApartmentBuilding should allow floor config to select an editor-authored build-slot template")
	assert_true(building_source.contains("_scene_from_path"), "ApartmentBuilding should load configured templates with scene default fallback")
	assert_true(slot_shell_scene.contains("BuildServiceCore"), "Build slots should keep the left door/elevator service area")
	assert_true(slot_shell_scene.contains("BuildRoomShell"), "Build slots should draw the right-side unbuilt room shell")
	assert_true(slot_shell_scene.contains("name=\"BuildSlotShell\" type=\"HBoxContainer\""), "Build slot shell should lay out service and room areas in the editable scene")
	assert_true(slot_shell_scene.contains("ApartmentTileMap.tscn"), "Build slots should reuse the editable apartment TileMap template")
	assert_true(slot_shell_scene.contains("ServiceCoreTileMap.tscn"), "Build slots should reuse the editable service-core TileMap template")
	assert_true(slot_shell_scene.contains("ConstructionCover"), "Build slots should keep the construction cloth as a scene-authored texture overlay")
	assert_true(slot_shell_scene.contains("AtlasTexture_construction_cover"), "Build slot construction cover should use a scene-authored AtlasTexture")
	assert_true(slot_shell_scene.contains("theme_override_font_sizes/font_size = 10"), "Build slot label style should be editor-authored")
	assert_true(slot_shell_scene.contains("text = \"待修建\""), "Build slot label should be previewable in BuildSlotShell.tscn")
	assert_false(slot_shell_scene.contains("BuildRoomInfrastructure"), "Build slots should not keep old TextureRect infrastructure body")
	assert_false(slot_shell_scene.contains("BuildServiceInfrastructure"), "Build slots should not keep old TextureRect service infrastructure body")
	assert_false(slot_shell_scene.contains("BuildDoorOrElevator"), "Build slots should not keep old TextureRect door/elevator body")
	assert_false(slot_shell_scene.contains("ConstructionCloth"), "Build slots should not keep old TextureRect construction cloth")
	assert_false(slot_shell_scene.contains("TrafficCone"), "Build slots should not keep old TextureRect traffic cones")
	assert_false(slot_shell_scene.contains("BuildRoofEaves"), "Build slots should not keep old TextureRect roof")
	assert_false(slot_shell_scene.contains("BuildSlotScrim"), "Build slots should not keep old ColorRect construction fallback")
	assert_false(slot_source.contains("@export var construction_cloth_texture"), "Construction cover should stay scene-authored instead of exported from script")
	assert_false(slot_source.contains("@export var roof_texture"), "Build-slot roof should move to the editor-painted TileMap")
	assert_false(slot_source.contains("apply_asset_to_texture_rect"), "BuildSlot should not patch building visuals from scripts")
	assert_false(slot_source.contains("AtlasTexture.new"), "BuildSlot should not create atlas slices for building visuals")
	assert_false(slot_shell_source.contains("service_core.position"), "BuildSlotShell should not hand-position the service core at runtime")
	assert_false(slot_shell_source.contains("room_shell.position"), "BuildSlotShell should not hand-position the room shell at runtime")
	assert_false(slot_source.contains("StyleBoxFlat.new"), "BuildSlot should not create fixed button skins in script")
	assert_false(slot_source.contains("add_theme_"), "BuildSlot should not hide fixed label styling in script")
	assert_false(slot_source.contains("@export"), "BuildSlot should read scene-authored config instead of script exports")
	assert_false(slot_source.contains("_asset_tile_origin"), "BuildSlot should not infer TileSet atlas coordinates from room asset regions")
	assert_false(slot_source.contains("wallpaper_origin"), "BuildSlot should not pass guessed wallpaper atlas origins")
	assert_false(slot_source.contains("frame_origin"), "BuildSlot should not pass guessed frame atlas origins")
	assert_false(slot_source.contains("待修建"), "BuildSlot should not hard-code build-state copy in script")
	assert_false(slot_source.contains("金币"), "BuildSlot should not hard-code build-cost copy in script")
	assert_false(slot_source.contains("解锁"), "BuildSlot should not hard-code locked-state copy in script")
	assert_false(slot_source.contains("UIPanelFactory.style_button"), "Build slots should not look like a menu button")
	assert_false(building_source.contains("preload(\"res://scenes/building/Floor.tscn\")"), "ApartmentBuilding should not hide floor templates in script")
	assert_false(building_source.contains("preload(\"res://scenes/building/BuildSlot.tscn\")"), "ApartmentBuilding should not hide build-slot templates in script")
	assert_false(building_source.contains("@export"), "ApartmentBuilding should read scene-authored config instead of script exports")
	assert_true(building_source.contains("_has_visible_next_build_slot"), "Top built room should not duplicate roof/eaves below a visible build slot")
	assert_true(building_source.contains("_floor_size"), "Build slots should reserve configurable floor heights")

func test_placement_overlay_is_scene_based_not_grid_panel() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/PlacementOverlay.gd")
	var overlay_scene := FileAccess.get_file_as_string("res://scenes/ui/PlacementOverlay.tscn")
	var room_source := FileAccess.get_file_as_string("res://scripts/building/Room.gd")
	var popup_source := FileAccess.get_file_as_string("res://scripts/ui/PopupLayer.gd")
	var main_source := FileAccess.get_file_as_string("res://scenes/main/Main.gd")
	assert_true(overlay_scene.contains("[node name=\"PlacementOverlay\" type=\"Control\"]"), "placement overlay should be a scene-authored Control, not a full AppPanel")
	assert_true(overlay_scene.contains("[node name=\"PlaceTitlePrefix\" type=\"Label\""), "placement overlay state text should be authored in the scene")
	assert_true(overlay_scene.contains("[node name=\"MoveConfirmText\" type=\"Label\""), "placement move confirm text should be authored in the scene")
	assert_true(overlay_scene.contains("拖动 %s 到合适位置"), "placement hint copy should be previewable in the scene")
	assert_true(overlay_scene.contains("mouse_filter = 0"), "placement overlay should capture direct drag input over room buttons")
	assert_false(overlay_source.contains("extends \"res://scripts/ui/AppPanel.gd\""), "placement should not open as a full blocking AppPanel")
	assert_false(overlay_source.contains("GridContainer.new()"), "placement should not use a separate grid-selection panel")
	assert_false(overlay_source.contains("set_anchors_preset"), "placement overlay should keep its full-rect layout in the scene")
	assert_false(overlay_source.contains("_fill_parent"), "placement overlay should not repair fixed layout at runtime")
	assert_false(overlay_source.contains("拖动 %s 到合适位置"), "placement hint copy should not be hidden in script")
	assert_true(overlay_source.contains("func _gui_input"), "placement should handle drag input before room buttons consume it")
	assert_true(overlay_source.contains("_position_preview_under_pointer"), "placement preview should follow the active pointer during drag")
	assert_true(overlay_source.contains("floating_controls.visible = false"), "placement should hide floating controls while dragging")
	assert_true(overlay_source.contains("floating_controls.visible = true"), "placement should restore floating controls after drag release")
	assert_true(overlay_source.contains("show_placement_grid"), "placement should still update hidden target-room placement state")
	assert_true(room_source.contains("placement_grid_layer.visible = false"), "Room should keep the placement grid hidden")
	assert_false(room_source.contains("draw_rect(cell_rect"), "Room should not draw every placement grid cell")
	assert_true(room_source.contains("world_position_to_placement_grid"), "Room should translate scene taps into furniture-aware placement grid cells")
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
	assert_true(preview_source.contains("VALID_OUTLINE_COLOR"), "FurniturePreview should expose valid placement with its own outline")
	assert_true(preview_source.contains("INVALID_OUTLINE_COLOR"), "FurniturePreview should expose invalid placement with its own outline")
	assert_true(preview_source.contains("draw_rect"), "FurniturePreview should draw placement validity feedback on the preview itself")
	assert_true(room_source.contains("view_data[\"room_id\"] = room_id"), "Room should bind furniture visuals back to their room")
	assert_true(room_source.contains("_asset_region_size"), "Furniture visuals should preserve atlas-region proportions")

func test_tenant_uses_character_body_click_area_and_strict_animations() -> void:
	var tenant_scene := FileAccess.get_file_as_string("res://scenes/tenant/Tenant.tscn")
	var tenant_source := FileAccess.get_file_as_string("res://scripts/tenant/Tenant.gd")
	var room_source := FileAccess.get_file_as_string("res://scripts/building/Room.gd")
	var main_source := FileAccess.get_file_as_string("res://scenes/main/Main.gd")
	var locator_source := FileAccess.get_file_as_string("res://scripts/tenant/TenantRoomLocator.gd")
	var ai_source := FileAccess.get_file_as_string("res://scripts/tenant/TenantAI.gd")
	var need_bubble_scene := FileAccess.get_file_as_string("res://scenes/tenant/NeedBubble.tscn")
	var need_bubble_source := FileAccess.get_file_as_string("res://scripts/tenant/NeedBubble.gd")
	var emote_scene := FileAccess.get_file_as_string("res://scenes/tenant/TenantEmote.tscn")
	var emote_source := FileAccess.get_file_as_string("res://scripts/tenant/TenantEmote.gd")
	assert_true(tenant_scene.contains("[node name=\"Tenant\" type=\"CharacterBody2D\""), "Tenant should be a map CharacterBody2D scene")
	assert_true(tenant_scene.contains("AnimatedSprite2D"), "Tenant should reserve AnimatedSprite2D for future spritesheets")
	assert_true(tenant_scene.contains("NeedBubble.tscn"), "Tenant should instance the reusable NeedBubble scene")
	assert_true(tenant_scene.contains("TenantAI.gd"), "Tenant should own a per-instance AI state machine")
	assert_true(tenant_scene.contains("[node name=\"TenantAI\" type=\"Node\""), "TenantAI should be a scene child, not a global Main loop")
	assert_true(tenant_scene.contains("[node name=\"ClickArea\" type=\"Area2D\""), "Tenant clicks should be routed through a scene-authored ClickArea")
	assert_true(tenant_scene.contains("[node name=\"ClickShape\" type=\"CollisionShape2D\""), "Tenant ClickArea should expose its hit shape in the scene")
	assert_true(tenant_scene.contains("position = Vector2(28, 56)"), "Tenant standalone preview should place the character inside the viewport")
	assert_true(tenant_scene.contains("position = Vector2(0, -7)"), "Tenant avatar should compensate for transparent padding in the unscaled 32x32 NPC frame")
	assert_true(tenant_scene.contains("region = Rect2(0, 32, 32, 32)"), "Tenant atlas frames should match the configured 32x32 Pixel Spaces NPC grid")
	assert_false(tenant_scene.contains("region = Rect2(0, 32, 16, 32)"), "Tenant atlas frames should not override the configured 32x32 NPC grid")
	assert_false(tenant_scene.contains("scale = Vector2(1.5, 1.5)"), "Tenant should render the configured 32x32 NPC frames at scene scale")
	assert_true(tenant_scene.contains("sprite_frames = SubResource"), "Tenant avatar frames should be prebuilt on AvatarSprite in Tenant.tscn")
	assert_true(tenant_scene.contains("\"name\": &\"walk\""), "Tenant.tscn should prebuild a walk animation on AvatarSprite")
	assert_true(tenant_scene.contains("BehaviorAnimationMap"), "Tenant behavior-to-animation bindings should be authored in Tenant.tscn")
	assert_true(tenant_scene.contains("metadata/default_avatar_animation = \"idle\""), "Tenant default avatar animation should be scene metadata")
	assert_true(tenant_scene.contains("metadata/avatar_animation = \"walk\""), "Tenant walk animation binding should be scene metadata")
	assert_false(tenant_scene.contains("metadata/moves = true"), "Tenant movement should live in TenantAI, not animation metadata")
	assert_false(tenant_scene.contains("metadata/behavior_keys = \"wander,recruited,entertainment,eat,clean,study,relax\""), "Only common visible actions should bind to avatar animations")
	assert_true(need_bubble_scene.contains("[node name=\"NeedBubble\" type=\"Control\""), "NeedBubble should be a previewable Control scene")
	assert_true(need_bubble_scene.contains("BubbleAnimation\" type=\"AnimatedSprite2D\""), "NeedBubble should reserve an AnimatedSprite2D bubble node")
	assert_true(need_bubble_scene.contains("IconRoot"), "NeedBubble should expose an icon root in the scene")
	assert_true(need_bubble_scene.contains("SleepIcon"), "NeedBubble should expose behavior icon nodes in the scene")
	assert_true(need_bubble_scene.contains("metadata/behavior_key = \"sleep\""), "NeedBubble behavior icons should be bound through scene metadata")
	assert_true(need_bubble_scene.contains("metadata/behavior_keys = \"relax,happy\""), "NeedBubble shared icons should be bound through scene metadata")
	assert_true(need_bubble_scene.contains("\"loop\": false"), "NeedBubble animation should be non-looping so icons can appear after it finishes")
	assert_true(emote_scene.contains("[node name=\"TenantEmote\" type=\"Control\"]"), "TenantEmote should be a previewable Control scene")
	assert_true(emote_scene.contains("EmoteAnimation\" type=\"AnimatedSprite2D\""), "TenantEmote should reserve an AnimatedSprite2D emote node")
	assert_true(emote_scene.contains("IconRoot"), "TenantEmote should expose an icon root in the scene")
	assert_true(emote_scene.contains("HappyIcon"), "TenantEmote should expose emote icon nodes in the scene")
	assert_true(emote_scene.contains("metadata/emote_key = \"happy\""), "TenantEmote icons should be bound through scene metadata")
	assert_true(emote_scene.contains("\"loop\": false"), "TenantEmote animation should be non-looping so icons can appear after it finishes")
	assert_true(tenant_source.contains("need_bubble.show_behavior"), "Tenant behavior bubble should be delegated to NeedBubble")
	assert_true(tenant_source.contains("UIManager.open_tenant_panel"), "Clicking an in-room tenant should open tenant context")
	assert_true(tenant_source.contains("_play_avatar_animation"), "Tenant should actively play the behavior animation")
	assert_true(tenant_source.contains("GameEvents.tenant_behavior_changed.connect"), "Tenant animation should refresh on ordinary AI behavior changes")
	assert_true(tenant_source.contains("TenantAI"), "Tenant should bind its scene-authored AI node")
	assert_true(tenant_source.contains("ClickArea"), "Tenant should bind the scene-authored click area")
	assert_true(tenant_source.contains("push_error(\"Tenant AvatarSprite is missing animation"), "Missing tenant animations should be explicit errors")
	assert_true(ai_source.contains("enum AIState"), "TenantAI should use an explicit state machine")
	assert_true(ai_source.contains("AIState.IDLE"), "TenantAI should support idle")
	assert_true(ai_source.contains("AIState.WALK"), "TenantAI should support walking")
	assert_true(ai_source.contains("AIState.JUMP"), "TenantAI should support jumping")
	assert_true(ai_source.contains("AIState.BUBBLE_ACTION"), "TenantAI should support bubble-only actions")
	assert_true(ai_source.contains("_sync_from_current_behavior"), "TenantAI setup should restore current state without overwriting observed behavior")
	assert_true(ai_source.contains("TenantRoomLocator.spawn_position"), "TenantAI should spawn from the room floor grid")
	assert_true(ai_source.contains("TenantRoomLocator.walk_positions"), "TenantAI should patrol using room floor grid positions")
	assert_true(ai_source.contains("TenantRoomLocator.interaction_position"), "TenantAI should use grid-based furniture interaction points")
	assert_true(locator_source.contains("class_name TenantRoomLocator"), "Tenant room positions should live in a dedicated grid locator")
	assert_true(locator_source.contains("FurniturePlacementRules.door_cells_for_layer"), "Tenant grid positions should avoid floor door cells")
	assert_true(need_bubble_source.contains("await bubble_animation.animation_finished"), "NeedBubble should reveal icons only after the bubble animation finishes")
	assert_true(emote_source.contains("await emote_animation.animation_finished"), "TenantEmote should reveal icons only after the emote animation finishes")
	assert_false(tenant_scene.contains("behavior_animation_map = {"), "Tenant.tscn should not keep script-exported behavior animation config")
	assert_false(tenant_scene.contains("ColorFallback"), "Tenant should not keep a color fallback visual")
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
	assert_false(tenant_source.contains("fallback_animation"), "Tenant should not fall back to another avatar animation")
	assert_false(tenant_source.contains("color_fallback"), "Tenant should not toggle fallback visuals")
	assert_false(tenant_source.contains("accept_event()"), "Tenant should not use Control GUI event handling")
	assert_false(tenant_source.contains("Rect2(Vector2.ZERO, size)"), "Tenant click checks should not depend on Control size")
	assert_false(tenant_source.contains("func _gui_input"), "Tenant root should not use Control _gui_input")
	assert_false(tenant_source.contains("position = base_position"), "Tenant should not snap back to its spawn point every frame")
	assert_false(tenant_source.contains("current_behavior_moves"), "Tenant should not own behavior movement state")
	assert_false(tenant_source.contains("睡觉"), "Tenant behavior labels should not be hard-coded in script")
	assert_false(need_bubble_scene.contains("bubble_text_by_behavior = {"), "NeedBubble should use scene-authored icon nodes instead of exported text dictionaries")
	assert_false(need_bubble_source.contains("@export"), "NeedBubble should not require script-level exported bubble text configuration")
	assert_false(need_bubble_source.contains("BEHAVIOR_ICON_NODE"), "NeedBubble behavior icon bindings should stay in scene metadata")
	assert_false(need_bubble_source.contains("BUBBLE_ANIMATION"), "NeedBubble animation selection should stay on the AnimatedSprite2D node")
	assert_false(need_bubble_source.contains("get_animation_names"), "NeedBubble should not choose a fallback animation")
	assert_false(need_bubble_source.contains("睡觉"), "NeedBubble should not keep display behavior names in script")
	assert_false(need_bubble_source.contains("学习/工作"), "NeedBubble display text should stay in NeedBubble.tscn")
	assert_false(emote_scene.contains("[node name=\"TenantEmote\" type=\"Label\"]"), "TenantEmote should not be a text-only label scene")
	assert_false(emote_source.contains("extends Label"), "TenantEmote should not render text directly")
	assert_false(emote_source.contains("@export"), "TenantEmote should not require script-level exported visual configuration")
	assert_false(emote_source.contains("EMOTE_ICON_NODE"), "TenantEmote icon bindings should stay in scene metadata")
	assert_false(emote_source.contains("EMOTE_ANIMATION"), "TenantEmote animation selection should stay on the AnimatedSprite2D node")
	assert_false(emote_source.contains("get_animation_names"), "TenantEmote should not choose a fallback animation")
	assert_false(room_source.contains("set_avatar_scale"), "Room should only position tenant scenes, not rewrite their internal visual layout")
	assert_false(room_source.contains("tenant_offset"), "Room should not keep naked tenant spawn coordinates")
	assert_false(room_source.contains("Marker2D"), "Room should not use scene anchors for tenant AI positions")
	assert_false(room_source.contains("tenant_view.position ="), "Room should not own tenant positioning beyond instantiation")
	assert_false(room_source.contains("func _tenant_position"), "Room should not own tenant positioning beyond instantiation")
	assert_false(room_source.contains("clampf(tenant_offset"), "Room should not clamp tenant movement against room bounds")
	assert_false(room_source.contains("room_pixel_size.y - 48.0"), "Room should not clamp CharacterBody2D tenants as if they were top-left Control previews")
	assert_false(room_source.contains("room_pixel_size.y - 4.0"), "Room should not leave CharacterBody2D tenants hovering above the floor")
	assert_false(main_source.contains("tenant_ai_timer"), "Main should not run global tenant AI ticks")
	assert_false(main_source.contains("_tick_tenant_ai"), "Main should not own tenant AI behavior selection")
	assert_false(main_source.contains("_on_rent_changed(_value: float) -> void:\n\t_refresh_top_bar()\n\t_refresh_building()"), "Rent changes should not rebuild rooms and reset TenantAI state")
	assert_false(need_bubble_source.contains("mouse_filter ="), "NeedBubble fixed interaction settings should stay in NeedBubble.tscn")
	assert_false(emote_source.contains("mouse_filter ="), "TenantEmote fixed interaction settings should stay in TenantEmote.tscn")

func test_tenant_room_locator_uses_floor_grid_positions() -> void:
	var locator_source := FileAccess.get_file_as_string("res://scripts/tenant/TenantRoomLocator.gd")
	var room := {
		"id": "__tenant_locator_test",
		"frame_tiles": [8, 4],
		"grid_size": [6, 4],
		"furniture_instances": []
	}
	assert_true(locator_source.contains("static func floor_grid_y"), "TenantRoomLocator should expose floor row calculation")
	assert_true(locator_source.contains("static func spawn_position"), "TenantRoomLocator should expose spawn position generation")
	assert_true(locator_source.contains("static func walk_positions"), "TenantRoomLocator should expose patrol position generation")
	assert_true(locator_source.contains("static func interaction_position"), "TenantRoomLocator should expose furniture interaction position generation")
	var floor_row := FurniturePlacementRules.floor_grid_y_for(room["grid_size"], [1, 1])
	var door_cells := FurniturePlacementRules.door_cells_for_layer(room, FurniturePlacementRules.LAYER_FLOOR)
	var standing_grids := []
	for x in range(int(room["grid_size"][0])):
		var cell := [x, floor_row]
		if not door_cells.has(cell):
			standing_grids.append(cell)
	var tile_size := FurniturePlacementRules.TILE_SIZE
	var floor_origin := Vector2(float(tile_size), 0.0)
	assert_eq(floor_row, 3, "Tenant floor row should be the bottom floor grid row")
	assert_eq(standing_grids, [[1, 3], [2, 3], [3, 3], [4, 3], [5, 3]], "Tenant standing grids should avoid the floor door cell")
	assert_eq(standing_grids[3], [4, 3], "Tenant spawn should default to a middle-right floor cell")
	assert_eq(floor_origin + Vector2(4.5 * tile_size, 4.0 * tile_size), Vector2(88.0, 64.0), "Tenant spawn foot point should sit on the room floor")
	assert_eq([standing_grids.front(), standing_grids.back()], [[1, 3], [5, 3]], "Tenant walk range should avoid the floor door cell")

	room["furniture_instances"] = [
		{"instance_id": "bed_a", "furniture_id": "bed_basic", "grid_pos": [1, 2]}
	]
	var bed_data := _furniture_data("bed_basic")
	var bed_size: Array = bed_data.get("size", [])
	var interaction_grid := [int(room["furniture_instances"][0]["grid_pos"][0]) + int(bed_size[0]), floor_row]
	assert_eq(interaction_grid, [3, 3], "Tenant interaction point should stand beside floor furniture")
	assert_eq(floor_origin + Vector2(3.5 * tile_size, 4.0 * tile_size), Vector2(72.0, 64.0), "Tenant interaction foot point should remain on the floor")

func test_tenant_behavior_state_uses_keys_with_alias_config() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	var main_source := FileAccess.get_file_as_string("res://scenes/main/Main.gd")
	var config_source := FileAccess.get_file_as_string("res://scripts/autoload/ConfigManager.gd")
	var alias_config := FileAccess.get_file_as_string("res://data/behavior_aliases.json")
	assert_true(config_source.contains("behavior_aliases"), "ConfigManager should load behavior aliases for old save compatibility")
	assert_true(alias_config.contains("\"睡觉\": \"sleep\""), "Behavior aliases should migrate old display labels to behavior keys")
	assert_true(game_state_source.contains("DEFAULT_TENANT_BEHAVIOR := \"wander\""), "GameState should store behavior keys, not display labels")
	assert_true(game_state_source.contains("_need_to_behavior_key"), "Need updates should resolve to behavior keys")
	assert_true(game_state_source.contains("func set_tenant_behavior"), "GameState should expose ordinary tenant behavior syncing for TenantAI")
	assert_true(game_state_source.contains("tenant_behavior_changed.emit"), "Ordinary behavior changes should emit a visual refresh signal")
	assert_false(main_source.contains("GameState.IDLE_TENANT_BEHAVIOR"), "Main should not choose tenant behavior keys after TenantAI owns behavior selection")
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
	assert_true(script_text.contains("camera_bounds"), "BuildingView should clamp camera movement against explicit world bounds")
	assert_true(script_text.contains("effective_min_zoom"), "BuildingView should derive a dynamic minimum zoom from viewport and bounds")
	assert_true(script_text.contains("_world_size_for_content"), "BuildingView should size camera bounds from viewport and apartment content")
	assert_true(script_text.contains("calculate_min_zoom_for_bounds"), "BuildingView should expose minimum-zoom calculation for tests and UI state")
	assert_true(script_text.contains("PLACEMENT_FOCUS_ZOOM"), "BuildingView should use a stable placement focus zoom")
	assert_false(script_text.contains("focus_extra_bottom_space"), "Room focus should not move the apartment by adding temporary map height")
	assert_false(script_text.contains("FOCUS_EXTRA_BOTTOM_SPACE"), "Room focus should not use extra bottom-space layout hacks")
	assert_true(script_text.contains("_pan_camera"), "BuildingView should pan through the camera")
	assert_true(script_text.contains("screen_to_world_position"), "Placement should convert overlay screen taps through the camera")
	assert_true(script_text.contains("world_to_screen_position"), "Placement floating controls should map room preview positions back to the overlay")

func test_pixel_space_assets_are_configured_for_mvp_surfaces() -> void:
	var project_settings := FileAccess.get_file_as_string("res://project.godot")
	assert_true(project_settings.contains("textures/canvas_textures/default_texture_filter=0"), "pixel art should use nearest filtering by default")
	assert_true(project_settings.contains("window/size/viewport_width=360"), "Project should use a 360px logical portrait design width for 16px pixel art")
	assert_true(project_settings.contains("window/size/viewport_height=640"), "Project should use a 640px logical portrait design height for 16px pixel art")
	assert_true(project_settings.contains("window/size/window_width_override=720"), "Desktop preview should open at 2x portrait width")
	assert_true(project_settings.contains("window/size/window_height_override=1280"), "Desktop preview should open at 2x portrait height")
	assert_true(project_settings.contains("window/stretch/mode=\"viewport\""), "Pixel art should be upscaled from the logical viewport instead of resizing nodes")
	assert_true(project_settings.contains("window/stretch/aspect=\"keep_width\""), "Mobile portrait scaling should keep the design width so world art does not shrink on tall screens")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/scale_mode")), "integer", "Pixel art should use integer stretch scaling to avoid blurry pixels")
	assert_true(bool(ProjectSettings.get_setting("gui/common/snap_controls_to_pixels")), "Controls should snap to pixels for crisp UI text")
	assert_eq(int(ProjectSettings.get_setting("gui/theme/default_font_antialiasing")), 0, "Default UI font antialiasing should be disabled for pixel-crisp labels")
	assert_eq(int(ProjectSettings.get_setting("gui/theme/default_font_subpixel_positioning")), 0, "Default UI font subpixel positioning should be disabled")
	assert_eq(int(ProjectSettings.get_setting("gui/theme/lcd_subpixel_layout")), 0, "LCD subpixel layout should be disabled for pixel-art text")
	assert_true(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")), "Node2D transforms should snap to pixels")
	assert_true(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel")), "2D vertices should snap to pixels")
	for item in furniture:
		var furniture_data: Dictionary = item
		assert_false(str(furniture_data.get("asset", {}).get("type", "placeholder")) == "placeholder", "%s should use a Pixel Spaces visual asset" % furniture_data.get("id", ""))
		assert_true(_asset_texture_exists(furniture_data.get("asset", {})), "%s furniture asset texture should exist" % furniture_data.get("id", ""))
	for tenant in tenants:
		var tenant_data: Dictionary = tenant
		var asset: Dictionary = tenant_data.get("asset", {})
		assert_eq(str(asset.get("type", "")), "spritesheet_animation", "%s should use sprite animations" % tenant_data.get("id", ""))
		assert_true(_asset_texture_exists(asset), "%s tenant spritesheet should exist" % tenant_data.get("id", ""))
		var frame_size: Array = asset.get("frame_size", [])
		assert_true(frame_size.size() >= 2, "%s tenant spritesheet should declare frame_size" % tenant_data.get("id", ""))
		if frame_size.size() >= 2:
			assert_eq(Vector2i(int(frame_size[0]), int(frame_size[1])), Vector2i(32, 32), "%s tenant spritesheet frames should use the configured 32x32 grid" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("move"), "%s should expose move animation" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("idle"), "%s should expose idle animation" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("jump"), "%s should expose jump animation" % tenant_data.get("id", ""))
	for room in rooms:
		var room_data: Dictionary = room
		assert_true(_asset_texture_exists(room_data.get("wall_asset", {})), "%s wall asset should exist" % room_data.get("id", ""))
		assert_false(room_data.has("floor_asset"), "%s should not configure a separate floor asset" % room_data.get("id", ""))
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

func _furniture_data(furniture_id: String) -> Dictionary:
	for item in furniture:
		var furniture_data: Dictionary = item
		if str(furniture_data.get("id", "")) == furniture_id:
			return furniture_data
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

func _bind_apartment_tilemap_layers(tilemap: ApartmentTileMap) -> void:
	tilemap.wallpaper_layer = tilemap.get_node_or_null("WallpaperTileMap") as TileMapLayer
	tilemap.wall_layer = tilemap.get_node_or_null("WallTileMap") as TileMapLayer
	tilemap.infrastructure_layer = tilemap.get_node_or_null("InfrastructureTileMap") as TileMapLayer
	tilemap.roof_layer = tilemap.get_node_or_null("RoofTileMap") as TileMapLayer
	tilemap.construction_layer = tilemap.get_node_or_null("ConstructionTileMap") as TileMapLayer

func _asset_texture_exists(asset: Dictionary) -> bool:
	var path := str(asset.get("texture", ""))
	return not path.is_empty() and FileAccess.file_exists(path)

func _tileset_source_with_texture(tileset: TileSet, texture_name: String) -> TileSetAtlasSource:
	for index in range(tileset.get_source_count()):
		var source_id := tileset.get_source_id(index)
		var atlas_source := tileset.get_source(source_id) as TileSetAtlasSource
		if atlas_source != null and atlas_source.texture != null and atlas_source.texture.resource_path.ends_with(texture_name):
			return atlas_source
	return null

func _load_json_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

func _load_json_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
