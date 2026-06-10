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


func test_coin_gain_sources_are_wired_to_recorded_signal() -> void:
	var game_state_source := FileAccess.get_file_as_string("res://scripts/autoload/GameState.gd")
	var top_bar_source := FileAccess.get_file_as_string("res://scripts/ui/TopStatusBar.gd")
	assert_true(game_state_source.contains("coin_gain_recorded.emit(amount, source)"), "coin gains should emit a source-aware signal")
	assert_true(top_bar_source.contains("source == \"auto_income\""), "top bar popup should only merge automatic income")


func test_region_rent_limit_blocks_expensive_candidates() -> void:
	var affordable_region := _region_data("region_affordable")
	var expected_rent: float = _calculate_room_rent("tenant_student_01", 100, 60)
	assert_true(expected_rent > float(affordable_region.get("max_rent_per_minute", 0.0)), "starter region should reject candidates whose expected rent exceeds its cap")
