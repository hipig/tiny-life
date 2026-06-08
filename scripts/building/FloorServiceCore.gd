class_name FloorServiceCore
extends Control

@onready var service_tile_map: ApartmentTileMap = $ServiceCoreTileMap
@onready var floor_label: Label = $FloorLabel

func apply_layout(service_width: float, floor_height: float) -> void:
	custom_minimum_size = Vector2(service_width, floor_height)
	size = custom_minimum_size
	if service_tile_map != null:
		var frame_tiles := Vector2i(
			maxi(3, int(round(service_width / ApartmentTileMap.TILE_SIZE))),
			maxi(3, int(round(floor_height / ApartmentTileMap.TILE_SIZE)))
		)
		service_tile_map.render_room_skeleton(frame_tiles, {}, false, false)

func set_floor_label(text: String) -> void:
	floor_label.text = text
