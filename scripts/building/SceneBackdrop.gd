class_name SceneBackdrop
extends Node2D

const TILE_SIZE := Vector2i(16, 16)

@export_range(1, 3, 1) var ground_rows: int = 3

var ground_band_height: float:
	get:
		return float(clampi(ground_rows, 1, 3) * TILE_SIZE.y)
