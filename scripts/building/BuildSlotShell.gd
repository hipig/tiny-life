class_name BuildSlotShell
extends HBoxContainer

@onready var left_room_shell: Control = $BuildLeftRoomShell
@onready var left_tile_map: ApartmentTileMap = $BuildLeftRoomShell/ApartmentTileMap
@onready var left_construction_cover: TextureRect = $BuildLeftRoomShell/ConstructionCover
@onready var service_core: Control = $BuildServiceCore
@onready var service_tile_map: ApartmentTileMap = $BuildServiceCore/ServiceCoreTileMap
@onready var right_room_shell: Control = $BuildRightRoomShell
@onready var right_tile_map: ApartmentTileMap = $BuildRightRoomShell/ApartmentTileMap
@onready var right_construction_cover: TextureRect = $BuildRightRoomShell/ConstructionCover
@onready var icon: TextureRect = $BuildRightRoomShell/BuildSlotStatusPanel/MarginContainer/StatusRow/BuildHammer
@onready var label: Label = $BuildRightRoomShell/BuildSlotStatusPanel/MarginContainer/StatusRow/BuildSlotLabel

func apply_layout(slot_size: Vector2, service_width: float, _wall_inset: float, _floor_height: float, _roof_height: float, left_frame_tiles := Vector2i(6, 4), right_frame_tiles := Vector2i(6, 4), tile_theme: Dictionary = {}) -> void:
	custom_minimum_size = slot_size
	size = custom_minimum_size
	var slot_height := slot_size.y
	var left_size := Vector2(left_frame_tiles.x * ApartmentTileMap.TILE_SIZE, slot_height)
	var right_size := Vector2(right_frame_tiles.x * ApartmentTileMap.TILE_SIZE, slot_height)
	left_room_shell.custom_minimum_size = left_size
	service_core.custom_minimum_size = Vector2(service_width, slot_height)
	right_room_shell.custom_minimum_size = right_size
	if service_tile_map != null:
		var service_tiles := Vector2i(maxi(3, int(round(service_width / ApartmentTileMap.TILE_SIZE))), maxi(4, int(round(slot_height / ApartmentTileMap.TILE_SIZE))))
		service_tile_map.render_room_skeleton(service_tiles, tile_theme, true, false, _service_edge_sides(), _service_body_sides(), "")
	if left_tile_map != null:
		left_tile_map.render_room_skeleton(left_frame_tiles, tile_theme, true, true, _room_edge_sides("left"), {}, "")
	if right_tile_map != null:
		right_tile_map.render_room_skeleton(right_frame_tiles, tile_theme, true, true, _room_edge_sides("right"), {}, "")
	set_construction_visible(true)

func set_construction_visible(value: bool) -> void:
	for tile_map in [left_tile_map, right_tile_map]:
		if tile_map != null:
			tile_map.set_construction_visible(value)
	if left_construction_cover != null:
		left_construction_cover.visible = value
	if right_construction_cover != null:
		right_construction_cover.visible = value

func set_locked_visuals(locked: bool) -> void:
	var tint := Color(0.62, 0.62, 0.62, 0.58) if locked else Color.WHITE
	if service_tile_map != null:
		service_tile_map.set_locked_visuals(locked)
	for tile_map in [left_tile_map, right_tile_map]:
		if tile_map != null:
			tile_map.set_locked_visuals(locked)
	for cover in [left_construction_cover, right_construction_cover]:
		if cover != null:
			cover.modulate = tint
	if icon != null:
		icon.modulate = tint
	if label != null:
		label.modulate = tint

func _service_edge_sides() -> Dictionary:
	return {
		"left": false,
		"right": false,
		"top": false,
		"bottom": false
	}

func _service_body_sides() -> Dictionary:
	return {
		"left": false,
		"right": false,
		"top": true,
		"bottom": true
	}

func _room_edge_sides(layout_side: String) -> Dictionary:
	return {
		"left": layout_side == "left",
		"right": layout_side == "right",
		"top": false,
		"bottom": false
	}
