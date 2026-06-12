class_name ProgressCard
extends PanelContainer

@onready var icon: TextureRect = $Body/Header/Icon
@onready var title_label: Label = $Body/Header/TitleLabel
@onready var progress_bar: ProgressBar = $Body/ProgressBar

var title_template := ""

var _ratio := 0.0
var _base_title := ""

func _ready() -> void:
	_bind_scene_text()
	_base_title = title_label.text

func setup(title: String, progress_text: String, ratio: float, icon_file := "XP_bar_5.png", _color_name := "white") -> void:
	AssetResolver.apply_asset_to_texture_rect(icon, UIPanelFactory.icon_asset(icon_file), Vector2i(16, 16))
	title_label.text = title
	_base_title = title
	set_progress(progress_text, ratio)

func set_progress(progress_text: String, ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	var base_title := _base_title
	if base_title.is_empty():
		base_title = title_label.text
		_base_title = base_title
	title_label.text = title_template % [base_title, progress_text] if not title_template.is_empty() else base_title
	progress_bar.value = _ratio

func _bind_scene_text() -> void:
	title_template = _template_text("TitleTemplate")

func _template_text(node_name: String) -> String:
	var template_label := get_node_or_null("TemplateText/%s" % node_name) as Label
	if template_label == null:
		push_error("ProgressCard scene is missing TemplateText/%s." % node_name)
		return ""
	return template_label.text
