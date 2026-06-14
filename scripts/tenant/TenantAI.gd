class_name TenantAI
extends Node

enum AIState {
	IDLE,
	WALK,
	JUMP,
	BUBBLE_ACTION,
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
var pending_action_behavior := ""
var pending_action_instance_id := ""
var pending_action_satisfaction_delta := 1
var pending_action_duration := DEFAULT_ACTION_SECONDS
var route_running := false

func setup(owner: Tenant, id: String, target_room_id: String) -> void:
	tenant = owner
	tenant_id = id
	room_id = target_room_id
	_connect_events()
	if tenant == null or room_id.is_empty():
		return
	_sync_from_current_behavior()

func _process(delta: float) -> void:
	if tenant == null or tenant_id.is_empty() or room_id.is_empty():
		return
	_recover_from_origin_position_if_needed("process")
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
				_enter_idle()
		AIState.AWAY:
			if _away_is_finished():
				_enter_returning()
		AIState.LEAVING, AIState.RETURNING:
			pass

func _choose_next_state() -> void:
	if _should_go_outside():
		_enter_leaving()
		return
	var use_targets := _furniture_use_targets()
	var roll := randf()
	if not use_targets.is_empty() and roll < 0.35:
		_walk_to_furniture_use(use_targets.pick_random())
	elif roll < 0.65:
		_enter_wander_walk()
	elif roll < 0.82:
		_enter_jump()
	else:
		_enter_idle()

func _sync_from_current_behavior() -> void:
	state_elapsed = 0.0
	_clear_pending_action()
	_recover_from_origin_position_if_needed("setup")
	match _presence_state():
		GameState.TENANT_PRESENCE_HOME:
			_resume_home_state()
			return
		GameState.TENANT_PRESENCE_LEAVING:
			_resume_leaving_route()
			return
		GameState.TENANT_PRESENCE_AWAY:
			_resume_away_state()
			return
		GameState.TENANT_PRESENCE_RETURNING:
			_resume_returning_route()
			return
	_resume_home_state()

func _resume_home_state() -> void:
	route_running = false
	tenant.visible = true
	if not tenant.ai_position_initialized or _tenant_position_is_origin():
		tenant.position = TenantRoomLocator.spawn_position(_room(), tenant_id)
		tenant.ai_position_initialized = true
	_sync_home_behavior_state()

func _resume_leaving_route() -> void:
	var view := _building_view()
	if view != null and _tenant_in_world_layer(view):
		if not _ensure_route_resume_position(GameState.TENANT_PRESENCE_LEAVING, "resume leaving route"):
			return
	elif not _ensure_room_resume_position("resume leaving route"):
		return
	_begin_leaving_route(false)

func _resume_away_state() -> void:
	if _tenant_position_is_origin():
		_recover_route_position(GameState.TENANT_PRESENCE_AWAY, "resume away state")
	_enter_away(false)

func _resume_returning_route() -> void:
	if not _ensure_route_resume_position(GameState.TENANT_PRESENCE_RETURNING, "resume returning route"):
		return
	_begin_returning_route(true, false)

func _sync_home_behavior_state() -> void:
	var tenant_state: Dictionary = GameState.tenants.get(tenant_id, {})
	var current_need := str(tenant_state.get("current_need", ""))
	var raw_behavior := str(tenant_state.get("current_behavior", GameState.IDLE_TENANT_BEHAVIOR))
	var behavior := ConfigManager.normalize_behavior_key(raw_behavior)
	if not current_need.is_empty():
		state = AIState.BUBBLE_ACTION
		pending_action_behavior = ConfigManager.normalize_behavior_key(current_need)
		pending_action_duration = DEFAULT_ACTION_SECONDS
		state_duration = pending_action_duration
		return
	if behavior == GameState.DEFAULT_TENANT_BEHAVIOR:
		_enter_wander_walk()
		return
	if behavior == "happy" or behavior == "jump":
		state = AIState.JUMP
		state_duration = JUMP_SECONDS
		return
	state = AIState.IDLE
	state_duration = randf_range(IDLE_MIN_SECONDS, IDLE_MAX_SECONDS)

func _enter_idle() -> void:
	_end_pending_interaction()
	state = AIState.IDLE
	state_elapsed = 0.0
	state_duration = randf_range(IDLE_MIN_SECONDS, IDLE_MAX_SECONDS)
	_clear_pending_action()
	GameState.set_tenant_behavior(tenant_id, GameState.IDLE_TENANT_BEHAVIOR)
	tenant.play_avatar_behavior(GameState.IDLE_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()

func _enter_wander_walk() -> void:
	target_position = TenantRoomLocator.wander_target_position(_room(), tenant.position)
	_enter_walk()

func _walk_to_furniture_use(target: Dictionary) -> void:
	pending_action_behavior = ConfigManager.normalize_behavior_key(str(target.get("behavior", "")))
	pending_action_instance_id = str(target.get("instance_id", ""))
	pending_action_satisfaction_delta = maxi(0, int(target.get("satisfaction_delta", 1)))
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
		if pending_action_behavior.is_empty():
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
	if not pending_action_instance_id.is_empty():
		GameEvents.furniture_interaction_started.emit(room_id, pending_action_instance_id, pending_action_behavior)
	GameState.observe_tenant_behavior(tenant_id, pending_action_behavior, pending_action_satisfaction_delta)

func _enter_leaving() -> void:
	if route_running:
		return
	if not tenant.ai_position_initialized or _tenant_position_is_origin():
		if _tenant_position_is_origin():
			push_warning("Tenant '%s' started leaving from the origin. Resetting to the stable room spawn first." % tenant_id)
		tenant.position = TenantRoomLocator.spawn_position(_room(), tenant_id)
		tenant.ai_position_initialized = true
	_begin_leaving_route(true)

func _enter_away(update_until: bool) -> void:
	_end_pending_interaction()
	_clear_pending_action()
	state = AIState.AWAY
	state_elapsed = 0.0
	route_running = false
	tenant.visible = false
	tenant.hide_behavior_bubble()
	tenant.play_avatar_behavior(GameState.AWAY_TENANT_BEHAVIOR)
	if update_until:
		var away_seconds := maxi(1, int(ConfigManager.get_tenant_ai_value("away_seconds")))
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_AWAY, _staggered_away_until(away_seconds))

func _enter_returning() -> void:
	if route_running:
		return
	var should_stagger_route_start := state != AIState.AWAY
	if not _ensure_route_resume_position(GameState.TENANT_PRESENCE_RETURNING, "start returning route"):
		return
	_begin_returning_route(should_stagger_route_start, true)

func _begin_leaving_route(update_presence: bool) -> void:
	_end_pending_interaction()
	_clear_pending_action()
	state = AIState.LEAVING
	state_elapsed = 0.0
	route_running = true
	tenant.visible = true
	tenant.play_avatar_behavior(GameState.DEFAULT_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()
	if update_presence or _presence_state() != GameState.TENANT_PRESENCE_LEAVING:
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_LEAVING)
	call_deferred("_run_leaving_route")

func _begin_returning_route(should_stagger_route_start: bool, update_presence: bool) -> void:
	_end_pending_interaction()
	_clear_pending_action()
	state = AIState.RETURNING
	state_elapsed = 0.0
	route_running = true
	tenant.visible = false
	tenant.play_avatar_behavior(GameState.RETURNING_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()
	if update_presence or _presence_state() != GameState.TENANT_PRESENCE_RETURNING:
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_RETURNING)
	if should_stagger_route_start:
		call_deferred("_run_returning_route_after_stagger")
	else:
		call_deferred("_run_returning_route")

func _run_leaving_route():
	var view := _building_view()
	if view == null:
		_finish_route_at_home()
		return
	var floor_index := _room_floor_index()
	var resumed_from_world := _tenant_in_world_layer(view)
	if not resumed_from_world:
		if not await _move_to_position(TenantRoomLocator.room_door_inside_position(_room()), "walk to room door"):
			return
		if not _route_can_continue(AIState.LEAVING):
			return
		await _play_room_door(view, true)
		if not _route_can_continue(AIState.LEAVING):
			return
		if not _promote_to_world_layer(view):
			_finish_route_at_home()
			return
		var room_door_world := _require_world_anchor(
			view.get_room_door_world_position(room_id),
			"room door",
			"resume leaving route at room door"
		)
		if not room_door_world.get("ok", false):
			return
		tenant.position = room_door_world["position"]
	var service_position := view.get_service_exit_world_position() if floor_index <= 1 else view.get_service_elevator_world_position(floor_index)
	if not await _move_to_position(service_position, "walk to service route anchor"):
		return
	if not _route_can_continue(AIState.LEAVING):
		return
	if not resumed_from_world:
		await _play_room_door(view, false)
		if not _route_can_continue(AIState.LEAVING):
			return
	if floor_index > 1:
		await _enter_elevator_at_floor(view, floor_index)
		if not _route_can_continue(AIState.LEAVING):
			return
		await _exit_elevator_at_floor(view, 1, -1.0)
		if not _route_can_continue(AIState.LEAVING):
			return
	await _leave_through_exit_door(view)
	if not _route_can_continue(AIState.LEAVING):
		return
	_enter_away(true)

func _run_returning_route():
	await _run_entry_route(true)

func _run_returning_route_after_stagger():
	var delay := _return_start_delay_seconds()
	if delay > 0.0:
		await _wait_seconds(delay)
	if state == AIState.RETURNING and route_running:
		await _run_returning_route()

func _run_entry_route(update_presence_on_finish: bool):
	var view := _building_view()
	if view == null:
		_finish_route_at_home(update_presence_on_finish)
		return
	if not _promote_to_world_layer(view):
		_finish_route_at_home(update_presence_on_finish)
		return
	if not tenant.ai_position_initialized or not tenant.visible:
		tenant.position = _visible_return_start_position(view, _room_floor_index(), Vector2.INF)
		tenant.ai_position_initialized = true
	tenant.visible = true
	await _enter_through_exit_door(view)
	if not _route_can_continue(AIState.RETURNING):
		return
	var floor_index := _room_floor_index()
	if floor_index > 1:
		await _enter_elevator_at_floor(view, 1)
		if not _route_can_continue(AIState.RETURNING):
			return
		await _exit_elevator_at_floor(view, floor_index, 1.0)
		if not _route_can_continue(AIState.RETURNING):
			return
	var room_door_world := _require_world_anchor(
		view.get_room_door_world_position(room_id),
		"room door",
		"resume returning route at room door",
		update_presence_on_finish
	)
	if not room_door_world.get("ok", false):
		return
	if not await _move_to_position(room_door_world["position"], "walk to room door from world route", update_presence_on_finish):
		return
	if not _route_can_continue(AIState.RETURNING):
		return
	await _play_room_door(view, true)
	if not _route_can_continue(AIState.RETURNING):
		return
	if not _place_in_room_layer(view):
		_finish_route_at_home(update_presence_on_finish)
		return
	tenant.position = TenantRoomLocator.room_door_inside_position(_room())
	if not await _move_to_position(TenantRoomLocator.spawn_position(_room(), tenant_id), "return to stable room spawn", update_presence_on_finish):
		return
	if not _route_can_continue(AIState.RETURNING):
		return
	await _play_room_door(view, false)
	if not _route_can_continue(AIState.RETURNING):
		return
	route_running = false
	if update_presence_on_finish:
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_HOME)
	_enter_idle()

func _move_to_position(destination: Vector2, recover_context := "", update_presence_on_recover := true):
	if not _is_valid_route_position(destination):
		_recover_missing_route_anchor(recover_context, update_presence_on_recover)
		return false
	if tenant != null and tenant.position.distance_to(destination) > ARRIVE_DISTANCE:
		_play_route_walk()
	while tenant != null and tenant.position.distance_to(destination) > ARRIVE_DISTANCE:
		var previous := tenant.position
		tenant.position = tenant.position.move_toward(destination, _route_speed() * get_process_delta_time())
		tenant.face_towards(tenant.position.x - previous.x)
		await get_tree().process_frame
	if tenant != null:
		tenant.position = destination
		tenant.ai_position_initialized = true
	return true

func _leave_through_exit_door(view: BuildingView):
	var exit_position := _require_world_anchor(
		view.get_service_exit_world_position(),
		"public exit",
		"leave through public exit"
	)
	if not exit_position.get("ok", false):
		return
	if not await _move_to_position(exit_position["position"], "walk to public exit"):
		return
	await _play_exit_door(view, true)
	if not await _move_to_position(_route_step_position(exit_position["position"], -1.0), "step through public exit"):
		return
	await _play_exit_door(view, false)
	if not await _move_to_position(view.get_offscreen_left_world_position(exit_position["position"].y), "walk to offscreen exit mark"):
		return

func _enter_through_exit_door(view: BuildingView):
	var exit_position := _require_world_anchor(
		view.get_service_exit_world_position(),
		"public exit",
		"enter through public exit"
	)
	if not exit_position.get("ok", false):
		return
	if not await _move_to_position(exit_position["position"], "walk to public entry"):
		return
	await _play_exit_door(view, true)
	if not await _move_to_position(_route_step_position(exit_position["position"], 1.0), "step through public entry"):
		return
	await _play_exit_door(view, false)

func _visible_return_start_position(view: BuildingView, floor_index: int, exit_position: Vector2) -> Vector2:
	return view.resolve_route_start_world_position(room_id, GameState.TENANT_PRESENCE_RETURNING)

func _enter_elevator_at_floor(view: BuildingView, floor_index: int):
	var elevator_position := view.get_service_elevator_world_position(floor_index)
	if not await _move_to_position(elevator_position, "walk to elevator at floor %d" % floor_index):
		return
	_play_route_idle()
	var door := view.get_service_elevator_door(floor_index)
	var duration := _elevator_animation_seconds()
	await _play_traffic_door(door, true, duration)
	await _wait_seconds(_elevator_idle_seconds())
	var hide_progress := _elevator_close_hide_progress()
	_start_traffic_door(door, false, duration)
	await _wait_seconds(duration * hide_progress)
	if tenant != null:
		tenant.visible = false
	await _wait_seconds(duration * (1.0 - hide_progress))
	_finish_traffic_door(door, false)

func _exit_elevator_at_floor(view: BuildingView, floor_index: int, direction: float):
	var elevator_position := view.get_service_elevator_world_position(floor_index)
	var door := view.get_service_elevator_door(floor_index)
	var duration := _elevator_animation_seconds()
	var show_progress := _elevator_open_show_progress()
	if not _is_valid_route_position(elevator_position):
		_recover_missing_route_anchor("exit elevator at floor %d" % floor_index)
		return
	_start_traffic_door(door, true, duration)
	await _wait_seconds(duration * show_progress)
	if tenant != null:
		tenant.position = elevator_position
		tenant.ai_position_initialized = true
		tenant.visible = true
		_play_route_idle()
	await _wait_seconds(duration * (1.0 - show_progress))
	_finish_traffic_door(door, true)
	await _wait_seconds(_elevator_idle_seconds())
	if not await _move_to_position(_route_step_position(elevator_position, direction), "leave elevator at floor %d" % floor_index):
		return
	await _play_elevator_door(view, floor_index, false)

func _route_step_position(origin: Vector2, direction: float) -> Vector2:
	var step_direction := -1.0 if direction < 0.0 else 1.0
	return origin + Vector2(DOOR_STEP_PIXELS * step_direction, 0.0)

func _play_room_door(view: BuildingView, open: bool):
	var door := view.get_room_door(room_id)
	var duration := _door_animation_seconds()
	if open:
		await _play_route_door_open(door, duration)
	else:
		await _play_traffic_door(door, open, duration)

func _play_exit_door(view: BuildingView, open: bool):
	var door := view.get_service_exit_door()
	var duration := _door_animation_seconds()
	if open:
		await _play_route_door_open(door, duration)
	else:
		await _play_traffic_door(door, open, duration)

func _play_elevator_door(view: BuildingView, floor_index: int, open: bool):
	var door := view.get_service_elevator_door(floor_index)
	var duration := _elevator_animation_seconds()
	await _play_traffic_door(door, open, duration)

func _play_route_door_open(door: TrafficDoor, duration: float):
	_play_route_idle()
	await _play_traffic_door(door, true, duration)
	await _wait_seconds(_door_open_idle_seconds())

func _play_traffic_door(door: TrafficDoor, open: bool, duration: float):
	_start_traffic_door(door, open, duration)
	await _wait_seconds(duration)
	_finish_traffic_door(door, open)

func _start_traffic_door(door: TrafficDoor, open: bool, duration: float) -> void:
	if door != null:
		if open:
			door.play_open(duration)
		else:
			door.play_close(duration)

func _finish_traffic_door(door: TrafficDoor, open: bool) -> void:
	if door != null:
		if open:
			door.set_open()
		else:
			door.set_closed()

func _play_route_idle() -> void:
	if tenant == null:
		return
	tenant.play_avatar_behavior(GameState.IDLE_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()

func _play_route_walk() -> void:
	if tenant == null:
		return
	tenant.play_avatar_behavior(GameState.DEFAULT_TENANT_BEHAVIOR)
	tenant.hide_behavior_bubble()

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
	tenant.visible = true
	if update_presence:
		GameState.set_tenant_presence(tenant_id, GameState.TENANT_PRESENCE_HOME)
	tenant.position = TenantRoomLocator.spawn_position(_room(), tenant_id)
	tenant.ai_position_initialized = true
	_enter_idle()

func _route_can_continue(expected_state: AIState) -> bool:
	return tenant != null and route_running and state == expected_state

func _ensure_route_resume_position(presence: String, recover_context: String) -> bool:
	if tenant == null:
		return false
	if tenant.ai_position_initialized and not _tenant_position_is_origin():
		return true
	return _recover_route_position(presence, recover_context)

func _ensure_room_resume_position(recover_context: String) -> bool:
	if tenant == null:
		return false
	if tenant.ai_position_initialized and not _tenant_position_is_origin():
		return true
	return _recover_room_position(recover_context)

func _recover_route_position(presence: String, recover_context: String) -> bool:
	var view := _building_view()
	if view == null:
		_recover_missing_route_anchor(recover_context)
		return false
	tenant.position = view.resolve_route_start_world_position(room_id, presence)
	tenant.ai_position_initialized = true
	return true

func _recover_room_position(recover_context: String) -> bool:
	if tenant == null:
		return false
	if _room().is_empty():
		_recover_missing_route_anchor(recover_context)
		return false
	tenant.position = TenantRoomLocator.spawn_position(_room(), tenant_id)
	tenant.ai_position_initialized = true
	return true

func _recover_from_origin_position_if_needed(recover_context: String) -> void:
	if tenant == null or room_id.is_empty() or not _tenant_position_is_origin():
		return
	push_warning("Tenant '%s' reset to the origin during %s. Recovering from presence '%s'." % [tenant_id, recover_context, _presence_state()])
	match _presence_state():
		GameState.TENANT_PRESENCE_LEAVING:
			var view := _building_view()
			if view != null and _tenant_in_world_layer(view):
				_recover_route_position(GameState.TENANT_PRESENCE_LEAVING, "%s from origin" % recover_context)
			else:
				_recover_room_position("%s from origin" % recover_context)
		GameState.TENANT_PRESENCE_AWAY:
			_recover_route_position(GameState.TENANT_PRESENCE_AWAY, "%s from origin" % recover_context)
		GameState.TENANT_PRESENCE_RETURNING:
			_recover_route_position(GameState.TENANT_PRESENCE_RETURNING, "%s from origin" % recover_context)
		_:
			tenant.position = TenantRoomLocator.spawn_position(_room(), tenant_id)
			tenant.ai_position_initialized = true

func _require_world_anchor(position: Vector2, anchor_name: String, recover_context: String, update_presence_on_recover := true) -> Dictionary:
	if _is_valid_route_position(position):
		return {
			"ok": true,
			"position": position
		}
	_recover_missing_route_anchor("%s (%s)" % [recover_context, anchor_name], update_presence_on_recover)
	return {
		"ok": false
	}

func _recover_missing_route_anchor(recover_context: String, update_presence_on_recover := true) -> void:
	push_warning("Tenant '%s' could not resolve a route anchor during %s. Returning to the stable room spawn." % [tenant_id, recover_context])
	_finish_route_at_home(update_presence_on_recover)

func _tenant_position_is_origin() -> bool:
	return tenant != null and tenant.position.is_equal_approx(Vector2.ZERO)

func _is_valid_route_position(position: Vector2) -> bool:
	return is_finite(position.x) and is_finite(position.y) and not position.is_equal_approx(Vector2.ZERO)

func _tenant_in_world_layer(view: BuildingView) -> bool:
	return tenant != null and view != null and tenant.get_parent() == view.get_tenant_world_layer()

func _should_go_outside() -> bool:
	if _presence_state() != GameState.TENANT_PRESENCE_HOME:
		return false
	if _building_view() == null:
		return false
	var chance := clampf(float(ConfigManager.get_tenant_ai_value("away_chance")), 0.0, 1.0)
	return chance > 0.0 and randf() < chance

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
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("return_stagger_seconds")))

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

func _furniture_use_targets() -> Array:
	var room := _room()
	var targets := []
	for instance in room.get("furniture_instances", []):
		var instance_data: Dictionary = instance
		var furniture_data := ConfigManager.get_furniture_data(str(instance_data.get("furniture_id", "")))
		var interaction: Dictionary = furniture_data.get("interaction", {})
		var behavior := str(interaction.get("behavior", ""))
		if behavior.is_empty():
			continue
		targets.append({
			"behavior": ConfigManager.normalize_behavior_key(behavior),
			"instance_id": str(instance_data.get("instance_id", "")),
			"satisfaction_delta": int(interaction.get("satisfaction_delta", 1)),
			"duration": float(interaction.get("duration", DEFAULT_ACTION_SECONDS)),
			"position": TenantRoomLocator.furniture_use_position(room, instance_data, furniture_data)
		})
	return targets

func _connect_events() -> void:
	if not GameEvents.tenant_furniture_reaction_requested.is_connected(_on_tenant_furniture_reaction_requested):
		GameEvents.tenant_furniture_reaction_requested.connect(_on_tenant_furniture_reaction_requested)

func _on_tenant_furniture_reaction_requested(target_tenant_id: String, target_room_id: String, _furniture_id: String, reaction_key: String) -> void:
	if target_tenant_id != tenant_id or target_room_id != room_id:
		return
	if tenant == null or route_running or _presence_state() != GameState.TENANT_PRESENCE_HOME:
		return
	_enter_purchase_reaction(reaction_key)

func _enter_purchase_reaction(reaction_key: String) -> void:
	_end_pending_interaction()
	_clear_pending_action()
	state = AIState.JUMP
	state_elapsed = 0.0
	state_duration = JUMP_SECONDS
	GameState.set_tenant_behavior(tenant_id, "happy")
	tenant.play_avatar_behavior("happy")
	tenant.hide_behavior_bubble()
	tenant.play_emote("like" if reaction_key == "favorite" else "present", 1.1)

func _end_pending_interaction() -> void:
	if state == AIState.BUBBLE_ACTION and not pending_action_instance_id.is_empty():
		GameEvents.furniture_interaction_finished.emit(room_id, pending_action_instance_id, pending_action_behavior)

func _clear_pending_action() -> void:
	pending_action_behavior = ""
	pending_action_instance_id = ""
	pending_action_satisfaction_delta = 1
	pending_action_duration = DEFAULT_ACTION_SECONDS

func _room() -> Dictionary:
	return GameState.rooms.get(room_id, {})

func _tenant_state() -> Dictionary:
	return GameState.tenants.get(tenant_id, {})

func _presence_state() -> String:
	return str(_tenant_state().get("presence_state", GameState.TENANT_PRESENCE_HOME))

func _room_floor_index() -> int:
	return int(_room().get("floor_index", 1))

func _route_speed() -> float:
	return maxf(1.0, float(ConfigManager.get_tenant_ai_value("route_speed")))

func _door_animation_seconds() -> float:
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("door_animation_seconds")))

func _elevator_animation_seconds() -> float:
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("elevator_animation_seconds")))

func _door_open_idle_seconds() -> float:
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("door_open_idle_seconds")))

func _elevator_idle_seconds() -> float:
	return maxf(0.0, float(ConfigManager.get_tenant_ai_value("elevator_idle_seconds")))

func _elevator_open_show_progress() -> float:
	return clampf(float(ConfigManager.get_tenant_ai_value("elevator_open_show_progress")), 0.0, 1.0)

func _elevator_close_hide_progress() -> float:
	return clampf(float(ConfigManager.get_tenant_ai_value("elevator_close_hide_progress")), 0.0, 1.0)

func _building_view() -> BuildingView:
	var node: Node = tenant
	while node != null:
		if node is BuildingView:
			return node as BuildingView
		node = node.get_parent()
	return null
