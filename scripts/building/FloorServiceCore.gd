class_name FloorServiceCore
extends Control

@onready var service_tile_map: ApartmentTileMap = $ServiceCoreTileMap
@onready var floor_label: Label = $FloorLabel

func apply_layout(service_width: float, floor_height: float) -> void:
	custom_minimum_size = Vector2(service_width, floor_height)
	size = custom_minimum_size

func set_floor_label(text: String) -> void:
	floor_label.text = text
