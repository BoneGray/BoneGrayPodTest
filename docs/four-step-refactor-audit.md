# 四步重构审计

本文用于判断当前项目是否满足前面约定的四步优化基线。结论：四步已经阶段达标，可以继续扩展新武器、新敌人和战斗配置。已经迁移到新标准的旧入口不再保留。

## 1. 标准结构

状态：已达标。

完成内容：

- `docs/development-guidelines.md` 记录项目开发规范、需求讨论规则、命名规则、属性描述规则和验证习惯。
- `docs/professional-game-development-guidelines.md` 记录通用专业化开发流程，要求先抽公共模型，再实现具体资源差异。
- `docs/architecture.md` 记录 Player、Enemy、Combat、Equipment、Item、Scene 的责任边界。
- `.codex/skills/gamezombieworld-development/SKILL.md` 已把核心文档列为进入项目开发时的来源。
- 新需求默认按“先确认玩法目标和规则，再进入实现”的方式推进。

当前要求：

- 不再为已经完成迁移的旧流程保留兼容入口。
- 如果确实需要阶段性延期清理，必须记录原因、所属系统、验证风险和删除触发条件。

## 2. Player 重构

状态：已达标。

完成内容：

- Player 已有状态机、输入映射和战斗控制器分层。
- Player 攻击阶段按前摇、有效帧、后摇管理。
- 拳头、木棒、枪械的攻击数据进入 `AttackProfile`。
- 玩家武器的战斗数值不再从 `WeaponData` 读取 fallback 字段。
- E 键承担拾取/丢弃，K 键当前不执行功能。

验证覆盖：

- `tools/validate_player_state_machine.gd`
- `tools/validate_player_weapon_attack_profiles.gd`
- `tools/validate_repeat_attack_profile_generic.gd`
- `tools/validate_firearm_weapon_logic.gd`
- `tools/validate_player_drop_weapon.gd`

正式待办：

- Player 的装备可视层、手部动画层级和节点引用后续可以继续拆成更明确的 Visual/Equipment 控制器。
- 这是下一轮工程整洁度优化，不是旧兼容入口。

## 3. Enemy 重构

状态：已达标。

完成内容：

- Enemy 已拆出状态机、移动控制器、战斗控制器和武器控制器。
- 普通追击、攻击槽位、特殊攻击、死亡生命周期和武器回收逻辑有明确责任边界。
- Big、Small、Axe 的攻击行为已使用资源化攻击配置。
- Axe 的投掷武器归属和拾取逻辑避免多只 Axe 互相抢同一把斧子。

验证覆盖：

- `tools/validate_enemy_state_machine.gd`
- `tools/validate_enemy_movement_controller.gd`
- `tools/validate_enemy_combat_controller.gd`
- `tools/validate_enemy_weapon_controller.gd`
- `tools/validate_enemy_attack_profile_resources.gd`
- `tools/validate_enemy_strategy_profiles.gd`
- `tools/validate_zombie_big_stun_attack.gd`
- `tools/validate_zombie_small_cross_attack.gd`
- `tools/validate_zombie_axe_owner_bound_pickup.gd`

正式待办：

- Enemy 的视觉表现控制可以继续拆出专门控制器。
- 追击距离、攻击槽位、巡逻范围等数值后续可以继续资源化到 Stats/Profile。

## 4. 战斗数据资源化

状态：已达标。

完成内容：

- Player 侧使用 `AttackProfile` 承载伤害、输入模式、连发规则、攻击阶段、移动规则、命中帧、最大命中目标、投射物、枪口火光、弹壳和墙体命中特效。
- Enemy 侧使用 `EnemyAttackProfile` 承载攻击类型、伤害、冷却、范围、权重、特殊冷却、眩晕、穿越攻击、投掷物和运行时冷却字段。
- `WeaponData` 只承载物品身份、视觉、拾取场景和攻击 profile 入口。
- 世界拾取物统一使用 `PickupItem.item_data`。
- `weapon_pickup.gd` 和 `weapon_data` 拾取属性入口已删除。

验证覆盖：

- Player 攻击资源验证覆盖拳头、木棒、手枪、步枪和散弹枪。
- Enemy 攻击资源验证覆盖 Big、Small、Axe。
- 拾取/丢弃、枪械连发、弹壳、墙体弹孔、Axe 拾取等链路都有回归验证。

当前硬规则：

- 不允许把玩家武器战斗数值写回 `WeaponData`。
- 不允许新建单武器拾取脚本。
- 不允许新场景使用 `weapon_data` 作为拾取属性。
- 新武器、新工具、新消耗品优先接入 `ItemData` / `PickupItem`。

## 后续建议

- 下一轮如果继续工程化，应优先拆 Player Visual/Equipment 控制器和 Enemy Visual 控制器。
- 新功能进入项目时，先判断是否属于已有公共模型；如果是，优先补配置和 profile，不写单对象分支。
