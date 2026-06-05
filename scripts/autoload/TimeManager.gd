extends Node

func now_unix() -> int:
	return int(Time.get_unix_time_from_system())

func format_duration(seconds: int) -> String:
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	if hours > 0:
		return "%d 小时 %d 分钟" % [hours, minutes]
	return "%d 分钟" % max(1, minutes)

