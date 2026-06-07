class_name BuildSlotShell
extends HBoxContainer

@onready var service_core: Control = $BuildServiceCore
@onready var service_tile_map: ApartmentTileMap = $BuildServiceCore/ServiceCoreTileMap
@onready var room_shell: Control = $BuildRoomShell
@onready var apartment_tile_map: ApartmentTileMap = $BuildRoomShell/ApartmentTileMap
@onready var icon: TextureRect = $BuildRoomShell/BuildSlotStatusPanel/MarginContainer/StatusRow/BuildHammer
@onready var label: Label = $BuildRoomShell/BuildSlotStatusPanel/MarginContainer/StatusRow/BuildSlotLabel

func apply_layout(slot_size: Vector2, service_width: float, _wall_inset: float, _floor_height: float, _roof_height: float) -> void:
	custom_minimum_size = slot_size
	size = custom_minimum_size
	var room_width := slot_size.x - service_width
	var slot_height := slot_size.y
	service_core.custom_minimum_size = Vector2(service_width, slot_height)
	room_shell.custom_minimum_size = Vector2(room_width, slot_height)
	if service_tile_map != null:
		service_tile_map.set_roof_visible(true)
		service_tile_map.set_construction_visible(false)
	if apartment_tile_map != null:
		apartment_tile_map.set_roof_visible(true)
		apartment_tile_map.set_construction_visible(true)

func set_locked_visuals(locked: bool) -> void:
	var tint := Color(0.62, 0.62, 0.62, 0.58) if locked else Color.WHITE
	if service_tile_map != null:
		service_tile_map.set_locked_visuals(locked)
	if apartment_tile_map != null:
		apartment_tile_map.set_locked_visuals(locked)
	if icon != null:
		icon.modulate = tint
	if label != null:
		label.modulate = tint
