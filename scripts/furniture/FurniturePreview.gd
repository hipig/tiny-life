class_name FurniturePreview
extends TextureRect

var furniture_id := ""
var grid_pos: Array = [0, 0]
var valid := false

func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_update_tint()

func setup(id: String, target_grid_pos := [0, 0], is_valid := false) -> void:
	furniture_id = id
	grid_pos = target_grid_pos
	valid = is_valid
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var asset: Dictionary = data.get("asset", {})
	AssetResolver.apply_asset_to_texture_rect(self, asset, Color("#b9784a"), Vector2i(56, 56))
	_update_tint()

func set_valid(value: bool) -> void:
	valid = value
	_update_tint()

func _update_tint() -> void:
	modulate = Color("#9be7a1") if valid else Color("#f4a3a3")
