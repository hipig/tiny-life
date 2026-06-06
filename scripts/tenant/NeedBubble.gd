class_name NeedBubble
extends Label

func _ready() -> void:
	visible = false
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_behavior(behavior: String) -> void:
	text = _bubble_text(behavior)
	visible = not text.is_empty()

func _bubble_text(behavior: String) -> String:
	match behavior:
		"energy", "睡觉":
			return "Zzz"
		"study", "学习/工作":
			return "书"
		"entertainment", "娱乐":
			return "♪"
		"hunger", "吃东西":
			return "食"
		"hygiene", "清洁":
			return "水"
		"comfort", "放松":
			return "心"
		"入住":
			return "Hi"
		_:
			return ""
