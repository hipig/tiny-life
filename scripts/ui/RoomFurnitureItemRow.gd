class_name RoomFurnitureItemRow
extends PanelContainer

signal move_requested(instance_id: String)
signal recycle_requested(instance_id: String)

@onready var preview: TextureRect = $Row/Preview
@onready var item_label: Label = $Row/ItemLabel
@onready var move_button: Button = $Row/MoveButton
@onready var recycle_button: Button = $Row/RecycleButton

var item_text_template := ""

var instance_id := ""

func setup(instance_data: Dictionary, furniture_data: Dictionary) -> void:
	_bind_scene_text()
	instance_id = str(instance_data.get("instance_id", ""))
	AssetResolver.apply_asset_to_texture_rect(preview, furniture_data.get("asset", {}), Vector2i(32, 32))
	item_label.text = item_text_template % [str(furniture_data["name"]), str(instance_data.get("grid_pos", []))]
	if not move_button.pressed.is_connected(_on_move_pressed):
		move_button.pressed.connect(_on_move_pressed)
	if not recycle_button.pressed.is_connected(_on_recycle_pressed):
		recycle_button.pressed.connect(_on_recycle_pressed)

func _on_move_pressed() -> void:
	move_requested.emit(instance_id)

func _on_recycle_pressed() -> void:
	recycle_requested.emit(instance_id)

func _bind_scene_text() -> void:
	item_text_template = _template_text("ItemTextTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("RoomFurnitureItemRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
