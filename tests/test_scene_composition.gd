@tool
extends "res://tests/support/TestSuiteBase.gd"

func suite_name() -> String:
	return "scene_composition"

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
	assert_true(main_source.contains("tenant_presence_changed.connect"), "Main should refresh open tenant panels when presence changes")
	assert_true(main_source.contains("_refresh_tenant_panel_if_open"), "Main should refresh an open TenantPanel without rebuilding the building")
	assert_true(main_source.contains("decor_return_room_id"), "Main should remember when a room opened the independent decor popup")
	assert_true(main_source.contains("UIManager.open_room_panel(return_room_id, \"decor\")"), "Closing a room-launched decor popup should return to that room's decor tab")
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
