class_name PanelTabButton
extends Button

signal tab_selected(tab_id: String)

const META_TAB_ID := &"tab_id"

var tab_id := ""

func _ready() -> void:
	_bind_scene_tab_id()

func setup(id := "", selected := false) -> void:
	if not id.is_empty():
		tab_id = id
	if tab_id.is_empty():
		_bind_scene_tab_id()
	disabled = selected
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	tab_selected.emit(tab_id)

func _bind_scene_tab_id() -> void:
	if has_meta(META_TAB_ID):
		tab_id = str(get_meta(META_TAB_ID)).strip_edges()
