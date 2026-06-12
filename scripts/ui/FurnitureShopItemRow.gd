class_name FurnitureShopItemRow
extends PanelContainer

signal place_requested(furniture_id: String)

@onready var preview: TextureRect = $Card/PreviewFrame/Preview
@onready var item_label: Label = $Card/ItemLabel
@onready var place_button: Button = $Card/PlaceButton

var price_button_template := ""
var place_insufficient_text := ""

var furniture_id := ""

func setup(item: Dictionary, can_buy: bool) -> void:
	_bind_scene_text()
	furniture_id = str(item.get("id", ""))
	AssetResolver.apply_asset_to_texture_rect(preview, item.get("asset", {}), Vector2i(48, 48))
	item_label.text = str(item.get("name", ""))
	place_button.text = price_button_template % int(item.get("price", 0))
	place_button.disabled = not can_buy
	place_button.tooltip_text = "" if can_buy else place_insufficient_text
	if not place_button.pressed.is_connected(_on_place_pressed):
		place_button.pressed.connect(_on_place_pressed)

func _on_place_pressed() -> void:
	place_requested.emit(furniture_id)

func _bind_scene_text() -> void:
	price_button_template = _template_text("PriceButtonTemplate")
	place_insufficient_text = _template_text("PlaceInsufficientText")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("FurnitureShopItemRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
