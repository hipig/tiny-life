extends Node

const SAVE_PATH := "user://save_main.json"

func init_platform() -> void:
	pass

func get_platform_name() -> String:
	return str(ConfigManager.platform_config.get("platform", "mock"))

func save_data(key: String, data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))

func load_data(key: String) -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

func delete_data(key: String) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func show_rewarded_ad(ad_type: String, callback: Callable) -> void:
	track_event("reward_ad_success", {"ad_type": ad_type, "mock": true})
	if callback.is_valid():
		callback.call(true)

func track_event(event_name: String, params: Dictionary = {}) -> void:
	print("[track]", event_name, params)

func get_safe_area() -> Rect2:
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)

func vibrate(duration_ms: int) -> void:
	pass

func share(payload: Dictionary) -> void:
	pass
