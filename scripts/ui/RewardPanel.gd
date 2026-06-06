class_name RewardPanel
extends "res://scripts/ui/AppPanel.gd"

signal offline_claim_requested(double: bool)
signal tenant_refresh_requested

func open() -> void:
	setup_panel("福利")
	var offline: Dictionary = EconomyManager.calculate_offline_income()
	add_text("当前可领取离线收益：%d" % int(offline.get("amount", 0)))
	add_action_button("领取离线收益", func(): offline_claim_requested.emit(false), Vector2(260, 56))
	add_action_button("看广告双倍领取", func(): offline_claim_requested.emit(true), Vector2(260, 56))
	add_action_button("看广告刷新租客申请", func(): tenant_refresh_requested.emit(), Vector2(260, 56))
