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

