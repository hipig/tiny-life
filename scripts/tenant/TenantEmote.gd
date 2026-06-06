class_name TenantEmote
extends Label

func _ready() -> void:
	visible = false
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func play_emote(text_value: String, seconds := 1.2) -> void:
	text = text_value
	visible = not text.is_empty()
	if text.is_empty():
		return
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(self):
		visible = false
