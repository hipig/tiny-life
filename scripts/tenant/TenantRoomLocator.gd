@tool
class_name TenantRoomLocator
extends RefCounted

const TILE_SIZE := FurniturePlacementRules.TILE_SIZE
const EDGE_INSET_PIXELS := 4.0
const DEFAULT_SPAWN_RATIO := 0.6
const HASH_BUCKETS := 1000

static func spawn_position(room: Dictionary, stable_key := "") -> Vector2:
	var ratio := DEFAULT_SPAWN_RATIO
	if not stable_key.is_empty():
		ratio = _stable_ratio(stable_key)
	var rect := floor_rect(room)
	return floor_position_at_x(room, lerpf(_floor_min_x(rect), _floor_max_x(rect), ratio))

static func wander_target_position(room: Dictionary, current_position: Vector2) -> Vector2:
	var rect := floor_rect(room)
	var left := floor_position_at_x(room, _floor_min_x(rect))
	var right := floor_position_at_x(room, _floor_max_x(rect))
	if current_position.distance_to(right) < current_position.distance_to(left):
		return left
	return right

static func room_door_inside_position(room: Dictionary) -> Vector2:
	var rect := floor_rect(room)
	var door_side := str(room.get("door_side", "left")).strip_edges().to_lower()
	if door_side == "right":
		return floor_position_at_x(room, _floor_max_x(rect))
	return floor_position_at_x(room, _floor_min_x(rect))

static func furniture_use_position(room: Dictionary, furniture_instance: Dictionary, furniture_data: Dictionary) -> Vector2:
	var anchor_pos: Array = furniture_instance.get("anchor_pos", [])
	if anchor_pos.size() < 2:
		return spawn_position(room)
	var orientation := str(furniture_instance.get("orientation", FurniturePlacementRules.DEFAULT_ORIENTATION))
	var bounds := FurniturePlacementRules.bounds_rect_for_anchor(room, furniture_data, anchor_pos, Vector2.ZERO, orientation)
	if bounds.size.x <= 0.0:
		return spawn_position(room)
	return floor_position_at_x(room, bounds.position.x + bounds.size.x * 0.5)

static func floor_position_at_x(room: Dictionary, x: float) -> Vector2:
	var rect := floor_rect(room)
	return Vector2(
		roundf(clampf(x, _floor_min_x(rect), _floor_max_x(rect))),
		floor_y(room)
	)

static func floor_y(room: Dictionary) -> float:
	return floor_rect(room).end.y

static func floor_rect(room: Dictionary) -> Rect2:
	var frame_tiles := _frame_tiles(room)
	return Rect2(
		0.0,
		0.0,
		float(maxi(1, frame_tiles.x) * TILE_SIZE),
		float(maxi(1, frame_tiles.y) * TILE_SIZE)
	)

static func _floor_min_x(rect: Rect2) -> float:
	if rect.size.x <= EDGE_INSET_PIXELS * 2.0:
		return rect.position.x + rect.size.x * 0.5
	return rect.position.x + EDGE_INSET_PIXELS

static func _floor_max_x(rect: Rect2) -> float:
	if rect.size.x <= EDGE_INSET_PIXELS * 2.0:
		return rect.position.x + rect.size.x * 0.5
	return rect.end.x - EDGE_INSET_PIXELS

static func _stable_ratio(stable_key: String) -> float:
	return float(posmod(int(stable_key.hash()), HASH_BUCKETS)) / float(HASH_BUCKETS - 1)

static func _frame_tiles(room: Dictionary) -> Vector2i:
	var raw: Variant = room.get("frame_tiles", [6, 4])
	if raw is Array and raw.size() >= 2:
		return Vector2i(maxi(2, int(raw[0])), int(raw[1]))
	if raw is Vector2i:
		return Vector2i(maxi(2, raw.x), raw.y)
	if raw is Vector2:
		return Vector2i(maxi(2, int(raw.x)), int(raw.y))
	return Vector2i(6, 4)
