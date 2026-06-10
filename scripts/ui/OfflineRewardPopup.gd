class_name OfflineRewardPopup
extends "res://scripts/ui/AppPanel.gd"

signal claim_requested(double: bool)

var list_root: VBoxContainer
var button_row: HBoxContainer
var offline_info_row: IconInfoRow
var amount_card: StatCard
var claim_button: PanelActionButton
var double_claim_button: PanelActionButton

var offline_duration_title_template := ""

func open(amount: int, seconds: int) -> void:
	setup_panel("", false)
	_bind_scene_nodes()
	if not _has_required_nodes():
		return
	_bind_scene_text()
	offline_info_row.set_title(offline_duration_title_template % TimeManager.format_duration(seconds))
	amount_card.set_value("%d" % amount)
	if not claim_button.action_requested.is_connected(_on_claim_pressed):
		claim_button.action_requested.connect(_on_claim_pressed)
	if not double_claim_button.action_requested.is_connected(_on_double_claim_pressed):
		double_claim_button.action_requested.connect(_on_double_claim_pressed)

func _bind_scene_nodes() -> void:
	list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ListRoot") as VBoxContainer
	button_row = get_node_or_null("PanelBox/ButtonRow") as HBoxContainer
	if list_root == null or button_row == null:
		return
	offline_info_row = list_root.get_node_or_null("OfflineInfoRow") as IconInfoRow
	amount_card = list_root.get_node_or_null("AmountCard") as StatCard
	claim_button = button_row.get_node_or_null("ClaimButton") as PanelActionButton
	double_claim_button = button_row.get_node_or_null("DoubleClaimButton") as PanelActionButton

func _has_required_nodes() -> bool:
	var ready := list_root != null \
		and button_row != null \
		and offline_info_row != null \
		and amount_card != null \
		and claim_button != null \
		and double_claim_button != null
	if not ready:
		push_error("OfflineRewardPopup scene is missing ListRoot, fixed ButtonRow, or one of its content/action nodes.")
	return ready

func _bind_scene_text() -> void:
	offline_duration_title_template = _template_text("OfflineDurationTitleTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("OfflineRewardPopup scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _on_claim_pressed() -> void:
	claim_requested.emit(false)

func _on_double_claim_pressed() -> void:
	claim_requested.emit(true)
