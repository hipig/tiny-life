class_name FloatingMenu
extends VBoxContainer

signal zoom_in_requested
signal zoom_out_requested

var zoom_in_button: Button
var zoom_out_button: Button

var zoom_tooltip_template := ""

func _ready() -> void:
	_bind_scene_text()
	_build_menu()

func set_zoom_state(zoom_scale: float, min_zoom: float, max_zoom: float) -> void:
	if zoom_in_button != null:
		zoom_in_button.disabled = zoom_scale >= max_zoom - 0.001
		zoom_in_button.tooltip_text = zoom_tooltip_template % (zoom_scale * 100.0)
	if zoom_out_button != null:
		zoom_out_button.disabled = zoom_scale <= min_zoom + 0.001
		zoom_out_button.tooltip_text = zoom_tooltip_template % (zoom_scale * 100.0)

func _build_menu() -> void:
	_bind_menu_button("TaskButton", UIManager.open_task_panel)
	_bind_menu_button("RewardButton", UIManager.open_reward_panel)
	_bind_menu_button("SettingsButton", UIManager.open_settings_panel)
	zoom_in_button = _bind_menu_button("ZoomInButton", func(): zoom_in_requested.emit())
	zoom_out_button = _bind_menu_button("ZoomOutButton", func(): zoom_out_requested.emit())

func _bind_menu_button(node_name: String, callback: Callable) -> Button:
	var button := get_node_or_null(node_name) as Button
	if button == null:
		push_error("FloatingMenu scene is missing %s." % node_name)
		return null
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)
	return button

func _bind_scene_text() -> void:
	zoom_tooltip_template = _template_text("ZoomTooltipTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("FloatingMenu scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
