# 公寓 TileMap 迁移计划

本文件记录公寓主体从脚本拼装/尺寸驱动过渡到编辑器可见 TileMap 的后续工作。

## 当前边界

- `Room.tscn`、`BuildSlot.tscn`、`Floor.tscn` 保留交互按钮和运行时数据绑定。
- `ApartmentTileMap.tscn` 与 `ServiceCoreTileMap.tscn` 已作为可编辑 TileMap 子场景存在。
- `ApartmentBuilding.tscn`、`Floor.tscn`、`Room.tscn` 已通过导出属性指定楼层、建造槽、房间、家具和租客子场景模板，脚本只按数据实例化这些编辑器可打开的模板。
- `floors.json` 可通过 `floor_scene_path` / `build_slot_scene_path` 选择楼层和施工槽模板；`rooms.json` 可通过 `room_scene_path` 选择房间模板。默认值仍指向当前 MVP 场景，后续可替换为手工铺好的不同尺寸 TileMap 模板。
- 家具、租客、摆放预览仍作为子场景挂到房间可视层。
- 脚本暂时允许按 `rooms.json` / `floors.json` 渲染房间尺寸、楼层尺寸、家具位置和租客挂点。

## 目标状态

- 房间墙体、地板、骨架、屋檐、施工层、服务核心全部由编辑器中可见的 `TileMapLayer` 承载。
- `TileMapLayer` 使用共享 `res://tilesets/apartment_tileset.tres`，不在运行时创建 TileSet。
- 房间格子大小、可扩展房间数量、楼层高度仍来自配置，但只用于交互区域、摆放网格和挂点绑定。
- 脚本不再生成或修补墙体、底色、描边、施工布、屋檐等主体视觉。

## 下一步

1. 在 `ApartmentTileMap.tscn` 和 `ServiceCoreTileMap.tscn` 中手工铺好默认 16x16 TileMap 模板。
2. 为每种房间宽度/高度拆出独立可预览房间壳子场景，减少 `RoomShell.apply_layout()` 的尺寸改写。
3. 为建造槽拆出独立可预览施工壳子场景，减少 `BuildSlotShell.apply_layout()` 的尺寸改写。
4. 将服务核心、房间、建造槽的 TileMap 模板按楼层配置选择或实例化，不运行时改 TileMap 位置和缩放。模板选择优先通过 `.tscn` 导出属性和 `rooms.json` / `floors.json` 完成。
5. 完成后删除建筑脚本中仅用于主体视觉尺寸修补的过渡逻辑，只保留数据绑定、点击状态和子场景实例化。

## 验收标准

- 打开公寓相关 `.tscn` 时，不运行游戏也能看到房间墙体、地面、屋檐和施工层效果。
- 静态扫描中，建筑脚本只剩配置数据绑定、相机位置、家具/租客/摆放预览等运行时数据渲染。
- 主场景 360x640 逻辑视口和 720x1280 桌面预览下，公寓、背景、UI 比例一致。
