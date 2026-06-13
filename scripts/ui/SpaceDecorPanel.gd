class_name SpaceDecorPanel
extends "res://scripts/ui/AppPanel.gd"

signal decor_apply_requested(target_ref: Dictionary, decor_id: String)

var target_ref: Dictionary = {}
var selected_category := ""

var decor_catalog
var title_template := ""

func open(next_target_ref: Dictionary, initial_category := "") -> void:
	target_ref = next_target_ref.duplicate(true)
	selected_category = initial_category
	_refresh()

func refresh() -> void:
	if target_ref.is_empty():
		return
	_refresh()

func _refresh() -> void:
	_bind_scene_text()
	setup_panel(title_template % str(target_ref.get("title", "")), false)
	_bind_scene_nodes()
	if decor_catalog != null:
		decor_catalog.open(target_ref, selected_category)
		selected_category = decor_catalog.get_selected_category()

func _bind_scene_nodes() -> void:
	decor_catalog = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/DecorCatalog")
	if decor_catalog == null:
		push_error("SpaceDecorPanel.tscn must expose DecorCatalog.")
		return
	if not decor_catalog.apply_requested.is_connected(_on_decor_apply_pressed):
		decor_catalog.apply_requested.connect(_on_decor_apply_pressed)
	if not decor_catalog.category_changed.is_connected(_on_category_changed):
		decor_catalog.category_changed.connect(_on_category_changed)

func _bind_scene_text() -> void:
	title_template = _template_text("TitleTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("SpaceDecorPanel scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _on_decor_apply_pressed(decor_id: String) -> void:
	decor_apply_requested.emit(target_ref.duplicate(true), decor_id)

func _on_category_changed(category: String) -> void:
	selected_category = category
