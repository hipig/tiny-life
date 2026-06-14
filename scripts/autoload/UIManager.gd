extends Node

enum UIState {
	NORMAL,
	ROOM_PANEL,
	SPACE_DECOR_PANEL,
	FURNITURE_SHOP,
	PLACING_NEW_FURNITURE,
	MOVING_EXISTING_FURNITURE,
	TENANT_PANEL,
	BUILD_CONFIRM,
	TASK_PANEL,
	APARTMENT_OVERVIEW,
	INCOME_DETAIL,
	RENT_DETAIL,
	REWARD_PANEL,
	SETTINGS_PANEL,
	POPUP
}

signal state_changed(state: int)
signal room_panel_requested(room_id: String, initial_tab: String)
signal furniture_shop_requested(room_id: String)
signal tenant_panel_requested(room_id: String, mode: String)
signal build_confirm_requested(room_id: String)
signal space_decor_panel_requested(target_ref: Dictionary, initial_category: String)
signal panel_requested(panel_name: String)
signal placement_requested(furniture_id: String, room_id: String)
signal move_existing_requested(room_id: String, instance_id: String)

var current_state: UIState = UIState.NORMAL

func set_state(state: UIState) -> void:
	current_state = state
	state_changed.emit(state)

func return_to_normal() -> void:
	set_state(UIState.NORMAL)

func allows_world_camera_input() -> bool:
	return current_state == UIState.NORMAL \
		or current_state == UIState.PLACING_NEW_FURNITURE \
		or current_state == UIState.MOVING_EXISTING_FURNITURE

func is_furniture_placement_state() -> bool:
	return current_state == UIState.PLACING_NEW_FURNITURE \
		or current_state == UIState.MOVING_EXISTING_FURNITURE

func blocks_world_camera_input() -> bool:
	return not allows_world_camera_input()

func open_room_panel(room_id: String, initial_tab := "furniture") -> void:
	set_state(UIState.ROOM_PANEL)
	room_panel_requested.emit(room_id, initial_tab)

func open_furniture_shop(room_id: String) -> void:
	set_state(UIState.FURNITURE_SHOP)
	furniture_shop_requested.emit(room_id)

func open_space_decor_panel(target_ref: Dictionary, initial_category := "") -> void:
	set_state(UIState.SPACE_DECOR_PANEL)
	space_decor_panel_requested.emit(target_ref.duplicate(true), initial_category)

func start_new_furniture_placement(furniture_id: String, room_id: String) -> void:
	set_state(UIState.PLACING_NEW_FURNITURE)
	placement_requested.emit(furniture_id, room_id)

func start_move_existing(room_id: String, instance_id: String) -> void:
	set_state(UIState.MOVING_EXISTING_FURNITURE)
	move_existing_requested.emit(room_id, instance_id)

func open_tenant_panel_for_recruit(room_id: String) -> void:
	set_state(UIState.TENANT_PANEL)
	tenant_panel_requested.emit(room_id, "recruit")

func open_tenant_panel(room_id: String) -> void:
	set_state(UIState.TENANT_PANEL)
	tenant_panel_requested.emit(room_id, "view")

func open_build_confirm(room_id: String) -> void:
	set_state(UIState.BUILD_CONFIRM)
	build_confirm_requested.emit(room_id)

func open_apartment_overview() -> void:
	set_state(UIState.APARTMENT_OVERVIEW)
	panel_requested.emit("apartment_overview")

func open_income_detail() -> void:
	set_state(UIState.INCOME_DETAIL)
	panel_requested.emit("income_detail")

func open_rent_detail() -> void:
	set_state(UIState.RENT_DETAIL)
	panel_requested.emit("rent_detail")

func open_task_panel() -> void:
	set_state(UIState.TASK_PANEL)
	panel_requested.emit("task")

func open_reward_panel() -> void:
	set_state(UIState.REWARD_PANEL)
	panel_requested.emit("reward")

func open_settings_panel() -> void:
	set_state(UIState.SETTINGS_PANEL)
	panel_requested.emit("settings")

func show_toast(message: String) -> void:
	GameEvents.toast_requested.emit(message)
