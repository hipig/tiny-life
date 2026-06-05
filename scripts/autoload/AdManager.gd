extends Node

func show_rewarded_ad(ad_type: String, callback: Callable) -> void:
	PlatformManager.show_rewarded_ad(ad_type, callback)

