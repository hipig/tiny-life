extends Control

const ROOM_PANEL_SCENE := preload("res://scenes/ui/RoomPanel.tscn")
const FURNITURE_SHOP_PANEL_SCENE := preload("res://scenes/ui/FurnitureShopPanel.tscn")
const PLACEMENT_OVERLAY_SCENE := preload("res://scenes/ui/PlacementOverlay.tscn")
const RECYCLE_CONFIRM_POPUP_SCENE := preload("res://scenes/ui/RecycleConfirmPopup.tscn")
const TENANT_PANEL_SCENE := preload("res://scenes/ui/TenantPanel.tscn")
const BUILD_CONFIRM_POPUP_SCENE := preload("res://scenes/ui/BuildConfirmPopup.tscn")
const APARTMENT_OVERVIEW_PANEL_SCENE := preload("res://scenes/ui/ApartmentOverviewPanel.tscn")
const INCOME_DETAIL_PANEL_SCENE := preload("res://scenes/ui/IncomeDetailPanel.tscn")
const RENT_DETAIL_PANEL_SCENE := preload("res://scenes/ui/RentDetailPanel.tscn")
const TASK_PANEL_SCENE := preload("res://scenes/ui/TaskPanel.tscn")
const REWARD_PANEL_SCENE := preload("res://scenes/ui/RewardPanel.tscn")
const SETTINGS_PANEL_SCENE := preload("res://scenes/ui/SettingsPanel.tscn")
const OFFLINE_REWARD_POPUP_SCENE := preload("res://scenes/ui/OfflineRewardPopup.tscn")

@onready var building_view: BuildingView = $BuildingView
@onready var top_status_bar: TopStatusBar = $CanvasLayer_UI/TopStatusBar
@onready var floating_menu: FloatingMenu = $CanvasLayer_UI/FloatingMenu
@onready var popup_layer: PopupLayer = $PopupLayer

var selected_room_id := ""
var state_loaded_once := false

func _ready() -> void:
	_connect_events()

func _connect_events() -> void:
	GameEvents.rent_changed.connect(_on_rent_changed)
	GameEvents.apartment_level_changed.connect(_on_apartment_level_changed)
	GameEvents.room_updated.connect(_on_room_updated)
	GameEvents.room_layout_changed.connect(func(_room_id): _refresh_building_if_loaded())
	GameEvents.room_unlocked.connect(func(_room_id): _refresh_building_if_loaded())
	GameEvents.room_decor_changed.connect(func(_room_id, _decor_id, _category): _refresh_building_if_loaded())
	GameEvents.furniture_placed.connect(func(_room_id, _furniture_id): _refresh_building_if_loaded())
	GameEvents.furniture_moved.connect(func(_room_id, _furniture_id): _refresh_building_if_loaded())
	GameEvents.furniture_recycled.connect(func(_room_id, _furniture_id): _refresh_building_if_loaded())
	GameEvents.tenant_recruited.connect(func(_tenant_id, _room_id): _refresh_building_if_loaded())
	GameEvents.tenant_behavior_changed.connect(func(_tenant_id, _behavior): _refresh_tenant_panels_if_open())
	GameEvents.tenant_presence_changed.connect(func(_tenant_id, _presence): _refresh_tenant_panels_if_open())
	GameEvents.task_updated.connect(func(_task_id): pass)
	GameEvents.task_completed.connect(func(task_id): _toast("toast_task_completed", [_task_title(task_id)]))
	GameEvents.toast_requested.connect(_show_toast)
	GameEvents.state_loaded.connect(_on_state_loaded)
	GameEvents.offline_income_ready.connect(_show_offline_reward)
	UIManager.room_panel_requested.connect(_show_room_panel)
	UIManager.furniture_shop_requested.connect(_show_furniture_shop)
	UIManager.tenant_panel_requested.connect(_show_tenant_panel)
	UIManager.build_confirm_requested.connect(_show_build_confirm)
	UIManager.panel_requested.connect(_show_named_panel)
	UIManager.placement_requested.connect(_show_new_placement)
	UIManager.move_existing_requested.connect(_show_move_existing)
	UIManager.state_changed.connect(_on_ui_state_changed)

func _refresh_all() -> void:
	_refresh_top_bar()
	_refresh_building()

func _on_state_loaded() -> void:
	state_loaded_once = true
	_refresh_all()

func _on_rent_changed(_value: float) -> void:
	_refresh_top_bar()
	_refresh_room_panel_if_open()

func _on_apartment_level_changed(_level: int) -> void:
	_refresh_top_bar()
	_refresh_building_if_loaded()

func _on_room_updated(_room_id: String) -> void:
	_refresh_building_if_loaded()
	_refresh_room_panel_if_open()

func _on_ui_state_changed(state: int) -> void:
	var placement_active := state == UIManager.UIState.PLACING_NEW_FURNITURE or state == UIManager.UIState.MOVING_EXISTING_FURNITURE
	if floating_menu != null:
		floating_menu.visible = not placement_active
	if not placement_active and building_view != null and building_view.has_method("clear_focus"):
		building_view.clear_focus()

func _refresh_top_bar() -> void:
	if top_status_bar != null and top_status_bar.has_method("refresh_from_state"):
		top_status_bar.refresh_from_state()

func _refresh_building() -> void:
	if building_view != null and building_view.has_method("refresh"):
		building_view.refresh()

func _refresh_building_if_loaded() -> void:
	if state_loaded_once:
		_refresh_building()

func _show_room_panel(room_id: String) -> void:
	selected_room_id = room_id
	var panel := _open_panel(ROOM_PANEL_SCENE) as RoomPanel
	panel.furniture_shop_requested.connect(UIManager.open_furniture_shop)
	panel.tenant_recruit_requested.connect(UIManager.open_tenant_panel_for_recruit)
	panel.tenant_view_requested.connect(UIManager.open_tenant_panel)
	panel.decor_apply_requested.connect(_on_decor_apply_requested)
	panel.move_furniture_requested.connect(_on_move_furniture_pressed)
	panel.recycle_furniture_requested.connect(_on_recycle_furniture_pressed)
	panel.open(room_id)

func _show_furniture_shop(room_id: String) -> void:
	selected_room_id = room_id
	var panel := _open_panel(FURNITURE_SHOP_PANEL_SCENE) as FurnitureShopPanel
	panel.place_requested.connect(_on_shop_place_pressed)
	panel.open(room_id)

func _show_new_placement(furniture_id: String, room_id: String) -> void:
	selected_room_id = room_id
	_clear_panel_layer_panels()
	if building_view != null and building_view.has_method("focus_room"):
		building_view.focus_room(room_id)
		await get_tree().process_frame
	var overlay := popup_layer.open_overlay(PLACEMENT_OVERLAY_SCENE) as PlacementOverlay
	overlay.new_placement_confirmed.connect(_confirm_new_placement)
	overlay.move_confirmed.connect(_confirm_move)
	overlay.recycle_requested.connect(_on_placement_recycle_requested)
	overlay.cancelled.connect(UIManager.open_room_panel)
	overlay.open_new(room_id, furniture_id)

func _show_move_existing(room_id: String, instance_id: String) -> void:
	selected_room_id = room_id
	_clear_panel_layer_panels()
	if building_view != null and building_view.has_method("focus_room"):
		building_view.focus_room(room_id)
		await get_tree().process_frame
	var overlay := popup_layer.open_overlay(PLACEMENT_OVERLAY_SCENE) as PlacementOverlay
	overlay.new_placement_confirmed.connect(_confirm_new_placement)
	overlay.move_confirmed.connect(_confirm_move)
	overlay.recycle_requested.connect(_on_placement_recycle_requested)
	overlay.cancelled.connect(UIManager.open_room_panel)
	overlay.open_move(room_id, instance_id)

func _confirm_new_placement(room_id: String, furniture_id: String, grid_pos: Array) -> void:
	var data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var price := int(data.get("price", 0))
	if not GameState.spend_coins(price):
		_toast("toast_insufficient_coins")
		return
	GameState.add_furniture_instance(room_id, furniture_id, grid_pos)
	SaveManager.save_game()
	_toast("toast_furniture_placed", [data.get("name", "furniture")])
	UIManager.open_room_panel(room_id)

func _on_move_furniture_pressed(instance_id: String) -> void:
	UIManager.start_move_existing(selected_room_id, instance_id)

func _on_recycle_furniture_pressed(instance_id: String) -> void:
	_confirm_recycle(selected_room_id, instance_id)

func _on_placement_recycle_requested(room_id: String, instance_id: String) -> void:
	selected_room_id = room_id
	UIManager.set_state(UIManager.UIState.POPUP)
	_confirm_recycle(room_id, instance_id)

func _on_shop_place_pressed(furniture_id: String, room_id: String) -> void:
	UIManager.start_new_furniture_placement(furniture_id, room_id)

func _on_decor_apply_requested(room_id: String, decor_id: String) -> void:
	var item: Dictionary = ConfigManager.get_room_decor_item(decor_id)
	if item.is_empty():
		return
	var category := str(item.get("category", "")).strip_edges()
	if ConfigManager.room_decor_field_for_category(category).is_empty():
		return
	var room: Dictionary = GameState.rooms.get(room_id, {})
	if ConfigManager.get_room_decor_id(room, category) == decor_id:
		_refresh_room_panel_if_open()
		return
	var price := int(item.get("price", 0))
	if GameState.coins < price:
		_toast("toast_insufficient_coins")
		_refresh_room_panel_if_open()
		return
	if not GameState.spend_coins(price):
		_toast("toast_insufficient_coins")
		_refresh_room_panel_if_open()
		return
	if GameState.apply_room_decor(room_id, decor_id):
		SaveManager.save_game()
		_toast("toast_room_decor_applied", [item.get("name", "")])
		_refresh_room_panel_if_open()
	else:
		GameState.add_coins(price, "decor_apply_refund")

func _confirm_move(room_id: String, instance_id: String, grid_pos: Array) -> void:
	if GameState.move_furniture_instance(room_id, instance_id, grid_pos):
		SaveManager.save_game()
		_toast("toast_furniture_moved")
	UIManager.open_room_panel(room_id)

func _confirm_recycle(room_id: String, instance_id: String) -> void:
	var panel := _open_panel(RECYCLE_CONFIRM_POPUP_SCENE) as RecycleConfirmPopup
	panel.recycle_confirmed.connect(_do_recycle)
	panel.recycle_cancelled.connect(UIManager.open_room_panel)
	panel.open(room_id, instance_id)

func _do_recycle(room_id: String, instance_id: String) -> void:
	var refund: int = GameState.recycle_furniture_instance(room_id, instance_id)
	if refund > 0:
		SaveManager.save_game()
		_toast("toast_furniture_recycled", [refund])
	UIManager.open_room_panel(room_id)

func _show_tenant_panel(room_id: String, mode: String) -> void:
	selected_room_id = room_id
	var panel := _open_panel(TENANT_PANEL_SCENE) as TenantPanel
	panel.tenant_recruit_requested.connect(_on_recruit_tenant_pressed)
	panel.open(room_id, mode)

func _on_recruit_tenant_pressed(tenant_id: String, room_id: String) -> void:
	if GameState.recruit_tenant(room_id, tenant_id):
		SaveManager.save_game()
		_toast("toast_tenant_recruited")
	UIManager.open_room_panel(room_id)

func _show_build_confirm(floor_index: int) -> void:
	var panel := _open_panel(BUILD_CONFIRM_POPUP_SCENE) as BuildConfirmPopup
	panel.build_confirmed.connect(_on_build_confirmed)
	panel.open(floor_index)

func _on_build_confirmed(floor_index: int) -> void:
	if GameState.build_floor(floor_index):
		SaveManager.save_game()
		_toast("toast_floor_built", [floor_index])
		UIManager.return_to_normal()
		_clear_panel_layer_panels()
		_refresh_building()

func _show_named_panel(panel_name: String) -> void:
	match panel_name:
		"apartment_overview":
			var panel := _open_panel(APARTMENT_OVERVIEW_PANEL_SCENE) as ApartmentOverviewPanel
			panel.open()
		"income_detail":
			var panel := _open_panel(INCOME_DETAIL_PANEL_SCENE) as IncomeDetailPanel
			panel.open()
		"rent_detail":
			var panel := _open_panel(RENT_DETAIL_PANEL_SCENE) as RentDetailPanel
			panel.open()
		"task":
			_show_task_panel()
		"reward":
			_show_reward_panel()
		"settings":
			_show_settings_panel()

func _show_task_panel() -> void:
	var panel := _open_panel(TASK_PANEL_SCENE) as TaskPanel
	panel.open()

func _show_reward_panel() -> void:
	var panel := _open_panel(REWARD_PANEL_SCENE) as RewardPanel
	panel.offline_claim_requested.connect(_on_reward_offline_claim_requested)
	panel.tenant_refresh_requested.connect(_on_reward_tenant_refresh_requested)
	panel.open()

func _on_reward_offline_claim_requested(double: bool) -> void:
	if double:
		AdManager.show_rewarded_ad("offline_double", func(success):
			if success:
				var amount: int = EconomyManager.claim_offline_income(true)
				_toast("toast_offline_double_claim", [amount])
				_show_reward_panel()
		)
		return
	var amount: int = EconomyManager.claim_offline_income(false)
	_toast("toast_offline_claim", [amount])
	_show_reward_panel()

func _on_reward_tenant_refresh_requested() -> void:
	AdManager.show_rewarded_ad("refresh_tenants", func(success):
		if success:
			ConfigManager.refresh_tenant_applications()
			_toast("toast_tenant_applications_refreshed")
	)

func _show_settings_panel() -> void:
	var panel := _open_panel(SETTINGS_PANEL_SCENE) as SettingsPanel
	panel.save_requested.connect(_on_save_pressed)
	panel.reset_requested.connect(_on_reset_pressed)
	panel.open()

func _on_save_pressed() -> void:
	SaveManager.save_game()
	_toast("toast_save_done")

func _on_reset_pressed() -> void:
	SaveManager.delete_save_and_restart()
	_clear_panel_layer_panels()
	_toast("toast_reset_done")

func _show_offline_reward(amount: int, seconds: int) -> void:
	UIManager.set_state(UIManager.UIState.POPUP)
	var panel := _open_panel(OFFLINE_REWARD_POPUP_SCENE) as OfflineRewardPopup
	panel.claim_requested.connect(_on_offline_reward_claim_requested)
	panel.open(amount, seconds)

func _on_offline_reward_claim_requested(double: bool) -> void:
	if double:
		AdManager.show_rewarded_ad("offline_double", func(success):
			if success:
				var got: int = EconomyManager.claim_offline_income(true)
				_toast("toast_offline_double_claim", [got])
				_clear_panel_layer_panels()
				UIManager.return_to_normal()
		)
		return
	var got: int = EconomyManager.claim_offline_income(false)
	_toast("toast_offline_claim", [got])
	_clear_panel_layer_panels()
	UIManager.return_to_normal()

func _open_panel(scene: PackedScene) -> AppPanel:
	return popup_layer.open_panel(scene, _on_panel_close_requested)

func _on_panel_close_requested() -> void:
	_clear_panel_layer_panels()
	UIManager.return_to_normal()

func _show_toast(message: String) -> void:
	popup_layer.show_toast(message)

func _toast(key: String, values: Array = []) -> void:
	var template := ConfigManager.text(key, key)
	if not values.is_empty():
		_show_toast(template % values)
		return
	_show_toast(template)

func _task_title(task_id: String) -> String:
	for task in ConfigManager.tasks:
		if str(task.get("id", "")) == task_id:
			return str(task.get("title", task_id))
	return task_id

func _refresh_room_panel_if_open() -> void:
	if UIManager.current_state == UIManager.UIState.ROOM_PANEL and not selected_room_id.is_empty():
		var panel := _active_panel() as RoomPanel
		if panel != null:
			panel.refresh()

func _refresh_tenant_panel_if_open() -> void:
	if UIManager.current_state == UIManager.UIState.TENANT_PANEL and not selected_room_id.is_empty():
		var panel := _active_panel() as TenantPanel
		if panel != null:
			panel.refresh()

func _refresh_tenant_panels_if_open() -> void:
	_refresh_room_panel_if_open()
	_refresh_tenant_panel_if_open()

func _active_panel() -> AppPanel:
	return popup_layer.active_panel()

func _clear_panel_layer_panels() -> void:
	popup_layer.clear_panels()

func _clear_children(node: Node) -> void:
	UIPanelFactory.clear_children(node)
