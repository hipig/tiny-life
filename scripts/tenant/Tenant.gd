extends Control

const META_DEFAULT_AVATAR_ANIMATION := &"default_avatar_animation"
const META_BEHAVIOR_KEY := &"behavior_key"
const META_BEHAVIOR_KEYS := &"behavior_keys"
const META_AVATAR_ANIMATION := &"avatar_animation"
const META_MOVES := &"moves"

@onready var color_fallback: ColorRect = $ColorFallback
@onready var avatar_sprite: AnimatedSprite2D = $AvatarSprite
@onready var need_bubble: NeedBubble = $NeedBubble
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_bindings: Node = get_node_or_null("BehaviorAnimationMap")

var tenant_id := ""
var room_id := ""
var current_animation := ""
var current_behavior := ""
var current_behavior_moves := false
var base_position := Vector2.ZERO
var wander_phase := 0.0
var fallback_animation := ""
var behavior_animation_by_key := {}
var behavior_moves_by_key := {}

func _ready() -> void:
	base_position = position
	_bind_scene_animation_config()
	_connect_events()
	if not tenant_id.is_empty():
		_refresh()

func _process(delta: float) -> void:
	if not current_behavior_moves:
		position = base_position
		return
	wander_phase += delta
	position.x = base_position.x + sin(wander_phase * 1.35) * 12.0

func setup(id: String, target_room_id := "") -> void:
	tenant_id = id
	room_id = target_room_id
	if is_inside_tree():
		base_position = position
		_refresh()

func _refresh() -> void:
	var state: Dictionary = GameState.tenants.get(tenant_id, {})
	var behavior := ConfigManager.normalize_behavior_key(str(state.get("current_behavior", "")), "wander")
	current_behavior = behavior
	current_behavior_moves = _behavior_moves(behavior)
	var next_animation := _animation_for_behavior(behavior)
	_play_avatar_animation(next_animation)
	need_bubble.show_behavior(behavior)
	if not fallback_animation.is_empty() and animation_player.has_animation(fallback_animation):
		animation_player.play(fallback_animation)

func _animation_for_behavior(behavior: String) -> String:
	return str(behavior_animation_by_key.get(behavior, fallback_animation))

func _behavior_moves(behavior: String) -> bool:
	return bool(behavior_moves_by_key.get(behavior, false))

func _bind_scene_animation_config() -> void:
	behavior_animation_by_key.clear()
	behavior_moves_by_key.clear()
	fallback_animation = str(avatar_sprite.animation)
	if animation_bindings == null:
		push_error("Tenant.tscn is missing BehaviorAnimationMap.")
		return
	var configured_fallback := _scene_meta_text(animation_bindings, META_DEFAULT_AVATAR_ANIMATION)
	if not configured_fallback.is_empty():
		fallback_animation = configured_fallback
	for child in animation_bindings.get_children():
		var animation_name := _scene_meta_text(child, META_AVATAR_ANIMATION)
		if animation_name.is_empty():
			continue
		var moves := false
		if child.has_meta(META_MOVES):
			moves = bool(child.get_meta(META_MOVES))
		for behavior_key in _metadata_keys(child, META_BEHAVIOR_KEY, META_BEHAVIOR_KEYS):
			behavior_animation_by_key[behavior_key] = animation_name
			behavior_moves_by_key[behavior_key] = moves

func _connect_events() -> void:
	if not GameEvents.tenant_behavior_observed.is_connected(_on_tenant_behavior_observed):
		GameEvents.tenant_behavior_observed.connect(_on_tenant_behavior_observed)
	if not GameEvents.tenant_recruited.is_connected(_on_tenant_recruited):
		GameEvents.tenant_recruited.connect(_on_tenant_recruited)
	if not GameEvents.state_loaded.is_connected(_on_state_loaded):
		GameEvents.state_loaded.connect(_on_state_loaded)

func _on_tenant_behavior_observed(changed_tenant_id: String, _behavior: String) -> void:
	if changed_tenant_id == tenant_id:
		_refresh()

func _on_tenant_recruited(changed_tenant_id: String, _room_id: String) -> void:
	if changed_tenant_id == tenant_id:
		_refresh()

func _on_state_loaded() -> void:
	if not tenant_id.is_empty():
		_refresh()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		if _can_open_tenant_panel(mouse_event.position):
			_open_tenant_panel()
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and _can_open_tenant_panel(touch_event.position):
			_open_tenant_panel()
			accept_event()

func _can_open_tenant_panel(local_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(local_position) and (
		UIManager.current_state == UIManager.UIState.NORMAL
		or UIManager.current_state == UIManager.UIState.ROOM_PANEL
	)

func _open_tenant_panel() -> void:
	var target_room_id := room_id
	if target_room_id.is_empty():
		var tenant: Dictionary = GameState.tenants.get(tenant_id, {})
		target_room_id = str(tenant.get("room_id", ""))
	if not target_room_id.is_empty():
		UIManager.open_tenant_panel(target_room_id)

func _play_avatar_animation(animation_name: String) -> void:
	if avatar_sprite.sprite_frames == null:
		current_animation = ""
		avatar_sprite.visible = false
		color_fallback.visible = true
		return
	var playable_animation := animation_name
	if not avatar_sprite.sprite_frames.has_animation(playable_animation):
		playable_animation = fallback_animation
	if not avatar_sprite.sprite_frames.has_animation(playable_animation):
		current_animation = ""
		avatar_sprite.visible = false
		color_fallback.visible = true
		return
	current_animation = playable_animation
	color_fallback.visible = false
	avatar_sprite.visible = true
	avatar_sprite.play(playable_animation)

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
