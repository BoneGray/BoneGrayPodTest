# Development Guidelines

## 可维护原型优先

- 后续新需求默认按照 `docs/architecture.md` 的标准流程判断，不再以快速看到临时效果为优先。
- 涉及玩家、敌人、装备、攻击、动画、碰撞、AI、状态切换的需求，先确认系统职责和阶段依赖，再决定实现方式。
- 如果当前架构不能干净承载需求，需要先说明必须补齐的前置阶段，例如状态机、攻击阶段数据、装备控制器或敌人 AI 状态。
- 可以分批实现，但不能为了短期效果继续把新规则堆进过载脚本。
- 当需求本身规则不清晰时，先讨论可行性、可玩性和选择逻辑，再进入代码修改。

## 需求实现原则

- 新需求先按专业游戏开发的标准流程拆解，再决定具体实现。
- 优先区分系统职责，不把不同概念混在同一个节点或脚本里。
- 遇到 Godot 已有的标准节点、资源和调试能力时，优先使用引擎原生方案。
- 只有在原生方案不能满足玩法、调试或表现需求时，才添加额外自定义节点或脚本。
- 先说明关键概念差异，再实现。例如移动碰撞、受击范围、攻击范围应分别建模。
- 保持测试场景独立，让 `Player`、`Enemy`、地图、相机等对象可以拖拽组合验证。
- 任何会影响后续扩展的结构性改动，都要优先考虑标准结构，而不是只修眼前效果。

## 玩法规则先讨论

涉及玩法规则、AI 决策、数值差异、攻击选择、装备系统、角色成长、敌人行为的需求，不能只因为资源或代码条件满足就直接实现。

实现前必须先和设计者讨论并确认：

- 这个功能解决什么玩法问题，是否真的提升可玩性？
- 玩家是否能理解、预判或应对这个机制？
- 不同选项之间的选择逻辑是什么，例如随机、轮换、权重、距离、冷却、血量、状态或阶段？
- 不同动作或配置之间是否有明确差异，例如伤害、范围、前摇、后摇、命中数量、冷却、风险和反馈？
- 这个机制是否应该先做成数据配置，而不是写死在脚本里？
- 是否需要保留更简单的临时版本，等玩法验证后再扩展？

例如敌人拥有 `attack_down_first` 和 `attack_down_second` 两套动画时，应先定义它们在玩法上的含义和选择规则，再决定代码实现。不能在没有讨论清楚的情况下直接做成随机选择或硬编码切换。

## Godot 结构约定

- 角色移动阻挡使用 `CharacterBody2D` 或合适的物理体配合 `CollisionShape2D`。
- 静态障碍使用 `StaticBody2D`、TileSet Physics Layer 或等价的 Godot 物理碰撞方案。
- 受击判断使用 `HitboxArea2D`，攻击判断使用 `AttackArea2D`。
- `AnimatedSprite2D` 只负责显示动画，不承担移动碰撞职责。
- `AnimationPlayer` 可以控制攻击帧、命中窗口和与动画强相关的状态。
- 调试碰撞优先使用 Godot 的可见碰撞形状，而不是额外绘制重复的调试节点。

## 玩家攻击输入约定

- 玩家主攻击输入由 `AttackProfile.input_mode` 决定，避免同一把武器同时混用点按、手动连按和长按连发。
- `single_press` 表示按一次只攻击一次，不使用后摇取消，也不使用长按重复。
- `tap_combo` 表示靠玩家手动连按接攻击，可以使用 `input_buffer_time` 和 `cancel_last_frames`，但按住攻击键不应自动重复。
- `hold_repeat` 表示按住自动重复攻击，使用 `hold_to_repeat_delay` 和当前攻击 `repeat_attack_cooldown`，但不使用短按缓存或后摇取消。
- 短按后摇取消必须发生在命中帧之后，不能取消前摇或命中帧，避免破坏命中判定和可读性。
- 玩家攻击运行时状态只能由 Player 攻击状态机统一维护；命中判定必须同时满足当前攻击 action、当前攻击动画和当前命中帧，不能只依赖 `AttackArea2D.monitoring` 或动画轨道残留值。
- 新武器如果需要不同攻击手感，优先选择或新增清晰的 `input_mode`；不要在脚本里临时堆多套输入判断。
- 自动武器通常使用 `hold_repeat` 和较短 `repeat_attack_cooldown`，如不需要后摇取消，应将 `cancel_last_frames` 设为 `0`。

## 2D 图层与排序约定

- 场景中玩家、敌人、地面道具、尸体和可遮挡装饰物应放在同一个开启 `y_sort_enabled` 的父节点下，例如 `WorldActors`。
- 外部遮挡关系交给 Y-Sort 处理：谁的地面原点 Y 值更大，谁显示在前面。
- 参与同一 Y-Sort 的角色和地面道具应保持同一根节点 `z_index` 层，避免固定 `z_index` 压过 Y-Sort。
- 地板、导航区域、碰撞障碍、UI、纯调试节点不放进 `WorldActors`，避免参与角色排序。
- 角色内部部件不交给外部 Y-Sort 处理，应由角色脚本根据方向或动画统一控制层级。
- `Player` 的身体和手部动画分层规则：面向 `up` 时手部在身体后面；面向 `down`、`side`、`side_left` 时手部在身体前面。
- 角色内部 `Sprite`、`HandsSprite` 等子视觉层只能在角色根节点排序层以内前后切换，不应使用高于根节点的正 `z_index`，否则会压过同层 Y-Sort 的地面道具。
- 丢弃武器只恢复空手手部资源，不隐藏 `HandsSprite`；空手、持枪、持近战武器都应走同一套手部同步和层级规则。
- 不要通过在场景里临时拖动 `Sprite`、`HandsSprite` 或拾取物的 `z_index` 来修视觉遮挡，优先修改排序父节点、地面原点或角色内部层级规则。

## 命名约定

所有新导入图片资源和 Godot 动画名称都应使用小写英文和下划线。
命名目标是让文件夹和 Godot 资源列表按名称排序时自然分组，方便查找和维护。

### Godot 动画名

游戏内动画名称格式为：

```text
动作_方向_补充_其他
```

命名顺序固定，优先保证按名称排序时能自然按动作分组，再按方向分组，最后才区分补充信息。

规则：

- `动作` 必填，例如 `idle`、`walk`、`attack`、`death`、`hurt`、`cast`。
- `方向` 必填，使用统一方向名，例如 `up`、`down`、`side`、`side_left`。
- `补充` 可选，用于区分同一动作的类型、段数或武器，例如 `first`、`second`、`heavy`、`knife`。
- `其他` 可选，用于更细的版本、状态或特殊标记。
- 不使用空格、大写、连字符或中文命名动画。
- 不推荐把序号放在动作前面，推荐 `attack_down_first` 这种动作优先的名称。

示例：

```text
idle_down
walk_side_left
attack_down_first
attack_side_second
death_side_first
death_side_second
hurt_up
```

现有旧动画命名可以在后续重构时逐步迁移，不要求一次性改完。

### 图片资源文件名

角色或敌人动画图片文件名可以比 Godot 动画名多一个对象前缀，格式为：

```text
对象_动作_方向_补充_其他
```

规则：

- `对象` 用于区分角色、敌人、武器、道具或场景对象，例如 `player`、`zombie_big`、`knife`。
- 后面的 `动作_方向_补充_其他` 与 Godot 动画名保持一致。
- 如果是序列图或精灵表，可以在末尾追加帧数或类型标记，例如 `sheet8`、`sheet15`、`icon`。
- 不使用空格、大写、连字符或中文命名图片文件。
- 外部购买资源的原始文件名可以保留在源素材库中；复制进项目 `assets/` 后，优先按本规则重命名，或在生成脚本中明确映射到本规则。

示例：

```text
player_walk_down_sheet8.png
player_attack_side_left_first_sheet6.png
zombie_big_attack_down_second_sheet15.png
zombie_big_death_side_first_sheet7.png
knife_icon.png
```

导入规则：

- `assets/` 中的新运行时图片资源应遵循图片资源文件名规则。
- 生成 `SpriteFrames` 或 `AnimationPlayer` 时，动画名应去掉对象前缀，只保留 `动作_方向_补充_其他`。
- 如果资源来自外部素材包且暂时不重命名，必须在导入脚本或文档中记录命名映射。

### 通用图片资源文件名

非角色动画类图片不强行套用 `动作_方向` 格式。
地形、建筑、道具、UI、特效等资源使用更通用的格式：

```text
类别_对象_用途_变体_规格
```

字段说明：

- `类别` 必填，用于大类分组，例如 `terrain`、`tileset`、`building`、`prop`、`ui`、`effect`、`weapon`、`tool`。
- `对象` 必填，用于说明资源主体，例如 `grass`、`road`、`house`、`fence`、`button`、`smoke`。
- `用途` 可选，用于说明资源用途或部件，例如 `tile`、`wall`、`roof`、`front`、`icon`、`panel`。
- `变体` 可选，用于说明颜色、状态、时间或版本，例如 `green`、`dark`、`damaged`、`broken`、`night`、`v01`。
- `规格` 可选，用于说明尺寸、瓦块规格或序列信息，例如 `tile16`、`tile32`、`sheet8`、`size64`。

推荐格式：

```text
terrain_地形类型_变体_规格
tileset_terrain_对象_变体_规格
building_建筑类型_部件_变体_规格
prop_对象_状态_规格
ui_用途_对象_状态_规格
effect_类型_状态_规格
```

示例：

```text
terrain_grass_green_tile16.png
terrain_road_asphalt_dark_tile16.png
tileset_terrain_background_bleak_yellow_tile16.png
building_house_wall_red_tile16.png
building_shop_front_damaged_tile16.png
prop_barrel_rusted_tile16.png
prop_tree_dead_tile32.png
ui_button_confirm_normal.png
ui_icon_weapon_knife.png
effect_hit_red_sheet6.png
effect_smoke_loop_sheet12.png
```

## 当前角色结构

`Player` 和 `Enemy` 都应使用以下标准层级：

```text
CharacterBody2D
├─ Sprite AnimatedSprite2D
├─ HandsSprite AnimatedSprite2D（玩家或可替换手部/武器层）
├─ BodyCollisionShape2D
├─ HitboxArea2D
│  └─ CollisionShape2D
├─ AttackArea2D
│  └─ CollisionShape2D
└─ AnimationPlayer
```

- `BodyCollisionShape2D` 用于移动阻挡和地图碰撞。
- `HitboxArea2D` 用于被攻击命中判断。
- `AttackArea2D` 用于攻击命中窗口。
- `Sprite` 只承载动画资源和显示状态。
- `HandsSprite` 只承载玩家手部或装备视觉层，层级由玩家脚本统一控制。
- `AnimationPlayer` 只控制动画帧和攻击范围开关等与动画同步的状态。

## 实现前检查

- 这个需求在成熟 2D 游戏里通常怎么做？
- Godot 是否已经有标准节点或资源可以解决？
- 这是移动碰撞、触发检测、战斗判定、视觉表现，还是 UI 状态？
- 这个需求是否包含玩法选择或 AI 决策？如果包含，必须先讨论可行性、可玩性和选择规则。
- 这个实现会不会让后续敌人、地图、关卡或动画系统变难？
- 是否需要独立测试场景验证，而不是直接堆到主场景？

## Godot Inspector 属性说明

- 新增 `@export` 属性时，默认在属性上方使用 `##` 文档注释说明用途。
- 如果属性会暴露给策划、美术或自己在 Inspector 中调参，说明里应尽量写清楚单位、推荐范围、默认值意图和注意事项。
- 同一类属性应使用 `@export_group` 分组，例如移动、战斗、视觉表现、调试、拾取表现等。
- 属性名保持英文代码命名，说明文字默认使用中文。
- 布尔开关应说明开启后影响什么；数值属性应说明越大或越小会带来什么效果。
## 渲染层级补充入口

- 涉及地形、建筑、树木、拾取物、飞行物、角色装备、手部动画、YSort 或 `z_index` 的需求，先看 `docs/render-layer-guidelines.md`。
- 地板、草地、马路、河流等地形底板属于 `TerrainLayer`，不参与 YSort。
- 玩家、敌人、地上可拾取物、掉落武器、树干、墙体主体、车辆、石块、草丛属于 `WorldActors`，由 YSort 按地面原点决定前后遮挡。
- 树冠、屋顶、天花板和天空遮挡属于 `HighOverlay`，固定覆盖在角色、装备、拾取物和飞行物之上。
- 飞行中的子弹、斧子、枪口火光、命中特效属于 `WorldEffects`；落地或变成可拾取物后进入 `WorldActors`。
- 角色内部的身体、头、手、武器、攻击特效只在角色根节点内部切换层级，不应靠高 `z_index` 压过世界物件。

## 通用专业化开发入口

- 后续涉及可复用系统、同类资源扩展、武器、工具、消耗品、敌人、角色、拾取物、攻击方式或渲染层级时，先参考 `docs/professional-game-development-guidelines.md`。
- 新需求默认先抽象公共概念，再接入当前资源；不要为了当前单个资源写一次性专属逻辑。
- 当前拾取系统基线是 `ItemData -> WeaponData` 和 `PickupItem.item_data`。新武器、工具、消耗品和弹药都应优先接入这条公共路径。

## PNG Import And Atlas Rules

新增单张或少量 PNG 时，不应直接把散图放进运行时目录后立即引用。先按以下流程处理：

1. 先分析资源用途，判断它属于角色动画、地面拾取物、UI、地形瓦块、建筑部件、场景装饰、特效还是投射物。
2. 再判断它应该放入已有目录、已有 atlas，还是需要新建一组 atlas。
3. 对地面拾取物、UI 图标、道具小图、建筑小件、自然装饰和小特效，优先合入对应 atlas，并生成或更新 `AtlasTexture` `.tres`。
4. 已存在 atlas 的坐标必须保持稳定。新增资源默认追加到 atlas 的末尾或下一行，不自动重排旧资源坐标。
5. 每个 atlas 必须维护 manifest，记录 atlas 路径、是否 append-only，以及每个子图的 `x/y/w/h`。
6. 游戏逻辑、`ItemData`、场景和资源文件应引用 `AtlasTexture` `.tres`，不要直接记录 atlas 坐标。
7. 引用全部切换到 `.tres` 后，旧的运行时散图和对应 `.import` 可以删除。
8. 手持武器动画、角色动画、大型 sprite sheet、TileSet 原图不强制合进通用 atlas；它们应按 SpriteFrames 或 TileSet 工作流处理。

当前推荐结构：

```text
assets/equipment/pickups/pickup_items_atlas.png
assets/equipment/pickups/pickup_items_atlas_manifest.json
resources/equipment/pickups/item_name_world_texture.tres
```

追加新拾取物示例：

```text
新增 food.png
-> 判断为地面拾取物
-> 追加进 pickup_items_atlas.png
-> 更新 pickup_items_atlas_manifest.json
-> 新增 food_world_texture.tres
-> ItemData.world_texture 引用 food_world_texture.tres
```
## Godot Inspector 属性说明补充

- `@export` 属性上方的 `##` 文档注释会显示在 Godot Inspector 中，应视为用户可见文本。
- 代码标识符、文件名、节点名保持英文；Inspector 属性说明、调参说明、设计说明默认使用中文。
- 除非是第三方原文、引擎固定术语或不可翻译的 API 名称，否则不要把 Inspector 属性说明写成英文。
- 每次新增或修改 `@export` 属性后，必须自查同一文件内新增的 `##` 说明是否为中文，并确认说明与当前属性职责一致。
- 如果属性属于通用组件或会被后续项目复用，中文说明要写清楚它面向的调参场景，避免只描述当前单个资源。
