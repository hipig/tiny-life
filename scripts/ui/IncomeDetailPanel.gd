class_name IncomeDetailPanel
extends "res://scripts/ui/AppPanel.gd"

var stats_grid: GridContainer
var info_root: VBoxContainer
var coin_card: StatCard
var total_rent_card: StatCard
var per_second_card: StatCard
var buffer_card: StatCard
var next_income_row: IconInfoRow
var offline_cap_row: IconInfoRow
var offline_cap_title_prefix := ""
var next_income_idle_text := ""
var next_income_tick_template := "%.1f"
var offline_cap_hours_template := "%d"
var offline_cap_hours_minutes_template := "%d %d"
var rent_value_template := "%.1f"

func open() -> void:
	setup_panel("", false)
	_bind_scene_nodes()
	coin_card.set_value("%d" % GameState.coins)
	total_rent_card.set_value(rent_value_template % GameState.total_rent_per_minute)
	per_second_card.set_value("%.3f" % EconomyManager.get_income_per_second())
	buffer_card.set_value("%.2f / 1.00" % EconomyManager.get_income_buffer())
	next_income_row.set_title(_next_income_tick_text())
	offline_cap_row.set_title("%s%s" % [offline_cap_title_prefix, _offline_cap_text()])

func _bind_scene_nodes() -> void:
	stats_grid = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/StatsGrid") as GridContainer
	info_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/InfoRoot") as VBoxContainer
	coin_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/StatsGrid/CoinCard") as StatCard
	total_rent_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/StatsGrid/TotalRentCard") as StatCard
	per_second_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/StatsGrid/PerSecondCard") as StatCard
	buffer_card = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/StatsGrid/BufferCard") as StatCard
	next_income_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/InfoRoot/NextIncomeRow") as IconInfoRow
	offline_cap_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/InfoRoot/OfflineCapRow") as IconInfoRow
	_bind_scene_text()

func _bind_scene_text() -> void:
	next_income_idle_text = next_income_row.title_label.text
	offline_cap_title_prefix = _template_text("OfflineCapTitlePrefix", "")
	next_income_tick_template = _template_text("NextIncomeTickTemplate", next_income_tick_template)
	offline_cap_hours_template = _template_text("OfflineCapHoursTemplate", offline_cap_hours_template)
	offline_cap_hours_minutes_template = _template_text("OfflineCapHoursMinutesTemplate", offline_cap_hours_minutes_template)
	rent_value_template = _template_text("RentValueTemplate", rent_value_template)

func _template_text(node_name: String, fallback: String) -> String:
	var template_label := get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TemplateText/%s" % node_name) as Label
	if template_label == null:
		return fallback
	return template_label.text

func _next_income_tick_text() -> String:
	var income_per_second: float = EconomyManager.get_income_per_second()
	if income_per_second <= 0.0:
		return next_income_idle_text
	var remaining: float = maxf(0.0, 1.0 - EconomyManager.get_income_buffer())
	var seconds: float = remaining / income_per_second
	return next_income_tick_template % seconds

func _offline_cap_text() -> String:
	var seconds := int(ConfigManager.get_economy_value("max_offline_seconds", 14400))
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	if minutes <= 0:
		return offline_cap_hours_template % hours
	return offline_cap_hours_minutes_template % [hours, minutes]
