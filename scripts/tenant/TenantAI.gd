class_name TenantAI
extends Node

enum AIState {
	IDLE,
	WALK,
	JUMP,
	BUBBLE_ACTION
}

const WALK_SPEED := 18.0
const ARRIVE_DISTANCE := 0.5
const IDLE_MIN_SECONDS := 2.0
const IDLE_MAX_SECONDS := 4.0
const JUMP_SECONDS := 0.8
const DEFAULT_ACTION_SECONDS := 3.0

var tenant: Tenant
var tenant_id := ""
var room_id := ""
var state := AIState.IDLE
var state_elapsed := 0.0
var state_duration := 0.0
var target_position := Vector2.ZERO
var pending_action_need := ""
var pending_action_duration := DEFAULT_ACTION_SECONDS

func setup(owner: Tenant, id: String, target_room_id: String) -> void:
	tenant = owner
	tenant_id = id
	room_id = target_room_id
	if tenant == null or room_id.is_empty():
		return
	tenant.position = TenantRoomLocator.spawn_position(_room())
	_sync_from_current_behavior()

func _process(delta: float) -> void:
	if tenant == null or tenant_id.is_empty() or room_id.is_empty() or _ai_paused():
		return
	state_elapsed += delta
	match state:
		AIState.IDLE:
			if state_elapsed >= state_duration:
				_choose_next_state()
		AIState.WALK:
			_process_walk(delta)
		AIState.JUMP:
			if state_elapsed >= state_duration:
				_enter_idle()
		AIState.BUBBLE_ACTION:
			if state_elapsed >= state_duration:
				tenant.hide_behavior_bubble()
				_enter_idle()

func _choose_next_state() -> void:
	var interactions := _interaction_targets()
	var roll := randf()
	if not interactions.is_empty() and roll < 0.35:
		_walk_to_interaction(interactions.pick_random())
	elif roll < 0.65:
		_enter_patrol_walk()
	elif roll < 0.82:
		_enter_jump()
	else:
		_enter_idle()

func _sync_from_current_behavior() -> void:
	state_elapsed = 0.0
	pending_action_need = ""
	var tenant_state: Dictionary = GameState.tenants.get(tenant_id, {})
	var current_need := str(tenant_state.get("current_need", ""))
	var behavior := ConfigManager.normalize_behavior_key(
		str(tenant_state.get("current_behavior", "")),
		GameState.IDLE_TENANT_BEHAVIOR
	)
	if not current_need.is_empty():
		state = AIState.BUBBLE_ACTION
		pending_action_need = current_need
		pending_action_duration = DEFAULT_ACTION_SECONDS
		state_duration = pending_action_duration
		return
	if behavior == GameState.DEFAULT_TENANT_BEHAVIOR:
		_enter_patrol_walk()
		return
	if behavior == "happy" or behavior == "jump":
		state = AIState.JUMP
		state_duration = JUMP_SECONDS
		return
	state = AIState.IDLE
	state_duration = randf_range(IDLE_MIN_SECONDS, IDLE_MAX_SECONDS)

func _enter_idle() -> void:
	state = AIState.IDLE
	state_elapsed = 0.0
	state_duration = randf_range(IDLE_MIN_SECONDS, IDLE_MAX_SECONDS)
	pending_action_need = ""
	GameState.set_tenant_behavior(tenant_id, GameState.IDLE_TENANT_BEHAVIOR)
	tenant.play_avatar_behavior(GameState.IDLE_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()

func _enter_patrol_walk() -> void:
	var positions := TenantRoomLocator.walk_positions(_room())
	if positions.is_empty():
		_enter_idle()
		return
	var left: Vector2 = positions[0]
	var right: Vector2 = positions[positions.size() - 1]
	target_position = left if tenant.position.distance_to(right) < tenant.position.distance_to(left) else right
	_enter_walk()

func _walk_to_interaction(target: Dictionary) -> void:
	pending_action_need = str(target.get("need", ""))
	pending_action_duration = maxf(0.1, float(target.get("duration", DEFAULT_ACTION_SECONDS)))
	var position_value: Variant = target.get("position", tenant.position)
	target_position = position_value if position_value is Vector2 else tenant.position
	_enter_walk()

func _enter_walk() -> void:
	state = AIState.WALK
	state_elapsed = 0.0
	GameState.set_tenant_behavior(tenant_id, GameState.DEFAULT_TENANT_BEHAVIOR)
	tenant.play_avatar_behavior(GameState.DEFAULT_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()
	tenant.face_towards(target_position.x - tenant.position.x)

func _process_walk(delta: float) -> void:
	var previous := tenant.position
	tenant.position = tenant.position.move_toward(target_position, WALK_SPEED * delta)
	tenant.face_towards(tenant.position.x - previous.x)
	if tenant.position.distance_to(target_position) <= ARRIVE_DISTANCE:
		tenant.position = target_position
		if pending_action_need.is_empty():
			_enter_idle()
		else:
			_enter_bubble_action()

func _enter_jump() -> void:
	state = AIState.JUMP
	state_elapsed = 0.0
	state_duration = JUMP_SECONDS
	GameState.set_tenant_behavior(tenant_id, "happy")
	tenant.play_avatar_behavior("happy")
	tenant.hide_behavior_bubble()

func _enter_bubble_action() -> void:
	state = AIState.BUBBLE_ACTION
	state_elapsed = 0.0
	state_duration = pending_action_duration
	GameState.observe_tenant_behavior(tenant_id, pending_action_need)

func _interaction_targets() -> Array:
	var room := _room()
	var targets := []
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		var furniture_data := ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		var interaction: Dictionary = furniture_data.get("interaction", {})
		var need := str(interaction.get("need", ""))
		if need.is_empty():
			continue
		targets.append({
			"need": need,
			"duration": float(interaction.get("duration", DEFAULT_ACTION_SECONDS)),
			"position": TenantRoomLocator.interaction_position(room, instance_data, furniture_data)
		})
	return targets

func _room() -> Dictionary:
	return GameState.rooms.get(room_id, {})

func _ai_paused() -> bool:
	return UIManager.current_state == UIManager.UIState.PLACING_NEW_FURNITURE \
		or UIManager.current_state == UIManager.UIState.MOVING_EXISTING_FURNITURE
