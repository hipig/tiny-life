class_name ApartmentRoof
extends Node2D

@onready var tile_map: ApartmentTileMap = $ApartmentTileMap
@onready var click_area: Area2D = $ClickArea
@onready var click_shape: CollisionShape2D = $ClickArea/Hitbox

var target_ref: Dictionary = {}

func _ready() -> void:
	if click_area != null and not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)

func apply_layout(roof_theme: Dictionary, next_target_ref: Dictionary = {}) -> void:
	target_ref = next_target_ref.duplicate(true)
	var offset := _vector2_from_array(roof_theme["offset_pixels"])
	position = offset
	var total_width_tiles := int(roof_theme["total_width_tiles"])
	if tile_map != null:
		tile_map.render_roof(total_width_tiles, roof_theme)
	_layout_click_area(total_width_tiles)
	visible = true

func hide_roof() -> void:
	visible = false
	if click_area != null:
		click_area.visible = false

func _vector2_from_array(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	push_error("Expected a [x, y] roof offset array.")
	return Vector2.ZERO

func _layout_click_area(total_width_tiles: int) -> void:
	if click_area == null or click_shape == null:
		return
	var width := maxf(float(total_width_tiles * ApartmentTileMap.TILE_SIZE), float(ApartmentTileMap.TILE_SIZE))
	click_area.visible = true
	click_area.position = Vector2.ZERO
	click_shape.position = Vector2(width * 0.5, -ApartmentTileMap.TILE_SIZE * 0.5)
	var rect := click_shape.shape as RectangleShape2D
	if rect != null:
		rect.size = Vector2(width, ApartmentTileMap.TILE_SIZE)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if target_ref.is_empty():
		return
	if not _can_open_decor_panel():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		UIManager.open_space_decor_panel(target_ref, ConfigManager.DECOR_ROOF)

func _can_open_decor_panel() -> bool:
	return UIManager.current_state == UIManager.UIState.NORMAL \
		or UIManager.current_state == UIManager.UIState.ROOM_PANEL \
		or UIManager.current_state == UIManager.UIState.SPACE_DECOR_PANEL
