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
- 建造楼层后。
- 完成任务后。
- 应用暂停/退出时。

同时支持约每 60 秒一次的自动存档。

存档数据至少包含：

```text
coins
total_rent_per_minute
apartment_level
apartment_exp
highest_built_floor
rooms
tenants
tasks
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
furniture_placed(room_id, furniture_id)
furniture_moved(room_id, furniture_id)
furniture_recycled(room_id, furniture_id)
tenant_recruited(tenant_id, room_id)
tenant_satisfaction_changed(tenant_id, value)
tenant_behavior_observed(tenant_id, behavior)
floor_built(floor_index)
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

禁止在 UI 脚本中用 `Button.new()`、`Label.new()`、`PanelContainer.new()`、`HBoxContainer.new()`、`VBoxContainer.new()` 等方式临时拼 UI 骨架。也不要在脚本中创建固定 `StyleBox`、固定字号、固定颜色、固定描边、固定 anchors、固定 offsets、固定 `custom_minimum_size` 等可在 Inspector 配置的布局和视觉样式。缺少必要 UI 节点时应报错并修正 `.tscn`，不要在脚本中兜底补建。

节点较多的界面必须拆分独立子场景，例如列表行、统计卡、操作按钮、页签按钮、复杂弹窗内容块。动态内容只能通过这些可在编辑器打开的子场景模板渲染。

公寓主体应优先使用 TileMap/TileMapLayer 结构实现。房间格子、墙面、地面、楼层外壳、屋檐和可建造状态尽量使用可编辑 TileMap 或拆分子场景表达，避免脚本运行时绘制不可预览的主体结构。

## 性能规则

- 可见楼层正常更新。
- 不可见楼层降低租客 AI 更新频率。
- 远景缩放时降低气泡和细节刷新频率。
- 离屏租客不运行完整行为动画，只计算收益和必要状态。
- 家具默认应是 `Sprite2D` 加轻量互动状态。
- 避免每个家具实例都运行 `_process`。
- 状态变化优先事件驱动。
- UI 面板尽量复用。
- 不要每帧重建商店、任务等列表。
- 顶部金币增长提示必须合并显示，不能每秒刷一个飘字。

## 安全区与分辨率

设计基准：

```text
720 x 1280
```

同时考虑：

```text
1080 x 1920
1440 x 2560
```

顶部状态栏和右侧悬浮菜单必须根据 `PlatformManager.get_safe_area()` 适配安全区。
