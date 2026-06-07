class_name TaskPanel
extends "res://scripts/ui/AppPanel.gd"

const TASK_ITEM_ROW_SCENE := preload("res://scenes/ui/TaskItemRow.tscn")

var task_list_root: VBoxContainer
var empty_task_row: IconInfoRow

func open() -> void:
	setup_panel("", false)
	task_list_root = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/TaskListRoot") as VBoxContainer
	empty_task_row = get_node_or_null("PanelBox/ScrollContainer/ContentRoot/EmptyTaskRow") as IconInfoRow
	UIPanelFactory.clear_children(task_list_root)
	var tasks := TaskManager.get_active_tasks()
	empty_task_row.visible = tasks.is_empty()
	if tasks.is_empty():
		return
	for task in tasks:
		var row := TASK_ITEM_ROW_SCENE.instantiate() as TaskItemRow
		task_list_root.add_child(row)
		row.setup(task)
