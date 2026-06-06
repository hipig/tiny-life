class_name FloatingMenu
extends VBoxContainer

signal zoom_in_requested
signal zoom_out_requested

var zoom_in_button: Button
var zoom_out_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(116, 0)
	add_theme_constant_override("separation", 10)
	_build_menu()

func set_zoom_state(zoom_scale: float, min_zoom: float, max_zoom: float) -> void:
	if zoom_in_button != null:
		zoom_in_button.disabled = zoom_scale >= max_zoom - 0.001
		zoom_in_button.tooltip_text = "当前缩放 %.0f%%" % (zoom_scale * 100.0)
	if zoom_out_button != null:
		zoom_out_button.disabled = zoom_scale <= min_zoom + 0.001
		zoom_out_button.tooltip_text = "当前缩放 %.0f%%" % (zoom_scale * 100.0)

func _build_menu() -> void:
	UIPanelFactory.clear_children(self)
	UIPanelFactory.add_button(self, "任务", UIManager.open_task_panel, Vector2(104, 62))
	UIPanelFactory.add_button(self, "福利", UIManager.open_reward_panel, Vector2(104, 62))
	UIPanelFactory.add_button(self, "设置", UIManager.open_settings_panel, Vector2(104, 62))
	zoom_in_button = UIPanelFactory.add_button(self, "放大", func(): zoom_in_requested.emit(), Vector2(104, 62))
	zoom_out_button = UIPanelFactory.add_button(self, "缩小", func(): zoom_out_requested.emit(), Vector2(104, 62))
