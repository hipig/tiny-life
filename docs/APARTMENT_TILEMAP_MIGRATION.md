# 公寓 TileMap 迁移计划

本文件记录公寓主体从旧像素尺寸/脚本拼装过渡到统一 16px 格子房间骨架的当前边界。

## 当前边界

- `Room.tscn`、`BuildSlot.tscn`、`Floor.tscn` 保留交互按钮和运行时数据绑定。
- `ApartmentTileMap.tscn` 与 `ServiceCoreTileMap.tscn` 已作为共享 TileMap 子场景存在。
- `ApartmentBuilding.tscn` 已预摆 `Floor_X`；`Floor.tscn` 已预摆左右房间、左右待建房间槽、左右公共区和中央服务核心；`Room.tscn` 保留房间 shell、家具层、租客层和模板文本。
- `floors.json` / `rooms.json` 只绑定配置 ID、尺寸、门朝向、解锁条件和默认装饰 ID，不再选择运行时场景模板。
- `rooms.json.frame_tiles` 是房间外框尺寸唯一标准，默认 `[6, 4]`，包含墙体；每格固定 16px，所以默认房间像素尺寸为 `96 x 64`。
- 房间高度固定为 4 格；后续扩建房间只增加宽度，例如 `[8, 4]`。
- `rooms.json.grid_size` 对应剖面房间摆放格，默认 `[6, 4]`，每格固定 `16px x 16px`；地面家具按自身高度吸附到最下面的地面线，墙面摆放层由上方墙面格派生为 `[columns, rows - 1]`，不写入配置。
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
  - `door_cell_from_left`、`door_cell_from_bottom`
  - 公寓级屋顶：`roof_left_tile`、`roof_tiles`、`roof_right_tile`、`total_width_tiles`、`offset_pixels`
  - `construction_marker_tile`

## 目标状态

- 房间骨架由壁纸、主题墙体、固定墙边、门和窗构成；不再使用单独 floor 层。壁纸按房间格子铺满，默认可只配置一个壁纸图块。
- `ApartmentTileMap.tscn` 不保存样例 `tile_map_data`。图层、TileSet、Inspector 坐标和静态覆盖层用于编辑器预览；运行时只按显式坐标和 `frame_tiles` 刷新需要变化的 TileMapLayer。
- 房间墙体、墙边、屋檐、服务核心由 `ApartmentTileMap.gd` 基于 `frame_tiles` 渲染到 `TileMapLayer`；施工状态使用 `ConstructionTileMap` 表达 16x16 边条/提示块，并用场景内静态 `ConstructionCover` 贴图覆盖大块施工布。
- `TileMapLayer` 使用共享 `res://tilesets/apartment_tileset.tres`，不在运行时创建 TileSet。
- 旧的 `room_size` / `grid_rect` 像素字段已废弃；配置和运行时状态只保留 `frame_tiles` / `grid_size`。
- Terrain 只用于编辑器中快速铺参考模板，不参与运行时房间生成。

## 下一步

1. 在 Godot 编辑器确认 `apartment_tileset.tres` 的 `RoomFrame`、`WallpaperFill` terrain 可见，可作为手工参考模板使用。
2. 后续换主题时，优先在 `room_decor.json` 的主题字段或 `ApartmentTileMap.tscn` Inspector 中填充正确图块坐标；不要在 `Room.gd` / `BuildSlot.gd` 中从素材 region 推算 tile 位置。
3. 为建造槽继续保留场景内 `ConstructionCover` 覆盖层，施工布不进入 terrain。
4. 保持业务脚本不调用 TileMap `set_cell`，只通过 `ApartmentTileMap.render_room_skeleton()` 传入格子尺寸和状态。

## 验收标准

- 打开 `ApartmentBuilding.tscn`、`Floor.tscn`、`Room.tscn`、`ApartmentTileMap.tscn` 可直接看到核心结构和代表性样式。
- 静态扫描中，只有 `ApartmentTileMap.gd` 允许调用 `set_cell` 绘制房间骨架。
- 运行时房间尺寸统一来自 `frame_tiles * 16px`，默认 6x4 = 96x64，扩建 8x4 = 128x64。
- 主场景 360x640 逻辑视口和 720x1280 桌面预览下，公寓、背景、UI 比例一致。
