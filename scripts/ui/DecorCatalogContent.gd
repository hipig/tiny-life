class_name DecorCatalogContent
extends VBoxContainer

const ROOM_DECOR_ITEM_ROW_SCENE := preload("res://scenes/ui/RoomDecorItemRow.tscn")

signal apply_requested(decor_id: String)
signal category_changed(category: String)

var target_ref: Dictionary = {}
var selected_category := ""

var decor_category_row: HBoxContainer
var decor_list_root: GridContainer

func _ready() -> void:
	_bind_scene_nodes()

func open(next_target_ref: Dictionary, initial_category := "") -> void:
	target_ref = next_target_ref.duplicate(true)
	var supported_categories := ConfigManager.supported_decor_categories_for_target(target_ref)
	if supported_categories.is_empty():
		push_error("DecorCatalogContent requires at least one supported category.")
		return
	if initial_category.is_empty() or not supported_categories.has(initial_category):
		if selected_category.is_empty() or not supported_categories.has(selected_category):
			selected_category = str(supported_categories[0])
	else:
		selected_category = initial_category
	refresh()

func refresh() -> void:
	if target_ref.is_empty():
		return
	_bind_scene_nodes()
	var supported_categories := ConfigManager.supported_decor_categories_for_target(target_ref)
	if supported_categories.is_empty():
		return
	if selected_category.is_empty() or not supported_categories.has(selected_category):
		selected_category = str(supported_categories[0])
	_configure_decor_category_filters(supported_categories)
	_render_decor_category(selected_category)

func get_selected_category() -> String:
	return selected_category

func _bind_scene_nodes() -> void:
	decor_category_row = get_node_or_null("DecorCategoryRow") as HBoxContainer
	decor_list_root = get_node_or_null("DecorListRoot") as GridContainer
	if decor_category_row == null or decor_list_root == null:
		push_error("DecorCatalogContent.tscn must expose DecorCategoryRow and DecorListRoot.")

func _configure_decor_category_filters(supported_categories: Array) -> void:
	for config in [
		{"node": "WallpaperDecorFilter", "category": ConfigManager.DECOR_WALLPAPER},
		{"node": "WallDecorFilter", "category": ConfigManager.DECOR_WALL},
		{"node": "DoorDecorFilter", "category": ConfigManager.DECOR_DOOR},
		{"node": "RoofDecorFilter", "category": ConfigManager.DECOR_ROOF}
	]:
		var filter_button := decor_category_row.get_node_or_null(str(config["node"])) as PanelTabButton
		if filter_button == null:
			continue
		var category := str(config["category"])
		filter_button.visible = supported_categories.has(category)
		filter_button.setup("", selected_category == category)
		if not filter_button.tab_selected.is_connected(_on_decor_filter_pressed):
			filter_button.tab_selected.connect(_on_decor_filter_pressed)

func _render_decor_category(category: String) -> void:
	if decor_list_root == null:
		return
	UIPanelFactory.clear_children(decor_list_root)
	var current_id := GameState.get_space_decor_id(target_ref, category)
	for item in ConfigManager.get_room_decor_items(category):
		var decor_item: Dictionary = item
		var row := ROOM_DECOR_ITEM_ROW_SCENE.instantiate() as RoomDecorItemRow
		decor_list_root.add_child(row)
		var item_id := str(decor_item.get("id", ""))
		var price := int(decor_item.get("price", 0))
		row.setup(decor_item, item_id == current_id, GameState.coins >= price)
		row.apply_requested.connect(_on_decor_apply_pressed)

func _on_decor_filter_pressed(category: String) -> void:
	selected_category = category
	category_changed.emit(selected_category)
	refresh()

func _on_decor_apply_pressed(decor_id: String) -> void:
	apply_requested.emit(decor_id)
