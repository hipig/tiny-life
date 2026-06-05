extends Node

func notify_event(event_name: String, params: Dictionary = {}) -> void:
	if GameState.tasks.is_empty():
		return
	for task_config in ConfigManager.tasks:
		var task_data: Dictionary = task_config
		var task_id := str(task_data.get("id", ""))
		var task_state: Dictionary = GameState.tasks.get(task_id, {})
		if task_state.is_empty() or bool(task_state.get("completed", false)):
			continue
		var changed: bool = _apply_event(task_data, task_state, event_name, params)
		if changed:
			GameState.tasks[task_id] = task_state
			GameEvents.task_updated.emit(task_id)
			if int(task_state.get("progress", 0)) >= int(task_data.get("target_value", 1)):
				_complete_task(task_data, task_state)

func _apply_event(task_config: Dictionary, task_state: Dictionary, event_name: String, params: Dictionary) -> bool:
	var type := str(task_config.get("type", ""))
	match type:
		"place_furniture_tag":
			if event_name != "furniture_placed":
				return false
			var furniture: Dictionary = ConfigManager.get_furniture_data(str(params.get("furniture_id", "")))
			if str(task_config.get("target_tag", "")) in furniture.get("tags", []):
				task_state["progress"] = int(task_state.get("progress", 0)) + 1
				return true
		"place_furniture_count":
			if event_name == "furniture_placed":
				task_state["progress"] = int(GameState.stats.get("furniture_placed_count", 0))
				return true
		"tenant_recruited_count":
			if event_name == "tenant_recruited":
				task_state["progress"] = int(GameState.stats.get("tenant_recruited_count", 0))
				return true
		"rent_reached":
			if event_name == "rent_reached":
				task_state["progress"] = int(floor(float(params.get("rent", 0.0))))
				return true
		"apartment_level_reached":
			if event_name == "apartment_level_reached":
				task_state["progress"] = int(params.get("level", GameState.apartment_level))
				return true
		"floor_built":
			if event_name == "floor_built" and int(params.get("floor_index", 0)) == int(task_config.get("floor_index", 0)):
				task_state["progress"] = 1
				return true
		"tenant_behavior_observed":
			if event_name == "tenant_behavior_observed" and str(params.get("behavior", "")) == str(task_config.get("behavior", "")):
				task_state["progress"] = int(task_state.get("progress", 0)) + 1
				return true
		"offline_reward_claimed":
			if event_name == "offline_reward_claimed":
				task_state["progress"] = int(GameState.stats.get("offline_claimed_count", 0))
				return true
	return false

func _complete_task(task_config: Dictionary, task_state: Dictionary) -> void:
	task_state["completed"] = true
	task_state["claimed"] = true
	GameState.add_coins(int(task_config.get("reward_coins", 0)))
	GameState.add_apartment_exp(int(task_config.get("reward_exp", 0)))
	GameEvents.task_completed.emit(str(task_config.get("id", "")))
	SaveManager.save_game()

func get_active_tasks() -> Array:
	var result: Array = []
	for task_config in ConfigManager.tasks:
		var task_data: Dictionary = task_config
		var task_state: Dictionary = GameState.tasks.get(str(task_data.get("id", "")), {})
		var merged: Dictionary = task_data.duplicate(true)
		merged["progress"] = int(task_state.get("progress", 0))
		merged["completed"] = bool(task_state.get("completed", false))
		result.append(merged)
	return result

func has_claimable_or_new() -> bool:
	for task in GameState.tasks.values():
		if bool(task.get("completed", false)):
			return true
	return false
