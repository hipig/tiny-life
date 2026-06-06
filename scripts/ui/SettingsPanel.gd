class_name SettingsPanel
extends "res://scripts/ui/AppPanel.gd"

signal save_requested
signal reset_requested

func open() -> void:
	setup_panel("设置")
	add_text("音效：开")
	add_text("音乐：开")
	add_text("语言：中文")
	add_text("画质：移动端")
	add_text("隐私 / 用户协议：占位入口")
	add_action_button("立即存档", func(): save_requested.emit())
	add_action_button("重置数据", func(): reset_requested.emit())
