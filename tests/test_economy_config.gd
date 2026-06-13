@tool
extends "res://tests/support/TestSuiteBase.gd"

func suite_name() -> String:
	return "economy_config"

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


func test_initial_building_starts_with_public_entry_and_second_floor_rooms() -> void:
	var first_floor := _floor_data(1)
	var second_floor := _floor_data(2)
	var third_floor := _floor_data(3)
	assert_true(bool(first_floor.get("initial_built", false)), "first floor should be built at new-game start")
	assert_eq(str(first_floor.get("visual_role", "")), "public_entry", "first floor should be a visual-only public entry floor")
	assert_eq(_room_ids_on_floor(1).size(), 0, "first floor should not configure rentable rooms")
	assert_true(bool(second_floor.get("initial_built", false)), "second floor should be built at new-game start")
	assert_eq(_room_ids_on_floor(2), ["room_201", "room_202"], "second floor should start with two rentable rooms")
	assert_false(bool(third_floor.get("initial_built", true)), "third floor structure should start unbuilt until its rooms become visible")
	assert_false(third_floor.has("build_cost"), "floor config should not carry construction cost after room-based building")
	assert_false(third_floor.has("required_apartment_level"), "floor config should not carry room-build level gates")
	for floor in floors:
		var floor_data: Dictionary = floor
		assert_false(floor_data.has("roof_asset"), "floor config should not carry apartment roof assets")
		assert_false(floor_data.has("roof_theme"), "floor config should not carry apartment roof themes")
		for public_area in floor_data.get("public_areas", []):
			var area_data: Dictionary = public_area
			for pair in [
				["default_wallpaper_id", "wallpaper"],
				["default_wall_style_id", "wall"]
			]:
				var decor_item := _room_decor_item(str(area_data.get(str(pair[0]), "")))
				assert_false(decor_item.is_empty(), "%s public area should configure %s" % [area_data.get("id", ""), pair[0]])
				assert_eq(str(decor_item.get("category", "")), str(pair[1]), "%s public area %s should point at the expected decor category" % [area_data.get("id", ""), pair[0]])
			if bool(area_data.get("has_entrance_door", false)):
				var door_item := _room_decor_item(str(area_data.get("default_door_style_id", "")))
				assert_false(door_item.is_empty(), "%s public area entrance should configure default door decor" % area_data.get("id", ""))
				assert_eq(str(door_item.get("category", "")), "door", "%s public area entrance door should point at door decor" % area_data.get("id", ""))
			else:
				assert_false(area_data.has("default_door_style_id"), "%s public area without entrance door should not configure door decor" % area_data.get("id", ""))
	var apartment_visuals := _load_json_dict("res://data/apartment_visuals.json")
	var roof_theme: Dictionary = apartment_visuals.get("roof_theme", {})
	var default_roof_item := _room_decor_item(str(roof_theme.get("default_roof_style_id", "")))
	assert_false(default_roof_item.is_empty(), "apartment roof should configure a default roof decor")
	assert_eq(str(default_roof_item.get("category", "")), "roof", "apartment default roof style should point at roof decor")
	assert_eq(int(roof_theme.get("total_width_tiles", 0)), 17, "apartment roof should support a configured total width")
	var roof_offset: Array = roof_theme.get("offset_pixels", [])
	assert_eq(roof_offset.size(), 2, "apartment roof should support configured pixel offset")
	assert_eq(int(roof_offset[0]), -16, "apartment roof x offset should allow one-tile left overflow")
	assert_eq(int(roof_offset[1]), -16, "apartment roof y offset should be configurable")
	var service_core_defaults: Dictionary = apartment_visuals.get("service_core_defaults", {})
	for pair in [
		["wallpaper_id", "wallpaper"],
		["wall_style_id", "wall"]
	]:
		var decor_item := _room_decor_item(str(service_core_defaults.get(str(pair[0]), "")))
		assert_false(decor_item.is_empty(), "service core should configure %s" % pair[0])
		assert_eq(str(decor_item.get("category", "")), str(pair[1]), "service core %s should point at the expected decor category" % pair[0])
	var room_301 := _room_data("room_301")
	var room_302 := _room_data("room_302")
	assert_false(bool(room_301.get("initial_unlocked", true)), "301 should start as a pending room")
	assert_false(bool(room_302.get("initial_unlocked", true)), "302 should start as a pending room")
	assert_eq(int(room_301.get("build_cost", 0)), 300, "301 should own its independent construction cost")
	assert_eq(int(room_302.get("build_cost", 0)), 400, "302 should own its independent construction cost")
	assert_eq(int(room_301.get("required_apartment_level", 0)), 1, "301 should own its apartment-level gate")


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
			var cell_width := float(maxi(1, int(frame_tiles[0])) * tile_size) / float(maxi(1, int(grid_size[0])))
			var cell_height := float(maxi(1, int(frame_tiles[1])) * tile_size) / float(maxi(1, int(grid_size[1])))
			assert_eq(Vector2(cell_width, cell_height), Vector2(16.0, 16.0), "%s placement cells should be 16x16 pixels" % str(layout_data.get("label", "")))


func test_room_building_rules_unlock_same_floor_independently() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	var task_source := FileAccess.get_file_as_string("res://scripts/autoload/TaskManager.gd")
	var building_source := FileAccess.get_file_as_string("res://scripts/building/ApartmentBuilding.gd")
	var floor_source := FileAccess.get_file_as_string("res://scripts/building/Floor.gd")
	assert_true(state_source.contains("func build_room(room_id: String)"), "GameState should expose room-based construction")
	assert_true(state_source.contains("func is_room_buildable(room_id: String)"), "GameState should expose buildability by room id")
	assert_true(state_source.contains("_lower_room_floors_complete"), "Room building should gate higher floors on lower-floor completion")
	assert_true(state_source.contains("stats[\"room_built_count\"]"), "Room building should update room-built statistics")
	assert_true(state_source.contains("GameEvents.room_built.emit(room_id, floor_index)"), "Room building should emit room_built with room id and floor index")
	assert_true(state_source.contains("TaskManager.notify_event(\"room_built\""), "Room building should notify tasks with the room-built event")
	assert_false(state_source.contains("func build_floor"), "GameState should not keep floor-based construction")
	assert_false(state_source.contains("highest_built_floor"), "GameState should not use highest_built_floor as construction authority")
	assert_true(task_source.contains("\"room_built_count\""), "TaskManager should support room-built-count tasks")
	assert_false(task_source.contains("\"floor_built\""), "TaskManager should not use floor-built tasks")
	assert_true(building_source.contains("GameState.get_space_decor_id(roof_target_ref, ConfigManager.DECOR_ROOF)"), "ApartmentBuilding should render the runtime selected apartment roof decor")
	assert_true(building_source.contains("ConfigManager.apartment_roof_theme_for_style(roof_style_id)"), "ApartmentBuilding should combine roof layout with the selected roof style")
	assert_true(building_source.contains("GameState.is_floor_visible(floor_index)"), "ApartmentBuilding should size visible floors from room buildability")
	assert_true(floor_source.contains("left_build_slot"), "Floor should own a left pending-room slot")
	assert_true(floor_source.contains("right_build_slot"), "Floor should own a right pending-room slot")
	assert_true(floor_source.contains("GameState.is_room_buildable"), "Floor should show pending-room slots from room buildability")


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
	assert_true(rules_source.contains("door_cells_for_layer"), "placement rules should keep a compatibility hook for route helpers")
	assert_false(rules_source.contains("in door_cells"), "placement rules should not reserve door cells after doors became outward-opening")
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
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "chair_basic", _furniture_data("chair_basic"), furniture_lookup, [0, 3]), "outward-opening doors should not block floor furniture at the old door cell")
	assert_true(FurniturePlacementRules.can_place_furniture_in_room(room, "painting_small", _furniture_data("painting_small"), furniture_lookup, [0, 0]), "door cells should not block wall furniture")

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


func test_coin_gain_sources_are_wired_to_recorded_signal() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	var top_bar_source := FileAccess.get_file_as_string("res://scripts/ui/TopStatusBar.gd")
	assert_true(game_state_source.contains("coin_gain_recorded.emit(amount, source)"), "coin gains should emit a source-aware signal")
	assert_true(top_bar_source.contains("source == \"auto_income\""), "top bar popup should only merge automatic income")


func test_region_rent_limit_blocks_expensive_candidates() -> void:
	var affordable_region := _region_data("region_affordable")
	var expected_rent: float = _calculate_room_rent("tenant_student_01", 100, 60)
	assert_true(expected_rent > float(affordable_region.get("max_rent_per_minute", 0.0)), "starter region should reject candidates whose expected rent exceeds its cap")


func _room_data(room_id: String) -> Dictionary:
	for room in rooms:
		var room_data: Dictionary = room
		if str(room_data.get("id", "")) == room_id:
			return room_data
	return {}
