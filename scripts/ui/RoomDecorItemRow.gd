class_name RoomDecorItemRow
extends PanelContainer

signal apply_requested(decor_id: String)

@onready var preview: TextureRect = $Card/PreviewFrame/Preview
@onready var item_label: Label = $Card/ItemLabel
@onready var apply_button: Button = $Card/ApplyButton

var price_button_template := ""
var applied_button_text := ""
var apply_insufficient_text := ""

var decor_id := ""

func setup(item: Dictionary, current: bool, can_buy: bool) -> void:
	_bind_scene_text()
	decor_id = str(item.get("id", ""))
	AssetResolver.apply_asset_to_texture_rect(preview, item.get("preview_asset", {}), Vector2i(64, 48))
	item_label.text = str(item.get("name", ""))
	if current:
		apply_button.text = applied_button_text
		apply_button.disabled = true
		apply_button.tooltip_text = ""
	elif can_buy:
		apply_button.text = price_button_template % int(item.get("price", 0))
		apply_button.disabled = false
		apply_button.tooltip_text = ""
	else:
		apply_button.text = apply_insufficient_text
		apply_button.disabled = true
		apply_button.tooltip_text = apply_insufficient_text
	if not apply_button.pressed.is_connected(_on_apply_pressed):
		apply_button.pressed.connect(_on_apply_pressed)

func _on_apply_pressed() -> void:
	apply_requested.emit(decor_id)

func _bind_scene_text() -> void:
	price_button_template = _template_text("PriceButtonTemplate")
	applied_button_text = _template_text("AppliedButtonText")
	apply_insufficient_text = _template_text("ApplyInsufficientText")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("RoomDecorItemRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
