@tool
class_name FloorServiceCore
extends Control

@onready var service_tile_map: ApartmentTileMap = $ServiceCoreTileMap
@onready var exit_door: TrafficDoor = $TrafficRoot/ExitDoor
@onready var elevator_door: TrafficDoor = $TrafficRoot/ElevatorDoor
@onready var floor_label: Label = $FloorLabel

var floor_index := 1

func apply_layout(service_width: float, floor_height: float, index := 1, edge_sides: Dictionary = {}, body_sides: Dictionary = {}) -> void:
	floor_index = index
	custom_minimum_size = Vector2(service_width, floor_height)
	size = custom_minimum_size
	if service_tile_map != null:
		var frame_tiles := Vector2i(
			maxi(3, int(round(service_width / ApartmentTileMap.TILE_SIZE))),
			maxi(4, int(round(floor_height / ApartmentTileMap.TILE_SIZE)))
		)
		service_tile_map.render_room_skeleton(frame_tiles, {}, false, false, edge_sides, body_sides, "")
	_layout_traffic_nodes(service_width, floor_height)

func set_floor_label(text: String) -> void:
	floor_label.text = text

func get_exit_door() -> TrafficDoor:
	if exit_door != null and exit_door.visible:
		return exit_door
	return null

func get_elevator_door() -> TrafficDoor:
	return elevator_door

func get_exit_anchor_local_position() -> Vector2:
	if exit_door != null and exit_door.visible:
		return exit_door.position
	return Vector2.ZERO

func get_elevator_anchor_local_position() -> Vector2:
	return Vector2(size.x * 0.5, maxf(ApartmentTileMap.TILE_SIZE, size.y))

func _layout_traffic_nodes(service_width: float, floor_height: float) -> void:
	if exit_door != null:
		exit_door.visible = false
		exit_door.position = Vector2(-ApartmentTileMap.TILE_SIZE * 0.5, maxf(ApartmentTileMap.TILE_SIZE, floor_height))
	if elevator_door != null:
		elevator_door.visible = true
		elevator_door.position = Vector2(service_width * 0.5, maxf(ApartmentTileMap.TILE_SIZE, floor_height - ApartmentTileMap.TILE_SIZE))
