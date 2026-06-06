class_name IncomeDetailPanel
extends "res://scripts/ui/AppPanel.gd"

func open() -> void:
	setup_panel("收益详情")
	add_text("当前金币：%d" % GameState.coins)
	add_text("总租金：%.1f / 分钟" % GameState.total_rent_per_minute)
	add_text("折算每秒收益：%.3f 金币" % EconomyManager.get_income_per_second())
	add_text("当前整数缓冲：%.2f / 1.00" % EconomyManager.get_income_buffer())
	add_text(_next_income_tick_text())
	add_text("自动收益按整数金币入账，小数会留在缓冲中。")
	add_text("离线收益上限：%s" % _offline_cap_text())

func _next_income_tick_text() -> String:
	var income_per_second: float = EconomyManager.get_income_per_second()
	if income_per_second <= 0.0:
		return "当前没有自动租金收入"
	var remaining: float = maxf(0.0, 1.0 - EconomyManager.get_income_buffer())
	var seconds: float = remaining / income_per_second
	return "约 %.1f 秒后入账下 1 个整数金币" % seconds

func _offline_cap_text() -> String:
	var seconds := int(ConfigManager.get_economy_value("max_offline_seconds", 14400))
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	if minutes <= 0:
		return "%d 小时" % hours
	return "%d 小时 %d 分钟" % [hours, minutes]
