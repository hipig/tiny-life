@tool
class_name TrafficDoor
extends Node2D

@export var closed_frame := 0
@export var open_frame := 1
@export var default_animation := "default"
@export var open_animation := "open"
@export var close_animation := "close"

@onready var door_sprite: AnimatedSprite2D = get_node_or_null("DoorSprite") as AnimatedSprite2D

var _warned_missing_frames := false

func _ready() -> void:
	set_closed()

func play_open(duration_seconds := -1.0) -> void:
	_play_visual(open_animation, default_animation, closed_frame, open_frame, false, duration_seconds)

func play_close(duration_seconds := -1.0) -> void:
	_play_visual(close_animation, default_animation, open_frame, closed_frame, true, duration_seconds)

func set_closed() -> void:
	_set_frame(default_animation, closed_frame)

func _play_visual(animation_name: String, fallback_animation: String, start_frame: int, fallback_frame: int, backwards: bool, duration_seconds: float) -> void:
	if door_sprite == null or door_sprite.sprite_frames == null:
		_warn_missing_frames()
		return
	if door_sprite.sprite_frames.has_animation(animation_name):
		door_sprite.play(animation_name, _custom_speed_for_duration(animation_name, duration_seconds))
		return
	if door_sprite.sprite_frames.has_animation(fallback_animation):
		var frame_count := door_sprite.sprite_frames.get_frame_count(fallback_animation)
		if frame_count <= 1:
			_set_frame(fallback_animation, fallback_frame)
			return
		door_sprite.animation = fallback_animation
		door_sprite.frame = clampi(start_frame, 0, frame_count - 1)
		var custom_speed := _custom_speed_for_duration(fallback_animation, duration_seconds)
		if backwards:
			door_sprite.play(fallback_animation, -custom_speed, true)
		else:
			door_sprite.play(fallback_animation, custom_speed)
		return
	_warn_missing_frames()

func _set_frame(animation_name: String, frame_index: int) -> void:
	if door_sprite == null or door_sprite.sprite_frames == null:
		_warn_missing_frames()
		return
	if not door_sprite.sprite_frames.has_animation(animation_name):
		_warn_missing_frames()
		return
	door_sprite.stop()
	door_sprite.animation = animation_name
	door_sprite.frame = clampi(frame_index, 0, maxi(0, door_sprite.sprite_frames.get_frame_count(animation_name) - 1))

func _warn_missing_frames() -> void:
	if _warned_missing_frames:
		return
	_warned_missing_frames = true
	push_warning("%s is missing SpriteFrames; traffic animation will be skipped." % name)

func _custom_speed_for_duration(animation_name: String, duration_seconds: float) -> float:
	if door_sprite == null or door_sprite.sprite_frames == null or duration_seconds <= 0.0:
		return 1.0
	var native_duration := _animation_duration(animation_name)
	if native_duration <= 0.0:
		return 1.0
	return maxf(0.01, native_duration / duration_seconds)

func _animation_duration(animation_name: String) -> float:
	if door_sprite == null or door_sprite.sprite_frames == null:
		return 0.0
	var frame_count := door_sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return 0.0
	var duration := 0.0
	for index in range(frame_count):
		duration += door_sprite.sprite_frames.get_frame_duration(animation_name, index)
	var speed := door_sprite.sprite_frames.get_animation_speed(animation_name)
	if speed <= 0.0:
		return duration
	return duration / speed
