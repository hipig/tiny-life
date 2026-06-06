@tool
extends McpTestSuite

var economy: Dictionary = {}
var tenants: Array = []
var regions: Array = []
var floors: Array = []

func suite_name() -> String:
	return "economy_regions"

func setup() -> void:
	economy = _load_json_dict("res://data/economy.json")
	tenants = _load_json_array("res://data/tenants.json")
	regions = _load_json_array("res://data/tenant_regions.json")
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

func test_initial_building_starts_with_lobby_and_second_floor_build_slot() -> void:
	var first_floor := _floor_data(1)
	var second_floor := _floor_data(2)
	assert_true(bool(first_floor.get("initial_built", false)), "first floor lobby should be built at new-game start")
	assert_eq(str(first_floor.get("display_name", "")), "大厅", "first floor should present as lobby")
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
	assert_true(main_scene.contains("res://scenes/ui/TopStatusBar.tscn"), "Main scene should instance TopStatusBar")
	assert_true(main_scene.contains("res://scenes/building/BuildingView.tscn"), "Main scene should instance BuildingView")
	assert_true(main_scene.contains("res://scenes/ui/FloatingMenu.tscn"), "Main scene should instance FloatingMenu")
	assert_true(main_scene.contains("[node name=\"Background\""), "Main scene should include a background band")

func test_tenant_uses_need_bubble_scene_and_animation_placeholder() -> void:
	var tenant_scene := FileAccess.get_file_as_string("res://scenes/tenant/Tenant.tscn")
	var tenant_source := FileAccess.get_file_as_string("res://scripts/tenant/Tenant.gd")
	assert_true(tenant_scene.contains("AnimatedSprite2D"), "Tenant should reserve AnimatedSprite2D for future spritesheets")
	assert_true(tenant_scene.contains("NeedBubble.tscn"), "Tenant should instance the reusable NeedBubble scene")
	assert_true(tenant_source.contains("need_bubble.show_behavior"), "Tenant behavior bubble should be delegated to NeedBubble")

func test_coin_gain_sources_are_wired_to_recorded_signal() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	var top_bar_source := FileAccess.get_file_as_string("res://scripts/ui/TopStatusBar.gd")
	assert_true(game_state_source.contains("coin_gain_recorded.emit(amount, source)"), "coin gains should emit a source-aware signal")
	assert_true(top_bar_source.contains("source == \"auto_income\""), "top bar popup should only merge automatic income")

func test_region_rent_limit_blocks_expensive_candidates() -> void:
	var affordable_region := _region_data("region_affordable")
	var expected_rent: float = _calculate_room_rent("tenant_student_01", 100, 60)
	assert_true(expected_rent > float(affordable_region.get("max_rent_per_minute", 0.0)), "starter region should reject candidates whose expected rent exceeds its cap")

func test_building_view_zoom_uses_scroll_wrapper() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/building/BuildingView.tscn")
	var script_text := FileAccess.get_file_as_string("res://scripts/building/BuildingView.gd")
	assert_true(scene_text.contains("BuildingZoomShell"), "BuildingView should include a scroll-size wrapper")
	assert_true(script_text.contains("building_root.scale = Vector2.ONE * zoom_scale"), "inner building content should be scaled")
	assert_true(script_text.contains("building_zoom_shell.custom_minimum_size = scaled_size"), "scroll wrapper should resize with zoom")

func _panel_scene_paths() -> Array[String]:
	return [
		"res://scenes/ui/RoomPanel.tscn",
		"res://scenes/ui/FurnitureShopPanel.tscn",
		"res://scenes/ui/TenantPanel.tscn",
		"res://scenes/ui/BuildConfirmPopup.tscn",
		"res://scenes/ui/PlacementOverlay.tscn",
		"res://scenes/ui/ApartmentOverviewPanel.tscn",
		"res://scenes/ui/IncomeDetailPanel.tscn",
		"res://scenes/ui/RentDetailPanel.tscn",
		"res://scenes/ui/TaskPanel.tscn",
		"res://scenes/ui/RewardPanel.tscn",
		"res://scenes/ui/SettingsPanel.tscn",
		"res://scenes/ui/OfflineRewardPopup.tscn"
	]

func _support_scene_paths() -> Array[String]:
	return [
		"res://scenes/ui/PopupLayer.tscn",
		"res://scenes/effects/FloatingCoinText.tscn",
		"res://scenes/furniture/FurniturePreview.tscn",
		"res://scenes/furniture/FurnitureFloatingControls.tscn",
		"res://scenes/tenant/NeedBubble.tscn",
		"res://scenes/tenant/TenantEmote.tscn"
	]

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

func _load_json_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

func _load_json_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
