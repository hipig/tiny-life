class_name SettingsPanel
extends "res://scripts/ui/AppPanel.gd"

signal save_requested
signal reset_requested

var list_root: VBoxContainer
var sfx_row: IconInfoRow
var music_row: IconInfoRow
var language_row: IconInfoRow
var quality_row: IconInfoRow
var privacy_row: IconInfoRow
var save_button: PanelActionButton
var reset_button: PanelActionButton

func open() -> void:
	setup_panel("", false)
	_bind_scene_nodes()
	if not save_button.action_requested.is_connected(_on_save_pressed):
		save_button.action_requested.connect(_on_save_pressed)
	if not reset_button.action_requested.is_connected(_on_reset_pressed):
		reset_button.action_requested.connect(_on_reset_pressed)

func _bind_scene_nodes() -> void:
	list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ListRoot") as VBoxContainer
	sfx_row = list_root.get_node_or_null("SfxRow") as IconInfoRow
	music_row = list_root.get_node_or_null("MusicRow") as IconInfoRow
	language_row = list_root.get_node_or_null("LanguageRow") as IconInfoRow
	quality_row = list_root.get_node_or_null("QualityRow") as IconInfoRow
	privacy_row = list_root.get_node_or_null("PrivacyRow") as IconInfoRow
	save_button = list_root.get_node_or_null("SaveButton") as PanelActionButton
	reset_button = list_root.get_node_or_null("ResetButton") as PanelActionButton

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_reset_pressed() -> void:
	reset_requested.emit()
