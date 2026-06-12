extends Node

var coin_buffer := 0.0
var autosave_timer := 0.0

func _process(delta: float) -> void:
	if GameState.rooms.is_empty():
		return
	income_tick(delta)
	autosave_timer += delta
	if autosave_timer >= float(ConfigManager.get_economy_value("autosave_seconds")):
		autosave_timer = 0.0
		SaveManager.save_game()

func calculate_room_rent(room: Dictionary) -> float:
	var tenant_id := str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		return 0.0
	return calculate_room_rent_for_tenant(room, tenant_id)

func calculate_room_rent_for_tenant(room: Dictionary, tenant_id: String) -> float:
	if tenant_id.is_empty():
		return 0.0
	return float(get_room_rent_breakdown(room, tenant_id).get("rent", 0.0))

func get_room_rent_breakdown(room: Dictionary, tenant_id := "") -> Dictionary:
	if tenant_id.is_empty():
		tenant_id = str(room.get("tenant_id", ""))
	if tenant_id.is_empty():
		return {
			"base_rent": 0.0,
			"score_part": 0.0,
			"pay_multiplier": 0.0,
			"satisfaction_multiplier": 0.0,
			"rent": 0.0
		}
	var tenant_state: Dictionary = GameState.tenants.get(tenant_id, {})
	var tenant_data: Dictionary = ConfigManager.get_tenant_data(tenant_id)
	var base_rent: float = float(ConfigManager.get_economy_value("base_rent"))
	var score_factor: float = float(ConfigManager.get_economy_value("score_rent_factor"))
	var score_part: float = float(room.get("score", 0)) * score_factor
	var pay_multiplier: float = float(tenant_data.get("pay_multiplier", 1.0))
	var satisfaction := int(tenant_state.get("satisfaction", int(tenant_data.get("initial_satisfaction", 60))))
	var satisfaction_multiplier: float = get_satisfaction_multiplier(satisfaction)
	return {
		"base_rent": base_rent,
		"score_part": score_part,
		"pay_multiplier": pay_multiplier,
		"satisfaction": satisfaction,
		"satisfaction_multiplier": satisfaction_multiplier,
		"rent": (base_rent + score_part) * pay_multiplier * satisfaction_multiplier
	}

func get_satisfaction_multiplier(value: int) -> float:
	if value <= 30:
		return 0.7
	if value <= 60:
		return 1.0
	if value <= 80:
		return 1.15
	return 1.3

func recalculate_total_rent() -> void:
	var total := 0.0
	for room_id in GameState.rooms.keys():
		var room: Dictionary = GameState.rooms[room_id]
		var rent := calculate_room_rent(room)
		room["rent_per_minute"] = rent
		GameState.rooms[room_id] = room
		total += rent
	GameState.total_rent_per_minute = total
	GameEvents.rent_changed.emit(total)
	TaskManager.notify_event("rent_reached", {"rent": total})

func income_tick(delta: float) -> void:
	var income_per_second: float = get_income_per_second()
	if income_per_second <= 0.0:
		return
	coin_buffer += income_per_second * delta
	if coin_buffer >= 1.0:
		var coins_to_add := int(coin_buffer)
		coin_buffer -= coins_to_add
		GameState.add_coins(coins_to_add, "auto_income")

func get_income_per_second() -> float:
	return GameState.total_rent_per_minute / 60.0

func get_income_buffer() -> float:
	return coin_buffer

func calculate_offline_income() -> Dictionary:
	var now: int = TimeManager.now_unix()
	var offline_seconds: int = max(0, now - GameState.last_save_timestamp)
	var capped_seconds: int = min(offline_seconds, int(ConfigManager.get_economy_value("max_offline_seconds")))
	var income: int = int(GameState.total_rent_per_minute / 60.0 * capped_seconds)
	return {"seconds": capped_seconds, "amount": income}

func claim_offline_income(double_reward := false) -> int:
	var result: Dictionary = calculate_offline_income()
	var amount: int = int(result.get("amount", 0))
	if double_reward:
		amount *= 2
	if amount > 0:
		GameState.add_coins(amount, "offline_income")
		GameState.stats["offline_claimed_count"] = int(GameState.stats.get("offline_claimed_count", 0)) + 1
		TaskManager.notify_event("offline_reward_claimed", {"amount": amount})
	elif double_reward:
		TaskManager.notify_event("offline_reward_claimed", {"amount": 0})
	GameState.last_save_timestamp = TimeManager.now_unix()
	SaveManager.save_game()
	return amount
