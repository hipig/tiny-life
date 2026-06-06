extends HBoxContainer

const ROOM_SCENE := preload("res://scenes/building/Room.tscn")
const ROOM_HEIGHT := 130.0

var floor_index := 0

func setup(index: int) -> void:
	floor_index = index
	UIPanelFactory.clear_children(self)
	add_theme_constant_override("separation", 8)

	var floor_data: Dictionary = ConfigManager.get_floor_data(floor_index)
	var label := Label.new()
	label.text = str(floor_data.get("display_name", "%dF" % floor_index))
	label.custom_minimum_size = Vector2(64, ROOM_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)

	for room in ConfigManager.rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) != floor_index:
			continue
		var room_view := ROOM_SCENE.instantiate()
		add_child(room_view)
		room_view.setup(str(room_data.get("id", "")))
