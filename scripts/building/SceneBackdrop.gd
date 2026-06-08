class_name SceneBackdrop
extends Node2D

const TILE_SIZE := Vector2i(16, 16)
const DEFAULT_GROUND_ROWS := 3
const META_GROUND_ROWS := &"ground_rows"

var ground_rows: int:
	get:
		var config := get_node_or_null("SceneConfig")
		if config == null or not config.has_meta(META_GROUND_ROWS):
			return DEFAULT_GROUND_ROWS
		return clampi(int(config.get_meta(META_GROUND_ROWS)), 1, DEFAULT_GROUND_ROWS)

var ground_band_height: float:
	get:
		return float(ground_rows * TILE_SIZE.y)
