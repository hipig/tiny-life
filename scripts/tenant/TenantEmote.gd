class_name TenantEmote
extends Control

const META_EMOTE_KEY := &"emote_key"
const META_EMOTE_KEYS := &"emote_keys"

@onready var emote_animation: AnimatedSprite2D = $EmoteAnimation
@onready var icon_root: Control = $IconRoot

var play_token := 0

func _ready() -> void:
	_hide_icons()
	visible = false

func play_emote(emote_key: String, seconds := 1.2) -> void:
	play_token += 1
	var token := play_token
	_hide_icons()
	var icon := _find_icon_for_emote(emote_key)
	if icon == null:
		push_error("TenantEmote.tscn is missing an icon for emote '%s'." % emote_key)
		visible = false
		return
	if not _play_emote_animation():
		visible = false
		return
	visible = true
	await emote_animation.animation_finished
	if token != play_token or not is_instance_valid(icon):
		return
	icon.visible = true
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(self) and token == play_token:
		visible = false

func _hide_icons() -> void:
	for child in icon_root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

func _play_emote_animation() -> bool:
	if emote_animation.sprite_frames == null:
		push_error("TenantEmote EmoteAnimation is missing SpriteFrames.")
		return false
	var animation_name := str(emote_animation.animation)
	if animation_name.is_empty():
		push_error("TenantEmote EmoteAnimation must select an animation in the scene.")
		return false
	if not emote_animation.sprite_frames.has_animation(animation_name):
		push_error("TenantEmote EmoteAnimation is missing animation '%s'." % animation_name)
		return false
	emote_animation.stop()
	emote_animation.frame = 0
	emote_animation.frame_progress = 0.0
	emote_animation.play(animation_name)
	return true

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
