# 公寓 TileMap 迁移计划

本文件记录公寓主体从旧像素尺寸/脚本拼装过渡到统一 16px 格子房间骨架的当前边界。

## 当前边界

- `Room.tscn`、`BuildSlot.tscn`、`Floor.tscn` 保留交互按钮和运行时数据绑定。
- `ApartmentTileMap.tscn` 与 `ServiceCoreTileMap.tscn` 已作为共享 TileMap 子场景存在。
- `ApartmentBuilding.tscn`、`Floor.tscn`、`Room.tscn` 已通过导出属性指定楼层、建造槽、房间、家具和租客子场景模板，脚本只按数据实例化这些编辑器可打开的模板。
- `floors.json` 可通过 `floor_scene_path` / `build_slot_scene_path` 选择楼层和施工槽模板；`rooms.json` 可通过 `room_scene_path` 选择房间模板。
- `rooms.json.frame_tiles` 是房间外框尺寸唯一标准，默认 `[8, 4]`，包含墙体；每格固定 16px，所以默认房间像素尺寸为 `128 x 64`。
- 房间高度固定为 4 格；后续扩建房间只增加宽度，例如 `[10, 4]`。
- `rooms.json.grid_size` 对应室内摆放网格，默认 `[6, 3]`，同样保持固定高度，扩建只增加列数。
- 家具、租客、摆放预览仍作为子场景挂到房间可视层。
- `ApartmentTileMap.gd` 是唯一允许调用 `set_cell` 动态生成房间骨架的建筑脚本；`Room.gd`、`Floor.gd`、`BuildSlot.gd`、`ApartmentBuilding.gd` 只传递 `frame_tiles` 和显隐状态。
- 图块坐标不在业务脚本中猜测。`ApartmentTileMap.gd` 已导出具体 Inspector 字段，由编辑器填：
  - `wallpaper_tile`、`wallpaper_tiles`
  - 主题墙体：`body_top_left_corner_tile`、`body_top_edge_tiles`、`body_top_right_corner_tile`
  - 主题墙体：`body_left_edge_tiles`、`body_right_edge_tiles`
  - 主题墙体：`body_bottom_left_corner_tile`、`body_bottom_edge_tiles`、`body_bottom_right_corner_tile`
  - 固定墙边：`edge_top_left_corner_tile`、`edge_top_edge_tiles`、`edge_top_right_corner_tile`
  - 固定墙边：`edge_left_edge_tiles`、`edge_right_edge_tiles`
  - 固定墙边：`edge_bottom_left_corner_tile`、`edge_bottom_edge_tiles`、`edge_bottom_right_corner_tile`
  - 门口短墙：`body_door_cutout_cells`、`body_door_short_wall_cells`、`body_door_short_wall_tiles`
  - 门口短墙：`edge_door_cutout_cells`、`edge_door_short_wall_cells`、`edge_door_short_wall_tiles`
  - `door_tile`、`roof_left_tile`、`roof_tiles`、`roof_right_tile`
  - `construction_marker_tile`

## 目标状态

- 房间骨架由壁纸、主题墙体、固定墙边、门和窗构成；不再使用单独 floor 层。壁纸按房间格子铺满，默认可只配置一个壁纸图块。
- `ApartmentTileMap.tscn` 中手动平铺的示例是默认图块模板来源：`WallpaperTileMap` 填满房间主体，`WallTileMap` 铺房间四周墙体，`InfrastructureTileMap` 铺外扩一格的黑色墙边、左侧门和右侧窗。运行时渲染会先读取这套模板，再按 `frame_tiles` 生成 8x4 或加宽后的房间骨架。
- 房间墙体、墙边、屋檐、服务核心由 `ApartmentTileMap.gd` 基于 `frame_tiles` 渲染到 `TileMapLayer`；施工状态使用 `ConstructionTileMap` 表达 16x16 边条/提示块，并用场景内静态 `ConstructionCover` 贴图覆盖大块施工布。
- `TileMapLayer` 使用共享 `res://tilesets/apartment_tileset.tres`，不在运行时创建 TileSet。
- 旧的 `room_size` / `grid_rect` 像素字段已废弃；配置和运行时状态只保留 `frame_tiles` / `grid_size`。
- Terrain 只用于编辑器中快速铺参考模板，不参与运行时房间生成。

## 下一步

1. 在 Godot 编辑器确认 `apartment_tileset.tres` 的 `RoomFrame`、`WallpaperFill` terrain 可见，可作为手工参考模板使用。
2. 后续换主题时，优先在 `ApartmentTileMap.tscn` 手动重铺模板或在 Inspector 中填充正确图块坐标；不要在 `Room.gd` / `BuildSlot.gd` 中从素材 region 推算 tile 位置。
3. 为建造槽继续保留场景内 `ConstructionCover` 覆盖层，施工布不进入 terrain。
4. 保持业务脚本不调用 TileMap `set_cell`，只通过 `ApartmentTileMap.render_room_skeleton()` 传入格子尺寸和状态。

## 验收标准

- 运行 `ApartmentTileMap.tscn` 可看到默认 8x4 房间骨架。
- 静态扫描中，只有 `ApartmentTileMap.gd` 允许调用 `set_cell` 绘制房间骨架。
- 运行时房间尺寸统一来自 `frame_tiles * 16px`，默认 8x4 = 128x64，扩建 10x4 = 160x64。
- 主场景 360x640 逻辑视口和 720x1280 桌面预览下，公寓、背景、UI 比例一致。
