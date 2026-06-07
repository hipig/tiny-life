class_name RoomShell
extends Control

@onready var apartment_tile_map: ApartmentTileMap = $ApartmentTileMap
@onready var name_badge: Label = $RoomNameBadge
@onready var rent_badge: Label = $RoomRentBadge
@onready var visual_layer: Control = $RoomVisualLayer
@onready var placement_grid_layer: Control = $PlacementGridLayer

func apply_layout(room_size: Vector2, _wall_inset: float, _floor_height: float, _roof_height: float) -> void:
	custom_minimum_size = room_size
	size = room_size

func set_roof_visible(value: bool) -> void:
	if apartment_tile_map != null:
		apartment_tile_map.set_roof_visible(value)

func clear_dynamic_views() -> void:
	for child in visual_layer.get_children():
		child.queue_free()
