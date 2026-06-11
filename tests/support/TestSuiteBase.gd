@tool
extends McpTestSuite

var economy: Dictionary = {}
var furniture: Array = []
var tenants: Array = []
var regions: Array = []
var rooms: Array = []
var floors: Array = []
var room_decor: Dictionary = {}

func setup() -> void:
	economy = _load_json_dict("res://data/economy.json")
	furniture = _load_json_array("res://data/furniture.json")
	tenants = _load_json_array("res://data/tenants.json")
	regions = _load_json_array("res://data/tenant_regions.json")
	rooms = _load_json_array("res://data/rooms.json")
	floors = _load_json_array("res://data/floors.json")
	room_decor = _load_json_dict("res://data/room_decor.json")


func _panel_scene_paths() -> Array[String]:
	return [
		"res://scenes/ui/RoomPanel.tscn",
		"res://scenes/ui/FurnitureShopPanel.tscn",
		"res://scenes/ui/TenantPanel.tscn",
		"res://scenes/ui/BuildConfirmPopup.tscn",
		"res://scenes/ui/ApartmentOverviewPanel.tscn",
		"res://scenes/ui/IncomeDetailPanel.tscn",
		"res://scenes/ui/RentDetailPanel.tscn",
		"res://scenes/ui/TaskPanel.tscn",
		"res://scenes/ui/RewardPanel.tscn",
		"res://scenes/ui/SettingsPanel.tscn",
		"res://scenes/ui/OfflineRewardPopup.tscn"
	]


func _app_panel_scene_paths() -> Array[String]:
	return [
		"res://scenes/ui/RoomPanel.tscn",
		"res://scenes/ui/FurnitureShopPanel.tscn",
		"res://scenes/ui/TenantPanel.tscn",
		"res://scenes/ui/BuildConfirmPopup.tscn",
		"res://scenes/ui/ApartmentOverviewPanel.tscn",
		"res://scenes/ui/IncomeDetailPanel.tscn",
		"res://scenes/ui/RentDetailPanel.tscn",
		"res://scenes/ui/TaskPanel.tscn",
		"res://scenes/ui/RewardPanel.tscn",
		"res://scenes/ui/SettingsPanel.tscn",
		"res://scenes/ui/OfflineRewardPopup.tscn",
		"res://scenes/ui/RecycleConfirmPopup.tscn"
	]


func _support_scene_paths() -> Array[String]:
	return [
		"res://scenes/ui/PlacementOverlay.tscn",
		"res://scenes/ui/PopupLayer.tscn",
		"res://scenes/effects/FloatingCoinText.tscn",
		"res://scenes/furniture/FurniturePreview.tscn",
		"res://scenes/furniture/FurnitureFloatingControls.tscn",
		"res://scenes/building/RoomDoor.tscn",
		"res://scenes/building/ExitDoor.tscn",
		"res://scenes/building/ElevatorDoor.tscn",
		"res://scenes/tenant/Tenant.tscn",
		"res://scenes/tenant/NeedBubble.tscn",
		"res://scenes/tenant/TenantEmote.tscn",
		"res://scenes/ui/ProgressCard.tscn",
		"res://scenes/ui/TaskItemRow.tscn",
		"res://scenes/ui/FurnitureShopItemRow.tscn",
		"res://scenes/ui/RoomFurnitureItemRow.tscn",
		"res://scenes/ui/RoomDecorItemRow.tscn",
		"res://scenes/ui/RentRoomRow.tscn",
		"res://scenes/ui/FloorOverviewRow.tscn",
		"res://scenes/ui/TenantOverviewRow.tscn"
	]


func _ui_script_paths() -> Array[String]:
	return [
		"res://scripts/ui/AppPanel.gd",
		"res://scripts/ui/ApartmentOverviewPanel.gd",
		"res://scripts/ui/BuildConfirmPopup.gd",
		"res://scripts/ui/FloatingMenu.gd",
		"res://scripts/ui/FurnitureShopItemRow.gd",
		"res://scripts/ui/FurnitureShopPanel.gd",
		"res://scripts/ui/FloorOverviewRow.gd",
		"res://scripts/ui/IconActionRow.gd",
		"res://scripts/ui/IconInfoRow.gd",
		"res://scripts/ui/IncomeDetailPanel.gd",
		"res://scripts/ui/OfflineRewardPopup.gd",
		"res://scripts/ui/PanelActionButton.gd",
		"res://scripts/ui/PanelTabButton.gd",
		"res://scripts/ui/PlacementOverlay.gd",
		"res://scripts/ui/PopupLayer.gd",
		"res://scripts/ui/ProgressCard.gd",
		"res://scripts/ui/RecycleConfirmPopup.gd",
		"res://scripts/ui/RentDetailPanel.gd",
		"res://scripts/ui/RentRoomRow.gd",
		"res://scripts/ui/RewardPanel.gd",
		"res://scripts/ui/RoomFurnitureItemRow.gd",
		"res://scripts/ui/RoomDecorItemRow.gd",
		"res://scripts/ui/RoomPanel.gd",
		"res://scripts/ui/SettingsPanel.gd",
		"res://scripts/ui/StatCard.gd",
		"res://scripts/ui/TaskPanel.gd",
		"res://scripts/ui/TaskItemRow.gd",
		"res://scripts/ui/TenantPanel.gd",
		"res://scripts/ui/TenantOverviewRow.gd",
		"res://scripts/ui/TopStatusBar.gd",
		"res://scripts/ui/UIPanelFactory.gd"
	]


func _presentation_script_paths() -> Array[String]:
	var paths := _ui_script_paths()
	paths.append_array([
		"res://scripts/effects/FloatingCoinText.gd",
		"res://scripts/furniture/Furniture.gd",
		"res://scripts/furniture/FurniturePreview.gd",
		"res://scripts/tenant/Tenant.gd",
		"res://scripts/tenant/NeedBubble.gd",
		"res://scripts/tenant/TenantEmote.gd"
	])
	return paths


func _calculate_room_rent(tenant_id: String, score: int, satisfaction: int) -> float:
	if tenant_id.is_empty():
		return 0.0
	var tenant: Dictionary = _tenant_data(tenant_id)
	var base_rent: float = float(economy.get("base_rent", 10.0))
	var score_factor: float = float(economy.get("score_rent_factor", 0.5))
	return (base_rent + float(score) * score_factor) * float(tenant.get("pay_multiplier", 1.0)) * _satisfaction_multiplier(satisfaction)


func _satisfaction_multiplier(value: int) -> float:
	if value <= 30:
		return 0.7
	if value <= 60:
		return 1.0
	if value <= 80:
		return 1.15
	return 1.3


func _tenant_data(tenant_id: String) -> Dictionary:
	for tenant in tenants:
		var tenant_data: Dictionary = tenant
		if str(tenant_data.get("id", "")) == tenant_id:
			return tenant_data
	return {}


func _furniture_data(furniture_id: String) -> Dictionary:
	for item in furniture:
		var furniture_data: Dictionary = item
		if str(furniture_data.get("id", "")) == furniture_id:
			return furniture_data
	return {}


func _unlocked_region_ids(apartment_level: int) -> Array:
	var ids: Array = []
	for region in regions:
		var region_data: Dictionary = region
		if apartment_level >= int(region_data.get("required_apartment_level", 1)):
			ids.append(str(region_data.get("id", "")))
	return ids


func _region_tenant_ids(region_id: String) -> Array:
	for region in regions:
		var region_data: Dictionary = region
		if str(region_data.get("id", "")) == region_id:
			return region_data.get("tenant_ids", [])
	return []


func _region_data(region_id: String) -> Dictionary:
	for region in regions:
		var region_data: Dictionary = region
		if str(region_data.get("id", "")) == region_id:
			return region_data
	return {}


func _floor_data(floor_index: int) -> Dictionary:
	for floor in floors:
		var floor_data: Dictionary = floor
		if int(floor_data.get("floor_index", 0)) == floor_index:
			return floor_data
	return {}


func _room_ids_on_floor(floor_index: int) -> Array:
	var ids: Array = []
	for room in rooms:
		var room_data: Dictionary = room
		if int(room_data.get("floor_index", 0)) == floor_index:
			ids.append(str(room_data.get("id", "")))
	return ids


func _room_decor_item(decor_id: String) -> Dictionary:
	for item in room_decor.get("items", []):
		var decor_item: Dictionary = item
		if str(decor_item.get("id", "")) == decor_id:
			return decor_item
	return {}


func _bind_apartment_tilemap_layers(tilemap: Variant) -> void:
	tilemap.set("wallpaper_layer", tilemap.get_node_or_null("WallpaperTileMap") as TileMapLayer)
	tilemap.set("wall_layer", tilemap.get_node_or_null("WallTileMap") as TileMapLayer)
	tilemap.set("infrastructure_layer", tilemap.get_node_or_null("InfrastructureTileMap") as TileMapLayer)
	tilemap.set("roof_layer", tilemap.get_node_or_null("RoofTileMap") as TileMapLayer)
	tilemap.set("construction_layer", tilemap.get_node_or_null("ConstructionTileMap") as TileMapLayer)


func _asset_texture_exists(asset: Dictionary) -> bool:
	var path := str(asset.get("texture", ""))
	return not path.is_empty() and FileAccess.file_exists(path)


func _tileset_source_with_texture(tileset: TileSet, texture_name: String) -> TileSetAtlasSource:
	for index in range(tileset.get_source_count()):
		var source_id := tileset.get_source_id(index)
		var atlas_source := tileset.get_source(source_id) as TileSetAtlasSource
		if atlas_source != null and atlas_source.texture != null and atlas_source.texture.resource_path.ends_with(texture_name):
			return atlas_source
	return null


func _load_json_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []


func _load_json_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
