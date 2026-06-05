extends Node

func _ready() -> void:
	call_deferred("load_game")

func save_game() -> void:
	var data: Dictionary = GameState.to_save_data()
	PlatformManager.save_data("save_main", data)

func load_game() -> void:
	PlatformManager.init_platform()
	var data: Dictionary = PlatformManager.load_data("save_main")
	if data.is_empty():
		GameState.reset_new_game()
		EconomyManager.recalculate_total_rent()
		GameEvents.state_loaded.emit()
		return
	GameState.from_save_data(data)
	var offline: Dictionary = EconomyManager.calculate_offline_income()
	if int(offline.get("amount", 0)) > 0:
		GameEvents.offline_income_ready.emit(int(offline.get("amount", 0)), int(offline.get("seconds", 0)))

func delete_save_and_restart() -> void:
	PlatformManager.delete_data("save_main")
	GameState.reset_new_game()
	save_game()
	GameEvents.state_loaded.emit()
