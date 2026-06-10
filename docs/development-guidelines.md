# Development Guidelines

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
- `AnimationPlayer` 只控制动画帧和攻击范围开关等与动画同步的状态。

## 实现前检查

- 这个需求在成熟 2D 游戏里通常怎么做？
- Godot 是否已经有标准节点或资源可以解决？
- 这是移动碰撞、触发检测、战斗判定、视觉表现，还是 UI 状态？
- 这个需求是否包含玩法选择或 AI 决策？如果包含，必须先讨论可行性、可玩性和选择规则。
- 这个实现会不会让后续敌人、地图、关卡或动画系统变难？
- 是否需要独立测试场景验证，而不是直接堆到主场景？
