@tool
extends Node

var _placeholder_texture_cache := {}

func color_from_asset(asset_config: Dictionary, fallback := Color.WHITE) -> Color:
	var hex := str(asset_config.get("color", ""))
	if hex.is_empty():
		return fallback
	return Color.html(hex)

func apply_asset_to_color_rect(rect: ColorRect, asset_config: Dictionary, fallback := Color.WHITE) -> void:
	rect.color = color_from_asset(asset_config, fallback)

func apply_asset_to_texture_rect(rect: TextureRect, asset_config: Dictionary, fallback := Color.WHITE, placeholder_size := Vector2i(32, 32)) -> void:
	rect.texture = texture_from_asset(asset_config, fallback, placeholder_size)

func apply_asset_to_button_icon(button: Button, asset_config: Dictionary, fallback := Color.WHITE, placeholder_size := Vector2i(16, 16)) -> void:
	button.icon = texture_from_asset(asset_config, fallback, placeholder_size)

func has_visual_asset(asset_config: Dictionary) -> bool:
	var asset_type := str(asset_config.get("type", "placeholder"))
	if asset_type == "placeholder":
		return false
	if asset_type == "single_sprite":
		return not str(asset_config.get("texture", "")).is_empty()
	if asset_type in ["atlas_region", "spritesheet_frame", "spritesheet_animation"]:
		return not str(asset_config.get("texture", "")).is_empty()
	return false

func apply_asset_to_sprite(sprite: Sprite2D, asset_config: Dictionary, fallback := Color.WHITE, placeholder_size := Vector2i(32, 32)) -> void:
	sprite.texture = texture_from_asset(asset_config, fallback, placeholder_size)
	sprite.region_enabled = false
	sprite.modulate = Color.WHITE

func apply_asset_to_animated_sprite(sprite: AnimatedSprite2D, asset_config: Dictionary, default_animation := "idle", fallback := Color.WHITE, placeholder_size := Vector2i(32, 40)) -> void:
	var frames := SpriteFrames.new()
	var asset_type := str(asset_config.get("type", "placeholder"))
	if asset_type == "spritesheet_animation":
		_add_spritesheet_animations(frames, asset_config, fallback, placeholder_size)
	else:
		_add_static_animation_frames(frames, asset_config, default_animation, fallback, placeholder_size)
	sprite.sprite_frames = frames
	var first_animation := default_animation
	if not frames.has_animation(first_animation):
		first_animation = str(asset_config.get("default_animation", "idle"))
	if not frames.has_animation(first_animation) and frames.has_animation("idle"):
		first_animation = "idle"
	if not frames.has_animation(first_animation) and frames.get_animation_names().size() > 0:
		first_animation = str(frames.get_animation_names()[0])
	sprite.animation = first_animation
	if frames.has_animation(first_animation):
		sprite.play(first_animation)

func texture_from_asset(asset_config: Dictionary, fallback := Color.WHITE, placeholder_size := Vector2i(32, 32)) -> Texture2D:
	var asset_type := str(asset_config.get("type", "placeholder"))
	match asset_type:
		"single_sprite":
			var path := str(asset_config.get("texture", ""))
			var texture := _load_texture(path)
			if texture != null:
				return texture
		"atlas_region":
			var texture := _atlas_texture(str(asset_config.get("texture", "")), _rect_from_array(asset_config.get("region", [0, 0, placeholder_size.x, placeholder_size.y])))
			if texture != null:
				return texture
		"spritesheet_frame":
			var texture := _spritesheet_frame_texture(asset_config, asset_config.get("frame", [0, 0]), fallback, placeholder_size)
			if texture != null:
				return texture
		"placeholder":
			pass
		_:
			pass
	return _placeholder_texture(color_from_asset(asset_config, fallback), placeholder_size)

func _add_spritesheet_animations(frames: SpriteFrames, asset_config: Dictionary, fallback: Color, placeholder_size: Vector2i) -> void:
	var animations: Dictionary = asset_config.get("animations", {})
	if animations.is_empty():
		var animation_name := str(asset_config.get("default_animation", "idle"))
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, true)
		frames.add_frame(animation_name, _placeholder_texture(color_from_asset(asset_config, fallback), placeholder_size))
		return
	for animation_key in animations.keys():
		var animation_name := str(animation_key)
		if not frames.has_animation(animation_name):
			frames.add_animation(animation_name)
		var animation_config: Variant = animations[animation_key]
		var frame_list: Array = []
		var loop := bool(asset_config.get("loop", true))
		var fps := float(asset_config.get("fps", 6.0))
		if animation_config is Dictionary:
			frame_list = animation_config.get("frames", [])
			loop = bool(animation_config.get("loop", loop))
			fps = float(animation_config.get("fps", fps))
		elif animation_config is Array:
			frame_list = animation_config
		frames.set_animation_loop(animation_name, loop)
		frames.set_animation_speed(animation_name, fps)
		if frame_list.is_empty():
			frames.add_frame(animation_name, _placeholder_texture(color_from_asset(asset_config, fallback), placeholder_size))
			continue
		for frame_entry in frame_list:
			frames.add_frame(
				animation_name,
				_spritesheet_frame_texture(asset_config, frame_entry, fallback, placeholder_size),
				_frame_duration(frame_entry)
			)

func _add_static_animation_frames(frames: SpriteFrames, asset_config: Dictionary, default_animation: String, fallback: Color, placeholder_size: Vector2i) -> void:
	var texture := texture_from_asset(asset_config, fallback, placeholder_size)
	var names: Array[String] = [default_animation]
	if default_animation != "idle":
		names.append("idle")
	for animation_name in names:
		if frames.has_animation(animation_name):
			continue
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, true)
		frames.set_animation_speed(animation_name, 4.0)
		frames.add_frame(animation_name, texture)

func _spritesheet_frame_texture(asset_config: Dictionary, frame_coord, fallback: Color, placeholder_size: Vector2i) -> Texture2D:
	var texture_path := str(asset_config.get("texture", ""))
	if frame_coord is Dictionary:
		texture_path = str(frame_coord.get("texture", texture_path))
		if frame_coord.has("region"):
			var direct_region := _rect_from_array(frame_coord.get("region", [0, 0, placeholder_size.x, placeholder_size.y]))
			var direct_texture := _atlas_texture(texture_path, direct_region)
			if direct_texture != null:
				return direct_texture
	var frame_size: Array = _array_from_value(
		frame_coord.get("frame_size", asset_config.get("frame_size", [placeholder_size.x, placeholder_size.y])) if frame_coord is Dictionary else asset_config.get("frame_size", [placeholder_size.x, placeholder_size.y]),
		[placeholder_size.x, placeholder_size.y]
	)
	var frame: Array = _frame_coord_from_entry(frame_coord)
	if frame.size() < 2 or frame_size.size() < 2:
		return _placeholder_texture(color_from_asset(asset_config, fallback), placeholder_size)
	var frame_offset: Array = _array_from_value(asset_config.get("frame_offset", [0, 0]), [0, 0])
	if frame_coord is Dictionary:
		frame_offset = _array_from_value(frame_coord.get("frame_offset", frame_offset), frame_offset)
	var region := Rect2(
		(float(frame[0]) + float(frame_offset[0])) * float(frame_size[0]),
		(float(frame[1]) + float(frame_offset[1])) * float(frame_size[1]),
		float(frame_size[0]),
		float(frame_size[1])
	)
	var texture := _atlas_texture(texture_path, region)
	if texture == null:
		return _placeholder_texture(color_from_asset(asset_config, fallback), placeholder_size)
	return texture

func _atlas_texture(texture_path: String, region: Rect2) -> Texture2D:
	var source := _load_texture(texture_path)
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas

func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var texture := load(path) as Texture2D
	return texture

func _frame_coord_from_entry(frame_entry) -> Array:
	if frame_entry is Dictionary:
		return _array_from_value(frame_entry.get("frame", [0, 0]), [0, 0])
	return _array_from_value(frame_entry, [0, 0])

func _frame_duration(frame_entry) -> float:
	if frame_entry is Dictionary:
		return maxf(0.01, float(frame_entry.get("duration", 1.0)))
	return 1.0

func _array_from_value(value, fallback: Array) -> Array:
	if value is Array:
		return value
	return fallback

func _placeholder_texture(color: Color, size: Vector2i) -> Texture2D:
	var safe_size := Vector2i(maxi(1, size.x), maxi(1, size.y))
	var key := "%s:%dx%d" % [color.to_html(true), safe_size.x, safe_size.y]
	if _placeholder_texture_cache.has(key):
		return _placeholder_texture_cache[key]
	var image := Image.create(safe_size.x, safe_size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	_placeholder_texture_cache[key] = texture
	return texture

func _rect_from_array(values) -> Rect2:
	var array: Array = values if values is Array else [0, 0, 32, 32]
	if array.size() < 4:
		return Rect2(0, 0, 32, 32)
	return Rect2(float(array[0]), float(array[1]), float(array[2]), float(array[3]))
