class_name RoomShell
extends Control

@onready var apartment_tile_map: ApartmentTileMap = $ApartmentTileMap
@onready var room_door: TrafficDoor = $RoomDoor
@onready var name_badge: Label = $RoomNameBadge
@onready var rent_badge: Label = $RoomRentBadge
@onready var visual_layer: Control = $RoomVisualLayer
@onready var placement_grid_layer: Control = $PlacementGridLayer

var roof_visible := false
var construction_visible := false

func apply_layout(room_pixel_size: Vector2, _wall_inset: float, _floor_height: float, _roof_height: float, frame_tiles := Vector2i(6, 4), tile_theme: Dictionary = {}, edge_sides: Dictionary = {}, body_sides: Dictionary = {}, door_side := "left", door_mirrored := false, door_theme: Dictionary = {}) -> void:
	custom_minimum_size = room_pixel_size
	size = room_pixel_size
	if apartment_tile_map != null:
		apartment_tile_map.render_room_skeleton(frame_tiles, tile_theme, roof_visible, construction_visible, edge_sides, body_sides, door_side)
	_layout_room_door(room_pixel_size, door_side, door_mirrored)
	if room_door != null:
		room_door.apply_visual_theme(door_theme)

func set_roof_visible(value: bool) -> void:
	roof_visible = value
	if apartment_tile_map != null:
		apartment_tile_map.set_roof_visible(value)

func set_construction_visible(value: bool) -> void:
	construction_visible = value
	if apartment_tile_map != null:
		apartment_tile_map.set_construction_visible(value)

func clear_dynamic_views() -> void:
	for child in visual_layer.get_children():
		child.queue_free()

func get_room_door() -> TrafficDoor:
	return room_door

func _layout_room_door(room_pixel_size: Vector2, door_side: String, door_mirrored: bool) -> void:
	if room_door == null:
		return
	var normalized_side := str(door_side).strip_edges().to_lower()
	var door_x := -ApartmentTileMap.TILE_SIZE * 0.5
	if normalized_side == "right":
		door_x = room_pixel_size.x + ApartmentTileMap.TILE_SIZE * 0.5
	room_door.position = Vector2(
		door_x,
		maxf(ApartmentTileMap.TILE_SIZE, room_pixel_size.y)
	)
	room_door.scale.x = -1.0 if door_mirrored else 1.0
