class_name TenantEmote
extends Control

const META_EMOTE_KEY := &"emote_key"
const META_EMOTE_KEYS := &"emote_keys"

@onready var emote_animation: AnimatedSprite2D = $EmoteAnimation
@onready var icon_root: Control = $IconRoot

func _ready() -> void:
	_hide_icons()
	_play_emote_animation()
	visible = false

func play_emote(emote_key: String, seconds := 1.2) -> void:
	_hide_icons()
	var icon := _find_icon_for_emote(emote_key)
	if icon == null:
		visible = false
		return
	icon.visible = true
	_play_emote_animation()
	visible = true
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(self):
		visible = false

func _hide_icons() -> void:
	for child in icon_root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

func _play_emote_animation() -> void:
	if emote_animation.sprite_frames == null:
		return
	var animation_name := str(emote_animation.animation)
	if not animation_name.is_empty() and emote_animation.sprite_frames.has_animation(animation_name):
		emote_animation.play(animation_name)
		return
	var animation_names := emote_animation.sprite_frames.get_animation_names()
	if not animation_names.is_empty():
		emote_animation.play(animation_names[0])

func _find_icon_for_emote(emote_key: String) -> CanvasItem:
	for child in icon_root.get_children():
		if child is CanvasItem and _metadata_matches(child, emote_key):
			return child as CanvasItem
	return null

func _metadata_matches(node: Node, key: String) -> bool:
	if key.is_empty():
		return false
	if node.has_meta(META_EMOTE_KEY) and str(node.get_meta(META_EMOTE_KEY)).strip_edges() == key:
		return true
	if node.has_meta(META_EMOTE_KEYS):
		return _metadata_key_list_has(node.get_meta(META_EMOTE_KEYS), key)
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
