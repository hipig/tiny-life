class_name FurnitureShopItemRow
extends PanelContainer

signal place_requested(furniture_id: String)

@onready var preview: TextureRect = $Row/Preview
@onready var item_label: Label = $Row/ItemLabel
@onready var place_button: Button = $Row/PlaceButton

var item_text_template := ""
var place_available_text := ""
var place_insufficient_text := ""

var furniture_id := ""

func setup(item: Dictionary, can_buy: bool) -> void:
	_bind_scene_text()
	furniture_id = str(item.get("id", ""))
	AssetResolver.apply_asset_to_texture_rect(preview, item.get("asset", {}), Color("#b9784a"), Vector2i(32, 32))
	item_label.text = item_text_template % [
		item.get("name", ""),
		int(item.get("price", 0)),
		_furniture_score(item)
	]
	place_button.text = place_available_text if can_buy else place_insufficient_text
	place_button.disabled = not can_buy
	if not place_button.pressed.is_connected(_on_place_pressed):
		place_button.pressed.connect(_on_place_pressed)

func _furniture_score(data: Dictionary) -> int:
	return int(data.get("comfort", 0)) + int(data.get("entertainment", 0)) + int(data.get("hygiene", 0)) + int(data.get("food", 0))

func _on_place_pressed() -> void:
	place_requested.emit(furniture_id)

func _bind_scene_text() -> void:
	item_text_template = _template_text("ItemTextTemplate")
	place_available_text = place_button.text
	place_insufficient_text = _template_text("PlaceInsufficientText")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("FurnitureShopItemRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
