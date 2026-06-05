extends Node

signal coins_changed(value: int)
signal coin_gain_batched(amount: int)
signal rent_changed(value: float)
signal apartment_level_changed(level: int)
signal room_updated(room_id: String)
signal furniture_placed(room_id: String, furniture_id: String)
signal furniture_moved(room_id: String, furniture_id: String)
signal furniture_recycled(room_id: String, furniture_id: String)
signal tenant_recruited(tenant_id: String, room_id: String)
signal tenant_satisfaction_changed(tenant_id: String, value: int)
signal tenant_behavior_observed(tenant_id: String, behavior: String)
signal floor_built(floor_index: int)
signal task_updated(task_id: String)
signal task_completed(task_id: String)
signal state_loaded
signal offline_income_ready(amount: int, seconds: int)
signal toast_requested(message: String)

