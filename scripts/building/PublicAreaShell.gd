class_name PublicAreaShell
extends Control

@onready var apartment_tile_map: ApartmentTileMap = $ApartmentTileMap
@onready var exit_door: TrafficDoor = $TrafficRoot/ExitDoor
@onready var area_name_label: Label = $AreaNameLabel

var target_ref: Dictionary = {}

func apply_layout(area_pixel_size: Vector2, frame_tiles := Vector2i(6, 4), tile_theme: Dictionary = {}, edge_sides: Dictionary = {}, body_sides: Dictionary = {}, label_text := "", has_entrance_door := false, door_side := "left", door_mirrored := false, door_theme: Dictionary = {}, next_target_ref: Dictionary = {}) -> void:
	target_ref = next_target_ref.duplicate(true)
	custom_minimum_size = area_pixel_size
	size = area_pixel_size
	if apartment_tile_map != null:
		var entrance_side := str(door_side).strip_edges().to_lower() if has_entrance_door else ""
		apartment_tile_map.render_room_skeleton(frame_tiles, tile_theme, false, false, edge_sides, body_sides, entrance_side)
	_layout_exit_door(area_pixel_size, has_entrance_door, door_side, door_mirrored)
	if exit_door != null:
		if has_entrance_door and not door_theme.is_empty():
			exit_door.apply_visual_theme(door_theme)
		else:
			exit_door.set_closed()
	if area_name_label != null:
		area_name_label.text = label_text

func get_exit_door() -> TrafficDoor:
	if exit_door != null and exit_door.visible:
		return exit_door
	return null

func get_exit_anchor_local_position() -> Vector2:
	if exit_door != null and exit_door.visible:
		return exit_door.position
	return Vector2.ZERO

func _layout_exit_door(area_pixel_size: Vector2, has_entrance_door: bool, door_side: String, door_mirrored: bool) -> void:
	if exit_door == null:
		return
	exit_door.visible = has_entrance_door
	if not has_entrance_door:
		return
	var normalized_side := str(door_side).strip_edges().to_lower()
	var door_x := ApartmentTileMap.TILE_SIZE * 0.5
	if normalized_side == "right":
		door_x = area_pixel_size.x - ApartmentTileMap.TILE_SIZE * 0.5
	exit_door.position = Vector2(
		door_x,
		maxf(ApartmentTileMap.TILE_SIZE, area_pixel_size.y)
	)
	exit_door.scale.x = -1.0 if door_mirrored else 1.0

func _gui_input(event: InputEvent) -> void:
	if target_ref.is_empty():
		return
	if not _can_open_decor_panel():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		UIManager.open_space_decor_panel(target_ref, ConfigManager.DECOR_WALLPAPER)
		accept_event()

func _can_open_decor_panel() -> bool:
	return UIManager.current_state == UIManager.UIState.NORMAL \
		or UIManager.current_state == UIManager.UIState.ROOM_PANEL \
		or UIManager.current_state == UIManager.UIState.SPACE_DECOR_PANEL
