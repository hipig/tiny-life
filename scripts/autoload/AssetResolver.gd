@tool
extends Node

func color_from_asset(asset_config: Dictionary) -> Color:
	if not asset_config.has("color"):
		_fail("Asset config is missing color.")
		return Color.WHITE
	var hex := str(asset_config["color"]).strip_edges()
	if hex.is_empty():
		_fail("Asset config color cannot be empty.")
		return Color.WHITE
	return Color.html(hex)

func apply_asset_to_color_rect(rect: ColorRect, asset_config: Dictionary) -> void:
	rect.color = color_from_asset(asset_config)

func apply_asset_to_texture_rect(rect: TextureRect, asset_config: Dictionary, expected_size := Vector2i(32, 32)) -> void:
	rect.texture = texture_from_asset(asset_config, expected_size)

func apply_asset_to_button_icon(button: Button, asset_config: Dictionary, expected_size := Vector2i(16, 16)) -> void:
	button.icon = texture_from_asset(asset_config, expected_size)

func has_visual_asset(asset_config: Dictionary) -> bool:
	return asset_config is Dictionary and not asset_config.is_empty() and str(asset_config.get("type", "")).strip_edges() != ""

func apply_asset_to_sprite(sprite: Sprite2D, asset_config: Dictionary, expected_size := Vector2i(32, 32)) -> void:
	sprite.texture = texture_from_asset(asset_config, expected_size)
	sprite.region_enabled = false
	sprite.modulate = Color.WHITE

func apply_asset_to_animated_sprite(sprite: AnimatedSprite2D, asset_config: Dictionary, default_animation := "", expected_size := Vector2i(32, 40)) -> void:
	var frames := SpriteFrames.new()
	var asset_type := _required_string(asset_config, "type", "AnimatedSprite asset")
	if asset_type == "spritesheet_animation":
		_add_spritesheet_animations(frames, asset_config, expected_size)
	else:
		_add_static_animation_frames(frames, asset_config, _resolved_animation_name(asset_config, default_animation), expected_size)
	sprite.sprite_frames = frames
	var animation_name := _resolved_animation_name(asset_config, default_animation)
	if not frames.has_animation(animation_name):
		push_error("AnimatedSprite asset is missing animation '%s'." % animation_name)
		sprite.stop()
		return
	sprite.animation = animation_name
	sprite.play(animation_name)

func texture_from_asset(asset_config: Dictionary, expected_size := Vector2i(32, 32)) -> Texture2D:
	var asset_type := _required_string(asset_config, "type", "Texture asset")
	match asset_type:
		"single_sprite":
			return _required_texture(_required_string(asset_config, "texture", "single_sprite asset"))
		"atlas_region":
			return _atlas_texture(_required_string(asset_config, "texture", "atlas_region asset"), _rect_from_array(asset_config["region"], expected_size))
		"spritesheet_frame":
			return _spritesheet_frame_texture(asset_config, asset_config["frame"] if asset_config.has("frame") else asset_config["region"], expected_size)
		_:
			_fail("Unsupported texture asset type '%s'." % asset_type)
			return null

func _add_spritesheet_animations(frames: SpriteFrames, asset_config: Dictionary, expected_size: Vector2i) -> void:
	var animations: Dictionary = asset_config["animations"]
	for animation_key in animations.keys():
		var animation_name := str(animation_key)
		_replace_animation(frames, animation_name)
		var animation_config: Variant = animations[animation_key]
		var frame_list: Array = []
		var loop := bool(asset_config["loop"]) if asset_config.has("loop") else true
		var fps := float(asset_config["fps"]) if asset_config.has("fps") else 6.0
		if animation_config is Dictionary:
			frame_list = animation_config.get("frames", [])
			loop = bool(animation_config.get("loop", loop))
			fps = float(animation_config.get("fps", fps))
		elif animation_config is Array:
			frame_list = animation_config
		frames.set_animation_loop(animation_name, loop)
		frames.set_animation_speed(animation_name, fps)
		for frame_entry in frame_list:
			frames.add_frame(
				animation_name,
				_spritesheet_frame_texture(asset_config, frame_entry, expected_size),
				_frame_duration(frame_entry)
			)

func _add_static_animation_frames(frames: SpriteFrames, asset_config: Dictionary, animation_name: String, expected_size: Vector2i) -> void:
	var texture := texture_from_asset(asset_config, expected_size)
	_replace_animation(frames, animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, 4.0)
	frames.add_frame(animation_name, texture)

func _spritesheet_frame_texture(asset_config: Dictionary, frame_coord, expected_size: Vector2i) -> Texture2D:
	var texture_path := _required_string(asset_config, "texture", "spritesheet asset")
	if frame_coord is Dictionary:
		if frame_coord.has("texture"):
			texture_path = str(frame_coord["texture"]).strip_edges()
		if frame_coord.has("region"):
			return _atlas_texture(texture_path, _rect_from_array(frame_coord["region"], expected_size))
	var frame_size: Array = frame_coord["frame_size"] if frame_coord is Dictionary and frame_coord.has("frame_size") else asset_config["frame_size"]
	var frame: Array = _frame_coord_from_entry(frame_coord)
	var frame_offset: Array = asset_config["frame_offset"] if asset_config.has("frame_offset") else [0, 0]
	if frame_coord is Dictionary:
		if frame_coord.has("frame_offset"):
			frame_offset = frame_coord["frame_offset"]
	var region := Rect2(
		(float(frame[0]) + float(frame_offset[0])) * float(frame_size[0]),
		(float(frame[1]) + float(frame_offset[1])) * float(frame_size[1]),
		float(frame_size[0]),
		float(frame_size[1])
	)
	return _atlas_texture(texture_path, region)

func _atlas_texture(texture_path: String, region: Rect2) -> Texture2D:
	var source := _required_texture(texture_path)
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas

func _required_texture(path: String) -> Texture2D:
	if path.is_empty():
		_fail("Asset texture path cannot be empty.")
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		_fail("Asset texture could not be loaded: %s" % path)
	return texture

func _resolved_animation_name(asset_config: Dictionary, preferred: String) -> String:
	if not preferred.strip_edges().is_empty():
		return preferred.strip_edges()
	return _required_string(asset_config, "default_animation", "AnimatedSprite asset")

func _frame_coord_from_entry(frame_entry) -> Array:
	if frame_entry is Dictionary:
		return _required_array(frame_entry["frame"], 2, "spritesheet frame")
	return _required_array(frame_entry, 2, "spritesheet frame")

func _frame_duration(frame_entry) -> float:
	if frame_entry is Dictionary:
		return maxf(0.01, float(frame_entry.get("duration", 1.0)))
	return 1.0

func _replace_animation(frames: SpriteFrames, animation_name: String) -> void:
	if frames.has_animation(animation_name):
		frames.remove_animation(animation_name)
	frames.add_animation(animation_name)

func _rect_from_array(values, expected_size: Vector2i) -> Rect2:
	var array: Array = _required_array(values, 4, "atlas region")
	if array.size() < 4:
		return Rect2(0, 0, expected_size.x, expected_size.y)
	return Rect2(float(array[0]), float(array[1]), float(array[2]), float(array[3]))

func _required_string(data: Dictionary, key: String, context: String) -> String:
	if not data.has(key):
		_fail("%s is missing key '%s'." % [context, key])
		return ""
	var value := str(data[key]).strip_edges()
	if value.is_empty():
		_fail("%s key '%s' cannot be empty." % [context, key])
	return value

func _required_array(value: Variant, size: int, context: String) -> Array:
	if value is Array and value.size() >= size:
		return value
	_fail("%s must be an array with at least %d entries." % [context, size])
	return []

func _fail(message: String) -> void:
	push_error(message)
	assert(false, message)
