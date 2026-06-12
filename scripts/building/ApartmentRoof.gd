class_name ApartmentRoof
extends Node2D

@onready var tile_map: ApartmentTileMap = $ApartmentTileMap

func apply_layout(roof_theme: Dictionary) -> void:
	var offset := _vector2_from_array(roof_theme["offset_pixels"])
	position = offset
	if tile_map != null:
		tile_map.render_roof(int(roof_theme["total_width_tiles"]), roof_theme)
	visible = true

func hide_roof() -> void:
	visible = false

func _vector2_from_array(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	push_error("Expected a [x, y] roof offset array.")
	return Vector2.ZERO
