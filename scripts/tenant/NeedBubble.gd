class_name NeedBubble
extends Control

const META_BEHAVIOR_KEY := &"behavior_key"
const META_BEHAVIOR_KEYS := &"behavior_keys"

@onready var bubble_animation: AnimatedSprite2D = $BubbleAnimation
@onready var icon_root: Control = $IconRoot

var show_token := 0

func _ready() -> void:
	_hide_icons()
	visible = false

func show_behavior(behavior: String) -> void:
	var key := ConfigManager.normalize_behavior_key(behavior)
	show_token += 1
	var token := show_token
	_hide_icons()
	var icon := _find_icon_for_behavior(key)
	if icon == null:
		push_error("NeedBubble.tscn is missing an icon for behavior '%s'." % key)
		visible = false
		return
	if not _play_bubble_animation():
		visible = false
		return
	visible = true
	await bubble_animation.animation_finished
	if token != show_token or not is_instance_valid(icon):
		return
	icon.visible = true

func hide_bubble() -> void:
	show_token += 1
	_hide_icons()
	visible = false

func has_behavior_icon(behavior: String) -> bool:
	var key := ConfigManager.normalize_behavior_key(behavior)
	return _find_icon_for_behavior(key) != null

func _hide_icons() -> void:
	for child in icon_root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

func _play_bubble_animation() -> bool:
	if bubble_animation.sprite_frames == null:
		push_error("NeedBubble BubbleAnimation is missing SpriteFrames.")
		return false
	var animation_name := str(bubble_animation.animation)
	if animation_name.is_empty():
		push_error("NeedBubble BubbleAnimation must select an animation in the scene.")
		return false
	if not bubble_animation.sprite_frames.has_animation(animation_name):
		push_error("NeedBubble BubbleAnimation is missing animation '%s'." % animation_name)
		return false
	bubble_animation.stop()
	bubble_animation.frame = 0
	bubble_animation.frame_progress = 0.0
	bubble_animation.play(animation_name)
	return true

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
