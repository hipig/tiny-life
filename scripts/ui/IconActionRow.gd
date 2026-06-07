class_name IconActionRow
extends PanelContainer

signal action_requested

@onready var icon: TextureRect = $Row/Icon
@onready var title_label: Label = $Row/Texts/TitleLabel
@onready var detail_label: Label = $Row/Texts/DetailLabel
@onready var action_button: Button = $Row/ActionButton

func setup(icon_file: String, title: String, detail: String, button_text: String, color_name := "white", skin := UIPanelFactory.ButtonSkin.GREEN, disabled := false) -> Button:
	AssetResolver.apply_asset_to_texture_rect(icon, UIPanelFactory.icon_asset(icon_file), Color("#fff4dc"), Vector2i(16, 16))
	title_label.text = title
	detail_label.text = detail
	detail_label.visible = not detail.is_empty()
	action_button.text = button_text
	action_button.disabled = disabled
	if not action_button.pressed.is_connected(_on_action_pressed):
		action_button.pressed.connect(_on_action_pressed)
	return action_button

func _on_action_pressed() -> void:
	action_requested.emit()
