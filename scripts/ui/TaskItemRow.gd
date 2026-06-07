class_name TaskItemRow
extends PanelContainer

@onready var icon: TextureRect = $Body/Header/Icon
@onready var title_label: Label = $Body/Header/TitleLabel
@onready var progress_label: Label = $Body/Header/ProgressLabel
@onready var progress_bar: ProgressBar = $Body/ProgressBar
@onready var description_label: Label = $Body/DescriptionLabel
@onready var reward_label: Label = $Body/RewardLabel

var completed_text := ""
var progress_text_template := ""
var reward_text_template := ""

var _ratio := 0.0

func setup(task: Dictionary) -> void:
	_bind_scene_text()
	var target := int(task.get("target_value", 1))
	var progress: int = min(int(task.get("progress", 0)), target)
	var completed := bool(task.get("completed", false))
	var status := completed_text if completed else progress_text_template % [progress, target]
	_ratio = 1.0 if target <= 0 else clampf(float(progress) / float(target), 0.0, 1.0)
	title_label.text = str(task.get("title", ""))
	progress_label.text = status
	description_label.text = str(task.get("description", ""))
	reward_label.text = reward_text_template % [
		int(task.get("reward_coins", 0)),
		int(task.get("reward_exp", 0))
	]
	progress_bar.value = _ratio

func _bind_scene_text() -> void:
	completed_text = _template_text("CompletedText")
	progress_text_template = _template_text("ProgressTextTemplate")
	reward_text_template = _template_text("RewardTextTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("TaskItemRow scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
