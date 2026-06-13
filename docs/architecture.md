# Architecture Standards

本文件记录 GameZombieWorld 后续可维护原型阶段的架构方向。新需求实现前，优先检查本文件，避免为了快速看到效果而继续把逻辑堆进过载脚本。

## 开发姿态

项目从“快速功能原型”进入“可维护原型”。新的玩法、AI、战斗、装备、动画、碰撞、角色需求，不再默认先做临时效果。

实现前必须确认：

- 这个需求应该由哪个系统负责。
- 当前架构是否能干净承载这个需求。
- 如果缺少前置架构，先说明需要完成哪些阶段。
- 优先分阶段实现，不把新玩法硬塞进已有大脚本。
- 保持可验证，但不为了马上看到效果牺牲系统边界。

如果需求暂时不能干净执行，需要明确说明前置阶段，例如：

```text
这个需求依赖 PlayerStateMachine，需要先完成玩家状态机拆分。
这个需求依赖 AttackProfile 阶段数据，需要先补齐攻击阶段配置。
这个需求依赖 EnemyStateMachine，需要先统一敌人状态流转。
这个需求依赖 EquipmentController，需要先整理装备控制边界。
```

## 角色模块标准

玩家和敌人应逐步靠近同一套高层结构：

```text
CharacterBody2D
+-- StateMachine
+-- VisualController
+-- MovementController
+-- CombatController
+-- EquipmentController 可选
+-- Stats 或 CharacterDefinition
+-- Controller 可选，产出 CharacterIntent
+-- Sprite / visual nodes
+-- BodyCollisionShape2D
+-- HitboxArea2D
+-- AttackArea2D
```

职责划分：

- `StateMachine` 负责当前行为状态和状态切换。
- `VisualController` 负责动画、层级、偏移、朝向和表现。
- `MovementController` 负责移动方向、速度修正和移动碰撞意图。
- `CombatController` 负责攻击执行、命中窗口、伤害结算和战斗反馈。
- `EquipmentController` 负责武器/工具的装备、卸下、拾取、丢弃和攻击配置来源。
- `Stats` 或 `CharacterDefinition` 负责数据，不负责行为。
- `Controller` 负责控制来源，例如玩家输入、敌人 AI 或脚本控制；它只产出 `CharacterIntent`，不直接改动画、伤害、碰撞或装备。

当前代码不要求一次性拆完，但新增功能应朝这些边界迁移。

如果一个需求需要“玩家控制敌人”或“AI 控制玩家”，应先参考 `docs/character-controller-refactor-design.md`，按 `Controller -> CharacterIntent -> CharacterActor` 的方向迁移，而不是为某个场景写专属输入或 AI 分支。

## 玩家状态标准

玩家应逐步使用明确状态：

```text
Idle
Move
Attack
Pickup
Stunned
Dead
```

规则：

- 同一时间只能有一个主状态拥有行为控制权。
- 状态切换必须经过统一入口。
- 状态进入和退出时清理自己拥有的运行时数据。
- 移动、攻击、拾取、眩晕、死亡不能各自绕过状态所有者去强行改动画和碰撞。

目标写法：

```gdscript
change_state(PlayerState.ATTACK)
change_state(PlayerState.STUNNED)
change_state(PlayerState.DEAD)
```

## 攻击阶段标准

攻击应被描述为几个阶段：

```text
Startup
Active
Recovery
Finished
```

规则：

- `Startup` 是前摇，默认不造成命中，除非配置明确允许。
- `Active` 是有效帧，命中、投射物生成、特殊效果应发生在这里。
- `Recovery` 是后摇，连段取消、输入缓存、恢复控制权等规则应发生在这里。
- `Finished` 负责清理攻击运行时状态，并把控制权交还给主状态机。

命中检测不能只依赖 `AttackArea2D.monitoring` 或动画轨道残留值，还必须同时匹配当前攻击动作、当前攻击动画和当前有效阶段。

## 输入模式标准

玩家主攻击由 `AttackProfile.input_mode` 决定：

```text
single_press
tap_combo
hold_repeat
```

规则：

- `single_press`：按一次只攻击一次。
- `tap_combo`：短按缓存和后摇取消，不使用长按自动重复。
- `hold_repeat`：按住按冷却自动重复，不使用短按连段取消。

除非未来明确设计某种混合武器，否则不要把三种输入模式混在同一套武器逻辑里。

当前默认：

```text
Unarmed: tap_combo
Baseball bat: tap_combo
Automatic gun: hold_repeat
```

## 碰撞职责标准

碰撞职责必须保持分离：

```text
BodyCollisionShape2D  移动阻挡
HitboxArea2D          被攻击范围
AttackArea2D          攻击命中范围
PickupArea2D          拾取范围
```

规则：

- 移动碰撞不能复用为受击范围。
- 受击范围不能复用为移动阻挡。
- 攻击范围只在有效攻击阶段启用。
- 拾取检测不绑定到战斗命中检测。

## 数据资源标准

战斗和装备行为应逐步数据驱动。

`AttackProfile` 应逐步覆盖：

```text
input_mode
damage
attack interval
startup_frames
active_frames
recovery_frames
cancel_window
movement_rule
hit_shape
projectile_scene
status_effect
```

`CharacterDefinition` 应逐步覆盖：

```text
display_name
base_stats
visual_resource
default_attack_profile
can_equip_weapon
can_use_tool
equipment_slots
```

脚本代码应通过清晰接口消费这些资源，避免把武器、敌人、角色差异写死在流程代码里。

## 敌人状态标准

敌人行为也应逐步使用明确状态：

```text
Idle
Patrol
Chase
Attack
RetrieveWeapon
Stunned
Dead
```

规则：

- AI 决策负责选择状态。
- 状态本身负责执行细节。
- 特殊攻击由攻击数据和状态规则描述，不散落在条件分支里。
- 死亡敌人不能继续执行分离、寻路、攻击、目标检测或拾取判断。

## 验证标准

每次有意义的系统改动，都应该补充或更新聚焦的验证脚本或测试场景。

最低验证分类：

```text
player movement
unarmed attack
melee weapon attack
firearm attack
pickup and drop
hurt and death
enemy chase and attack
enemy special attack
```

架构改动的验证目标不只是“场景能加载”，还要证明行为边界没有互相污染。
