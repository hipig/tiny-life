class_name PublicAreaShell
extends Control

@onready var apartment_tile_map: ApartmentTileMap = $ApartmentTileMap
@onready var exit_door: TrafficDoor = $TrafficRoot/ExitDoor
@onready var area_name_label: Label = $AreaNameLabel

func apply_layout(area_pixel_size: Vector2, frame_tiles := Vector2i(6, 4), tile_theme: Dictionary = {}, edge_sides: Dictionary = {}, body_sides: Dictionary = {}, label_text := "", has_entrance_door := false, door_side := "left", door_mirrored := false) -> void:
	custom_minimum_size = area_pixel_size
	size = area_pixel_size
	if apartment_tile_map != null:
		var entrance_side := str(door_side).strip_edges().to_lower() if has_entrance_door else ""
		apartment_tile_map.render_room_skeleton(frame_tiles, tile_theme, false, false, edge_sides, body_sides, entrance_side)
	_layout_exit_door(area_pixel_size, has_entrance_door, door_side, door_mirrored)
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
