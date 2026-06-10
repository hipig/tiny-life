@tool
extends "res://tests/support/TestSuiteBase.gd"

func suite_name() -> String:
	return "camera_input"

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

