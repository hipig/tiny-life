@tool
extends "res://tests/support/TestSuiteBase.gd"

func suite_name() -> String:
	return "pixel_assets"

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
		var furniture_id := str(furniture_data.get("id", ""))
		var orientations: Dictionary = furniture_data.get("orientations", {})
		assert_true(orientations.has(str(furniture_data.get("default_orientation", "default"))), "%s should expose its default visual orientation" % furniture_id)
		for orientation_key in orientations.keys():
			var orientation_data: Dictionary = orientations[orientation_key]
			var asset: Dictionary = orientation_data.get("asset", {})
			assert_false(str(asset.get("type", "placeholder")) == "placeholder", "%s %s should use a Pixel Spaces visual asset" % [furniture_id, orientation_key])
			assert_true(_asset_texture_exists(asset), "%s %s furniture asset texture should exist" % [furniture_id, orientation_key])
	for tenant in tenants:
		var tenant_data: Dictionary = tenant
		var asset: Dictionary = tenant_data.get("asset", {})
		assert_eq(str(asset.get("type", "")), "spritesheet_animation", "%s should use sprite animations" % tenant_data.get("id", ""))
		assert_true(_asset_texture_exists(asset), "%s tenant spritesheet should exist" % tenant_data.get("id", ""))
		var frame_size: Array = asset.get("frame_size", [])
		assert_true(frame_size.size() >= 2, "%s tenant spritesheet should declare frame_size" % tenant_data.get("id", ""))
		if frame_size.size() >= 2:
			assert_eq(Vector2i(int(frame_size[0]), int(frame_size[1])), Vector2i(32, 32), "%s tenant spritesheet frames should use the configured 32x32 grid" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("walk"), "%s should expose walk animation" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("idle"), "%s should expose idle animation" % tenant_data.get("id", ""))
		assert_true(asset.get("animations", {}).has("jump"), "%s should expose jump animation" % tenant_data.get("id", ""))
		var avatar_offset: Array = asset.get("avatar_offset", [])
		assert_true(avatar_offset.size() >= 2, "%s tenant spritesheet should declare avatar_offset" % tenant_data.get("id", ""))
	for room in rooms:
		var room_data: Dictionary = room
		for pair in [
			["default_wallpaper_id", "wallpaper"],
			["default_wall_style_id", "wall"],
			["default_door_style_id", "door"]
		]:
			var decor_item := _room_decor_item(str(room_data.get(str(pair[0]), "")))
			assert_false(decor_item.is_empty(), "%s should configure %s" % [room_data.get("id", ""), pair[0]])
			assert_eq(str(decor_item.get("category", "")), str(pair[1]), "%s %s should point at the right decor category" % [room_data.get("id", ""), pair[0]])
		assert_false(room_data.has("wall_asset"), "%s should not depend on a hard-coded wall_asset" % room_data.get("id", ""))
		assert_false(room_data.has("infrastructure_asset"), "%s should not depend on a hard-coded infrastructure_asset" % room_data.get("id", ""))
		assert_false(room_data.has("floor_asset"), "%s should not configure a separate floor asset" % room_data.get("id", ""))
	var decor_categories := {}
	for item in room_decor.get("items", []):
		var decor_item: Dictionary = item
		var category := str(decor_item.get("category", ""))
		decor_categories[category] = true
		assert_false(str(decor_item.get("id", "")).is_empty(), "room decor items should declare ids")
		assert_true(_asset_texture_exists(decor_item.get("preview_asset", {})), "%s decor preview asset should exist" % decor_item.get("id", ""))
		match category:
			"wallpaper":
				assert_false(decor_item.has("wallpaper_region"), "%s wallpaper should use explicit top/middle/bottom theme tiles instead of a single region" % decor_item.get("id", ""))
				var theme: Dictionary = decor_item.get("theme", {})
				var pattern: Dictionary = theme.get("wallpaper_pattern", {})
				for row_key in ["top", "middle", "bottom"]:
					var row_tiles: Array = pattern.get(row_key, [])
					assert_true(row_tiles.size() > 0, "%s wallpaper should declare %s row tiles" % [decor_item.get("id", ""), row_key])
					for tile in row_tiles:
						assert_true(tile is Array and tile.size() >= 2, "%s wallpaper %s row tiles should be atlas pairs" % [decor_item.get("id", ""), row_key])
			"wall":
				assert_false(decor_item.has("wall_region"), "%s wall should use explicit ApartmentTileMap theme tiles instead of a single region" % decor_item.get("id", ""))
				var theme: Dictionary = decor_item.get("theme", {})
				assert_true(theme.has("wall_body_source_id"), "%s wall should declare its TileSet source id" % decor_item.get("id", ""))
				for tile_key in [
					"body_top_left_corner_tile",
					"body_top_right_corner_tile",
					"body_bottom_left_corner_tile",
					"body_bottom_right_corner_tile"
				]:
					var tile: Array = theme.get(tile_key, [])
					assert_true(tile.size() >= 2, "%s wall should declare %s" % [decor_item.get("id", ""), tile_key])
				for tile_list_key in [
					"body_top_edge_tiles",
					"body_left_edge_tiles",
					"body_left_door_edge_tiles",
					"body_right_door_edge_tiles",
					"body_right_edge_tiles",
					"body_bottom_edge_tiles"
				]:
					var tiles: Array = theme.get(tile_list_key, [])
					assert_true(tiles.size() > 0, "%s wall should declare %s" % [decor_item.get("id", ""), tile_list_key])
					assert_true(tiles[0] is Array and tiles[0].size() >= 2, "%s wall %s entries should be atlas pairs" % [decor_item.get("id", ""), tile_list_key])
			"door":
				var door_asset: Dictionary = decor_item.get("door_asset", {})
				assert_eq(str(door_asset.get("type", "")), "spritesheet_animation", "%s door should use animated spritesheet config" % decor_item.get("id", ""))
				assert_true(_asset_texture_exists(door_asset), "%s door asset texture should exist" % decor_item.get("id", ""))
				assert_true(door_asset.get("animations", {}).has("default"), "%s door should expose a default animation" % decor_item.get("id", ""))
				assert_true(door_asset.get("animations", {}).has("open"), "%s door should expose an open animation" % decor_item.get("id", ""))
				assert_true(door_asset.get("animations", {}).has("close"), "%s door should expose a close animation" % decor_item.get("id", ""))
				for animation_name in ["default", "open", "close"]:
					var frames: Array = door_asset.get("animations", {}).get(animation_name, [])
					assert_eq(frames.size(), 4, "%s door %s animation should declare 4 frames" % [decor_item.get("id", ""), animation_name])
				var frame_size: Array = door_asset.get("frame_size", [])
				if frame_size.size() >= 2:
					assert_eq(Vector2i(int(frame_size[0]), int(frame_size[1])), Vector2i(16, 32), "%s door frame size should match room doors" % decor_item.get("id", ""))
				assert_eq(int(decor_item.get("closed_frame", -1)), 0, "%s door should use frame 0 as closed" % decor_item.get("id", ""))
				assert_eq(int(decor_item.get("open_frame", -1)), 3, "%s door should use frame 3 as fully open" % decor_item.get("id", ""))
			"roof":
				var theme: Dictionary = decor_item.get("theme", {})
				assert_true(theme.has("wall_edge_source_id"), "%s roof should declare its TileSet source id" % decor_item.get("id", ""))
				for tile_key in ["roof_left_tile", "roof_right_tile"]:
					var tile: Array = theme.get(tile_key, [])
					assert_true(tile.size() >= 2, "%s roof should declare %s" % [decor_item.get("id", ""), tile_key])
				var roof_tiles: Array = theme.get("roof_tiles", [])
				assert_true(roof_tiles.size() > 0, "%s roof should declare repeatable roof tiles" % decor_item.get("id", ""))
				assert_true(roof_tiles[0] is Array and roof_tiles[0].size() >= 2, "%s roof tile entries should be atlas pairs" % decor_item.get("id", ""))
	assert_true(decor_categories.has("wallpaper"), "room_decor should include wallpaper items")
	assert_true(decor_categories.has("wall"), "room_decor should include wall items")
	assert_true(decor_categories.has("door"), "room_decor should include door items")
	assert_true(decor_categories.has("roof"), "room_decor should include roof items")
	for floor in floors:
		var floor_data: Dictionary = floor
		assert_true(_asset_texture_exists(floor_data.get("floor_icon_asset", {})), "%dF icon asset should exist" % int(floor_data.get("floor_index", 0)))
		assert_true(_asset_texture_exists(floor_data.get("build_icon_asset", {})), "%dF build icon should exist" % int(floor_data.get("floor_index", 0)))
	var ui_scenes := FileAccess.get_file_as_string("res://scenes/ui/FloatingMenu.tscn") + FileAccess.get_file_as_string("res://scenes/ui/TopStatusBar.tscn")
	assert_true(ui_scenes.contains("res://assets/pixel_spaces/icons/"), "core UI scenes should reference Pixel Spaces icons")
