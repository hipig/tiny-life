class_name BuildSlotShell
extends Control

@onready var room_shell: Control = $BuildRoomShell
@onready var tile_map: ApartmentTileMap = $BuildRoomShell/ApartmentTileMap
@onready var construction_cover: TextureRect = $BuildRoomShell/ConstructionCover
@onready var status_panel: PanelContainer = $BuildRoomShell/BuildSlotStatusPanel
@onready var icon: TextureRect = $BuildRoomShell/BuildSlotStatusPanel/MarginContainer/StatusRow/BuildHammer
@onready var label: Label = $BuildRoomShell/BuildSlotStatusPanel/MarginContainer/StatusRow/BuildSlotLabel

func apply_layout(slot_size: Vector2, _wall_inset: float, _floor_height: float, _roof_height: float, frame_tiles := Vector2i(6, 4), tile_theme: Dictionary = {}, edge_sides: Dictionary = {}) -> void:
	custom_minimum_size = slot_size
	size = custom_minimum_size
	room_shell.custom_minimum_size = slot_size
	room_shell.size = slot_size
	if tile_map != null:
		tile_map.render_room_skeleton(frame_tiles, tile_theme, false, false, edge_sides, {}, "")
	_layout_cover(slot_size, frame_tiles)
	_layout_status(slot_size, frame_tiles)
	set_construction_visible(true)

func set_construction_visible(value: bool) -> void:
	if construction_cover != null:
		construction_cover.visible = value

func set_locked_visuals(locked: bool) -> void:
	var tint := Color(0.62, 0.62, 0.62, 0.58) if locked else Color.WHITE
	if tile_map != null:
		tile_map.set_locked_visuals(locked)
	if construction_cover != null:
		construction_cover.modulate = tint
	if status_panel != null:
		status_panel.modulate = tint
	if icon != null:
		icon.modulate = tint
	if label != null:
		label.modulate = tint

func _layout_cover(slot_size: Vector2, _frame_tiles: Vector2i) -> void:
	if construction_cover == null:
		return
	var cover_rect := _cover_rect(slot_size)
	var cover_size := cover_rect.size
	construction_cover.custom_minimum_size = cover_size
	construction_cover.size = cover_size
	construction_cover.position = cover_rect.position

func _layout_status(slot_size: Vector2, _frame_tiles: Vector2i) -> void:
	if status_panel == null:
		return
	var panel_size := Vector2(minf(58.0, maxf(46.0, slot_size.x - 12.0)), 24.0)
	status_panel.custom_minimum_size = panel_size
	status_panel.size = panel_size
	status_panel.position = (slot_size - panel_size) * 0.5

func _cover_rect(slot_size: Vector2) -> Rect2:
	var inset := 2.0
	var position := Vector2(inset, inset)
	var size := Vector2(
		maxf(1.0, slot_size.x - inset * 2.0),
		maxf(1.0, slot_size.y - inset * 2.0)
	)
	return Rect2(position, size)
