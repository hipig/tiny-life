class_name BuildConfirmPopup
extends "res://scripts/ui/AppPanel.gd"

signal build_confirmed(floor_index: int)

var floor_index := 0

func open(target_floor_index: int) -> void:
	floor_index = target_floor_index
	var floor: Dictionary = ConfigManager.get_floor_data(floor_index)
	var cost := int(floor.get("build_cost", 0))
	setup_panel("建造第 %d 层" % floor_index)
	add_text("需要金币：%d" % cost)
	add_text("当前金币：%d" % GameState.coins)
	if GameState.coins < cost:
		add_text("还差：%d" % (cost - GameState.coins))
	var confirm := Button.new()
	UIPanelFactory.style_button(confirm)
	confirm.text = "确认建造"
	confirm.disabled = GameState.coins < cost
	confirm.pressed.connect(func(): build_confirmed.emit(floor_index))
	content_root.add_child(confirm)
