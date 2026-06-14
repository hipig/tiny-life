class_name FurniturePreview
extends TextureRect

const VALID_OUTLINE_COLOR := Color(0.27, 0.95, 0.45, 0.95)
const INVALID_OUTLINE_COLOR := Color(0.98, 0.22, 0.18, 0.95)
const VALID_FILL_COLOR := Color(0.27, 0.95, 0.45, 0.12)
const INVALID_FILL_COLOR := Color(0.98, 0.22, 0.18, 0.14)
const OUTLINE_WIDTH := 2.0

var furniture_id := ""
var anchor_pos: Array = [0.0, 0.0]
var orientation := FurniturePlacementRules.DEFAULT_ORIENTATION
var valid := false

func _ready() -> void:
	_update_tint()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func _draw() -> void:
	var rect := Rect2(Vector2.ONE, size - Vector2(2.0, 2.0))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(rect, VALID_FILL_COLOR if valid else INVALID_FILL_COLOR, true)
	draw_rect(rect, VALID_OUTLINE_COLOR if valid else INVALID_OUTLINE_COLOR, false, OUTLINE_WIDTH)

func setup(id: String, target_anchor_pos := [0.0, 0.0], is_valid := false, target_orientation := FurniturePlacementRules.DEFAULT_ORIENTATION) -> void:
	furniture_id = id
	anchor_pos = target_anchor_pos
	orientation = target_orientation
	valid = is_valid
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var asset := FurniturePlacementRules.orientation_asset_for(data, orientation)
	AssetResolver.apply_asset_to_texture_rect(self, asset, Vector2i(56, 56))
	rotation_degrees = FurniturePlacementRules.orientation_rotation_degrees_for(data, orientation)
	pivot_offset = size * 0.5
	_update_tint()

func set_valid(value: bool) -> void:
	valid = value
	_update_tint()

func _update_tint() -> void:
	modulate = Color(1, 1, 1, 0.78) if valid else Color(1, 0.72, 0.72, 0.72)
	queue_redraw()
