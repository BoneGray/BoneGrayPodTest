# 四步重构审计

本文用于判断当前项目是否已经满足前面约定的四步优化基线。结论先放前面：当前四步均已阶段达标，可以继续在此基础上扩展新武器、新敌人和战斗配置。

## 1. 标准结构

状态：已达标。

已完成内容：

- `docs/development-guidelines.md` 记录了项目开发规范、需求讨论规则、命名规则、属性描述规则和验证习惯。
- `docs/architecture.md` 记录了 Player、Enemy、Combat、Equipment、Item、Scene 的责任边界。
- `.codex/skills/gamezombieworld-development/SKILL.md` 已把核心文档列为进入项目开发时的来源。
- 新需求默认按“先确认玩法目标和规则，再进入实现”的方式推进。

本次补齐：

- 新增本文作为四步重构的审计入口。
- Skill 已补充本文和第四步收尾文档，避免后续只靠聊天记录判断项目状态。

保留项：

- 标准结构会随着新系统继续更新，但当前已经足够支撑后续 Gameplay 开发。

## 2. Player 先重构

状态：已达标。

已完成内容：

- Player 已有状态机、输入映射和战斗控制器分层，攻击逻辑不再直接散落在单一脚本里。
- Player 攻击阶段已按前摇、命中、后摇管理，并支持按武器配置移动规则。
- 拳头、木棒、自动步枪的攻击数据已进入 `AttackProfile` 资源。
- `WeaponData` 保留兼容字段，但新逻辑优先读取 `AttackProfile`。
- E 键承担拾取/丢弃，K 键不再承载旧拾取逻辑。

验证覆盖：

- `tools/validate_player_state_machine.gd`
- `tools/validate_player_weapon_attack_profiles.gd`
- `tools/validate_repeat_attack_profile_generic.gd`
- `tools/validate_gun_weapon_logic.gd`
- `tools/validate_automatic_gun_fire.gd`
- `tools/validate_player_drop_weapon.gd`

保留项：

- Player 的装备可视层、手部动画层级和节点引用仍可继续拆成更明确的 Visual/Equipment 控制器。
- 这属于下一轮工程整洁度优化，不阻塞当前第二步达标。

## 3. Enemy 再跟进

状态：已达标。

已完成内容：

- Enemy 已拆出状态机、移动控制器、战斗控制器和武器控制器。
- 普通追击、攻击槽位、特殊攻击、死亡生命周期和武器回收逻辑有了更明确的责任边界。
- Big、Small、Axe 的攻击行为已使用资源化攻击配置。
- Axe 的投掷武器归属和拾取逻辑已避免多只 Axe 互相抢斧子的基础问题。

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

保留项：

- Enemy 的视觉表现控制还可以继续拆出专门控制器。
- 追击距离、攻击槽位、巡逻范围等数值后续可以进一步资源化或统一进入 Stats/Profile。

## 4. 战斗数据资源化

状态：已达标。

已完成内容：

- Player 侧使用 `AttackProfile` 承载伤害、冷却、输入模式、连发规则、攻击阶段、移动规则、命中帧、最大命中目标、投射物、枪口火光、弹壳和墙体命中特效等数据。
- Enemy 侧使用 `EnemyAttackProfile` 承载攻击类型、伤害、冷却、范围、权重、特殊冷却、眩晕、穿越攻击、投掷物和运行时冷却字段。
- `docs/combat-data-resourceization-closeout.md` 已记录第四步收尾范围、迁移规则和验证结果。
- 新增或调整武器、敌人攻击方式时，应优先新增或修改资源文件，而不是把新数值写回脚本。

验证覆盖：

- Player 攻击资源验证已覆盖拳头、木棒和自动步枪。
- Enemy 攻击资源验证已覆盖 Big、Small、Axe。
- 棒球棍拾取、玩家丢弃武器、自动步枪、墙体弹孔、Axe 拾取等相关链路已做回归验证。

保留项：

- `WeaponData` 中的旧 combat 字段暂时保留为兼容兜底，新武器不应继续依赖它们。
- 部分平衡数值仍在具体场景或敌人 Stats 中，后续可在扩展关卡和难度系统时继续资源化。

## 后续建议

下一阶段可以从下面几个方向任选其一推进：

- 拆 Player Visual/Equipment 控制器，让手部、武器、枪口、弹壳、拾取物层级更容易维护。
- 把 Enemy 的追击、巡逻、攻击槽位和特殊攻击选择进一步数据化。
- 接入下一把枪械或散弹枪，用当前 `AttackProfile` 体系验证扩展性。
- 开始设计玩家装备栏、弹药、装填和武器耐久等系统。
