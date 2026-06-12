class_name BuildConfirmPopup
extends "res://scripts/ui/AppPanel.gd"

signal build_confirmed(room_id: String)

var room_id := ""
var stats_grid: GridContainer
var message_root: VBoxContainer
var cost_card: StatCard
var coin_card: StatCard
var status_row: IconInfoRow
var confirm_button: Button

var title_template := ""
var can_build_title := ""
var can_build_detail := ""
var can_build_icon_file := ""
var insufficient_title := ""
var insufficient_detail_template := ""
var insufficient_icon_file := ""

func open(target_room_id: String) -> void:
	room_id = target_room_id
	var room_config: Dictionary = ConfigManager.get_room_config(room_id)
	var cost := int(room_config.get("build_cost", 0))
	var room_name := str(room_config.get("room_name", room_id))
	setup_panel("", false)
	_bind_scene_nodes()
	_bind_scene_text()
	title_label.text = title_template % room_name
	cost_card.set_value("%d" % cost)
	coin_card.set_value("%d" % GameState.coins)
	if GameState.coins < cost:
		status_row.set_icon(insufficient_icon_file)
		status_row.set_title(insufficient_title)
		status_row.set_detail(insufficient_detail_template % (cost - GameState.coins))
	else:
		status_row.set_icon(can_build_icon_file)
		status_row.set_title(can_build_title)
		status_row.set_detail(can_build_detail)
	confirm_button.disabled = GameState.coins < cost or not GameState.is_room_buildable(room_id)
	if not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)

func _bind_scene_nodes() -> void:
	stats_grid = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/StatsGrid") as GridContainer
	message_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/MessageRoot") as VBoxContainer
	cost_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/StatsGrid/CostCard") as StatCard
	coin_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/StatsGrid/CoinCard") as StatCard
	status_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/MessageRoot/StatusRow") as IconInfoRow
	confirm_button = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ConfirmButton") as Button

func _bind_scene_text() -> void:
	title_template = _template_text("TitleTemplate")
	can_build_title = _template_text("CanBuildTitle")
	can_build_detail = _template_text("CanBuildDetail")
	can_build_icon_file = _template_text("CanBuildIconFile")
	insufficient_title = _template_text("InsufficientTitle")
	insufficient_detail_template = _template_text("InsufficientDetailTemplate")
	insufficient_icon_file = _template_text("InsufficientIconFile")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("BuildConfirmPopup scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _on_confirm_pressed() -> void:
	build_confirmed.emit(room_id)
