# 2D 渲染层级规范

本文用于统一 GameZombieWorld 的世界遮挡、角色内部遮挡、拾取物、飞行物和建筑/树木的渲染规则。目标是让玩家游玩时看到的层级符合地图空间逻辑，而不是靠单个节点临时调 `z_index`。

## 核心原则

- 世界层级和角色内部层级是两套系统。
- 世界层级决定 Player、Enemy、地上物件、树干、墙体、车辆之间谁挡谁。
- 角色内部层级决定身体、头、手、武器、攻击特效之间谁挡谁。
- 世界遮挡优先由 `YSort` 解决；角色内部遮挡优先由角色 Visual 逻辑按方向/动画解决。
- 不通过把角色内部节点调到很高的正 `z_index` 来修局部问题，否则会破坏世界遮挡。
- 可复用场景资源必须保持完整、可检查的节点结构；禁止资源脚本在编辑器或运行时私自 `reparent` 自身子节点来适配世界层级。
- 树木、建筑、家具等需要跨层显示的复合物件，必须先保持完整 prefab，再由统一放置器、构建器或明确的场景层级规范处理跨层拆分。

## 世界层级

推荐场景结构：

```text
World
+-- TerrainLayer
|   +-- Floor
|   +-- Grass
|   +-- Road
|   +-- River
|   +-- GroundTile
+-- ShadowLayer
|   +-- BuildingShadow
|   +-- TreeShadow
|   +-- CloudShadow
+-- WorldActors
|   +-- GroundProps
|   +-- Pickups
|   +-- DroppedWeapons
|   +-- Player
|   +-- Enemies
|   +-- TreeTrunk
|   +-- WallBody
|   +-- Car
+-- WorldEffects
|   +-- Bullets
|   +-- ThrownWeapons
|   +-- HitEffects
|   +-- MuzzleFlash
+-- HighOverlay
|   +-- TreeCanopy
|   +-- BuildingRoof
|   +-- Ceiling
|   +-- SkyBlocker
+-- UI
```

### TerrainLayer

不参与 YSort。

包含：

- 地板
- 草地
- 马路
- 河流
- 土地
- 地面瓦块

规则：

- TerrainLayer 永远在角色、道具、建筑主体下面。
- 它只是地面材质，不负责遮挡角色。

### WorldActors

开启 `y_sort_enabled`。

包含：

- 玩家
- 敌人
- 地上可拾取物
- 掉落武器
- 草丛
- 石块
- 车
- 墙体主体
- 树干
- 尸体
- 其他需要和角色互相遮挡的地面物件

规则：

- 这些节点的根节点应保持同一世界排序层，默认 `z_index = 0`。
- 谁的地面原点 Y 值更大，谁显示在前面。
- 可拾取物、掉落武器、尸体不要用固定高 `z_index` 压过角色。
- 节点原点应尽量放在脚底、底部接地点或物体和地面接触的位置。

### HighOverlay

不参与 WorldActors 的 YSort，固定覆盖在 WorldActors 上方。

包含：

- 树冠
- 屋顶
- 天花板
- 天空遮挡
- 高处装饰

规则：

- 玩家、敌人、装备、地上物、飞行物在高层遮挡区域下方时，应一起被遮挡。
- 树应拆成两个逻辑部分：树干进入 WorldActors，树冠进入 HighOverlay；但拆分不得由树资源自身脚本偷偷搬节点完成。
- 建筑也应拆成底部/墙体/屋顶：可交互或可遮挡主体进入 WorldActors，屋顶和天花板进入 HighOverlay。

## 可复用场景资源结构

树木、建筑、家具、车辆、可交互大型物件这类会反复拖入地图的资源，必须遵守以下规则：

- 资源场景本身必须保持完整结构，打开 `.tscn` 时应能看到全部关键节点。
- 资源场景不允许依赖 `@tool`、`_ready()` 或运行时脚本把自身子节点搬到其他父节点。
- 资源场景可以暴露锚点、碰撞、视觉部件和配置，但不能把世界层级职责藏在资源内部。
- 如果一个资源需要同时进入 `WorldActors`、`ShadowLayer`、`HighOverlay` 等多个世界层，必须使用统一的场景放置/构建流程生成最终层级。
- 第一次接入新类型资源时，先做一个样板资源和样板场景验证；验证通过后再批量导入同类资源。

树木资源的基础结构：

```text
TreeXxx.tscn
+-- Shadow
+-- Trunk
|   +-- Sprite
|   +-- CollisionShape2D
+-- Canopy
```

在资源场景里，`Trunk`、`Canopy`、`Shadow` 必须始终可见；任何让它们在编辑器场景树里消失的实现都不合格。

### WorldEffects

用于世界中的表现效果。

包含：

- 子弹
- 飞行中的斧子
- 命中特效
- 枪口火光
- 弹壳飞出表现

规则：

- 飞行物在飞行中可以位于 WorldActors 上方，但应低于 HighOverlay。
- 飞行物落地、停留或变成可拾取物后，应切换到 WorldActors，由 YSort 管理。
- 命中特效、枪口火光这类短生命周期表现可以放在 WorldEffects，避免和地上物 YSort 抢层级。

## 角色内部层级

推荐角色结构：

```text
CharacterBody2D
+-- Shadow
+-- VisualRoot
|   +-- BackEquipment
|   +-- Body
|   +-- Head
|   +-- FrontHands
|   +-- FrontWeapon
|   +-- AttackEffect
+-- CollisionRoot
|   +-- BodyCollisionShape2D
|   +-- HitboxArea2D
|   +-- AttackArea2D
```

当前项目还没有完全拆成这个结构时，可以继续使用现有 `Sprite` 和 `HandsSprite`，但必须遵守同一规则：

- 角色根节点参与 WorldActors 的 YSort。
- `Sprite`、`HandsSprite`、武器动画只在角色根节点内部切换层级。
- 内部视觉层不应升到角色根节点世界层级之上。
- 身体主 Sprite 应保持在角色根节点的世界基准层，不能为了让手或武器显示在前面而降到 `-1`，否则会被同层墙体、拾取物或敌人错误遮挡。
- 面向上时，手和枪通常在身体后面。
- 面向下时，手和枪通常在身体前面。
- 面向侧面时，手和枪在身体前侧，但不应遮住头部核心识别区域。

## 典型案例

### 人物和树

- 人在树干上方：树干遮挡人物。
- 人在树干下方：人物遮挡树干。
- 树冠永远覆盖人物、敌人、装备和飞行物。

### 人物和地上武器

- 武器在人物下方：武器遮挡人物。
- 武器在人物上方：人物遮挡武器。
- 人物的手部动画不能因为内部 `z_index` 过高而压过地上武器。

### 人物持枪

- 玩家整体依然由 WorldActors 的 YSort 决定世界遮挡。
- 枪和手只在玩家内部排序。
- 面向上时枪被身体遮挡。
- 面向下时枪遮挡身体。
- 玩家和枪应一起被树冠、屋顶、天花板覆盖。

### 投掷斧子

- 飞行中：属于 WorldEffects，表现为高于地面角色的飞行物。
- 落地后：变成 WorldActors 内的掉落武器或可拾取物，按 YSort 和角色互相遮挡。

## 禁止做法

- 不要把 Player、Enemy、Pickup 的根节点长期设置为不同固定 `z_index` 来修遮挡。
- 不要把 `HandsSprite`、武器 Sprite、装备 Sprite 调到高于角色根节点的世界层级。
- 不要让树冠、屋顶、天花板参与和角色同一套 YSort。
- 不要把地板、马路、河流放进 WorldActors。
- 不要用调试障碍物的临时层级规则作为正式地图层级规则。
- 不要让可复用资源通过脚本自动修改自己的父子层级结构。
- 不要因为单个样板场景看起来正确，就把临时拆层脚本扩散成正式资源流程。

## 验证要求

新增地图、角色、武器、拾取物、建筑、树木或飞行物时，至少检查：

- 角色能正确遮挡树干，也能被树干遮挡。
- 树冠、屋顶、天花板能覆盖角色整体，包括装备和手部动画。
- 地上武器和可拾取物能按 YSort 和玩家互相遮挡。
- 玩家面向上、下、侧面时，身体、手、武器的内部遮挡正确。
- 飞行物落地后能切换成 WorldActors 逻辑，而不是继续停留在飞行效果层。

## 迁移流程

具体迁移顺序见 `docs/render-layer-migration-plan.md`。

- 先改项目级规则和可复用资源。
- 再选样板场景验证。
- 最后逐个迁移正式场景。
- `navigation_obstacle_test_scene` 是当前第一版样板场景，不是为它单独写特例。

## 场景物体复杂度分级

新增树木、墙体、家具、车辆、草丛、石头、屋顶、天花板、可交互装饰或地面道具前，必须先判断它属于哪一类，再决定资源结构。不要默认把所有图片都做成完整复合物体，也不要为了眼前效果直接拖散图进主场景。

分级规则：

| 等级 | 用途 | 推荐结构 | 典型例子 |
| --- | --- | --- | --- |
| A 完整交互物体 | 会阻挡移动、参与 YSort、可能遮挡玩家、可能交互或状态变化 | `Split` 源资源 + `CompoundPropDefinition` + `PlacementMarker`，必要时带 `OcclusionFadeArea`、碰撞体、交互脚本 | 可进入建筑、重要树、门、柜子、可破坏大物体 |
| B 普通实体物体 | 会阻挡移动并参与 YSort，但不需要复杂交互或透明淡化 | 独立场景或复合物体简化版，保留视觉节点和碰撞体 | 普通石头、箱子、低墙、车辆主体 |
| C 纯视觉装饰 | 只提升画面，不挡路、不交互、不需要透明淡化 | 普通 `Sprite2D`、装饰场景或 atlas 引用 | 小草、地面垃圾、远景杂物、小花 |
| D 批量背景/地形装饰 | 大量重复出现，主要作为环境底图或纹理 | `TileMap`、合图、atlas、大背景图或未来批量渲染方案 | 密林背景、大片草地纹理、碎石地、墙面纹理 |

判断问题：

- 它会阻挡玩家或敌人移动吗？
- 它需要和玩家、敌人、地上物互相遮挡吗？
- 它是否有高层部分会盖住角色，例如树冠、屋顶、天花板？
- 玩家是否能交互、拾取、破坏、打开或触发它？
- 它是否需要透明淡化来保证玩家可读性？
- 它会不会在同一张地图里大量重复出现？
- 它更像地形、背景装饰、普通实体，还是完整复合物体？

实现原则：

- A 类优先走完整模板流程，先做一个样板资源验证，再批量扩展。
- B 类可以走简化场景，但仍要遵守 YSort、碰撞和锚点规则。
- C 类不要加入碰撞、Area2D、透明淡化或持续 `_process`，除非玩法确实需要。
- D 类不要做成大量独立节点，优先使用 TileMap、合图、atlas 或大图。
- 如果资源现在只用于视觉，但未来可能交互，先按当前需求做轻量版本，并在文档或资源备注里记录未来升级点。
- 是否做性能优化系统必须基于实际数量和 profiler 结果；现在先分类，后续再做分区加载、可见性暂停或批量渲染。

## 复合物体摆放层级方案

树木、建筑、墙体、家具、车辆、屋顶、天花板这类复合物体不能直接当作一个普通 `WorldActors` 子节点处理，因为它们内部经常同时包含低层阴影、世界排序主体和高层覆盖部分。

正式流程分成两类资源：

```text
SourcePrefab
+-- Shadow
+-- Trunk / Body / Wall
+-- Canopy / Roof / Ceiling

RuntimeGeneratedParts
+-- Shadow      -> ShadowLayer
+-- Trunk       -> WorldActors
+-- Canopy      -> HighOverlay
```

规则：

- `SourcePrefab` 是美术和结构的完整源资源，打开 `.tscn` 时必须能看到完整节点结构。
- `RuntimeGeneratedParts` 是 marker 运行时从完整源资源复制出来的分层节点，每个节点明确进入对应世界层。
- `WorldActors` 里的排序部分必须是直接子节点，不能藏在一个整体 prefab 里面，否则 YSort 只会排序整体 prefab，不会排序树干/墙体和 Player。
- 禁止用 `@tool`、`_ready()`、运行时脚本或调试脚本把源资源的子节点偷偷 `reparent` 到其他层。
- 新增同类资源时，先做一个样板资源验证层级，再批量生成同类 part。

树木当前标准：

```text
tree_yellow_split.tscn              # 唯一需要维护的完整源资源
tree_yellow_placement_marker.tscn   # 地图里拖放的放置点，运行时从源资源生成三层
```

### 复合物体放置流程

地图中不要直接拖 `tree_yellow_split.tscn` 这类完整源资源作为正式物体。正式摆放时使用 placement marker：

```text
CompoundPropMarkers
+-- TreeYellow      # 只负责表示“一棵树”的位置
+-- TreeYellow2
```

构建工具读取 marker 后生成真正参与渲染的三层节点：

```text
ShadowLayer/TreeShadowLayer/TreeYellowShadow
WorldActors/TreeYellowTrunk
HighOverlay/TreeCanopyLayer/TreeYellowCanopy
```

当前样板资源：

```text
resources/world/props/trees/tree_yellow_compound_prop.tres
scenes/world/props/trees/tree_yellow_placement_marker.tscn
tools/build_compound_prop_layers.gd
```

使用规则：

- 日常编辑时移动 `CompoundPropMarkers` 下的 marker，marker 表示整棵树的摆放点。
- marker 可以包含编辑器预览图，方便搭场景时看到物体大致位置；预览只用于编辑器，运行时会被移除，不参与正式碰撞或层级。
- 正式提交或测试前，运行构建工具同步生成 `ShadowLayer`、`WorldActors`、`HighOverlay` 的实际节点。
- 生成出的 `WorldActors/*Trunk` 才参与角色 YSort；marker 本身不参与战斗、碰撞或渲染。
- 如果后续新增树、建筑或屋顶，先新增对应 `CompoundPropDefinition`，再新增 marker 场景，不要复制临时拆层逻辑。

### 源资源维护规则

完整源资源是复合物体的 source of truth。以 `tree_yellow_split.tscn` 为例：

- 调整 `Shadow` 会影响运行时生成到 `ShadowLayer` 的树影。
- 调整 `Trunk/Sprite` 和 `Trunk/CollisionShape2D` 会影响运行时生成到 `WorldActors` 的树干和碰撞。
- 调整 `Canopy` 会影响运行时生成到 `HighOverlay` 的树冠。

当前运行时 marker 会优先读取 `CompoundPropDefinition.source_scene`，直接从完整源资源生成正式三层。因此日常搭场景和运行测试时，只要修改 `tree_yellow_split.tscn`，运行时生成的树影、树干碰撞和树冠位置都会跟着变化。

规则：

- 日常调整先改完整源资源。
- marker 运行时优先从完整源资源生成正式三层。
- 不再维护 `tree_yellow_shadow_part.tscn`、`tree_yellow_trunk_actor.tscn`、`tree_yellow_canopy_part.tscn` 这类静态 part，避免源资源和运行资源漂移。
## 高层遮挡透明规则

树冠、屋顶、天花板、前景墙体、高草这类处在 `HighOverlay` 的视觉遮挡物，可以在玩家进入遮挡区域时临时降低透明度，帮助玩家辨认自己和交互对象的位置。

规则：
- 透明变化属于“前景遮挡物”的能力，不属于 Player、Enemy 或世界 YSort 的能力。
- 不通过修改 Player、Enemy、Pickup 的透明度来解决遮挡可读性问题。
- 不改变 `WorldActors` 的 YSort，也不改变树干、墙体、家具主体的碰撞逻辑。
- 可复用资源应在完整源资源里配置遮挡区域，例如根节点下的 `OcclusionFadeArea`。
- marker 从完整源资源生成 `HighOverlay` 节点时，遮挡区域随对应高层视觉节点一起复制。
- 一个 `OcclusionFadeArea` 可以用多个 `CollisionShape2D` 拼出复杂遮挡轮廓，也可以同时淡化多个视觉目标。
- 树冠、屋顶这类前景部分可以淡得更明显；树干、墙体上半部这类实体主体只应轻微淡化，并且只淡化视觉 Sprite，不淡化碰撞体或排序主体。
- 复合物体跨层生成后，如果 `HighOverlay` 的遮挡区域需要连带淡化 `WorldActors` 里的主体 Sprite，应通过 `CompoundPropDefinition` 显式配置，不要写场景特例。
- 对复合物体，常用透明度应优先在 `CompoundPropDefinition` 中调整：`overlay_faded_alpha` 控制高层视觉，`sort_actor_sprite_faded_alpha` 控制 YSort 主体 Sprite。
- 默认只允许 `player` 组触发透明变化；敌人是否触发应按具体玩法另行讨论。
- `fade_target_path`、`trigger_group`、`faded_alpha`、`fade_in_time`、`fade_out_time` 必须作为可调属性暴露，并写明属性描述。

推荐默认值：
```text
trigger_group = "player"
faded_alpha = 0.45
overlay_faded_alpha = 0.45
fade_in_time = 0.12
fade_out_time = 0.18
sort_actor_sprite_faded_alpha = 0.72
```

标准结构：
```text
TreeXxx.tscn
+-- Shadow
+-- Trunk
|   +-- Sprite
|   +-- CollisionShape2D
+-- Canopy
+-- OcclusionFadeArea
    +-- CollisionShape2D
    +-- CollisionShape2D2
```
## 环境摆动动画规则

树木、草丛、藤蔓、旗帜、门帘、布条等环境氛围动画，应优先使用通用 `AmbientSway2D`，不要为单个资源写一次性动画脚本。

规则：
- 摆动只作用在视觉节点上，例如 `Trunk/Sprite`、`Canopy`、草叶 Sprite、布条 Sprite。
- 不要摆动 `StaticBody2D`、`CollisionShape2D`、`Area2D`、`OcclusionFadeArea` 或参与 YSort 的主体根节点。
- 树干、墙体主体这类实体视觉只能轻微摆动；树冠、草叶、藤蔓这类柔性视觉可以更明显。
- 同类物体应使用 `randomize_phase` 或 `phase_offset` 错开摆动，避免整片场景同步摇动。
- 摆动参数必须作为 Inspector 可调属性暴露，并使用中文 `##` 注释说明用途。

推荐树木参数：
```text
Trunk/Sprite:
duration = 3.2
position_amplitude = Vector2(0.25, 0)
rotation_degrees_amplitude = 0.45

Canopy:
duration = 2.6
position_amplitude = Vector2(1.1, 0.25)
rotation_degrees_amplitude = 1.0
scale_amplitude = Vector2(0.006, 0.006)
```

## 树木与复合环境物体模板

`tree_yellow_split.tscn` 是当前树木模板。后续新增树木、可遮挡建筑、带屋顶家具、藤蔓、门帘等复合环境物体时，应优先沿用这套结构，再按资源差异调整部件名称和参数。

标准树木源资源结构：
```text
TreeXxxSplit
+-- Shadow
+-- Trunk
|   +-- Sprite              # 可挂 AmbientSway2D，只做轻微视觉摆动
|   +-- CollisionShape2D    # 不摆动，负责实体碰撞
+-- Canopy                  # 可挂 AmbientSway2D，负责高层覆盖视觉
+-- OcclusionFadeArea       # 不摆动，负责玩家进入遮挡区检测
    +-- CollisionShape2D    # 可以多个 shape 拼复杂轮廓
```

配套资源：
```text
resources/world/props/trees/tree_xxx_compound_prop.tres
scenes/world/props/trees/tree_xxx_placement_marker.tscn
scenes/world/props/trees/tree_xxx_split.tscn
```

模板规则：
- `Split` 场景是唯一需要维护的完整源资源，打开 `.tscn` 时必须能看到完整结构。
- 地图里拖放 `PlacementMarker`，不要直接把 `Split` 场景当正式物体放进 `WorldActors`。
- `CompoundPropDefinition` 负责配置生成路径、透明度和跨层淡化规则。
- `AmbientSway2D` 只能挂视觉节点，不能挂碰撞节点、遮挡检测区域或参与 YSort 的主体根节点。
- `OcclusionFadeArea` 和视觉节点平级，表达“整个复合物体的遮挡检测”，不要藏在 `Canopy` 里。
- 同类资源新增前，先复制模板并改资源引用、碰撞范围、遮挡范围和摆动参数；不要复制运行时生成节点作为源资源。
