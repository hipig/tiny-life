class_name TaskPanel
extends "res://scripts/ui/AppPanel.gd"

func open() -> void:
	setup_panel("任务")
	for task in TaskManager.get_active_tasks():
		var target := int(task.get("target_value", 1))
		var progress: int = min(int(task.get("progress", 0)), target)
		var status := "完成" if bool(task.get("completed", false)) else "%d/%d" % [progress, target]
		add_text("%s  [%s]\n%s" % [task.get("title", ""), status, task.get("description", "")])
