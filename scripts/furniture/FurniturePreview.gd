class_name FurniturePreview
extends TextureRect

var furniture_id := ""
var grid_pos: Array = [0, 0]
var valid := false

func _ready() -> void:
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
	modulate = Color(1, 1, 1, 0.78) if valid else Color(1, 0.72, 0.72, 0.72)
