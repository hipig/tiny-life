class_name FloatingCoinText
extends Label

func _ready() -> void:
	visible = false
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 24)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_shadow_color", Color.BLACK)
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)

func show_message(message: String, seconds := 1.6) -> void:
	text = message
	visible = true
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(self):
		visible = false
