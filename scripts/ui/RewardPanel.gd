class_name RewardPanel
extends "res://scripts/ui/AppPanel.gd"

signal offline_claim_requested(double: bool)
signal tenant_refresh_requested

var list_root: VBoxContainer
var offline_income_card: StatCard
var offline_double_row: IconInfoRow
var tenant_refresh_row: IconInfoRow
var offline_claim_button: PanelActionButton
var offline_double_button: PanelActionButton
var tenant_refresh_button: PanelActionButton

var offline_income_value_template := ""

func open() -> void:
	setup_panel("", false)
	_bind_scene_nodes()
	_bind_scene_text()
	var offline: Dictionary = EconomyManager.calculate_offline_income()
	offline_income_card.set_value(offline_income_value_template % int(offline.get("amount", 0)))
	_connect_buttons()

func _bind_scene_nodes() -> void:
	list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/ListRoot") as VBoxContainer
	offline_income_card = list_root.get_node_or_null("OfflineIncomeCard") as StatCard
	offline_double_row = list_root.get_node_or_null("OfflineDoubleRow") as IconInfoRow
	tenant_refresh_row = list_root.get_node_or_null("TenantRefreshRow") as IconInfoRow
	offline_claim_button = list_root.get_node_or_null("OfflineClaimButton") as PanelActionButton
	offline_double_button = list_root.get_node_or_null("OfflineDoubleButton") as PanelActionButton
	tenant_refresh_button = list_root.get_node_or_null("TenantRefreshButton") as PanelActionButton

func _bind_scene_text() -> void:
	offline_income_value_template = _template_text("OfflineIncomeValueTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("RewardPanel scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text

func _connect_buttons() -> void:
	if not offline_claim_button.action_requested.is_connected(_on_offline_claim_pressed):
		offline_claim_button.action_requested.connect(_on_offline_claim_pressed)
	if not offline_double_button.action_requested.is_connected(_on_offline_double_pressed):
		offline_double_button.action_requested.connect(_on_offline_double_pressed)
	if not tenant_refresh_button.action_requested.is_connected(_on_tenant_refresh_pressed):
		tenant_refresh_button.action_requested.connect(_on_tenant_refresh_pressed)

func _on_offline_claim_pressed() -> void:
	offline_claim_requested.emit(false)

func _on_offline_double_pressed() -> void:
	offline_claim_requested.emit(true)

func _on_tenant_refresh_pressed() -> void:
	tenant_refresh_requested.emit()
