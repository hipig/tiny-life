class_name StatCard
extends PanelContainer

@onready var icon: TextureRect = $Row/Icon
@onready var title_label: Label = $Row/Texts/TitleLabel
@onready var value_label: Label = $Row/Texts/ValueLabel

func setup(title: String, value: String, icon_file := "Frame Icons/Star_full.png", color_name := "white") -> void:
	set_icon(icon_file)
	set_title(title)
	set_value(value)

func set_title(title: String) -> void:
	title_label.text = title

func set_value(value: String) -> void:
	value_label.text = value

func set_icon(icon_file: String) -> void:
	if icon_file.is_empty():
		return
	AssetResolver.apply_asset_to_texture_rect(icon, UIPanelFactory.icon_asset(icon_file), Color("#fff4dc"), Vector2i(16, 16))
