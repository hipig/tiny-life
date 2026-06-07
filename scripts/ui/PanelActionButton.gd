class_name PanelActionButton
extends Button

signal action_requested

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func setup(label := "", icon_asset := {}, disabled_value := false) -> void:
	if not label.is_empty():
		text = label
	disabled = disabled_value
	if icon_asset is Dictionary and not icon_asset.is_empty():
		AssetResolver.apply_asset_to_button_icon(self, icon_asset, Color.WHITE, Vector2i(16, 16))

func _on_pressed() -> void:
	action_requested.emit()
