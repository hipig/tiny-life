class_name TenantAI
extends Node

enum AIState {
	IDLE,
	WALK,
	JUMP,
	BUBBLE_ACTION,
	ENTERING,
	LEAVING,
	AWAY,
	RETURNING
}

const WALK_SPEED := 18.0
const ARRIVE_DISTANCE := 0.5
const IDLE_MIN_SECONDS := 2.0
const IDLE_MAX_SECONDS := 4.0
const JUMP_SECONDS := 0.8
const DEFAULT_ACTION_SECONDS := 3.0
const DOOR_STEP_PIXELS := 12.0

var tenant: Tenant
var tenant_id := ""
var room_id := ""
var state := AIState.IDLE
var state_elapsed := 0.0
var state_duration := 0.0
var target_position := Vector2.ZERO
var pending_action_need := ""
var pending_action_duration := DEFAULT_ACTION_SECONDS
var route_running := false

static var startup_entry_tenant_ids: Dictionary = {}
static var startup_entry_active_tenant_ids: Dictionary = {}
static var startup_entry_refresh_active := false

static func reset_startup_entry_session() -> void:
	startup_entry_tenant_ids.clear()
	startup_entry_active_tenant_ids.clear()
	startup_entry_refresh_active = false

static func begin_startup_entry_refresh() -> void:
	startup_entry_tenant_ids.clear()
	startup_entry_active_tenant_ids.clear()
	startup_entry_refresh_active = true

static func end_startup_entry_refresh() -> void:
	startup_entry_refresh_active = false

static func is_startup_entry_active(id: String) -> bool:
	return startup_entry_active_tenant_ids.has(id)

func setup(owner: Tenant, id: String, target_room_id: String) -> void:
	tenant = owner
	tenant_id = id
	room_id = target_room_id
	if tenant == null or room_id.is_empty():
		return
	var presence := _presence_state()
	if presence == GameState.TENANT_PRESENCE_HOME:
		if _should_play_startup_entry():
			_enter_startup_entry()
			return
		tenant.visible = true
		tenant.position = TenantRoomLocator.spawn_position(_room())
	elif presence == GameState.TENANT_PRESENCE_AWAY:
		tenant.visible = false
	else:
		tenant.visible = true
	_sync_from_current_behavior()

func _process(delta: float) -> void:
	if tenant == null or tenant_id.is_empty() or room_id.is_empty():
		return
	if state != AIState.AWAY and _ai_paused():
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
		AIState.AWAY:
			if _away_is_finished():
				_enter_returning()
		AIState.ENTERING, AIState.LEAVING, AIState.RETURNING:
			pass

func _choose_next_state() -> void:
	if _should_go_outside():
		_enter_leaving()
		return
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
	match _presence_state():
		GameState.TENANT_PRESENCE_AWAY:
			_enter_away(false)
			return
		GameState.TENANT_PRESENCE_LEAVING, GameState.TENANT_PRESENCE_RETURNING:
			_enter_returning()
			return

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

func _enter_leaving() -> void:
	if route_running:
		return
	state = AIState.LEAVING
	state_elapsed = 0.0
	route_running = true
	pending_action_need = ""
	tenant.visible = true
	tenant.play_avatar_behavior(GameState.DEFAULT_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()
	GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_LEAVING)
	call_deferred("_run_leaving_route")

func _enter_startup_entry() -> void:
	if route_running:
		return
	startup_entry_tenant_ids[tenant_id] = true
	startup_entry_active_tenant_ids[tenant_id] = true
	state = AIState.ENTERING
	state_elapsed = 0.0
	route_running = true
	pending_action_need = ""
	tenant.visible = false
	tenant.position = Vector2.ZERO
	tenant.play_avatar_behavior(GameState.DEFAULT_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()
	call_deferred("_run_startup_entry_route")

func _enter_away(update_until: bool) -> void:
	state = AIState.AWAY
	state_elapsed = 0.0
	route_running = false
	pending_action_need = ""
	tenant.visible = false
	tenant.hide_behavior_bubble()
	tenant.play_avatar_behavior(GameState.AWAY_TENANT_BEHAVIOR)
	if update_until:
		var away_seconds := maxi(1, int(ConfigManager.get_tenant_ai_value("away_seconds", 18)))
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_AWAY, _staggered_away_until(away_seconds))

func _enter_returning() -> void:
	if route_running:
		return
	var should_stagger_route_start := state != AIState.AWAY
	state = AIState.RETURNING
	state_elapsed = 0.0
	route_running = true
	pending_action_need = ""
	tenant.visible = false
	tenant.play_avatar_behavior(GameState.RETURNING_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()
	if _presence_state() != GameState.TENANT_PRESENCE_RETURNING:
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_RETURNING)
	if should_stagger_route_start:
		call_deferred("_run_returning_route_after_stagger")
	else:
		call_deferred("_run_returning_route")

func _run_startup_entry_route():
	await _run_entry_route(false, true)

func _run_leaving_route():
	var view := _building_view()
	if view == null:
		_finish_route_at_home()
		return
	var floor_index := _room_floor_index()
	await _move_to_position(TenantRoomLocator.room_door_inside_position(_room()))
	await _play_room_door(view, true)
	if not _promote_to_world_layer(view):
		_finish_route_at_home()
		return
	var room_door_world := view.get_room_door_world_position(room_id)
	if room_door_world != Vector2.ZERO:
		tenant.position = room_door_world
	var service_position := view.get_service_exit_world_position() if floor_index <= 1 else view.get_service_elevator_world_position(floor_index)
	await _move_to_position(service_position)
	await _play_room_door(view, false)
	if floor_index > 1:
		await _enter_elevator_at_floor(view, floor_index)
		await _exit_elevator_at_floor(view, 1, -1.0)
	await _leave_through_exit_door(view)
	_enter_away(true)

func _run_returning_route():
	await _run_entry_route(true, false)

func _run_returning_route_after_stagger():
	var delay := _return_start_delay_seconds()
	if delay > 0.0:
		await _wait_seconds(delay)
	if state == AIState.RETURNING and route_running:
		await _run_returning_route()

func _run_entry_route(update_presence_on_finish: bool, force_offscreen_start: bool):
	var view := _building_view()
	if view == null:
		_finish_route_at_home(update_presence_on_finish)
		return
	if not _promote_to_world_layer(view):
		_finish_route_at_home(update_presence_on_finish)
		return
	var floor_index := _room_floor_index()
	var exit_position := view.get_service_exit_world_position()
	if exit_position == Vector2.ZERO:
		exit_position = view.get_room_door_world_position(room_id)
	if force_offscreen_start or tenant.position == Vector2.ZERO or not tenant.visible:
		tenant.position = view.get_offscreen_left_world_position(exit_position.y)
	tenant.visible = true
	await _enter_through_exit_door(view)
	if floor_index > 1:
		await _enter_elevator_at_floor(view, 1)
		await _exit_elevator_at_floor(view, floor_index, 1.0)
	var room_door_world := view.get_room_door_world_position(room_id)
	if room_door_world == Vector2.ZERO:
		_finish_route_at_home(update_presence_on_finish)
		return
	await _move_to_position(room_door_world)
	await _play_room_door(view, true)
	if not _place_in_room_layer(view):
		_finish_route_at_home(update_presence_on_finish)
		return
	tenant.position = TenantRoomLocator.room_door_inside_position(_room())
	await _move_to_position(TenantRoomLocator.spawn_position(_room()))
	await _play_room_door(view, false)
	route_running = false
	_mark_startup_entry_finished()
	if update_presence_on_finish:
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_HOME)
	_enter_idle()

func _move_to_position(destination: Vector2):
	while tenant != null and tenant.position.distance_to(destination) > ARRIVE_DISTANCE:
		if _ai_paused():
			await get_tree().process_frame
			continue
		var previous := tenant.position
		tenant.position = tenant.position.move_toward(destination, _route_speed() * get_process_delta_time())
		tenant.face_towards(tenant.position.x - previous.x)
		await get_tree().process_frame
	if tenant != null:
		tenant.position = destination

func _leave_through_exit_door(view: BuildingView):
	var exit_position := view.get_service_exit_world_position()
	if exit_position == Vector2.ZERO:
		exit_position = tenant.position
	await _move_to_position(exit_position)
	await _play_exit_door(view, true)
	await _move_to_position(_route_step_position(exit_position, -1.0))
	await _play_exit_door(view, false)
	await _move_to_position(view.get_offscreen_left_world_position(tenant.position.y))

func _enter_through_exit_door(view: BuildingView):
	var exit_position := view.get_service_exit_world_position()
	if exit_position == Vector2.ZERO:
		exit_position = tenant.position
	await _move_to_position(exit_position)
	await _play_exit_door(view, true)
	await _move_to_position(_route_step_position(exit_position, 1.0))
	await _play_exit_door(view, false)

func _enter_elevator_at_floor(view: BuildingView, floor_index: int):
	var elevator_position := view.get_service_elevator_world_position(floor_index)
	await _move_to_position(elevator_position)
	await _play_elevator_door(view, floor_index, true)
	await _play_elevator_door(view, floor_index, false)
	tenant.visible = false

func _exit_elevator_at_floor(view: BuildingView, floor_index: int, direction: float):
	var elevator_position := view.get_service_elevator_world_position(floor_index)
	await _play_elevator_door(view, floor_index, true)
	tenant.position = elevator_position
	tenant.visible = true
	await _move_to_position(_route_step_position(elevator_position, direction))
	await _play_elevator_door(view, floor_index, false)

func _route_step_position(origin: Vector2, direction: float) -> Vector2:
	var step_direction := -1.0 if direction < 0.0 else 1.0
	return origin + Vector2(DOOR_STEP_PIXELS * step_direction, 0.0)

func _play_room_door(view: BuildingView, open: bool):
	var door := view.get_room_door(room_id)
	var duration := _door_animation_seconds()
	await _play_traffic_door(door, open, duration)

func _play_exit_door(view: BuildingView, open: bool):
	var door := view.get_service_exit_door()
	var duration := _door_animation_seconds()
	await _play_traffic_door(door, open, duration)

func _play_elevator_door(view: BuildingView, floor_index: int, open: bool):
	var door := view.get_service_elevator_door(floor_index)
	var duration := _elevator_animation_seconds()
	await _play_traffic_door(door, open, duration)

func _play_traffic_door(door: TrafficDoor, open: bool, duration: float):
	if door != null:
		if open:
			door.play_open(duration)
		else:
			door.play_close(duration)
	await _wait_seconds(duration)
	if door != null:
		if open:
			door.set_open()
		else:
			door.set_closed()

func _wait_seconds(seconds: float):
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout

func _promote_to_world_layer(view: BuildingView) -> bool:
	var layer := view.get_tenant_world_layer()
	if layer == null or tenant == null:
		return false
	if tenant.get_parent() == layer:
		return true
	var current_global_position := tenant.global_position
	var parent := tenant.get_parent()
	if parent != null:
		parent.remove_child(tenant)
	layer.add_child(tenant)
	tenant.global_position = current_global_position
	return true

func _place_in_room_layer(view: BuildingView) -> bool:
	var layer := view.get_room_visual_layer(room_id)
	if layer == null or tenant == null:
		return false
	var current_global_position := tenant.global_position
	var parent := tenant.get_parent()
	if parent != null:
		parent.remove_child(tenant)
	layer.add_child(tenant)
	tenant.global_position = current_global_position
	return true

func _finish_route_at_home(update_presence := true) -> void:
	route_running = false
	_mark_startup_entry_finished()
	tenant.visible = true
	if update_presence:
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_HOME)
	tenant.position = TenantRoomLocator.spawn_position(_room())
	_enter_idle()

func _should_go_outside() -> bool:
	if _presence_state() != GameState.TENANT_PRESENCE_HOME:
		return false
	if _building_view() == null:
		return false
	var chance := clampf(float(ConfigManager.get_tenant_ai_value("away_chance", 0.12)), 0.0, 1.0)
	return chance > 0.0 and randf() < chance

func _should_play_startup_entry() -> bool:
	if not startup_entry_refresh_active:
		return false
	if startup_entry_tenant_ids.has(tenant_id):
		return false
	if not bool(ConfigManager.get_tenant_ai_value("entry_from_offscreen", true)):
		return false
	if _room().is_empty():
		return false
	return _building_view() != null

func _mark_startup_entry_finished() -> void:
	if tenant_id.is_empty():
		return
	startup_entry_active_tenant_ids.erase(tenant_id)

func _away_is_finished() -> bool:
	var tenant_state := _tenant_state()
	var until := int(tenant_state.get("away_until_timestamp", 0))
	return until <= TimeManager.now_unix()

func _staggered_away_until(away_seconds: int) -> int:
	var now := TimeManager.now_unix()
	var stagger_seconds := _return_stagger_seconds()
	var target := now + maxi(1, away_seconds)
	if stagger_seconds <= 0.0:
		return target
	var step := maxi(1, int(stagger_seconds + 0.5))
	target += int(float(_tenant_return_order_index()) * stagger_seconds + 0.5)
	var occupied_return_times := {}
	for other_id in GameState.tenants.keys():
		if str(other_id) == tenant_id:
			continue
		var other_tenant: Dictionary = GameState.tenants[other_id]
		if str(other_tenant.get("presence_state", "")) != GameState.TENANT_PRESENCE_AWAY:
			continue
		var other_until := int(other_tenant.get("away_until_timestamp", 0))
		if other_until > now:
			occupied_return_times[other_until] = true
	while occupied_return_times.has(target):
		target += step
	return target

func _return_start_delay_seconds() -> float:
	return float(_tenant_return_order_index()) * _return_stagger_seconds()

func _return_stagger_seconds() -> float:
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("return_stagger_seconds", 4.0)))

func _tenant_return_order_index() -> int:
	var index := 0
	for item in ConfigManager.tenants:
		var tenant_data: Dictionary = item
		var configured_tenant_id := str(tenant_data.get("id", ""))
		var tenant_state: Dictionary = GameState.tenants.get(configured_tenant_id, {})
		if str(tenant_state.get("room_id", "")).is_empty():
			continue
		if configured_tenant_id == tenant_id:
			return index
		index += 1
	var tenant_ids := GameState.tenants.keys()
	tenant_ids.sort()
	index = 0
	for id in tenant_ids:
		var tenant_state: Dictionary = GameState.tenants[id]
		if str(tenant_state.get("room_id", "")).is_empty():
			continue
		if str(id) == tenant_id:
			return index
		index += 1
	return maxi(0, tenant_ids.find(tenant_id))

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

func _tenant_state() -> Dictionary:
	return GameState.tenants.get(tenant_id, {})

func _presence_state() -> String:
	return str(_tenant_state().get("presence_state", GameState.TENANT_PRESENCE_HOME))

func _room_floor_index() -> int:
	return int(_room().get("floor_index", 1))

func _route_speed() -> float:
	return maxf(1.0, float(ConfigManager.get_tenant_ai_value("route_speed", 24.0)))

func _door_animation_seconds() -> float:
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("door_animation_seconds", 0.24)))

func _elevator_animation_seconds() -> float:
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("elevator_animation_seconds", 0.36)))

func _building_view() -> BuildingView:
	var node: Node = tenant
	while node != null:
		if node is BuildingView:
			return node as BuildingView
		node = node.get_parent()
	return null

func _ai_paused() -> bool:
	return UIManager.current_state == UIManager.UIState.PLACING_NEW_FURNITURE \
		or UIManager.current_state == UIManager.UIState.MOVING_EXISTING_FURNITURE
