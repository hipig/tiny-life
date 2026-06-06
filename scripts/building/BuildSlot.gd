extends Button

var floor_index := 0

func _ready() -> void:
	UIPanelFactory.style_button(self, Vector2(560, 100))
	clip_text = true
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func setup(index: int) -> void:
	floor_index = index
	if is_inside_tree():
		_refresh()

func _refresh() -> void:
	var floor: Dictionary = ConfigManager.get_floor_data(floor_index)
	if floor.is_empty():
		visible = false
		return
	var required_level := int(floor.get("required_apartment_level", 1))
	var display_name := str(floor.get("display_name", "%dF" % floor_index))
	if GameState.apartment_level < required_level:
		text = "%s 待开放  Lv.%d 解锁" % [display_name, required_level]
		disabled = true
		return
	disabled = false
	text = "%s 待修建\n需要金币 %d" % [display_name, int(floor.get("build_cost", 0))]

func _on_pressed() -> void:
	if floor_index > 0 and not disabled:
		UIManager.open_build_confirm(floor_index)
