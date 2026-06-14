class_name Tenant
extends CharacterBody2D

const META_BEHAVIOR_KEY := &"behavior_key"
const META_BEHAVIOR_KEYS := &"behavior_keys"
const META_AVATAR_ANIMATION := &"avatar_animation"
const TENANT_VIEW_GROUP := &"tenant_views"
const META_TENANT_ID := &"tenant_id"
const META_ROOM_ID := &"room_id"

@onready var avatar_sprite: AnimatedSprite2D = $AvatarSprite
@onready var need_bubble: NeedBubble = $NeedBubble
@onready var tenant_emote: TenantEmote = $TenantEmote
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var click_area: Area2D = get_node_or_null("ClickArea") as Area2D
@onready var click_shape: CollisionShape2D = get_node_or_null("ClickArea/ClickShape") as CollisionShape2D
@onready var animation_bindings: Node = get_node_or_null("BehaviorAnimationMap")
@onready var tenant_ai: TenantAI = get_node_or_null("TenantAI") as TenantAI

var tenant_id := ""
var room_id := ""
var current_animation := ""
var current_behavior := ""
var behavior_animation_by_key := {}
var click_handled_frame := -1
var ai_position_initialized := false

func _ready() -> void:
	_bind_scene_animation_config()
	_connect_click_area()
	_connect_events()
	if not tenant_id.is_empty():
		_apply_avatar_asset()
		_start_ai()
		_refresh()

func setup(id: String, target_room_id := "") -> void:
	tenant_id = id
	room_id = target_room_id
	_bind_view_identity()
	if is_inside_tree():
		_apply_avatar_asset()
		_start_ai()
		_refresh()

func _bind_view_identity() -> void:
	if not is_in_group(TENANT_VIEW_GROUP):
		add_to_group(TENANT_VIEW_GROUP)
	set_meta(META_TENANT_ID, tenant_id)
	set_meta(META_ROOM_ID, room_id)

func _refresh() -> void:
	var state: Dictionary = GameState.tenants.get(tenant_id, {})
	var behavior := ConfigManager.normalize_behavior_key(str(state.get("current_behavior", GameState.DEFAULT_TENANT_BEHAVIOR)))
	current_behavior = behavior
	var next_animation := _animation_for_behavior(behavior)
	_play_avatar_animation(next_animation)
	if _uses_bubble_for_behavior(behavior):
		need_bubble.show_behavior(behavior)
	else:
		need_bubble.hide_bubble()

func _start_ai() -> void:
	if tenant_ai == null:
		push_error("Tenant.tscn must expose a TenantAI child.")
		return
	tenant_ai.setup(self, tenant_id, room_id)

func play_avatar_behavior(behavior: String) -> void:
	var key := ConfigManager.normalize_behavior_key(behavior)
	_play_avatar_animation(_animation_for_behavior(key))

func show_behavior_bubble(behavior: String) -> void:
	var key := ConfigManager.normalize_behavior_key(behavior)
	if need_bubble.has_behavior_icon(key):
		need_bubble.show_behavior(key)
	else:
		push_error("Tenant NeedBubble is missing an icon for behavior '%s'." % key)

func hide_behavior_bubble() -> void:
	need_bubble.hide_bubble()

func play_emote(emote_key: String, seconds := 1.2) -> void:
	if tenant_emote != null:
		tenant_emote.play_emote(emote_key, seconds)

func face_towards(delta_x: float) -> void:
	if absf(delta_x) < 0.01:
		return
	avatar_sprite.flip_h = delta_x < 0.0

func _animation_for_behavior(behavior: String) -> String:
	if behavior_animation_by_key.has(behavior):
		return str(behavior_animation_by_key[behavior])
	if need_bubble.has_behavior_icon(behavior):
		if behavior_animation_by_key.has(GameState.IDLE_TENANT_BEHAVIOR):
			return str(behavior_animation_by_key[GameState.IDLE_TENANT_BEHAVIOR])
		push_error("Tenant.tscn is missing an idle avatar animation binding for bubble behavior '%s'." % behavior)
		return ""
	push_error("Tenant.tscn is missing an avatar animation binding or behavior icon for behavior '%s'." % behavior)
	return ""

func _uses_bubble_for_behavior(behavior: String) -> bool:
	return not behavior_animation_by_key.has(behavior) and need_bubble.has_behavior_icon(behavior)

func _bind_scene_animation_config() -> void:
	behavior_animation_by_key.clear()
	if animation_bindings == null:
		push_error("Tenant.tscn is missing BehaviorAnimationMap.")
		return
	for child in animation_bindings.get_children():
		var animation_name := _scene_meta_text(child, META_AVATAR_ANIMATION)
		if animation_name.is_empty():
			push_error("Tenant behavior animation binding '%s' is missing avatar_animation metadata." % child.name)
			continue
		var behavior_keys := _metadata_keys(child, META_BEHAVIOR_KEY, META_BEHAVIOR_KEYS)
		if behavior_keys.is_empty():
			push_error("Tenant behavior animation binding '%s' is missing behavior metadata." % child.name)
			continue
		for behavior_key in behavior_keys:
			behavior_animation_by_key[behavior_key] = animation_name

func _apply_avatar_asset() -> void:
	var tenant_data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var asset: Dictionary = tenant_data["asset"]
	var avatar_offset: Array = asset["avatar_offset"]
	_apply_avatar_offset(Vector2(float(avatar_offset[0]), float(avatar_offset[1])))
	var default_animation := str(asset["default_animation"])
	AssetResolver.apply_asset_to_animated_sprite(
		avatar_sprite,
		asset,
		default_animation,
		_vector2i_from_array(asset["frame_size"])
	)
	current_animation = ""

func _apply_avatar_offset(offset: Vector2) -> void:
	avatar_sprite.position = offset
	if body_shape != null:
		body_shape.position = offset
	if click_shape != null:
		click_shape.position = offset

func _connect_click_area() -> void:
	if click_area == null:
		push_error("Tenant.tscn must expose a ClickArea Area2D child.")
		return
	if not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)

func _connect_events() -> void:
	if not GameEvents.tenant_behavior_changed.is_connected(_on_tenant_behavior_changed):
		GameEvents.tenant_behavior_changed.connect(_on_tenant_behavior_changed)
	if not GameEvents.tenant_recruited.is_connected(_on_tenant_recruited):
		GameEvents.tenant_recruited.connect(_on_tenant_recruited)
	if not GameEvents.state_loaded.is_connected(_on_state_loaded):
		GameEvents.state_loaded.connect(_on_state_loaded)

func _on_tenant_behavior_changed(changed_tenant_id: String, _behavior: String) -> void:
	if changed_tenant_id == tenant_id:
		_refresh()

func _on_tenant_recruited(changed_tenant_id: String, _room_id: String) -> void:
	if changed_tenant_id == tenant_id:
		_apply_avatar_asset()
		_refresh()

func _on_state_loaded() -> void:
	if not tenant_id.is_empty():
		_apply_avatar_asset()
		_refresh()

func _input(event: InputEvent) -> void:
	if not _is_primary_press_event(event) or not _can_open_tenant_panel():
		return
	var local_event := make_input_local(event)
	if _click_area_contains_local_position(_event_position(local_event)):
		_open_tenant_panel_from_click()

func _on_click_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if _is_primary_press_event(event) and _can_open_tenant_panel():
		_open_tenant_panel_from_click()

func _is_primary_press_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2.ZERO

func _click_area_contains_local_position(local_position: Vector2) -> bool:
	if click_area == null or click_shape == null or click_shape.shape == null:
		return false
	var area_position := click_area.transform.affine_inverse() * local_position
	var shape_position := click_shape.transform.affine_inverse() * area_position
	if click_shape.shape is RectangleShape2D:
		var rectangle := click_shape.shape as RectangleShape2D
		return Rect2(-rectangle.size * 0.5, rectangle.size).has_point(shape_position)
	push_error("Tenant ClickArea only supports RectangleShape2D hit boxes.")
	return false

func _can_open_tenant_panel() -> bool:
	return UIManager.current_state == UIManager.UIState.NORMAL \
		or UIManager.current_state == UIManager.UIState.ROOM_PANEL

func _open_tenant_panel_from_click() -> void:
	var frame := Engine.get_process_frames()
	if click_handled_frame == frame:
		return
	click_handled_frame = frame
	_open_tenant_panel()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _open_tenant_panel() -> void:
	var target_room_id := room_id
	if target_room_id.is_empty():
		var tenant: Dictionary = GameState.tenants.get(tenant_id, {})
		target_room_id = str(tenant.get("room_id", ""))
	if not target_room_id.is_empty():
		UIManager.open_tenant_panel(target_room_id)

func _play_avatar_animation(animation_name: String) -> void:
	if animation_name.is_empty():
		current_animation = ""
		avatar_sprite.visible = false
		avatar_sprite.stop()
		return
	if avatar_sprite.sprite_frames == null:
		push_error("Tenant AvatarSprite is missing SpriteFrames.")
		current_animation = ""
		avatar_sprite.visible = false
		avatar_sprite.stop()
		return
	if not avatar_sprite.sprite_frames.has_animation(animation_name):
		push_error("Tenant AvatarSprite is missing animation '%s'." % animation_name)
		current_animation = ""
		avatar_sprite.visible = false
		avatar_sprite.stop()
		return
	avatar_sprite.visible = true
	if current_animation != animation_name or not avatar_sprite.is_playing():
		avatar_sprite.play(animation_name)
	current_animation = animation_name

func _scene_meta_text(node: Node, meta_key: StringName) -> String:
	if node == null or not node.has_meta(meta_key):
		return ""
	return str(node.get_meta(meta_key)).strip_edges()

func _metadata_keys(node: Node, single_key: StringName, list_key: StringName) -> Array[String]:
	var keys: Array[String] = []
	if node.has_meta(single_key):
		var single_value := str(node.get_meta(single_key)).strip_edges()
		if not single_value.is_empty():
			keys.append(single_value)
	if node.has_meta(list_key):
		_append_metadata_key_list(keys, node.get_meta(list_key))
	return keys

func _append_metadata_key_list(keys: Array[String], raw_value: Variant) -> void:
	if raw_value is PackedStringArray:
		for item in raw_value:
			_append_metadata_key(keys, str(item))
	elif raw_value is Array:
		for item in raw_value:
			_append_metadata_key(keys, str(item))
	else:
		for item in str(raw_value).split(",", false):
			_append_metadata_key(keys, item)

func _append_metadata_key(keys: Array[String], raw_key: String) -> void:
	var key := raw_key.strip_edges()
	if key.is_empty() or keys.has(key):
		return
	keys.append(key)

func _vector2i_from_array(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	push_error("Tenant asset frame_size must be [width, height].")
	return Vector2i.ZERO
