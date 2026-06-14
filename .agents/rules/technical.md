# 技术规则

## 引擎与语言

- 使用 Godot 4.x。
- 使用 GDScript。
- 不引入 C#。
- 保留后续适配 Android、Web、微信小游戏、抖音小游戏、TapTap、iOS 的可能性。

## 架构原则

遵循 TRD 中的技术原则：

- 内容配置表驱动。
- 平台能力抽象。
- 资源加载抽象。
- UI 状态机管理。
- 场景交互优先。
- 业务逻辑与平台 SDK 解耦。
- MVP 内容可以少，但框架应按可发行版本搭建。

## Autoload Manager

预期 Autoload 脚本：

```text
GameState.gd
GameEvents.gd
ConfigManager.gd
AssetResolver.gd
SaveManager.gd
PlatformManager.gd
AdManager.gd
EconomyManager.gd
TimeManager.gd
TaskManager.gd
UIManager.gd
```

Manager 职责必须清晰：

- `GameState`：权威运行时状态和存档状态。
- `GameEvents`：跨系统信号。
- `ConfigManager`：加载和查询 JSON 配置。
- `AssetResolver`：应用单图、图集区域、帧图、TileSet 等资源配置。
- `SaveManager`：通过 `PlatformManager` 完成序列化和反序列化。
- `PlatformManager`：安全区、存档、广告、埋点、震动、分享、平台名。
- `AdManager`：业务侧唯一广告入口。
- `EconomyManager`：房间租金、总租金、自动收益、离线收益。
- `TaskManager`：任务进度和奖励。
- `UIManager`：UI 状态、面板切换、点击冲突处理。

## 平台抽象

玩法代码禁止直接调用平台 SDK。

使用以下抽象：

```text
PlatformManager
BasePlatformProvider
AndroidPlatformProvider
TapTapPlatformProvider
WebPlatformProvider
WeChatMiniGameProvider
DouyinMiniGameProvider
```

MVP 可以先使用 Mock Provider，但 Provider 接口应保持稳定。

## 存档规则

玩法代码必须调用 `SaveManager`，不得直接调用本地文件 API。

以下时机必须存档：

- 家具摆放后。
- 家具移动后。
- 家具回收后。
- 招募租客后。
- 建造房间后。
- 应用房间、公区、服务核心或屋顶装修后。
- 完成任务后。
- 应用暂停/退出时。

同时支持约每 60 秒一次的自动存档。

存档数据至少包含：

```text
coins
total_rent_per_minute
apartment_level
apartment_exp
rooms
public_area_decor
apartment_decor
tenants
tasks
stats
last_save_timestamp
```

## 事件与信号

跨系统通知使用 `GameEvents`。

预期信号包括：

```text
coins_changed(value)
coin_gain_batched(amount)
rent_changed(value)
apartment_level_changed(level)
room_updated(room_id)
decor_target_changed(kind, target_id, decor_id, category)
furniture_placed(room_id, furniture_id)
furniture_moved(room_id, furniture_id)
furniture_recycled(room_id, furniture_id)
tenant_recruited(tenant_id, room_id)
tenant_satisfaction_changed(tenant_id, value)
tenant_behavior_observed(tenant_id, behavior)
room_built(room_id, floor_index)
task_updated(task_id)
task_completed(task_id)
```

## 场景与脚本位置

遵循 TRD 目录结构：

```text
scenes/main/Main.tscn
scenes/ui/
scenes/building/
scenes/furniture/
scenes/tenant/
scenes/effects/
scripts/autoload/
scripts/platform/
scripts/camera/
scripts/building/
scripts/furniture/
scripts/tenant/
scripts/ui/
data/
assets/pixel_spaces/
```

不要把玩法脚本散落在仓库根目录。

## 编辑器所见即所得

UI 层必须在 `.tscn` 中搭建可预览的节点结构、布局、按钮、卡片、空状态、页签、列表容器和固定视觉样式，目标是编辑器所见即所得。

GDScript 在 UI 中只负责：

- 绑定运行时数据到已经存在的场景节点。
- 切换节点可见性、状态、禁用态和选中态。
- 连接信号。
- 实例化已经拆分好的子条目场景，例如列表行、卡片模板、弹窗场景。

禁止在 UI 脚本中用 `Button.new()`、`Label.new()`、`PanelContainer.new()`、`HBoxContainer.new()`、`VBoxContainer.new()` 等方式临时拼 UI 骨架。这里的 UI 脚本特指 UI / presentation 脚本。也不要在 UI / presentation 脚本中创建固定 `StyleBox`、固定字号、固定颜色、固定描边、固定 anchors、固定 offsets、固定 `custom_minimum_size` 等可在 Inspector 配置的布局和视觉样式。缺少必要 UI 节点时应报错并修正 `.tscn`，不要在脚本中兜底补建。`Tenant.gd` 这类角色表现脚本允许处理碰撞、动画、朝向、位置和运行时空间关系，不适用 UI 固定布局规则。

节点较多的界面必须拆分独立子场景，例如列表行、统计卡、操作按钮、页签按钮、复杂弹窗内容块。动态内容只能通过这些可在编辑器打开的子场景模板渲染。房间装修和公寓层级装修共享的 `DecorCatalogContent`、独立 `SpaceDecorPanel` 和装修条目行都必须保持 scene-first。

公寓主体应优先使用 TileMap/TileMapLayer 结构实现。核心公寓与核心 UI 采用 scene-first / WYSIWYG authoring：`ApartmentBuilding/Floor/Room/BuildSlot/PublicAreaShell/FloorServiceCore/ApartmentRoof` 的节点树、容器、服务核心、左右房间、公共区、覆盖层、点击热区和模板文本必须预先存在于 `.tscn` 中。脚本只绑定配置 ID、刷新显隐/状态/文本、实例化家具、租客、飘字等天然运行时对象；禁止运行时清空后重建核心楼层、房间、建造槽或面板骨架。

配置缺失即错误。`ConfigManager` 和 `AssetResolver` 不提供业务 fallback，不生成占位颜色、占位纹理或默认 scene path。存档只接受当前 schema；配置 ID 或结构失效时重置到当前默认状态并给出明确错误。

## 公寓骨架约束

- 房间和公共区骨架统一按 16px TileMap 格子生成；基础房间为 `6 x 4`，内部摆放网格等于 `frame_tiles`。
- 中央电梯厅固定 3 格宽，高度跟随楼层；电梯厅与左右房间共用墙体，电梯厅自身不绘制左右墙体。
- 标准出租楼层按“左侧 01 房 / 中央电梯厅 / 右侧 02 房”组装；后续套房结构只能通过 `layout_side = "suite"` 走显式代码路径，电梯仍居中。
- 1F 入口门属于左侧大厅公共区的左外墙，不属于中央电梯厅或前台服务核心；一楼不配置出租房间。
- 所有门所在墙体必须按“对应上角 + 竖向长边 + 门洞短边 + 独立门场景 + 下边”的结构组织。左墙门使用左上角，右墙门使用右上角。
- 01 房在右墙开门且不镜像；02 房在左墙开门且镜像。门已外开，家具摆放不得再剔除门口格；租客室内移动只使用房间地面线连续坐标，不配置可站区、巡逻点或互动点；家具摆放、重叠和租客使用位置必须使用实例当前 `orientation` 对应的 `footprint` 派生运行时矩形。
- 房间是建造状态权威：`rooms[id].unlocked` 表示该房间已建成；`floors.json` 不保存房间建造价格或等级门槛。
- 待建房间槽必须与同侧建成房间同宽同高，且放在 `Floor.tscn` 的左/右房间位中；待建房间所在楼层仍必须显示中央电梯厅和电梯门。
- 整栋公寓只允许一个独立屋顶，由 `ApartmentBuilding.tscn` 的 `ApartmentRoof` 节点渲染；房间、待建槽和电梯厅不得各自绘制屋顶。
- 公寓屋顶布局配置来自 `apartment_visuals.json`，必须支持 `default_roof_style_id`、`total_width_tiles` 和 `offset_pixels`；实际屋顶主题通过运行态 `apartment_decor` 选择 `room_decor.json` 中的 `roof` 分类条目解析。屋顶锚定最高可见楼层上方，可按配置比公寓主体左右各宽一个格子并调整 Y 方向位置。
- 公共区、服务核心/电梯厅和屋顶都是可点击装修目标。服务核心装修为整栋共享；公共区目标 ID 使用 `<floor_index>:<area_id>`；屋顶目标为整栋共享。
- 电梯门本体本期不纳入可换装范围，只保留原表现。
- `ApartmentBuilding.tscn` 必须预摆所有当前配置楼层的 `Floor_X` 节点；`Floor.tscn` 必须预摆 `LeftRoom`、`RightRoom`、`LeftBuildSlot`、`RightBuildSlot`、`LeftPublicArea`、`RightPublicArea` 和 `FloorServiceCore`。

## 像素视口基线

项目逻辑视口为 `360 x 640`，桌面预览覆盖为 `720 x 1280`。拉伸模式使用 `viewport`、`keep_width`、`integer`，并启用 Control 像素吸附，保证像素美术按整数倍放大。

## 性能规则

- 可见楼层正常更新。
- 不可见楼层降低租客 AI 更新频率。
- 远景缩放时降低气泡和细节刷新频率。
- 离屏租客不运行完整行为动画，只计算收益和必要状态。
- 家具默认应是 `Sprite2D` 加轻量互动状态。
- 家具转向只允许配置声明的地面家具，运行时仅做素材/尺寸/旋转等空间变换；墙面家具保持固定朝向。
- 避免每个家具实例都运行 `_process`。
- 状态变化优先事件驱动。
- UI 面板尽量复用。
- 不要每帧重建商店、任务等列表。
- 顶部金币增长提示必须合并显示，不能每秒刷一个飘字。

## 安全区与分辨率

设计基准：

```text
360 x 640 logical viewport
720 x 1280 desktop preview
```

同时考虑：

```text
1080 x 1920
1440 x 2560
```

顶部状态栏和右侧悬浮菜单必须根据 `PlatformManager.get_safe_area()` 适配安全区。
