class_name FurniturePreview
extends TextureRect

const DEFAULT_FURNITURE_TEXTURE := preload("res://assets/pixel_spaces/furniture/Furniture.png")

@export_group("Asset Overrides")
@export var override_configured_asset := false
@export var asset_texture: Texture2D = DEFAULT_FURNITURE_TEXTURE
@export var asset_region := Rect2(0.0, 49.0, 28.0, 14.0)

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
	_apply_asset_or_export(asset, Color("#b9784a"), Vector2i(56, 56))
	_update_tint()

func set_valid(value: bool) -> void:
	valid = value
	_update_tint()

func _update_tint() -> void:
	modulate = Color(1, 1, 1, 0.78) if valid else Color(1, 0.72, 0.72, 0.72)

func _apply_asset_or_export(asset_config: Dictionary, fallback: Color, placeholder_size := Vector2i(56, 56)) -> void:
	if not override_configured_asset:
		AssetResolver.apply_asset_to_texture_rect(self, asset_config, fallback, placeholder_size)
		return
	texture = _atlas_texture_from_export(asset_texture, asset_region)
	if texture == null:
		texture = AssetResolver.texture_from_asset(asset_config, fallback, placeholder_size)

func _atlas_texture_from_export(source_texture: Texture2D, region: Rect2) -> Texture2D:
	if source_texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = region
	return atlas
