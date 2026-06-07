class_name NeedBubble
extends Control

const META_BEHAVIOR_KEY := &"behavior_key"
const META_BEHAVIOR_KEYS := &"behavior_keys"

@onready var bubble_animation: AnimatedSprite2D = $BubbleAnimation
@onready var icon_root: Control = $IconRoot

func _ready() -> void:
	_hide_icons()
	_play_bubble_animation()
	visible = false

func show_behavior(behavior: String) -> void:
	var key := ConfigManager.normalize_behavior_key(behavior, "")
	_hide_icons()
	var icon := _find_icon_for_behavior(key)
	if icon == null:
		visible = false
		return
	icon.visible = true
	_play_bubble_animation()
	visible = true

func _hide_icons() -> void:
	for child in icon_root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

func _play_bubble_animation() -> void:
	if bubble_animation.sprite_frames == null:
		return
	var animation_name := str(bubble_animation.animation)
	if not animation_name.is_empty() and bubble_animation.sprite_frames.has_animation(animation_name):
		bubble_animation.play(animation_name)
		return
	var animation_names := bubble_animation.sprite_frames.get_animation_names()
	if not animation_names.is_empty():
		bubble_animation.play(animation_names[0])

func _find_icon_for_behavior(behavior_key: String) -> CanvasItem:
	for child in icon_root.get_children():
		if child is CanvasItem and _metadata_matches(child, behavior_key):
			return child as CanvasItem
	return null

func _metadata_matches(node: Node, key: String) -> bool:
	if key.is_empty():
		return false
	if node.has_meta(META_BEHAVIOR_KEY) and str(node.get_meta(META_BEHAVIOR_KEY)).strip_edges() == key:
		return true
	if node.has_meta(META_BEHAVIOR_KEYS):
		return _metadata_key_list_has(node.get_meta(META_BEHAVIOR_KEYS), key)
	return false

func _metadata_key_list_has(raw_value: Variant, key: String) -> bool:
	if raw_value is PackedStringArray:
		for item in raw_value:
			if str(item).strip_edges() == key:
				return true
	elif raw_value is Array:
		for item in raw_value:
			if str(item).strip_edges() == key:
				return true
	else:
		for item in str(raw_value).split(",", false):
			if item.strip_edges() == key:
				return true
	return false
