extends TextureRect

var instance_data: Dictionary = {}
var furniture_id := ""

func _ready() -> void:
	custom_minimum_size = Vector2(26, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func setup(data: Dictionary) -> void:
	instance_data = data
	furniture_id = str(instance_data.get("furniture_id", ""))
	var furniture_data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var asset: Dictionary = furniture_data.get("asset", {})
	AssetResolver.apply_asset_to_texture_rect(self, asset, Color("#b9784a"), Vector2i(26, 26))
	tooltip_text = str(furniture_data.get("name", "家具"))
