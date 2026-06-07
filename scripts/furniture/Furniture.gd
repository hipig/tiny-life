extends TextureRect

const LONG_PRESS_SECONDS := 0.5
const DEFAULT_FURNITURE_TEXTURE := preload("res://assets/pixel_spaces/furniture/Furniture.png")

@export_group("Asset Overrides")
@export var override_configured_asset := false
@export var asset_texture: Texture2D = DEFAULT_FURNITURE_TEXTURE
@export var asset_region := Rect2(0.0, 49.0, 28.0, 14.0)

@export_group("Scene Text")
@export var fallback_furniture_name := ""

var instance_data: Dictionary = {}
var furniture_id := ""
var room_id := ""
var _pressing := false
var _press_time := 0.0

func _process(delta: float) -> void:
	if not _pressing:
		return
	_press_time += delta
	if _press_time < LONG_PRESS_SECONDS:
		return
	_pressing = false
	if UIManager.current_state != UIManager.UIState.NORMAL and UIManager.current_state != UIManager.UIState.ROOM_PANEL:
		return
	if not room_id.is_empty():
		UIManager.start_move_existing(room_id, str(instance_data.get("instance_id", "")))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_pressing = true
			_press_time = 0.0
		else:
			var was_short := _pressing and _press_time < LONG_PRESS_SECONDS
			_pressing = false
			if was_short:
				UIManager.show_toast(str(tooltip_text))
		accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_pressing = true
			_press_time = 0.0
		else:
			var was_short_touch := _pressing and _press_time < LONG_PRESS_SECONDS
			_pressing = false
			if was_short_touch:
				UIManager.show_toast(str(tooltip_text))
		accept_event()

func setup(data: Dictionary) -> void:
	instance_data = data
	furniture_id = str(instance_data.get("furniture_id", ""))
	room_id = str(instance_data.get("room_id", room_id))
	var furniture_data: Dictionary = ConfigManager.get_furniture_data(furniture_id)
	var asset: Dictionary = furniture_data.get("asset", {})
	_apply_asset_or_export(asset, Color("#b9784a"), Vector2i(26, 26))
	tooltip_text = str(furniture_data.get("name", fallback_furniture_name))

func _apply_asset_or_export(asset_config: Dictionary, fallback: Color, placeholder_size := Vector2i(26, 26)) -> void:
	if not override_configured_asset:
		AssetResolver.apply_asset_to_texture_rect(self, asset_config, fallback, placeholder_size)
		return
	texture = _atlas_texture_from_export(asset_texture, asset_region)
	if texture == null:
		texture = AssetResolver.texture_from_asset(asset_config, fallback, placeholder_size)

func _atlas_texture_from_export(source_texture: Texture2D, region: Rect2) -> Texture2D:
	if source_texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = region
	return atlas
