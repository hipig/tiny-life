class_name FurnitureShopPanel
extends "res://scripts/ui/AppPanel.gd"

const FURNITURE_SHOP_ITEM_ROW_SCENE := preload("res://scenes/ui/FurnitureShopItemRow.tscn")
const CATEGORY_ALL := "__all__"
const SORT_DEFAULT := "default"
const SORT_PRICE_ASC := "price_asc"
const SORT_PRICE_DESC := "price_desc"
const SORT_SCORE := "score"
const SORT_COMFORT := "comfort"
const SORT_ENTERTAINMENT := "entertainment"
const SORT_HYGIENE := "hygiene"
const SORT_FOOD := "food"
const QUICK_AFFORDABLE := "affordable"
const QUICK_FLOOR_ITEM := "floor_item"
const QUICK_WALL_ITEM := "wall_item"
const QUICK_INTERACTIVE := "interactive"
const QUICK_ROTATABLE := "rotatable"
const SORT_DESCENDING_KEYS := [SORT_PRICE_DESC, SORT_SCORE, SORT_COMFORT, SORT_ENTERTAINMENT, SORT_HYGIENE, SORT_FOOD]

signal place_requested(furniture_id: String, room_id: String)

var room_id := ""
var list_root: GridContainer
var category_dropdown: OptionButton
var sort_dropdown: OptionButton
var quick_filter_grid: GridContainer
var result_label: Label
var empty_state_label: Label

var title_template := ""
var result_count_template := ""
var selected_category := CATEGORY_ALL
var selected_sort := SORT_DEFAULT
var active_quick_filters: Dictionary = {}
var category_option_ids: Array[String] = []
var sort_option_ids: Array[String] = []

func open(target_room_id: String) -> void:
	room_id = target_room_id
	var room: Dictionary = GameState.get_room(room_id)
	setup_panel("", false)
	_bind_scene_nodes()
	_bind_scene_text()
	_configure_dropdown_options()
	_connect_coin_updates()
	title_label.text = title_template % str(room["room_name"])
	_refresh_list()

func _exit_tree() -> void:
	if GameEvents.coins_changed.is_connected(_on_coins_changed):
		GameEvents.coins_changed.disconnect(_on_coins_changed)

func _bind_scene_nodes() -> void:
	list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ListRoot") as GridContainer
	category_dropdown = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/FilterRoot/CategoryFilterRow/CategoryDropdown") as OptionButton
	sort_dropdown = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/FilterRoot/SortFilterRow/SortDropdown") as OptionButton
	quick_filter_grid = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/FilterRoot/QuickFilterGrid") as GridContainer
	result_label = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ResultLabel") as Label
	empty_state_label = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/EmptyStateLabel") as Label
	if list_root == null or category_dropdown == null or sort_dropdown == null or quick_filter_grid == null or result_label == null or empty_state_label == null:
		push_error("FurnitureShopPanel scene is missing filter dropdowns, quick filters, result labels, or ListRoot.")

func _bind_scene_text() -> void:
	title_template = _template_text("TitleTemplate")
	result_count_template = _template_text("ResultCountTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("FurnitureShopPanel scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _refresh_list() -> void:
	_configure_filter_controls()
	UIPanelFactory.clear_children(list_root)
	var items := _filtered_sorted_furniture()
	var total_count := ConfigManager.furniture.size()
	result_label.text = result_count_template % [items.size(), total_count]
	empty_state_label.visible = items.is_empty()
	list_root.visible = not items.is_empty()
	for item_data in items:
		var item: Dictionary = item_data
		var can_buy := GameState.coins >= int(item.get("price", 0))
		var row := FURNITURE_SHOP_ITEM_ROW_SCENE.instantiate() as FurnitureShopItemRow
		list_root.add_child(row)
		row.setup(item, can_buy)
		row.place_requested.connect(_on_place_pressed)

func _configure_dropdown_options() -> void:
	category_option_ids = _populate_dropdown_from_templates(category_dropdown, "CategoryOptions")
	sort_option_ids = _populate_dropdown_from_templates(sort_dropdown, "SortOptions")
	_select_dropdown_id(category_dropdown, category_option_ids, selected_category)
	_select_dropdown_id(sort_dropdown, sort_option_ids, selected_sort)
	if not category_dropdown.item_selected.is_connected(_on_category_dropdown_selected):
		category_dropdown.item_selected.connect(_on_category_dropdown_selected)
	if not sort_dropdown.item_selected.is_connected(_on_sort_dropdown_selected):
		sort_dropdown.item_selected.connect(_on_sort_dropdown_selected)

func _populate_dropdown_from_templates(dropdown: OptionButton, template_group_name: String) -> Array[String]:
	var option_ids: Array[String] = []
	if dropdown == null:
		return option_ids
	dropdown.clear()
	var template_group := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % template_group_name)
	if template_group == null:
		push_error("FurnitureShopPanel scene is missing TemplateText/%s." % template_group_name)
		return option_ids
	for child in template_group.get_children():
		var option_label := child as Label
		if option_label == null:
			continue
		if not option_label.has_meta(PanelTabButton.META_TAB_ID):
			push_error("FurnitureShopPanel option %s is missing metadata/tab_id." % option_label.name)
			continue
		var option_id := str(option_label.get_meta(PanelTabButton.META_TAB_ID)).strip_edges()
		dropdown.add_item(option_label.text)
		option_ids.append(option_id)
	return option_ids

func _select_dropdown_id(dropdown: OptionButton, option_ids: Array[String], option_id: String) -> void:
	if dropdown == null:
		return
	var option_index := option_ids.find(option_id)
	if option_index < 0 and not option_ids.is_empty():
		option_index = 0
	if option_index >= 0:
		dropdown.select(option_index)

func _configure_filter_controls() -> void:
	_select_dropdown_id(category_dropdown, category_option_ids, selected_category)
	_select_dropdown_id(sort_dropdown, sort_option_ids, selected_sort)
	_configure_button_group(quick_filter_grid, Callable(self, "_on_quick_filter_pressed"))

func _configure_button_group(container: GridContainer, callback: Callable) -> void:
	if container == null:
		return
	for child in container.get_children():
		var filter_button := child as PanelTabButton
		if filter_button == null:
			continue
		var filter_id := filter_button.tab_id
		if filter_id.is_empty() and filter_button.has_meta(PanelTabButton.META_TAB_ID):
			filter_id = str(filter_button.get_meta(PanelTabButton.META_TAB_ID)).strip_edges()
		var selected := _is_quick_filter_active(filter_id)
		filter_button.setup_toggle("", selected)
		if not filter_button.tab_selected.is_connected(callback):
			filter_button.tab_selected.connect(callback)

func _filtered_sorted_furniture() -> Array:
	var indexed_items: Array = []
	var index := 0
	for item_data in ConfigManager.furniture:
		var item: Dictionary = item_data
		if _matches_active_filters(item):
			indexed_items.append({"item": item, "index": index})
		index += 1
	if selected_sort != SORT_DEFAULT:
		indexed_items.sort_custom(Callable(self, "_sort_indexed_furniture"))
	var result: Array = []
	for entry_data in indexed_items:
		var entry: Dictionary = entry_data
		result.append(entry["item"])
	return result

func _matches_active_filters(item: Dictionary) -> bool:
	if selected_category != CATEGORY_ALL and str(item["category"]) != selected_category:
		return false
	if _is_quick_filter_active(QUICK_AFFORDABLE) and GameState.coins < int(item["price"]):
		return false
	if _is_quick_filter_active(QUICK_FLOOR_ITEM) and bool(item["wall_item"]):
		return false
	if _is_quick_filter_active(QUICK_WALL_ITEM) and not bool(item["wall_item"]):
		return false
	if _is_quick_filter_active(QUICK_INTERACTIVE) and not bool(item["interactive"]):
		return false
	if _is_quick_filter_active(QUICK_ROTATABLE) and not ConfigManager.furniture_can_rotate(item):
		return false
	return true

func _sort_indexed_furniture(a: Dictionary, b: Dictionary) -> bool:
	var item_a: Dictionary = a["item"]
	var item_b: Dictionary = b["item"]
	var key_a := _sort_value_for(item_a, selected_sort)
	var key_b := _sort_value_for(item_b, selected_sort)
	if key_a != key_b:
		return key_a > key_b if SORT_DESCENDING_KEYS.has(selected_sort) else key_a < key_b
	var price_a := int(item_a["price"])
	var price_b := int(item_b["price"])
	if price_a != price_b:
		return price_a < price_b
	return int(a["index"]) < int(b["index"])

func _sort_value_for(item: Dictionary, sort_id: String) -> int:
	match sort_id:
		SORT_PRICE_ASC, SORT_PRICE_DESC:
			return int(item["price"])
		SORT_SCORE:
			return ConfigManager.get_furniture_score(item)
		SORT_COMFORT:
			return int(item["comfort"])
		SORT_ENTERTAINMENT:
			return int(item["entertainment"])
		SORT_HYGIENE:
			return int(item["hygiene"])
		SORT_FOOD:
			return int(item["food"])
		_:
			return 0

func _is_quick_filter_active(filter_id: String) -> bool:
	return bool(active_quick_filters.get(filter_id, false))

func _on_category_dropdown_selected(index: int) -> void:
	if index < 0 or index >= category_option_ids.size():
		return
	selected_category = category_option_ids[index]
	_refresh_list()

func _on_sort_dropdown_selected(index: int) -> void:
	if index < 0 or index >= sort_option_ids.size():
		return
	selected_sort = sort_option_ids[index]
	_refresh_list()

func _on_quick_filter_pressed(filter_id: String) -> void:
	active_quick_filters[filter_id] = not _is_quick_filter_active(filter_id)
	_refresh_list()

func _connect_coin_updates() -> void:
	if not GameEvents.coins_changed.is_connected(_on_coins_changed):
		GameEvents.coins_changed.connect(_on_coins_changed)

func _on_coins_changed(_value: int) -> void:
	if room_id.is_empty():
		return
	_refresh_list()

func _on_place_pressed(furniture_id: String) -> void:
	place_requested.emit(furniture_id, room_id)
