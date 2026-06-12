# 2D 渲染层级规范

本文用于统一 GameZombieWorld 的世界遮挡、角色内部遮挡、拾取物、飞行物和建筑/树木的渲染规则。目标是让玩家游玩时看到的层级符合地图空间逻辑，而不是靠单个节点临时调 `z_index`。

## 核心原则

- 世界层级和角色内部层级是两套系统。
- 世界层级决定 Player、Enemy、地上物件、树干、墙体、车辆之间谁挡谁。
- 角色内部层级决定身体、头、手、武器、攻击特效之间谁挡谁。
- 世界遮挡优先由 `YSort` 解决；角色内部遮挡优先由角色 Visual 逻辑按方向/动画解决。
- 不通过把角色内部节点调到很高的正 `z_index` 来修局部问题，否则会破坏世界遮挡。

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
- 树应拆成两个逻辑部分：树干进入 WorldActors，树冠进入 HighOverlay。
- 建筑也应拆成底部/墙体/屋顶：可交互或可遮挡主体进入 WorldActors，屋顶和天花板进入 HighOverlay。

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
