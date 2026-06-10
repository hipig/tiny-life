class_name BuildSlotShell
extends HBoxContainer

@onready var service_core: Control = $BuildServiceCore
@onready var service_tile_map: ApartmentTileMap = $BuildServiceCore/ServiceCoreTileMap
@onready var room_shell: Control = $BuildRoomShell
@onready var apartment_tile_map: ApartmentTileMap = $BuildRoomShell/ApartmentTileMap
@onready var construction_cover: TextureRect = $BuildRoomShell/ConstructionCover
@onready var icon: TextureRect = $BuildRoomShell/BuildSlotStatusPanel/MarginContainer/StatusRow/BuildHammer
@onready var label: Label = $BuildRoomShell/BuildSlotStatusPanel/MarginContainer/StatusRow/BuildSlotLabel

func apply_layout(slot_size: Vector2, service_width: float, _wall_inset: float, _floor_height: float, _roof_height: float, frame_tiles := Vector2i(8, 4), tile_theme: Dictionary = {}) -> void:
	custom_minimum_size = slot_size
	size = custom_minimum_size
	var room_width := slot_size.x - service_width
	var slot_height := slot_size.y
	service_core.custom_minimum_size = Vector2(service_width, slot_height)
	room_shell.custom_minimum_size = Vector2(room_width, slot_height)
	if service_tile_map != null:
		var service_tiles := Vector2i(maxi(3, int(round(service_width / ApartmentTileMap.TILE_SIZE))), frame_tiles.y)
		service_tile_map.render_room_skeleton(service_tiles, tile_theme, true, false, _service_edge_sides(), _service_body_sides(), false)
	if apartment_tile_map != null:
		apartment_tile_map.render_room_skeleton(frame_tiles, tile_theme, true, true, _room_edge_sides(), {}, false)
	set_construction_visible(true)

func set_construction_visible(value: bool) -> void:
	if apartment_tile_map != null:
		apartment_tile_map.set_construction_visible(value)
	if construction_cover != null:
		construction_cover.visible = value

func set_locked_visuals(locked: bool) -> void:
	var tint := Color(0.62, 0.62, 0.62, 0.58) if locked else Color.WHITE
	if service_tile_map != null:
		service_tile_map.set_locked_visuals(locked)
	if apartment_tile_map != null:
		apartment_tile_map.set_locked_visuals(locked)
	if construction_cover != null:
		construction_cover.modulate = tint
	if icon != null:
		icon.modulate = tint
	if label != null:
		label.modulate = tint

func _service_edge_sides() -> Dictionary:
	return {
		"left": true,
		"right": false,
		"top": false,
		"bottom": false
	}

func _service_body_sides() -> Dictionary:
	return {
		"left": true,
		"right": false,
		"top": true,
		"bottom": true
	}

func _room_edge_sides() -> Dictionary:
	return {
		"left": false,
		"right": true,
		"top": false,
		"bottom": false
	}
