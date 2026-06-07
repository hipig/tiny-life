class_name FurnitureFloatingControls
extends HBoxContainer

signal confirmed
signal cancelled

func _ready() -> void:
	_bind_buttons()

func set_confirm_enabled(value: bool) -> void:
	var confirm := get_node_or_null("ConfirmButton") as Button
	if confirm != null:
		confirm.disabled = not value

func _bind_buttons() -> void:
	var confirm := get_node_or_null("ConfirmButton") as Button
	var cancel := get_node_or_null("CancelButton") as Button
	if confirm == null or cancel == null:
		push_error("FurnitureFloatingControls.tscn must expose ConfirmButton and CancelButton.")
		return
	if not confirm.pressed.is_connected(_on_confirm_pressed):
		confirm.pressed.connect(_on_confirm_pressed)
	if not cancel.pressed.is_connected(_on_cancel_pressed):
		cancel.pressed.connect(_on_cancel_pressed)

func _on_confirm_pressed() -> void:
	confirmed.emit()

func _on_cancel_pressed() -> void:
	cancelled.emit()
