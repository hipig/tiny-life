extends Node

func color_from_asset(asset_config: Dictionary, fallback := Color.WHITE) -> Color:
	var hex := str(asset_config.get("color", ""))
	if hex.is_empty():
		return fallback
	return Color.html(hex)

func apply_asset_to_color_rect(rect: ColorRect, asset_config: Dictionary, fallback := Color.WHITE) -> void:
	rect.color = color_from_asset(asset_config, fallback)

