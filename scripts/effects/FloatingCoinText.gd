class_name FloatingCoinText
extends Label

func show_message(message: String, seconds := 1.6) -> void:
	text = message
	visible = true
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(self):
		visible = false
