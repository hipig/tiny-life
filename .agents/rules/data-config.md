# 数据与配置规则

## 配置优先

不要把玩法内容硬编码在业务逻辑中。

以下内容必须来自配置：

- 家具价格。
- 家具属性。
- 家具回收比例。
- 家具标签和互动数据。
- 楼层价格和等级要求。
- 租客支付倍率。
- 租客偏好。
- 任务奖励和目标。
- 经济常量。
- 公寓等级要求。
- 玩法配置文案和可复用本地化文案。
- 平台配置。

预期数据文件：

```text
data/furniture.json
data/tenants.json
data/rooms.json
data/floors.json
data/tasks.json
data/economy.json
data/apartment_levels.json
data/ui_text.json
data/behavior_aliases.json
data/tenant_regions.json
data/room_decor.json
data/platform_config.json
```

配置采用严格 schema：缺文件、缺 key、类型不符、ID 重复、引用不存在或行为别名无法归一时，启动阶段必须报错。业务代码不得为价格、文案、资源、场景路径、租客区域、房间装饰或经济常量提供 fallback。

## 家具数据

每个家具配置应包含：

```text
id
name 或 text_key
category
price
refund_rate
size
comfort
entertainment
hygiene
food
tags
interactive
requires_wall
wall_item
asset
interaction
```

家具评分 MVP 可先使用：

```text
comfort + entertainment + hygiene + food
```

家具互动应描述：

- 需求类型。
- 气泡/图标。
- 持续时间。
- 视觉反馈。
- 满意度变化。

## 房间数据

房间运行时/存档数据应包含：

```text
id
floor_index
room_name
layout_side
door_side
door_mirrored
door_visual_offset
unlocked
level
frame_tiles
grid_size
wallpaper_id
wall_style_id
door_style_id
tenant_id
furniture_instances
score
comfort
entertainment
hygiene
food
rent_per_minute
```

家具实例应包含：

```text
instance_id
furniture_id
grid_pos
mirrored
```

楼层配置必须包含：

```text
floor_index
display_name
visual_role
initial_built
required_apartment_level
build_cost
service_label
public_areas
floor_icon_asset
build_icon_asset
```

核心公寓结构采用 scene-first：`ApartmentBuilding/Floor/Room/BuildSlot/PublicAreaShell` 由 `.tscn` 预摆节点定义结构，配置只绑定 ID、尺寸、门朝向、解锁和装饰数据。`rooms.json`、`floors.json` 和 `public_areas` 不允许使用 `*_scene_path` 字段选择运行时模板。

## 房间装饰数据

`room_decor.json` 保留为当前有效配置。每个装饰项必须声明：

```text
id
category
name
price
preview_asset
theme 或 door_asset
```

装饰分类固定为 `wallpaper`、`wall`、`door`。房间默认装饰 ID 必须引用对应分类；RoomPanel 的装饰页签只渲染配置中存在的分类和条目，不提供默认文案、默认资源或默认价格。

## 租客数据

每个租客配置应包含：

```text
id
name 或 text_key
job
personality
rarity
pay_multiplier
initial_satisfaction
favorite_tags
asset
```

租客运行时数据应追踪：

```text
satisfaction
current_need
current_behavior
room_id
presence_state
away_until_timestamp
presence_target_room_id
```

`tenant_regions.json` 保留为当前有效配置。每个区域必须声明：

```text
id
name
required_apartment_level
rent_tolerance_level
max_rent_per_minute
tenant_ids
application_count
```

租客招募区域、候选租客、候选数量、租金上限和展示文案必须来自该配置和场景模板文本；TenantPanel 不提供默认区域、默认候选数量或默认文案 fallback。

PRD 中的 MVP 租客：

- 小林：学生，容易满足，喜欢床/书桌/书架，支付倍率 1.0。
- 阿哲：宅家玩家，娱乐需求高，喜欢电视/游戏机/沙发，支付倍率 1.15。
- 米娜：白领，收入稳定，喜欢电脑桌/咖啡/灯，支付倍率 1.2。
- 阿禾：文艺青年，喜欢装饰、植物、画、书架，支付倍率 1.25。
- 奶奶：退休老人，满意度高，喜欢沙发/植物/灯，支付倍率 0.9。

## 经济规则

自动收益：

```text
每秒金币 = 总租金 / 60
```

推荐 MVP 房间租金公式：

```text
(基础租金 + 房间评分 * 0.5) * 租客支付倍率 * 满意度倍率
```

空房间不产生租金。

满意度倍率：

```text
0-30: 0.7
31-60: 1.0
61-80: 1.15
81-100: 1.3
```

离线收益：

```text
总租金 / 60 * 离线秒数
```

MVP 离线收益上限：

```text
4 小时
```

## 任务

任务配置至少支持：

- 摆放家具任务。
- 招募租客任务。
- 租金目标任务。
- 公寓等级任务。
- 建造楼层任务。
- 观察租客行为任务。

任务完成后应发放配置中的金币和公寓经验奖励。

## 本地化

即使 MVP 只做中文，也要预留本地化边界，但必须服从编辑器所见即所得的 UI 工作流。

- 固定 UI 结构、默认按钮文案、面板标题、空状态、说明行和可调显示模板优先写在对应 `.tscn` 或场景导出属性中，方便直接在 Godot 编辑器中预览和调整。
- 玩法配置里的名称、描述、任务文本、租客/家具文本等仍可使用 `text_key` 或 `ui_text.json`，避免后续本地化时重写玩法逻辑。
- GDScript 不应硬编码固定中文 UI 文案；需要动态格式化时，把模板导出到场景或放入配置，脚本只填运行时数据。

## 资源配置

资源配置可以描述：

- 单张 Sprite。
- 图集区域。
- Spritesheet 帧。
- TileSet。

使用 `AssetResolver` 应用资源配置。玩法组件不要重复实现资源解析逻辑，也不要生成占位颜色、占位纹理或临时资源来掩盖缺失配置。
