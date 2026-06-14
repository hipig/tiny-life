class_name SceneBackdrop
extends Node2D

const TILE_SIZE := Vector2i(16, 16)
const DEFAULT_GROUND_ROWS := 3
const DEFAULT_GROUND_OFFSET_TILES := 0
const META_GROUND_ROWS := &"ground_rows"
const META_GROUND_OFFSET_TILES := &"ground_offset_tiles"

var ground_rows: int:
	get:
		var config := get_node_or_null("SceneConfig")
		if config == null or not config.has_meta(META_GROUND_ROWS):
			return DEFAULT_GROUND_ROWS
		return clampi(int(config.get_meta(META_GROUND_ROWS)), 1, DEFAULT_GROUND_ROWS)

var ground_offset_tiles: int:
	get:
		var config := get_node_or_null("SceneConfig")
		if config == null or not config.has_meta(META_GROUND_OFFSET_TILES):
			return DEFAULT_GROUND_OFFSET_TILES
		return maxi(0, int(config.get_meta(META_GROUND_OFFSET_TILES)))

var ground_offset_pixels: float:
	get:
		return float(ground_offset_tiles * TILE_SIZE.y)

var ground_band_height: float:
	get:
		return float(ground_rows * TILE_SIZE.y)
