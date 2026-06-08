class_name FloatingMenu
extends VBoxContainer

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	_bind_menu_button("TaskButton", UIManager.open_task_panel)
	_bind_menu_button("RewardButton", UIManager.open_reward_panel)
	_bind_menu_button("SettingsButton", UIManager.open_settings_panel)

func _bind_menu_button(node_name: String, callback: Callable) -> Button:
	var button := get_node_or_null(node_name) as Button
	if button == null:
		push_error("FloatingMenu scene is missing %s." % node_name)
		return null
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)
	return button
