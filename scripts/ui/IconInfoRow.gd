class_name IconInfoRow
extends PanelContainer

@onready var row: HBoxContainer = $Row
@onready var icon: TextureRect = $Row/Icon
@onready var title_label: Label = $Row/Texts/TitleLabel
@onready var detail_label: Label = $Row/Texts/DetailLabel

func setup(icon_file: String, title: String, detail := "", color_name := "white") -> HBoxContainer:
	set_icon(icon_file)
	set_title(title)
	set_detail(detail)
	return row

func set_title(title: String) -> void:
	title_label.text = title

func set_detail(detail := "") -> void:
	detail_label.text = detail
	detail_label.visible = not detail.is_empty()

func set_icon(icon_file: String) -> void:
	if icon_file.is_empty():
		return
	AssetResolver.apply_asset_to_texture_rect(icon, UIPanelFactory.icon_asset(icon_file), Color("#fff4dc"), Vector2i(16, 16))
