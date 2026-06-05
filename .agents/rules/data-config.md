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
- UI 文案。
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
data/platform_config.json
```

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
unlocked
level
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
```

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

即使 MVP 只做中文，UI 文案也应通过 `ui_text.json` 使用 key 管理。

配置中优先使用文案 key，避免后续本地化时重写玩法逻辑。

## 资源配置

资源配置可以描述：

- 单张 Sprite。
- 图集区域。
- Spritesheet 帧。
- TileSet。

使用 `AssetResolver` 应用资源配置。玩法组件不要重复实现资源解析逻辑。

