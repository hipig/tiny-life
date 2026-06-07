class_name ApartmentTileMap
extends Node2D

@onready var wall_layer: TileMapLayer = $WallTileMap
@onready var floor_layer: TileMapLayer = $FloorTileMap
@onready var infrastructure_layer: TileMapLayer = $InfrastructureTileMap
@onready var roof_layer: TileMapLayer = $RoofTileMap
@onready var construction_layer: TileMapLayer = $ConstructionTileMap

func set_roof_visible(value: bool) -> void:
	if roof_layer != null:
		roof_layer.visible = value

func set_construction_visible(value: bool) -> void:
	if construction_layer != null:
		construction_layer.visible = value

func set_locked_visuals(locked: bool) -> void:
	var tint := Color(0.62, 0.62, 0.62, 0.58) if locked else Color.WHITE
	for layer in [wall_layer, floor_layer, infrastructure_layer, roof_layer, construction_layer]:
		if layer != null:
			layer.modulate = tint
