class_name RentDetailPanel
extends "res://scripts/ui/AppPanel.gd"

func open() -> void:
	setup_panel("租金构成")
	for room in GameState.get_unlocked_rooms():
		var room_data: Dictionary = room
		var tenant_id := str(room_data.get("tenant_id", ""))
		if tenant_id.is_empty():
			add_text("%s：空房，不产生租金" % room_data.get("room_name", ""))
			continue
		var tenant_data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
		var breakdown: Dictionary = EconomyManager.get_room_rent_breakdown(room_data)
		add_text("%s：%.1f / 分钟\n基础 %.1f + 评分加成 %.1f，租客 %s 倍率 %.2f，满意度倍率 %.2f" % [
			room_data.get("room_name", ""),
			float(breakdown.get("rent", 0.0)),
			float(breakdown.get("base_rent", 0.0)),
			float(breakdown.get("score_part", 0.0)),
			tenant_data.get("name", "租客"),
			float(breakdown.get("pay_multiplier", 1.0)),
			float(breakdown.get("satisfaction_multiplier", 1.0))
		])
