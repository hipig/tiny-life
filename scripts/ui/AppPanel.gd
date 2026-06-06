class_name AppPanel
extends PanelContainer

signal close_requested

var title_label: Label
var content_root: VBoxContainer
var _layout_ready := false

func _ready() -> void:
	_ensure_layout()

func setup_panel(title: String) -> void:
	_ensure_layout()
	title_label.text = title
	clear_content()

func clear_content() -> void:
	_ensure_layout()
	UIPanelFactory.clear_children(content_root)

func add_text(text: String, font_size := 20) -> Label:
	_ensure_layout()
	var label := UIPanelFactory.make_label(text, font_size)
	content_root.add_child(label)
	return label

func add_action_button(text: String, callback: Callable, min_size := Vector2(120, 48)) -> Button:
	_ensure_layout()
	return UIPanelFactory.add_button(content_root, text, callback, min_size)

func add_row() -> HBoxContainer:
	_ensure_layout()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content_root.add_child(row)
	return row

func _ensure_layout() -> void:
	if _layout_ready:
		return
	name = "ActivePanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 24
	offset_top = 92
	offset_right = -24
	offset_bottom = -40

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var close := Button.new()
	UIPanelFactory.style_button(close, Vector2(76, 44))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.text = "关闭"
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	content_root = VBoxContainer.new()
	content_root.add_theme_constant_override("separation", 8)
	content_root.custom_minimum_size = Vector2(620, 0)
	content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_root)
	_layout_ready = true
