# Enemy Refactor Design

本文档定义第三步 `Enemy` 跟进的目标、边界、迁移顺序和需要确认的玩法问题。当前阶段先做诊断和结构约束，不直接改变 `Zombie Big`、`Zombie Small`、`Zombie Axe` 的现有可玩表现。

## 重构目标

`BaseEnemy` 当前已经承载了过多职责：

- 目标搜索、发现范围、丢失目标范围。
- 主状态切换和生命周期。
- 追击、巡逻、攻击站位、攻击槽管理。
- NavigationAgent2D、直接移动、分离推力和障碍绕行。
- 普通攻击、特殊攻击、投射物、穿越攻击、重击眩晕。
- 斧子投掷、落地、找回、无斧攻击和拾回动画。
- 受伤、死亡、死亡后禁用碰撞和逻辑。
- 动画播放、方向计算、死亡动画随机选择。
- AttackArea2D、HitboxArea2D、BodyCollisionShape2D 的读取和开关。

第三步目标不是一次性把 `BaseEnemy` 拆成最终形态，而是让敌人逐步靠近和 Player 类似的结构：

```text
Enemy
+-- EnemyStateMachine
+-- EnemyMovementController
+-- EnemyCombatController
+-- EnemyWeaponController 可选
+-- EnemyVisualController
+-- EnemyStats / EnemyDefinition
```

## 当前状态诊断

`BaseEnemy` 目前已有内部 `State`：

```text
IDLE
CHASE
APPROACH_ATTACK_SLOT
ATTACK
HURT
DEAD
PATROL
```

现有状态问题：

- `APPROACH_ATTACK_SLOT` 是攻击准备状态，但它同时混合了移动、站位、攻击选择和攻击槽进度判断。
- `HURT` 已存在枚举，但当前受伤主要表现为闪红反馈，没有形成完整受伤状态流。
- `RetrieveWeapon` 没有独立状态，斧子找回逻辑通过多个条件分支散落在无目标和有目标流程里。
- `DEAD` 的禁用逻辑已经比较明确，但死亡前后的清理职责仍散在 `die()`、`deactivate()`、`_disable_combat_logic()` 中。
- 攻击阶段没有统一 `Startup / Active / Recovery / Finished` 运行时对象，当前依赖 `attack_elapsed`、动画回调、命中帧和 profile 字典共同决定。

## 目标状态

第三步建议把敌人主状态统一为：

```text
Idle
Patrol
Chase
ApproachAttackSlot
Attack
RetrieveWeapon
Stunned
Dead
```

状态含义：

- `Idle`：没有目标，也没有必须执行的找回武器行为。
- `Patrol`：没有目标时的短距离随机移动。
- `Chase`：有有效目标，但还没有进入攻击站位或攻击提交。
- `ApproachAttackSlot`：近战敌人正在寻找或接近攻击槽。
- `Attack`：敌人已经提交一次攻击，进入攻击阶段控制。
- `RetrieveWeapon`：敌人需要找回自己掉落的武器，例如 `Zombie Axe`。
- `Stunned`：敌人被控制或硬直，后续如果加入玩家 stun/击退可使用。
- `Dead`：终态，禁止目标搜索、寻路、分离、攻击、拾取和碰撞。

## 模块边界

### EnemyStateMachine

负责：

- 当前主状态。
- 合法状态切换。
- 进入状态时初始化本状态运行时。
- 退出状态时清理本状态运行时。

不负责：

- 具体移动方向。
- 攻击命中。
- 动画资源选择。
- 特殊攻击数值。

### EnemyMovementController

负责：

- 追击方向。
- NavigationAgent2D 或直接移动策略。
- 分离推力。
- 巡逻移动。
- 攻击槽接近移动。
- 卡住/进度判断。

不负责：

- 选择攻击动作。
- 生成投射物。
- 造成伤害。
- 播放攻击动画。

### EnemyCombatController

负责：

- 当前攻击动作和攻击配置。
- 攻击类型：`melee`、`cross`、`projectile`、未来的 `leap`、`area` 等。
- 攻击阶段：`Startup`、`Active`、`Recovery`、`Finished`。
- 命中窗口和命中目标去重。
- 攻击槽进入攻击的提交条件。
- 特殊攻击可用性判断。
- 伤害、状态效果和冷却读取。

不负责：

- NavigationAgent2D 的路径更新。
- 实际场景节点的创建和挂载。
- 动画层级和 SpriteFrames 切换。

### EnemyWeaponController

当前只对 `Zombie Axe` 有明确需求。

负责：

- 是否持有武器。
- 投射物落地后登记可找回武器。
- 找回武器的目标位置、超时和进度判断。
- 拾回武器后的状态恢复。

不负责：

- 投射物飞行物理。
- 玩家拾取敌人武器。
- 通用掉落系统。

### EnemyVisualController

后续可拆，当前先不强制实现。

负责：

- idle/walk/attack/death 动画选择。
- 方向和 `last_horizontal_direction`。
- 有武器/无武器动画后缀。
- 死亡动画随机选择。
- sprite 偏移和受伤闪红。

## 现有敌人差异

### Zombie Big

当前规则：

- `attack_first`：普通近战。
- `attack_second`：重击近战，命中后给玩家 `stun`，持续约 `0.8` 秒。
- 移动速度较慢，生命较高。

重构注意：

- `attack_second` 应作为一个特殊 melee profile，而不是写死成 Big 专属分支。
- stun 应留在攻击配置里，由 `EnemyCombatController` 统一应用。

### Zombie Small

当前规则：

- `attack_first`：普通近战。
- `attack_second`：`cross` 穿越攻击。
- `cross` 会锁定攻击开始时的目标位置，身体穿过或绕到玩家另一侧。
- 命中方式使用 `hit_detection = "body_motion"`，根据身体扫过范围判断，而不是 AttackArea2D。

重构注意：

- `cross` 需要独立攻击类型处理。
- 攻击开始后不能持续追踪玩家，否则会导致闪现感和不可读。
- 死亡时必须冻结当前位置，不能继续执行 body motion。

### Zombie Axe

当前规则：

- `attack_first`：有斧普通近战。
- `attack_second`：投掷斧子，`type = "projectile"`。
- 投掷后进入无斧状态，可以使用 `attack_first_no_axe`。
- 斧子落地后，敌人优先找回自己的斧子。
- 如果玩家已经足够近，无斧状态可以优先近战，而不是强行捡斧。
- 隔墙时不能投掷，投射物也不能卡进墙里导致敌人永远捡不到。

重构注意：

- 斧子找回应进入 `RetrieveWeapon` 状态，而不是散在目标和巡逻判断中。
- 投射物是否命中墙、是否落地、是否注册 pickup，应归属 projectile/weapon retrieval 边界。
- 敌人投掷武器当前仍是敌人专属，玩家暂不能拾取。

## 攻击槽规则

当前攻击槽系统用于避免多只敌人挤在同一个方向攻击玩家。

保留规则：

- 近战敌人优先申请和自己相对方向一致的攻击槽。
- 已申请攻击槽后，不应因为固定时间太短就频繁换槽。
- 只有在卡住、不可达或明显没有进展时才放弃当前槽。
- 到达攻击槽后，即使根节点距离略超出基础攻击距离，也可以提交攻击；实际命中仍由命中窗口和命中形状决定。

第三步不建议一开始重写攻击槽管理器。应先把“申请、释放、排除方向、到达判断、卡住判断”收敛到清晰接口。

## 生命周期规则

死亡后必须立即停止：

```text
目标搜索
追击和寻路
分离推力
攻击槽申请和释放之外的攻击槽更新
攻击判定
投射物生成
武器找回
巡逻
受击监测
移动碰撞
HitboxArea2D
AttackArea2D
```

死亡后允许：

```text
播放死亡动画
保留尸体视觉
等待对象池或后续尸体清理系统回收
```

## 迁移顺序

第三步建议按以下顺序推进：

1. 新增 `EnemyStateMachine`，先只承接状态名、状态切换和基础合法性检查。
2. `BaseEnemy` 保留旧 `state` 字段作为兼容镜像，验证脚本仍可读取。
3. 把 `Dead`、`Idle`、`Patrol`、`Chase` 的进入/退出清理规则收敛到统一入口。
4. 新增 `EnemyCombatController`，先承接攻击配置读取、攻击类型、当前攻击运行时、命中目标去重。
5. 保留 `AttackArea2D`、投射物实例化、动画播放在 `BaseEnemy`，等边界稳定后再拆。
6. 把 `RetrieveWeapon` 从分支逻辑提升为显式状态，但不改变 `Zombie Axe` 当前行为。
7. 补充验证脚本或调整现有验证，证明 Big、Small、Axe 行为不回归。

## 当前验证资产

已有验证覆盖：

```text
tools/validate_enemy_attack_ai.gd
tools/validate_enemy_attack_alignment.gd
tools/validate_enemy_attack_slot_manager.gd
tools/validate_enemy_attack_slot_progress.gd
tools/validate_enemy_attacks_from_arrived_slot.gd
tools/validate_enemy_clears_dead_target.gd
tools/validate_dead_enemy_inactive.gd
tools/validate_enemy_detection_range.gd
tools/validate_enemy_directional_death.gd
tools/validate_enemy_directional_idle.gd
tools/validate_enemy_navigation_runtime.gd
tools/validate_enemy_single_close_stability.gd
tools/validate_navigation_obstacle_test_scene.gd
tools/validate_zombie_axe_setup.gd
tools/validate_zombie_small_death_alignment.gd
```

第三步每个切片至少应跑和改动相关的子集，结构迁移后建议跑完整敌人验证子集。

## 需要确认的玩法问题

这些问题不阻塞第三步第一刀，但在进入 EnemyCombatController 深拆前需要确认：

1. **特殊攻击选择规则**
   - Big 的重击是随机、按冷却、距离触发，还是玩家被其他敌人牵制时才触发？
   - Small 的穿越攻击是随机穿插，还是有独立冷却和最小距离？
   - Axe 的投掷是优先远程，还是与近战混合随机？

2. **攻击槽竞争规则**
   - 多只敌人围攻时，是否允许多个敌人在同一方向排队？
   - 攻击槽满了的敌人应该等待、绕路、还是短暂巡游？

3. **RetrieveWeapon 优先级**
   - Axe 无斧时，如果玩家在近处，优先近战已经成立；这个近处阈值后续是否要按敌人配置？
   - 找回斧子是否允许穿越危险区域或绕远路？

4. **Stunned 状态**
   - 敌人是否也会被玩家造成 stun？
   - 如果会，stun 是否打断所有攻击，包括投掷和 cross？

5. **尸体和对象池**
   - 死亡动画结束后，尸体是保留在场景中、延迟消失，还是进入对象池？
   - 如果进入对象池，尸体视觉是否需要单独的 corpse 节点保留？

## 第一刀完成标准

第三步第一刀完成后应满足：

- 有清晰的 Enemy 重构边界文档。
- 不改变现有敌人玩法表现。
- 明确哪些问题需要玩法确认。
- 下一步可以开始实现 `EnemyStateMachine`，且不会和现有验证脚本冲突。
