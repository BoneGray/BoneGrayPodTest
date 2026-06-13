# Player Refactor Design

## Firearm Reload State

枪械换弹属于独立的 Player 主状态，不属于 Attack 阶段。

当前规则：

- `Reload` 状态允许从 `Idle`、`Move`、`Attack` 进入。
- `Reload` 状态禁止开火和拾取交互。
- `Reload` 状态允许按武器配置减速移动，身体播放 idle/walk，手部/武器层播放 `reload_<direction>`。
- 换弹时间由手部/武器层 SpriteFrames 中对应 `reload_<direction>` 动画帧数和速度计算。
- 当前阶段保留无限备弹，只管理弹匣内子弹数。
- `WeaponData.magazine_size` 定义弹匣容量，`FirearmController` 持有运行时弹匣和换弹状态。
- `Stunned`、`Dead`、丢弃或移除武器必须打断换弹。
- 新枪械必须通过共享 reload 流程验证，不允许在 Player 中按单把枪写换弹分支。
- `R` 是枪械手动换弹键；只有当前武器是枪械、弹匣未满、且没有处于死亡/眩晕/换弹时才响应。
- `Attack` 中按 `R` 不立即打断当前射击，而是缓存换弹请求；当前攻击动画结束并清理命中窗口后，再进入 `Reload`。
- 如果换弹前属于 `hold_repeat` 枪械连发语义，并且换弹完成时玩家仍按住 `J`，则恢复连发并沿用换弹前锁定的射击方向。
- 如果换弹来自普通点按，或者换弹完成前玩家松开 `J`，则回到 `Idle` 或 `Move`，不自动开火。
- `Stunned`、`Dead`、丢弃武器或切换武器必须同时清理换弹状态和换弹后的连发恢复意图。
- 新枪械只能通过 `WeaponData` 和 `AttackProfile` 接入共享换弹流程，不允许在 `Player` 里按单把枪写换弹分支。

本文件定义 `Player` 第一阶段重构的目标、边界和执行顺序。当前阶段只做设计约束，不直接要求一次性拆完所有代码。

## 重构目标

`Player` 重构的核心目标不是“换一种写法”，而是解决现有逻辑互相污染的问题：

- 攻击动画结束后仍可能残留命中判定。
- 移动、攻击、连击、拾取、丢弃武器之间会互相抢控制权。
- 拳头、木棒、枪械的输入逻辑被混在同一段流程中。
- 动画、命中帧、移动减速、武器表现、手部层级之间缺少清晰边界。
- 后续新增武器、角色、状态效果时容易继续堆条件判断。

重构后，玩家行为应由状态机统一调度，由各控制器分别负责自己的职责。

## 第一阶段范围

第一阶段只处理 `Player`，暂时不重构敌人。

第一阶段包含：

- 定义玩家主状态。
- 定义攻击阶段。
- 定义输入模式。
- 定义模块职责。
- 定义运行时清理规则。
- 定义验证脚本覆盖范围。

第一阶段不包含：

- 新增复杂连招系统。
- 新增完整装备栏 UI。
- 重写全部动画资源。
- 重构所有敌人 AI。
- 一次性把所有脚本拆成最终形态。

## 玩家主状态

玩家同一时间只能处于一个主状态：

```text
Idle
Move
Attack
Pickup
Stunned
Dead
```

状态含义：

- `Idle`：没有移动、攻击、拾取、受控异常时的默认状态。
- `Move`：玩家主动移动中。
- `Attack`：玩家正在执行一次攻击流程。
- `Pickup`：玩家正在执行拾取或交互动作。
- `Stunned`：玩家被眩晕、硬直或强制控制。
- `Dead`：玩家死亡，停止输入、移动、攻击和拾取。

规则：

- 状态切换必须走统一入口，例如 `change_state(next_state)`。
- 状态进入时初始化本状态需要的数据。
- 状态退出时清理本状态留下的数据。
- 其他模块不能绕过状态机直接强行切换动画、攻击判定或移动锁定。

## 状态优先级

当多个事件同时发生时，优先级如下：

```text
Dead > Stunned > Attack > Pickup > Move > Idle
```

规则：

- `Dead` 可以打断所有状态。
- `Stunned` 可以打断移动、拾取和攻击，但不能打断死亡。
- `Attack` 可以允许受限移动，但仍由攻击状态拥有控制权。
- `Pickup` 不能在死亡、眩晕、攻击有效阶段中强行发生。
- `Move` 只在没有更高优先级状态时生效。

## 状态切换表

第一阶段先允许以下状态切换：

```text
Idle -> Move
Idle -> Attack
Move -> Attack
Attack -> Move
Attack -> Stunned
Stunned -> Idle
Dead -> 不允许切出
```

规则：

- `Idle -> Move`：玩家输入移动方向。
- `Idle -> Attack`：玩家按下攻击键并且当前允许攻击。
- `Move -> Attack`：玩家移动中按下攻击键，进入攻击状态并应用攻击移动规则。
- `Attack -> Move`：攻击正常结束，且玩家仍然有移动输入。
- `Attack -> Stunned`：玩家攻击中被眩晕或进入强制受控状态。
- `Stunned -> Idle`：眩晕结束，且没有移动输入和攻击输入。
- `Dead` 是终态，不能切回其他状态。

暂不开放的切换：

```text
Move -> Pickup
Attack -> Pickup
Pickup -> Attack
Stunned -> Attack
Dead -> Any
```

这些切换后续如果需要扩展，必须先定义玩法理由和优先级。

## 攻击阶段

每次攻击必须拆成四个阶段：

```text
Startup
Active
Recovery
Finished
```

阶段含义：

- `Startup`：前摇，播放准备动作，默认不能造成命中。
- `Active`：有效帧，允许命中、生成投射物、生成枪口火焰、抛弹壳等。
- `Recovery`：后摇，允许恢复移动、输入缓存、连段取消等。
- `Finished`：结束阶段，清理攻击运行时状态并回到合适主状态。

规则：

- 命中只能发生在 `Active`。
- 投射物生成只能发生在 `Active`。
- 后摇取消只能发生在 `Recovery`。
- 前摇取消只能发生在 `Startup`，取消后必须进入 `Idle`，让玩家可以顺利转向或进入其他允许状态。
- `Finished` 必须关闭 `AttackArea2D`，清空已命中目标，恢复移动速度和转向权限。

## 攻击中移动和转向

第一阶段保留当前可移动攻击手感，但把规则明确为攻击配置的一部分。

当前规则：

```text
拳头: 攻击中可慢速移动，可按输入方向调整攻击朝向
木棒: 攻击中可慢速移动，可按输入方向调整攻击朝向
自动步枪: 连发中可慢速移动，开火方向锁定为开始射击时的方向
```

规则：

- 攻击中移动速度由攻击状态或 `AttackProfile` 派生，不由移动代码临时决定。
- 近战攻击中允许按输入方向调整攻击朝向，身体动画、手部/武器表现和 `AttackArea2D` 必须同步切换。
- 自动步枪连发中不允许按移动输入改变开火方向；松开攻击键后才恢复正常转向。
- 攻击结束或取消后必须恢复正常移动速度和转向权限。

## 输入模式

玩家主攻击由 `AttackProfile.input_mode` 决定。

```text
single_press
tap_combo
hold_repeat
```

当前武器规则：

```text
拳头: tap_combo
木棒: tap_combo
自动步枪: hold_repeat
手枪: hold_repeat
散弹枪: hold_repeat
E 键: 拾取/丢弃
K 键: 暂时空置，什么都不做
```

模式规则：

- `single_press`：按一次只触发一次攻击，不缓存、不自动重复。
- `tap_combo`：短按可以在后摇窗口内缓存下一次攻击，不因为长按自动重复。
- `hold_repeat`：长按按冷却重复攻击，不使用短按后摇取消。
- `tap_combo` 的节奏主要由动画帧、命中帧和后摇取消窗口控制；攻击动画自然结束后应清理 lockout，避免长 lockout 把玩家锁到无法再次攻击。
- `manual_attack_lockout` 是手动点按起手的最小间隔，近战和枪械都适用。
- `repeat_attack_cooldown` 是持续按住时的重复攻击间隔，主要用于 `hold_repeat`。
- `hold_repeat` 的 repeat interval 是持续按住时的连发频率控制，不是点按后的硬锁时间。
- `hold_repeat` 如果攻击键仍然按住，攻击动画结束后应保留 runtime lockout，用它控制下一次自动触发。
- `hold_repeat` 如果攻击键已经松开，攻击动画结束后应清理 runtime lockout，让下一次点按可以立即重新开始。
- 如果未来某把枪需要限制点按频率，应通过弹药、换弹、枪机、蓄力或单独的 fire-rate lock 资源规则表达，不要混用当前 runtime lockout。

当前手感规则：

```text
拳头: 短按连击
木棒: 短按连击
自动步枪: 长按连发
攻击中: 允许减速移动
```

枪械行为基准：

```text
自动步枪是当前枪械运行时逻辑基准。
手枪、散弹枪和后续新增枪械默认继承自动步枪的 hold_repeat 运行时规则。
枪械攻击中允许减速移动，但默认锁定开火方向，不因移动输入改变当前射击方向。
枪械移动中不能清掉长按连发计时。
枪械差异优先放在 AttackProfile / WeaponData 数据里，例如伤害、冷却、弹丸数、散布、速度、生命周期、枪口偏移、弹壳偏移、换弹和弹药规则。
如需某把枪允许转向射击、蓄力、点按限速或特殊装填，必须先作为显式玩法例外讨论，并写入资源字段或专门控制器，不能直接在 Player 主流程增加隐式分支。
```

禁止规则：

- 不允许拳头或木棒进入 `hold_repeat` 运行时状态。
- 不允许自动步枪走 `tap_combo` 后摇取消逻辑。
- 不允许同一个攻击流程同时使用短按缓存和长按重复。

## 交互按键

第一阶段按键职责：

```text
J: 攻击
E: 拾取/丢弃
K: 空置，按下后什么都不做
```

`E` 键规则：

- 有当前武器时，优先丢弃当前武器。
- 没有当前武器且附近有可拾取物时，执行拾取。
- 没有当前武器且附近没有可拾取物时，什么都不发生。
- 死亡、眩晕、攻击有效帧中不能执行拾取/丢弃。

`K` 键规则：

- 当前阶段不绑定任何功能。
- 后续如果重新启用，必须先明确它属于战斗、交互、道具还是调试输入。

## 模块边界

目标结构：

```text
Player
+-- PlayerStateMachine
+-- PlayerMovementController
+-- PlayerCombatController
+-- PlayerEquipmentController
+-- PlayerVisualController
+-- PlayerStats
```

职责：

- `PlayerStateMachine`：唯一负责主状态和状态切换。
- `PlayerMovementController`：负责输入方向、移动速度、移动修正和 `move_and_slide`。
- `PlayerCombatController`：负责攻击请求、攻击阶段、命中窗口、伤害结算、攻击运行时清理。
- `PlayerEquipmentController`：负责当前武器、拾取、丢弃、攻击配置来源。
- `PlayerVisualController`：负责身体动画、手部动画、武器表现、层级、偏移和方向。
- `PlayerStats`：负责血量、攻击力、防御力、移动速度等数值。

第一阶段可以先保留部分代码在现有脚本里，但逻辑必须按这些边界重排，并为后续拆文件留出清晰接口。

## 控制权规则

状态机控制：

```text
当前主状态
是否允许移动
是否允许转向
是否允许攻击
是否允许拾取
```

战斗控制：

```text
当前攻击配置
当前攻击动作
当前攻击动画
当前攻击阶段
当前有效帧
已命中目标列表
```

移动控制：

```text
输入方向
基础速度
状态速度倍率
攻击速度倍率
最终速度
```

视觉控制：

```text
身体动画
手部动画
武器动画
方向
层级
偏移
```

装备控制：

```text
当前装备
默认空手配置
拾取候选
丢弃逻辑
攻击配置来源
```

## 运行时清理规则

进入或退出状态时必须清理对应数据。

攻击结束必须清理：

```text
AttackArea2D.monitoring
AttackArea2D/CollisionShape2D.disabled
已命中目标列表
当前攻击配置
当前攻击动作
当前攻击动画
当前攻击阶段
输入缓存
长按重复标记
攻击移动倍率
攻击转向锁定
```

lockout 清理必须按输入模式区分：

```text
tap_combo: 动画自然结束后清理 runtime lockout，避免长 lockout 锁住短按连击手感。
hold_repeat + 攻击键仍按住: 保留 runtime lockout，用 repeat_attack_cooldown 控制连发间隔。
hold_repeat + 攻击键已松开: 动画自然结束后清理 runtime lockout，下一次点按可以重新开火。
single_press: 是否保留 lockout 取决于该武器是否设计为强节奏单发；需要在 AttackProfile 或后续 fire-rate 规则中明确。
```

`hold_repeat` 的输入计时属于“按住攻击键”的运行时状态，不能被移动动画切换清掉。玩家一边按住枪械攻击一边移动时，移动/行走流程只能改变移动表现，不能重置 `primary_attack_hold_time`、`primary_attack_repeat_ready` 或 `primary_attack_repeat_active`。

移动开始必须确认：

```text
没有残留攻击有效判定
没有残留攻击移动倍率
没有残留攻击转向锁定
当前动画由视觉控制器决定
```

死亡必须清理：

```text
输入
移动
攻击
拾取
状态效果
攻击区域
可交互状态
```

## 数据来源

攻击数据优先来自 `AttackProfile`：

```text
input_mode
damage
manual_attack_lockout
repeat_attack_cooldown
startup_frames
active_frames
recovery_frames
cancel_last_frames
movement_speed_multiplier
allow_turning
projectile_scene
status_effect
```

玩家数据来自 `PlayerStats`，未来可以迁移到 `CharacterDefinition`：

```text
max_health
attack_power
defense
move_speed
pickup_range
can_equip_weapon
can_use_tool
```

规则：

- 武器差异写进资源，不写死在流程判断里。
- 角色差异写进角色数据，不写死在 `Player` 主脚本里。
- 视觉偏移优先由资源或配置提供，不靠运行时临时猜值。

## 第一阶段迁移顺序

建议按这个顺序执行：

1. 新增 `PlayerStateMachine` 的最小结构，只负责记录和切换主状态。
2. 把攻击运行时变量集中到攻击控制区域，禁止散落在输入、动画、移动流程里。
3. 把攻击阶段判断集中到 `PlayerCombatController` 或等价区域。
4. 把 `AttackProfile.input_mode` 的分支集中到一个入口。
5. 把移动速度倍率和转向锁定改成状态派生结果。
6. 把身体动画、手部动画、武器层级交给视觉控制区域统一处理。
7. 保留现有可玩效果，逐步删除旧的重复判断。

## 验证范围

第一阶段完成后至少验证：

```text
空手短按攻击可以命中，松开后不会进入长按重复状态。
木棒短按攻击可以命中，松开后不会进入长按重复状态。
自动步枪长按可以连续开火，松开后立即恢复移动和转向。
攻击结束后走路不会继续命中敌人。
攻击中允许移动时，移动速度只在攻击状态内降低。
丢弃武器后手部动画恢复正常。
眩晕和死亡可以正确打断攻击。
```

建议验证脚本：

```text
tools/validate_player_state_machine.gd
tools/validate_player_attack_phases.gd
tools/validate_repeat_attack_profile_generic.gd
tools/validate_automatic_gun_fire.gd
tools/validate_firearm_hold_repeat_all_weapons.gd
tools/validate_player_drop_weapon.gd
tools/validate_player_layered_weapon_visual.gd
```

## FirearmController 边界

枪械运行时由 `scripts/player/firearm_controller.gd` 承接。`Player` 只负责读取当前 `AttackProfile`、进入攻击状态、提供角色当前方向、发射起点和装备视觉偏移，然后把投射物、枪口火光、弹壳、散射和枪械 `hold_repeat` 的保留/清理规则交给 `FirearmController`。

规则：

- `Player` 不允许为 `gun`、`pistol`、`shotgun` 或后续单把枪增加专属分支。
- 枪械是否属于枪械运行时，由 `AttackProfile.attack_type = projectile` 或 `WeaponData.weapon_type = firearm` 判断。
- 枪械差异必须优先写在 `AttackProfile` / `WeaponData` 数据里，例如伤害、冷却、弹丸数量、散射角、弹速、生命周期、枪口偏移、弹壳偏移、弹壳速度和后续弹药/换弹规则。
- 如果某把枪需要不同于自动步枪基准的输入方式、转向规则、蓄力、装填或特殊射击，必须先作为显式玩法例外讨论，再新增资源字段或专门控制器，不要写进 `Player` 主流程。

相关验证：

```text
tools/validate_firearm_controller_baseline.gd
tools/validate_firearm_hold_repeat_all_weapons.gd
tools/validate_automatic_gun_fire.gd
```

## 第二步落地状态

当前 `Player` 重构第二步已经完成一轮可运行收尾，范围是“玩家攻击逻辑结构化”，不包含敌人重构和完整装备系统拆分。

已落地内容：

- `PlayerStateMachine` 已成为玩家主状态的权威来源，覆盖 `Idle`、`Move`、`Attack`、`Pickup`、`Stunned`、`Dead`。
- `PlayerInputMap` 已承接主攻击键、交互键和空置键的按键判断。
- `PlayerCombatController` 已承接攻击运行时和攻击配置读取：
  - 当前攻击配置、动作、动画、阶段。
  - 当前攻击是否到过命中窗口。
  - 已命中过的目标列表和最大目标数限制。
  - 主攻击输入缓冲、长按连发计时、连发状态。
  - `AttackProfile`、`WeaponData`、空手默认配置之间的读取优先级。
  - 攻击输入模式、攻击类型、命中帧、后摇取消帧、攻击力和冷却读取。
- 旧的 `PlayerAttackRuntime` 中间结构已被移除，避免出现两套攻击运行时来源。
- `Player` 主脚本仍保留部分兼容方法和调试镜像字段，例如 `_clear_attack_runtime_state()`、`_get_current_attack_hit_count()`、`_current_attack_action`。这些接口用于现有验证脚本和编辑器调试，真实状态以 `PlayerCombatController` 为准。

仍保留在 `Player` 主脚本中的职责：

- `AttackArea2D` 的节点开关、位置同步和重叠目标收集。
- 对命中目标调用 `take_damage()` 和发出 `attack_hit` 信号。
- 枪械投射物、枪口火焰、弹壳等场景节点生成已委托给 `FirearmController`；`Player` 只提供发射起点、方向和装备视觉偏移。
- 身体动画、手部/武器动画、层级和偏移同步。
- 装备拾取、丢弃和手部资源切换。

这些职责保留在主脚本里是当前阶段的有意选择，因为它们仍直接依赖场景节点和视觉层级。后续如果继续瘦身，应优先拆 `PlayerEquipmentController` 和 `PlayerVisualController`，而不是继续扩大 `PlayerCombatController` 或重新把枪械特例写回 `Player`。

当前已通过的核心验证：

```text
tools/validate_repeat_attack_profile_generic.gd
tools/validate_automatic_gun_fire.gd
tools/validate_firearm_hold_repeat_all_weapons.gd
tools/validate_player_state_machine.gd
tools/validate_player_attack_target_limits.gd
tools/validate_baseball_bat_pickup.gd
```

## 第三步入口

下一阶段进入 `Enemy` 跟进前，应先按玩家第二步的经验定义敌人边界，而不是直接改具体敌人脚本。

第三步建议顺序：

1. 梳理 `BaseEnemy` 当前状态、追击、攻击、死亡、特殊攻击、投掷物和拾取武器逻辑。
2. 定义 `EnemyStateMachine` 的最小状态集合，例如 `Idle`、`Patrol`、`Chase`、`Attack`、`RetrieveWeapon`、`Stunned`、`Dead`。
3. 定义 `EnemyCombatController` 承接攻击选择、攻击阶段、命中窗口、攻击槽和特殊攻击规则。
4. 保留现有 `big`、`small`、`axe` 的可玩效果，先迁移边界，再扩展新敌人。
5. 建立敌人验证脚本，覆盖追击、障碍绕行、攻击槽、死亡停止逻辑、特殊攻击和投掷物回收。

## 完成标准

第一阶段重构完成后，应满足：

- `Player` 的主状态有唯一权威来源。
- 攻击命中只在有效攻击阶段发生。
- 拳头、木棒、自动步枪不会共享错误的输入模式运行时状态。
- 移动、攻击、拾取、眩晕、死亡不会互相绕过状态机抢控制。
- 视觉层级和动画选择由视觉控制逻辑统一处理。
- 新增武器时主要改资源配置，而不是继续扩展 `Player` 主流程条件分支。

## 暂不处理的问题

这些问题不在第一阶段一次性处理：

- 完整装备栏和背包 UI。
- 多角色选择系统。
- 敌人统一状态机。
- 复杂连招树。
- 武器耐久、弹药背包、装填系统。
- 网络同步或存档系统。

这些内容后续应基于第一阶段的状态机和控制器边界继续扩展。

## Firearm Hold Session 规则

`hold_repeat` 枪械必须拥有独立于单次射击动画的持续射击会话。这个会话不替代 `manual_attack_lockout` 或 `repeat_attack_cooldown`，而是补充它们没有覆盖的“长按期间角色保持什么状态”的问题。

职责划分：

```text
manual_attack_lockout: 点按/第一枪后的手动输入最小间隔
repeat_attack_cooldown: 长按连发时两枪之间的自动开火间隔
firearm_hold_session: 按住攻击键期间的持续状态，负责锁定开火方向、减速移动和退出清理
```

规则：

- 按下主攻击键并使用 `hold_repeat` 枪械时，开始 `firearm_hold_session`，记录 `locked_fire_direction`。
- 会话存在期间，即使单次射击动画已经结束并回到 `idle` 或 `walk`，角色仍使用锁定方向显示和开火。
- 会话存在期间允许移动，但移动输入不改变当前开火方向，移动速度使用攻击移动倍率。
- 下一次自动开火由 `repeat_attack_cooldown` 决定，不由射击动画时长决定。
- 松开主攻击键、眩晕、死亡、丢弃/切换武器时，必须结束 `firearm_hold_session`。
- 新增枪械验证必须覆盖：原地长按连发、移动长按连发、拾取后长按连发，以及长按间隔中按其他方向移动仍保持锁定开火方向。
