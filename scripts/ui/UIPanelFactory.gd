class_name UIPanelFactory
extends RefCounted

static func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func clear_active_panels(panel_layer: Node) -> void:
	for child in panel_layer.get_children():
		if child is PanelContainer:
			panel_layer.remove_child(child)
			child.queue_free()

static func style_button(button: Button, min_size := Vector2(120, 48)) -> void:
	button.custom_minimum_size = min_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL

static func make_label(text: String, font_size := 20) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	return label

static func add_button(parent: Control, text: String, callback: Callable, min_size := Vector2(120, 48)) -> Button:
	var button := Button.new()
	style_button(button, min_size)
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

static func make_panel(panel_layer: Node, title: String, close_callback: Callable) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "ActivePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 92
	panel.offset_right = -24
	panel.offset_bottom = -40
	panel_layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var close := Button.new()
	style_button(close, Vector2(76, 44))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.text = "关闭"
	close.pressed.connect(close_callback)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.custom_minimum_size = Vector2(620, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content
