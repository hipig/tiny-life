class_name OfflineRewardPopup
extends "res://scripts/ui/AppPanel.gd"

signal claim_requested(double: bool)

func open(amount: int, seconds: int) -> void:
	setup_panel("离线收益")
	add_text("你离线了 %s" % TimeManager.format_duration(seconds))
	add_text("获得金币：%d" % amount)
	add_action_button("领取", func(): claim_requested.emit(false), Vector2(260, 56))
	add_action_button("看广告双倍领取", func(): claim_requested.emit(true), Vector2(260, 56))
