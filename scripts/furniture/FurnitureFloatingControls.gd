class_name FurnitureFloatingControls
extends HBoxContainer

signal confirmed
signal cancelled
signal recycled

func _ready() -> void:
	_bind_buttons()

func set_confirm_enabled(value: bool) -> void:
	var confirm := get_node_or_null("ConfirmButton") as Button
	if confirm != null:
		confirm.disabled = not value

func set_recycle_visible(value: bool) -> void:
	var recycle := get_node_or_null("RecycleButton") as Button
	if recycle != null:
		recycle.visible = value

func _bind_buttons() -> void:
	var confirm := get_node_or_null("ConfirmButton") as Button
	var cancel := get_node_or_null("CancelButton") as Button
	var recycle := get_node_or_null("RecycleButton") as Button
	if confirm == null or cancel == null or recycle == null:
		push_error("FurnitureFloatingControls.tscn must expose ConfirmButton, CancelButton, and RecycleButton.")
		return
	if not confirm.pressed.is_connected(_on_confirm_pressed):
		confirm.pressed.connect(_on_confirm_pressed)
	if not cancel.pressed.is_connected(_on_cancel_pressed):
		cancel.pressed.connect(_on_cancel_pressed)
	if not recycle.pressed.is_connected(_on_recycle_pressed):
		recycle.pressed.connect(_on_recycle_pressed)

func _on_confirm_pressed() -> void:
	confirmed.emit()

func _on_cancel_pressed() -> void:
	cancelled.emit()

func _on_recycle_pressed() -> void:
	recycled.emit()
