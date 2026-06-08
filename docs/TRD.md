# 1. 技术总目标

## 1.1 引擎

```text
Godot 4.x
```

## 1.2 语言

```text
GDScript
```

不使用 C#，方便后续 Web / 小游戏平台适配。

---

## 1.3 技术原则

```text
内容配置表驱动
平台能力抽象
资源加载抽象
UI 状态机管理
场景交互优先
业务逻辑与平台 SDK 解耦
MVP 内容少，但框架按可发行版本搭建
```

---

# 2. 工程目录结构

```text
res://
  scenes/
    main/
      Main.tscn

    ui/
      TopStatusBar.tscn
      FloatingMenu.tscn
      RoomPanel.tscn
      FurnitureShopPanel.tscn
      TenantPanel.tscn
      TaskPanel.tscn
      RewardPanel.tscn
      SettingsPanel.tscn
      ApartmentOverviewPanel.tscn
      IncomeDetailPanel.tscn
      RentDetailPanel.tscn
      BuildConfirmPopup.tscn
      PlacementOverlay.tscn
      PopupLayer.tscn

    building/
      BuildingView.tscn
      Floor.tscn
      Room.tscn
      BuildSlot.tscn

    furniture/
      Furniture.tscn
      FurniturePreview.tscn
      FurnitureFloatingControls.tscn

    tenant/
      Tenant.tscn
      NeedBubble.tscn
      TenantEmote.tscn

    effects/
      FloatingCoinText.tscn
      FloatingIcon.tscn
      HighlightOverlay.tscn

  scripts/
    autoload/
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

    platform/
      BasePlatformProvider.gd
      AndroidPlatformProvider.gd
      TapTapPlatformProvider.gd
      WebPlatformProvider.gd
      WeChatMiniGameProvider.gd
      DouyinMiniGameProvider.gd

    camera/
      CameraController.gd

    building/
      BuildingManager.gd
      Floor.gd
      Room.gd
      BuildSlot.gd
      PlacementGrid.gd

    furniture/
      Furniture.gd
      FurniturePreview.gd
      FurniturePlacementManager.gd
      FurnitureVisualFeedback.gd

    tenant/
      Tenant.gd
      TenantAI.gd
      NeedsComponent.gd
      BehaviorComponent.gd

    ui/
      TopStatusBar.gd
      FloatingMenu.gd
      RoomPanel.gd
      FurnitureShopPanel.gd
      TenantPanel.gd
      TaskPanel.gd
      RewardPanel.gd
      ApartmentOverviewPanel.gd
      PlacementOverlay.gd

  data/
    furniture.json
    tenants.json
    rooms.json
    floors.json
    tasks.json
    economy.json
    apartment_levels.json
    ui_text.json
    behavior_aliases.json
    platform_config.json

  assets/
    pixel_spaces/
      furniture/
      npc/
      building/
      tileset/
      ui/
      icons/
      effects/
```

---

# 3. 主场景结构

## 3.1 Main.tscn

```text
Main
├── BuildingView
│   ├── Camera2D
│   └── BuildingRoot
│       ├── Floor_1
│       ├── Floor_2
│       ├── Floor_3
│       └── BuildSlot_Next
│
├── CanvasLayer_UI
│   ├── TopStatusBar
│   ├── FloatingMenu
│   ├── PlacementOverlay
│   └── PopupLayer
│
└── Managers
```

---

## 3.2 UI 层说明

```text
TopStatusBar：顶部公寓等级 / 金币 / 租金
FloatingMenu：右侧任务 / 福利 / 设置
PlacementOverlay：摆放状态提示层
PopupLayer：所有弹窗统一入口
```

## 3.3 UI 编辑器工作流

UI 层以编辑器所见即所得为准。

所有 UI 面板、页签、按钮、卡片、空状态、列表容器、固定布局和固定视觉样式都必须直接配置在 `.tscn` 中。GDScript 只负责：

```text
绑定数据到场景中已经存在的节点
切换可见性、选中态、禁用态
连接信号
实例化已经拆分好的子条目场景
```

禁止在 UI 脚本中用 `Button.new()`、`Label.new()`、`PanelContainer.new()`、`HBoxContainer.new()`、`VBoxContainer.new()` 等方式临时拼 UI 骨架，也禁止把固定 `StyleBox`、固定字号、固定颜色、固定描边、固定 anchors、固定 offsets、固定 `custom_minimum_size` 等 Inspector 可配置布局和视觉样式藏在脚本里。

动态列表允许按数据实例化独立子条目场景，例如：

```text
StatCard.tscn
IconInfoRow.tscn
IconActionRow.tscn
PanelActionButton.tscn
FurnitureShopItemRow.tscn
RoomFurnitureItemRow.tscn
TaskItemRow.tscn
```

节点过多的界面必须继续拆分为独立子场景，保证编辑器中能直接预览布局和视觉层级。

---

# 4. UI 状态机

## 4.1 UIState

```gdscript
enum UIState {
    NORMAL,
    ROOM_PANEL,
    FURNITURE_SHOP,
    PLACING_NEW_FURNITURE,
    MOVING_EXISTING_FURNITURE,
    TENANT_PANEL,
    BUILD_CONFIRM,
    TASK_PANEL,
    APARTMENT_OVERVIEW,
    INCOME_DETAIL,
    RENT_DETAIL,
    REWARD_PANEL,
    SETTINGS_PANEL,
    POPUP
}
```

---

## 4.2 UIManager 职责

```text
管理当前 UI 状态
控制面板打开关闭
防止点击冲突
控制摆放状态下的输入规则
控制普通状态下点击房间 / 小人 / 楼层
```

---

## 4.3 状态规则

### NORMAL

允许：

```text
点击房间
点击小人
长按家具
点击可施工楼层
拖动 / 缩放相机
```

### ROOM_PANEL

允许：

```text
切换房间 UI Tab
打开家具商店
打开租客招募
点击其他房间切换目标房间，可选
```

### FURNITURE_SHOP

允许：

```text
选择家具
关闭商店
```

### PLACING_NEW_FURNITURE

允许：

```text
拖动家具预览
缩放 / 平移视图，可选
确认摆放
取消摆放
```

禁止：

```text
打开房间 UI
点击小人
点击建造
长按其他家具
```

### MOVING_EXISTING_FURNITURE

允许：

```text
拖动当前家具
确认位置
取消移动
回收家具
```

---

# 5. 顶部状态栏技术设计

## 5.1 TopStatusBar.tscn

```text
TopStatusBar
├── ApartmentLevelButton
├── CoinDisplay
├── RentDisplay
└── CoinGainPopupAnchor
```

---

## 5.2 TopStatusBar.gd

监听信号：

```gdscript
coins_changed
rent_changed
apartment_level_changed
coin_gain_batched
```

点击事件：

```gdscript
func _on_apartment_level_pressed():
    UIManager.open_apartment_overview()

func _on_coin_pressed():
    UIManager.open_income_detail()

func _on_rent_pressed():
    UIManager.open_rent_detail()
```

---

## 5.3 +金币提示合并

不要每秒显示 +金币。

EconomyManager 或 TopStatusBar 内做合并：

```gdscript
var pending_coin_popup_amount := 0
var coin_popup_interval := 6.0
```

逻辑：

```gdscript
func add_coin_popup_amount(amount: int):
    pending_coin_popup_amount += amount

func flush_coin_popup():
    if pending_coin_popup_amount > 0:
        show_floating_coin_text(pending_coin_popup_amount)
        pending_coin_popup_amount = 0
```

---

# 6. 公寓视图技术设计

## 6.1 BuildingView.tscn

```text
BuildingView
├── Camera2D
├── BuildingRoot
└── InputArea
```

公寓主体应改为 TileMap / TileMapLayer 优先的可编辑结构。楼层外壳、房间格子、墙面、地面、屋檐和施工层表现应尽量由 `.tscn` 中的 TileMapLayer 或拆分子场景承载，脚本只绑定配置数据、切换状态和实例化子场景，不运行时绘制不可预览的主体结构。

详细迁移边界与验收标准见 `docs/APARTMENT_TILEMAP_MIGRATION.md`。

迁移顺序：

```text
1. 新增 res://tilesets/apartment_tileset.tres，统一引用公寓墙体、地板、屋檐、施工层、门梯等 16x16 素材。
2. 新建 ApartmentTileMap.tscn，至少包含 WallpaperTileMap、WallTileMap、InfrastructureTileMap、RoofTileMap、ConstructionTileMap。
3. Room.tscn / Floor.tscn 保留交互按钮和租客/家具挂点，但房间墙体、地板、骨架、屋檐改由 TileMapLayer 编辑器手动铺设。
4. 建造槽状态通过切换已铺好的 TileMapLayer/子场景可见性表达，不在脚本中生成色块、框线或施工素材。
5. 房间大小、格子大小、房间数量扩展继续来自 rooms.json / floors.json；脚本只把配置绑定到交互区域、家具网格和租客挂点。
6. 完成迁移后移除 RoomShell / BuildSlotShell 中用于墙面、地面、屋檐和施工表现的 TextureRect/ColorRect 兜底结构；租客、家具、摆放网格保留为数据驱动子场景或交互挂点。
```

---

## 6.2 CameraController.gd

功能：

```text
单指拖动
双指缩放
点击与拖动区分
缩放范围限制
相机边界限制
```

参数：

```gdscript
var min_zoom := 0.6
var max_zoom := 2.2
var drag_threshold := 10.0
```

---

## 6.3 输入识别

需要区分：

```text
点击
长按
拖动
双指缩放
```

长按家具时间建议：

```text
0.45 ~ 0.6 秒
```

---

# 7. 建造系统技术设计

## 7.1 BuildSlot 状态

```gdscript
enum BuildSlotState {
    HIDDEN,
    BUILDABLE,
    COMPLETED
}
```

---

## 7.2 floors.json

```json
[
  {
    "floor_index": 1,
    "initial_built": true,
    "required_apartment_level": 1,
    "build_cost": 0
  },
  {
    "floor_index": 2,
    "initial_built": true,
    "required_apartment_level": 1,
    "build_cost": 0
  },
  {
    "floor_index": 3,
    "initial_built": false,
    "required_apartment_level": 2,
    "build_cost": 500
  },
  {
    "floor_index": 4,
    "initial_built": false,
    "required_apartment_level": 3,
    "build_cost": 1200
  }
]
```

---

## 7.3 BuildSlot.tscn

```text
BuildSlot
├── OutlineSprite
├── ConstructionIcon
├── CostLabel
└── ClickArea
```

---

## 7.4 BuildSlot.gd

```gdscript
func refresh_state():
    if floor_index <= GameState.highest_built_floor:
        set_state(BuildSlotState.COMPLETED)
        return

    if floor_index == GameState.highest_built_floor + 1 \
    and GameState.apartment_level >= required_apartment_level:
        set_state(BuildSlotState.BUILDABLE)
        return

    set_state(BuildSlotState.HIDDEN)
```

点击：

```gdscript
func _on_click_area_pressed():
    if state != BuildSlotState.BUILDABLE:
        return

    UIManager.open_build_confirm(floor_index)
```

---

## 7.5 建造确认

BuildConfirmPopup 显示：

```text
楼层编号
建造价格
当前金币
确认按钮状态
金币不足提示
```

确认逻辑：

```gdscript
func confirm_build(floor_index: int):
    var cost = ConfigManager.get_floor_cost(floor_index)

    if GameState.coins < cost:
        return

    GameState.spend_coins(cost)
    BuildingManager.build_floor(floor_index)
    TaskManager.notify_event("floor_built", {"floor_index": floor_index})
    SaveManager.save_game()
```

---

# 8. 房间系统技术设计

## 8.1 Room.tscn

```text
Room
├── BackgroundLayer
├── WallLayer
├── FloorLayer
├── PlacementGrid
├── FurnitureContainer
├── TenantContainer
├── BubbleContainer
└── ClickArea
```

---

## 8.2 Room.gd

职责：

```text
管理房间数据
管理家具实例
管理租客
计算房间评分
计算房间租金
处理房间空白点击
提供家具摆放网格
```

---

## 8.3 房间点击

```gdscript
func _on_click_area_pressed(event):
    if UIManager.current_state != UIState.NORMAL:
        return

    UIManager.open_room_panel(room_id)
```

---

## 8.4 RoomData

```gdscript
class_name RoomData

var id: String
var floor_index: int
var room_name: String
var unlocked: bool
var level: int
var tenant_id: String
var furniture_instances: Array
var score: int
var comfort: int
var entertainment: int
var hygiene: int
var food: int
var rent_per_minute: float
```

---

## 8.5 房间存档示例

```json
{
  "id": "room_101",
  "floor_index": 1,
  "room_name": "101 房",
  "unlocked": true,
  "level": 1,
  "tenant_id": "tenant_student_01",
  "furniture_instances": [
    {
      "instance_id": "f_0001",
      "furniture_id": "bed_basic",
      "grid_pos": [2, 3],
      "mirrored": false
    }
  ],
  "score": 45,
  "rent_per_minute": 32
}
```

---

# 9. RoomPanel 技术设计

## 9.1 RoomPanel.tscn

```text
RoomPanel
├── Header
│   ├── RoomNameLabel
│   └── CloseButton
├── TabBar
│   ├── OverviewTabButton
│   ├── FurnitureTabButton
│   └── TenantTabButton
├── ContentRoot
│   ├── OverviewContent
│   ├── FurnitureContent
│   └── TenantContent
```

---

## 9.2 RoomPanel 功能

```text
显示房间状态
切换 Tab
添加家具
招募租客
查看租客
```

---

## 9.3 打开家具商店

```gdscript
func _on_add_furniture_pressed():
    UIManager.open_furniture_shop(target_room_id)
```

---

## 9.4 打开租客招募

```gdscript
func _on_recruit_tenant_pressed():
    UIManager.open_tenant_panel_for_recruit(target_room_id)
```

---

# 10. 家具配置与资源系统

## 10.1 furniture.json 示例

```json
[
  {
    "id": "bed_basic",
    "name": "普通床",
    "category": "bed",
    "price": 100,
    "refund_rate": 0.5,
    "size": [2, 3],
    "comfort": 20,
    "entertainment": 0,
    "hygiene": 0,
    "food": 0,
    "tags": ["bed", "simple"],
    "interactive": true,
    "requires_wall": true,
    "wall_item": false,
    "asset": {
      "type": "atlas_region",
      "texture": "res://assets/pixel_spaces/furniture_atlas.png",
      "region": [0, 0, 64, 48]
    },
    "interaction": {
      "need": "energy",
      "bubble": "zzz",
      "duration": 4,
      "visual_effect": "highlight",
      "floating_icon": "zzz",
      "satisfaction_delta": 1
    }
  }
]
```

---

## 10.2 AssetResolver.gd

素材可能是：

```text
单张 sprite
atlas 图集区域
spritesheet 某一帧
tileset
```

AssetResolver 统一处理。

---

## 10.3 AssetResolver 接口

```gdscript
func apply_asset_to_sprite(sprite: Sprite2D, asset_config: Dictionary):
    var type = asset_config.get("type", "single_sprite")

    match type:
        "single_sprite":
            sprite.texture = load(asset_config["texture"])
            sprite.region_enabled = false

        "atlas_region":
            sprite.texture = load(asset_config["texture"])
            sprite.region_enabled = true
            var r = asset_config["region"]
            sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])

        "spritesheet_frame":
            sprite.texture = load(asset_config["texture"])
            sprite.region_enabled = true
            var frame = asset_config["frame"]
            var size = asset_config["frame_size"]
            sprite.region_rect = Rect2(
                frame[0] * size[0],
                frame[1] * size[1],
                size[0],
                size[1]
            )
```

---

# 11. 家具实例系统

## 11.1 Furniture.tscn

```text
Furniture
├── Sprite2D
├── HighlightOverlay
├── InteractionPoints
├── EffectAnchor
└── CollisionArea
```

---

## 11.2 Furniture.gd

属性：

```gdscript
var instance_id: String
var furniture_id: String
var room_id: String
var grid_pos: Vector2i
var data: Dictionary
```

功能：

```text
应用资源
提供互动点
进入使用状态
退出使用状态
响应长按
```

---

## 11.3 长按家具

```gdscript
func _on_long_pressed():
    if UIManager.current_state != UIState.NORMAL:
        return

    FurniturePlacementManager.start_move_existing(self)
```

---

# 12. 家具摆放系统技术设计

## 12.1 FurniturePlacementManager.gd

职责：

```text
新家具摆放
已有家具移动
合法性判断
确认摆放
取消摆放
回收家具
```

---

## 12.2 新家具摆放

```gdscript
func start_new_furniture_placement(furniture_id: String, target_room_id: String):
    UIManager.set_state(UIState.PLACING_NEW_FURNITURE)

    current_mode = "new"
    current_furniture_id = furniture_id
    target_room = BuildingManager.get_room(target_room_id)

    preview = preload("res://scenes/furniture/FurniturePreview.tscn").instantiate()
    target_room.add_child(preview)
    preview.setup(furniture_id)
    preview.position = target_room.get_center_position()

    target_room.show_grid(true)
```

---

## 12.3 确认新家具摆放

```gdscript
func confirm_new_placement():
    if not preview.is_valid:
        return

    var data = ConfigManager.get_furniture_data(current_furniture_id)
    var price = data["price"]

    if GameState.coins < price:
        UIManager.show_toast("金币不足")
        return

    GameState.spend_coins(price)

    target_room.add_furniture_instance(
        current_furniture_id,
        preview.grid_pos,
        false
    )

    target_room.recalculate_stats()
    EconomyManager.recalculate_total_rent()
    TaskManager.notify_event("furniture_placed", {
        "room_id": target_room.id,
        "furniture_id": current_furniture_id
    })

    SaveManager.save_game()
    exit_placement_mode()
```

---

## 12.4 移动已有家具

```gdscript
func start_move_existing(furniture: Furniture):
    UIManager.set_state(UIState.MOVING_EXISTING_FURNITURE)

    current_mode = "move"
    moving_furniture = furniture
    original_grid_pos = furniture.grid_pos
    target_room = BuildingManager.get_room(furniture.room_id)

    target_room.grid.release(furniture)
    furniture.set_as_preview(true)
    target_room.show_grid(true)
```

---

## 12.5 确认移动

```gdscript
func confirm_move():
    if not moving_furniture.preview_valid:
        return

    moving_furniture.grid_pos = moving_furniture.preview_grid_pos
    target_room.grid.occupy(moving_furniture)
    moving_furniture.set_as_preview(false)

    target_room.recalculate_stats()
    SaveManager.save_game()
    exit_placement_mode()
```

---

## 12.6 取消移动

```gdscript
func cancel_move():
    moving_furniture.grid_pos = original_grid_pos
    target_room.grid.occupy(moving_furniture)
    moving_furniture.restore_position()
    moving_furniture.set_as_preview(false)

    exit_placement_mode()
```

---

## 12.7 回收家具

```gdscript
func recycle_furniture(furniture: Furniture):
    var data = ConfigManager.get_furniture_data(furniture.furniture_id)
    var refund = int(data["price"] * data.get("refund_rate", 0.5))

    GameState.add_coins(refund)
    target_room.remove_furniture_instance(furniture.instance_id)
    target_room.recalculate_stats()
    EconomyManager.recalculate_total_rent()

    TaskManager.notify_event("furniture_recycled", {
        "furniture_id": furniture.furniture_id
    })

    SaveManager.save_game()
```

---

# 13. PlacementGrid 技术设计

## 13.1 PlacementGrid.gd

职责：

```text
管理网格大小
管理占用格子
世界坐标转网格坐标
网格坐标转世界坐标
判断家具是否可摆放
```

---

## 13.2 核心函数

```gdscript
func world_to_grid(world_pos: Vector2) -> Vector2i:
    pass

func grid_to_world(grid_pos: Vector2i) -> Vector2:
    pass

func can_place(furniture_data: Dictionary, grid_pos: Vector2i) -> bool:
    pass

func occupy(furniture_instance):
    pass

func release(furniture_instance):
    pass
```

---

## 13.3 can_place 判断

```text
是否超出房间边界
是否与已有家具重叠
是否挡住门
是否符合墙面规则
是否满足靠墙要求
```

---

# 14. FurnitureShopPanel 技术设计

## 14.1 FurnitureShopPanel.tscn

```text
FurnitureShopPanel
├── Header
│   ├── TitleLabel
│   └── CloseButton
├── CategoryTabs
├── FurnitureList
└── FurnitureItemTemplate
```

---

## 14.2 打开参数

```gdscript
func open(target_room_id: String):
    self.target_room_id = target_room_id
    title_label.text = "为 %s 添加家具" % BuildingManager.get_room(target_room_id).room_name
    refresh_list()
```

---

## 14.3 家具条目

每个家具条目显示：

```text
图标
名称
价格
主要属性
摆放按钮
```

金币不足时：

```text
按钮置灰
显示金币不足
```

---

## 14.4 点击摆放

```gdscript
func _on_place_pressed(furniture_id: String):
    var data = ConfigManager.get_furniture_data(furniture_id)

    if GameState.coins < data["price"]:
        UIManager.show_toast("金币不足")
        return

    UIManager.close_furniture_shop()
    FurniturePlacementManager.start_new_furniture_placement(furniture_id, target_room_id)
```

---

# 15. 租客系统技术设计

## 15.1 Tenant.tscn

```text
Tenant
├── AnimatedSprite2D
├── NeedBubble
├── ClickArea
├── TenantAI
└── EffectAnchor
```

---

## 15.2 tenants.json 示例

```json
[
  {
    "id": "tenant_student_01",
    "name": "小林",
    "job": "学生",
    "personality": "勤奋",
    "rarity": "common",
    "pay_multiplier": 1.0,
    "initial_satisfaction": 60,
    "favorite_tags": ["bed", "desk", "bookshelf"],
    "asset": {
      "type": "spritesheet_frame",
      "texture": "res://assets/pixel_spaces/npc/student.png",
      "frame": [0, 0],
      "frame_size": [32, 32]
    }
  }
]
```

---

## 15.3 TenantData

```gdscript
class_name TenantData

var id: String
var name: String
var job: String
var personality: String
var rarity: String
var pay_multiplier: float
var satisfaction: int
var favorite_tags: Array
var current_need: String
var current_behavior: String
var room_id: String
```

---

## 15.4 TenantPanel

从两个入口打开：

```text
点击小人
房间 UI 的租客 Tab
```

功能：

```text
查看租客状态
招募租客
显示申请列表
```

---

## 15.5 招募租客

```gdscript
func recruit_tenant(tenant_id: String, room_id: String):
    var room = BuildingManager.get_room(room_id)

    if room.tenant_id != "":
        return

    room.tenant_id = tenant_id
    GameState.assign_tenant_to_room(tenant_id, room_id)
    room.spawn_tenant(tenant_id)
    room.recalculate_stats()
    EconomyManager.recalculate_total_rent()

    TaskManager.notify_event("tenant_recruited", {
        "tenant_id": tenant_id,
        "room_id": room_id
    })

    SaveManager.save_game()
```

---

# 16. TenantAI 技术设计

## 16.1 状态机

```gdscript
enum TenantAIState {
    IDLE,
    WANDER,
    CHOOSE_NEED,
    MOVE_TO_FURNITURE,
    INTERACT,
    REACT
}
```

---

## 16.2 AI 流程

```text
Idle
↓
选择需求
↓
寻找对应家具
↓
走到互动点
↓
显示气泡 / 进度条 / 家具高亮
↓
应用满意度变化
↓
回到 Idle / Wander
```

---

## 16.3 需求与家具匹配

| 需求            | 家具标签                | 气泡    |
| ------------- | ------------------- | ----- |
| energy        | bed                 | zzz   |
| hunger        | fridge / table      | food  |
| entertainment | tv / game / sofa    | fun   |
| hygiene       | sink / bath         | water |
| study         | desk / book         | book  |
| comfort       | plant / lamp / sofa | heart |

---

## 16.4 AI 伪代码

```gdscript
func choose_next_behavior():
    var need = pick_need()
    var target = room.find_furniture_by_need(need)

    if target == null:
        show_bubble("question")
        state = TenantAIState.WANDER
        return

    current_target = target
    state = TenantAIState.MOVE_TO_FURNITURE
```

```gdscript
func interact_with_target():
    current_target.set_in_use(true)

    var interaction = current_target.data.get("interaction", {})
    show_bubble(interaction.get("bubble", "happy"))

    await get_tree().create_timer(interaction.get("duration", 3)).timeout

    current_target.set_in_use(false)
    apply_interaction_result(interaction)
    state = TenantAIState.REACT
```

---

# 17. EconomyManager 技术设计

## 17.1 职责

```text
计算房间租金
计算总租金
处理自动金币增长
处理离线收益
发出金币变化信号
```

---

## 17.2 房间租金计算

```gdscript
func calculate_room_rent(room: RoomData) -> float:
    if room.tenant_id == "":
        return 0.0

    var base_rent = 10.0
    var score_part = room.score * 0.5

    var tenant = GameState.get_tenant(room.tenant_id)
    var pay_multiplier = tenant.pay_multiplier
    var satisfaction_multiplier = get_satisfaction_multiplier(tenant.satisfaction)

    return (base_rent + score_part) * pay_multiplier * satisfaction_multiplier
```

---

## 17.3 总租金

```gdscript
func recalculate_total_rent():
    var total := 0.0

    for room in GameState.rooms:
        total += calculate_room_rent(room)

    GameState.total_rent_per_minute = total
    GameEvents.rent_changed.emit(total)
```

---

## 17.4 自动收益

```gdscript
func income_tick(delta):
    var income_per_second = GameState.total_rent_per_minute / 60.0
    coin_buffer += income_per_second * delta

    if coin_buffer >= 1.0:
        var coins_to_add = int(coin_buffer)
        coin_buffer -= coins_to_add
        GameState.add_coins(coins_to_add)
        GameEvents.coin_gain_batched.emit(coins_to_add)
```

---

# 18. 离线收益技术设计

## 18.1 存档字段

```json
{
  "last_save_timestamp": 1710000000
}
```

---

## 18.2 计算逻辑

```gdscript
func calculate_offline_income():
    var now = Time.get_unix_time_from_system()
    var offline_seconds = now - GameState.last_save_timestamp
    var capped_seconds = min(offline_seconds, GameState.max_offline_seconds)

    var income = GameState.total_rent_per_minute / 60.0 * capped_seconds
    return int(income)
```

---

## 18.3 登录弹窗

如果离线收益大于 0，打开 OfflineRewardPopup。

支持：

```text
普通领取
广告双倍领取
```

---

# 19. 公寓等级技术设计

## 19.1 apartment_levels.json

```json
[
  {
    "level": 1,
    "required_exp": 0
  },
  {
    "level": 2,
    "required_exp": 100
  },
  {
    "level": 3,
    "required_exp": 300
  },
  {
    "level": 4,
    "required_exp": 700
  }
]
```

---

## 19.2 经验来源

```gdscript
func add_apartment_exp(amount: int):
    GameState.apartment_exp += amount
    check_level_up()
```

事件经验建议：

```text
摆放家具 +5
招募租客 +20
建造楼层 +50
完成任务 +任务配置值
```

---

## 19.3 升级逻辑

```gdscript
func check_level_up():
    var next_level_data = ConfigManager.get_level_data(GameState.apartment_level + 1)

    if next_level_data and GameState.apartment_exp >= next_level_data["required_exp"]:
        GameState.apartment_level += 1
        GameEvents.apartment_level_changed.emit(GameState.apartment_level)
        BuildingManager.refresh_build_slots()
```

---

# 20. TaskManager 技术设计

## 20.1 tasks.json 示例

```json
[
  {
    "id": "task_place_bed",
    "title": "布置第一张床",
    "description": "在任意房间放置一张床",
    "type": "place_furniture_tag",
    "target_tag": "bed",
    "target_value": 1,
    "reward_coins": 50,
    "reward_exp": 20
  }
]
```

---

## 20.2 TaskManager 监听事件

```text
furniture_placed
tenant_recruited
floor_built
rent_reached
apartment_level_reached
tenant_behavior_observed
```

---

## 20.3 任务完成

```gdscript
func complete_task(task):
    task.completed = true
    GameState.add_coins(task.reward_coins)
    GameState.add_apartment_exp(task.reward_exp)
    GameEvents.task_completed.emit(task.id)
    SaveManager.save_game()
```

---

# 21. 存档系统

## 21.1 SaveManager

不要直接耦合本地文件路径。

SaveManager 通过 PlatformManager 保存。

```gdscript
func save_game():
    var data = GameState.to_save_data()
    PlatformManager.save_data("save_main", data)
```

```gdscript
func load_game():
    var data = PlatformManager.load_data("save_main")
    GameState.from_save_data(data)
```

---

## 21.2 存档内容

```json
{
  "coins": 1200,
  "total_rent_per_minute": 88,
  "apartment_level": 3,
  "apartment_exp": 250,
  "highest_built_floor": 3,
  "rooms": [],
  "tenants": [],
  "tasks": [],
  "last_save_timestamp": 1710000000
}
```

---

## 21.3 存档时机

```text
每 60 秒自动存档
家具摆放后
家具移动后
家具回收后
招募租客后
建造楼层后
完成任务后
应用暂停 / 退出时
```

---

# 22. 平台抽象

## 22.1 PlatformManager

统一平台能力。

```gdscript
func init_platform()
func get_platform_name() -> String
func save_data(key: String, data: Dictionary)
func load_data(key: String) -> Dictionary
func show_rewarded_ad(ad_type: String, callback: Callable)
func track_event(event_name: String, params: Dictionary)
func get_safe_area() -> Rect2
func vibrate(duration_ms: int)
func share(payload: Dictionary)
```

---

## 22.2 Provider

```text
BasePlatformProvider
AndroidPlatformProvider
TapTapPlatformProvider
WebPlatformProvider
WeChatMiniGameProvider
DouyinMiniGameProvider
```

MVP 可以先实现：

```text
BasePlatformProvider
AndroidPlatformProvider mock
WebPlatformProvider mock
```

微信 / 抖音 Provider 先保留接口。

---

## 22.3 AdManager

业务代码只调用 AdManager。

```gdscript
func show_rewarded_ad(ad_type: String, callback: Callable):
    PlatformManager.show_rewarded_ad(ad_type, callback)
```

---

# 23. 配置表系统

## 23.1 ConfigManager

加载：

```text
furniture.json
tenants.json
floors.json
tasks.json
economy.json
apartment_levels.json
ui_text.json
behavior_aliases.json
```

---

## 23.2 原则

禁止在业务逻辑中硬编码：

```text
家具价格
家具属性
楼层价格
租客倍率
任务奖励
玩法配置文案、可复用本地化文案
```

全部走配置表。

---

# 24. 本地化预留

即使 MVP 只做中文，也建议为可复用和玩法配置文案预留 key。

固定 UI 结构、默认按钮文案、面板标题、空状态、说明行和显示模板优先写在 `.tscn` 或场景导出属性中，保证 Godot 编辑器可直接预览。脚本只填运行时数据，不硬编码固定中文 UI 文案。

ui_text.json：

```json
{
  "button_add_furniture": "添加家具",
  "button_recruit_tenant": "招募租客",
  "label_rent_per_minute": "租金 / 分钟",
  "label_apartment_level": "公寓 Lv."
}
```

---

# 25. 性能设计

## 25.1 小人 AI 优化

```text
可见楼层正常更新
不可见楼层降低 AI 更新频率
远景缩放时降低气泡和细节刷新
离屏小人只计算收益，不播放行为
```

---

## 25.2 家具优化

```text
家具默认只使用 Sprite2D
不要每件家具都跑复杂 _process
互动家具才有轻量反馈组件
家具状态变化使用事件触发
```

---

## 25.3 UI 优化

```text
面板复用
列表使用对象池，可选
避免频繁重建家具列表
顶部金币跳动合并显示
```

---

# 26. 多分辨率与安全区

## 26.1 适配要求

需要考虑：

```text
刘海屏
挖孔屏
底部手势条
不同长宽比
小游戏容器边界
```

---

## 26.2 UI 安全区

TopStatusBar 和 FloatingMenu 应根据 PlatformManager.get_safe_area() 调整。

---

# 27. 事件与信号

## 27.1 GameEvents.gd

```gdscript
signal coins_changed(value)
signal coin_gain_batched(amount)
signal rent_changed(value)
signal apartment_level_changed(level)

signal room_updated(room_id)
signal furniture_placed(room_id, furniture_id)
signal furniture_moved(room_id, furniture_id)
signal furniture_recycled(room_id, furniture_id)

signal tenant_recruited(tenant_id, room_id)
signal tenant_satisfaction_changed(tenant_id, value)
signal tenant_behavior_observed(tenant_id, behavior)

signal floor_built(floor_index)
signal task_updated(task_id)
signal task_completed(task_id)
```

---

# 28. 埋点预留

PlatformManager.track_event 预留以下事件：

```text
game_start
tutorial_step
room_opened
furniture_shop_opened
furniture_placed
furniture_moved
furniture_recycled
tenant_recruited
floor_built
apartment_level_up
reward_ad_show
reward_ad_success
offline_reward_claimed
```

---

# 29. 开发里程碑

## Milestone 1：主界面与公寓视图

目标：

```text
竖屏界面
顶部状态栏
右侧悬浮按钮
公寓可拖动缩放
点击房间
```

---

## Milestone 2：房间 UI 与家具摆放

目标：

```text
点击房间打开 RoomPanel
RoomPanel 支持家具 Tab
家具商店
新家具购买即摆放
隐藏网格吸附
确认后扣金币
```

---

## Milestone 3：家具移动与回收

目标：

```text
长按家具进入操作
移动已有家具
取消移动
回收家具返还金币
重新计算房间评分
```

---

## Milestone 4：租客招募与小人 AI

目标：

```text
房间租客 Tab
租客申请列表
招募入住
小人在房间走动
根据家具显示行为气泡
```

---

## Milestone 5：收益与等级

目标：

```text
自动金币增长
顶部 +金币 合并提示
房间租金计算
总租金计算
公寓等级
新楼层可建造
```

---

## Milestone 6：任务 / 福利 / 存档

目标：

```text
任务系统
离线收益
广告 Mock
本地存档
平台抽象
```

---

## Milestone 7：发行框架整理

目标：

```text
配置表整理
AssetResolver 完整化
安全区适配
本地化 key
埋点接口
性能优化
Android 导出准备
```

---

# 30. MVP 验收标准

## 30.1 主界面

```text
无底部常驻按钮
顶部只显示公寓等级、收益、租金
右侧显示任务、福利、设置
中间公寓可拖动缩放
```

---

## 30.2 房间交互

```text
点击房间空白打开 RoomPanel
RoomPanel 有家具 / 租客 Tab
家具 Tab 可打开家具商店
租客 Tab 可招募租客
```

---

## 30.3 家具

```text
选择家具后进入摆放
家具吸附网格
合法位置可确认
确认后扣金币
长按家具可移动
长按家具可回收
回收返还金币
无仓库
无家具详情
```

---

## 30.4 租客

```text
空房可招募租客
租客入住后显示小人
小人会在房间内移动
小人会使用家具并冒气泡
点击小人显示状态
```

---

## 30.5 收益

```text
金币自动增长
顶部金币显示变化
顶部偶尔显示 +金币
租金随家具和租客变化
离线收益可结算
```

---

## 30.6 建造

```text
公寓等级达到后下一层出现可施工状态
点击可施工楼层弹确认
金币不足确认按钮置灰
金币足够可建造
建造后新楼层出现
```

---

# 31. 当前最终设计总结

这版游戏的核心不是菜单，而是公寓本体。

最终主交互链路是：

```text
点击房间
↓
房间 UI
↓
添加家具 / 招募租客
↓
家具摆放 / 租客入住
↓
租金自动增长
↓
公寓等级提升
↓
新楼层出现
↓
点击建造
↓
继续扩张
```

最终 UI 结构是：

```text
顶部：
公寓等级 / 收益 / 租金

右侧：
任务 / 福利 / 设置

中间：
所有核心操作

底部：
无
```

最终系统边界是：

```text
单栋公寓
无底部按钮
无仓库
无家具详情
无街区
无多建筑
自动收租
场景内建造
房间内添加家具和招租
长按家具移动 / 回收
```
