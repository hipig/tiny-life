class_name FurnitureFloatingControls
extends HBoxContainer

signal confirmed
signal cancelled

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	if get_child_count() == 0:
		_build_buttons()

func set_confirm_enabled(value: bool) -> void:
	var confirm := get_node_or_null("ConfirmButton") as Button
	if confirm != null:
		confirm.disabled = not value

func _build_buttons() -> void:
	var confirm := Button.new()
	confirm.name = "ConfirmButton"
	UIPanelFactory.style_button(confirm, Vector2(96, 44))
	confirm.text = "确认"
	confirm.pressed.connect(func(): confirmed.emit())
	add_child(confirm)

	var cancel := Button.new()
	cancel.name = "CancelButton"
	UIPanelFactory.style_button(cancel, Vector2(96, 44))
	cancel.text = "取消"
	cancel.pressed.connect(func(): cancelled.emit())
	add_child(cancel)
