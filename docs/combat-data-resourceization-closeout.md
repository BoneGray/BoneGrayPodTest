# 战斗数据资源化收尾

本文记录第四步“战斗数据资源化”的当前完成范围、保留边界和后续入口。

## 完成范围

### Player / Weapon

玩家武器战斗数据以 `AttackProfile` 为主。

当前已经资源化的字段：

```text
profile_id
attack_type
animation_action
damage
cooldown
input_mode
repeat_mode
hold_to_repeat_delay
input_buffer_time
cancel_last_frames
startup_frames
active_frames
recovery_frames
movement_rule
hit_frames
max_targets
projectile_scene
projectile_speed
projectile_lifetime
projectile_blocked_by_mask
projectile_wall_backoff
wall_impact_scene
wall_impact_offset
wall_impact_hold_time
wall_impact_fade_time
wall_impact_pool_limit
muzzle_flash_scene
muzzle_flash_offsets
muzzle_flash_pool_limit
casing_scene
casing_offsets
casing_eject_speed
casing_speed_variance
casing_lifetime
casing_pool_limit
```

当前已有玩家攻击配置：

| 配置 | 输入模式 | 移动规则 | 说明 |
| --- | --- | --- | --- |
| `unarmed_primary_attack.tres` | `tap_combo` | `slow_turn_to_input` | 空手短按连击 |
| `unarmed_secondary_attack.tres` | `single_press` fallback | `slow_turn_to_input` | 保留给后续副攻击 |
| `baseball_bat_primary_attack.tres` | `tap_combo` | `slow_turn_to_input` | 木棒短按连击 |
| `baseball_bat_secondary_attack.tres` | `single_press` fallback | `slow_turn_to_input` | 木棒副攻击，当前未绑定输入 |
| `gun_primary_attack.tres` | `hold_repeat` | `slow_locked_direction` | 自动步枪长按连发 |

`WeaponData` 现在主要负责武器身份、视觉、拾取场景和攻击配置入口。

以下 `WeaponData` 字段只作为迁移 fallback 保留，新武器默认不填写：

```text
attack_power
attack_cooldown
repeat_while_held
hold_to_repeat_delay
```

### Enemy

敌人攻击配置以 `EnemyAttackProfile` 为主。

当前已有敌人攻击资源：

| 配置 | 类型 | 说明 |
| --- | --- | --- |
| `zombie_default_melee_attack.tres` | `melee` | Big / Small 默认近战 |
| `zombie_big_heavy_stun_attack.tres` | `melee` | Big 重击，命中后 stun |
| `zombie_small_cross_attack.tres` | `cross` | Small 穿越攻击，身体扫过判定 |
| `zombie_axe_melee_attack.tres` | `melee` | Axe 有斧近战 |
| `zombie_axe_no_weapon_melee_attack.tres` | `melee` | Axe 无斧近战 |
| `zombie_axe_throw_attack.tres` | `projectile` | Axe 丢斧子 |

当前 Big / Small / Axe 的所有 `attack_actions` 都已经有资源化 profile。

## 运行时边界

- `PlayerCombatController` 负责读取 `AttackProfile`，解释输入模式、阶段、冷却、伤害、命中帧、目标上限和攻击移动规则。
- `Player` 主脚本仍负责角色场景节点操作，例如动画播放、`AttackArea2D` 开关、装备视觉同步、发射起点和当前方向。
- `FirearmController` 负责枪械投射物、枪口火焰、弹壳、弹丸散射和枪械 `hold_repeat` 保留/清理规则。`Player` 不应按单把枪名称写分支。
- `EnemyCombatController` 负责敌人攻击选择权重、特殊攻击冷却、上下文权重、命中目标去重和伤害读取。
- `BaseEnemy` 仍负责敌人场景节点操作、动画播放、移动、导航、攻击槽和特定攻击执行入口。

## 保留的迁移 fallback

以下 fallback 是有意保留，不视为第四步未完成：

- `PlayerStats.attack_power` / `attack_cooldown`：角色没有武器或攻击 profile 缺少字段时的兜底值。
- `WeaponData.attack_power` / `attack_cooldown` / `repeat_while_held` / `hold_to_repeat_delay`：旧资源兼容字段，新武器不再使用。
- `EnemyStats.attack_power` / `attack_cooldown`：敌人默认攻击力和默认攻击冷却，单个 `EnemyAttackProfile` 可以覆盖伤害或特殊冷却。
- `EnemyStats.attack_profiles` 支持 Dictionary：旧数据兼容入口；新敌人默认使用 `EnemyAttackProfile` 资源。

## 验证脚本

第四步收尾后至少需要通过：

```text
tools/validate_player_weapon_attack_profiles.gd
tools/validate_repeat_attack_profile_generic.gd
tools/validate_gun_weapon_logic.gd
tools/validate_automatic_gun_fire.gd
tools/validate_bullet_wall_impact.gd
tools/validate_baseball_bat_pickup.gd
tools/validate_player_drop_weapon.gd
tools/validate_player_state_machine.gd
tools/validate_enemy_attack_profile_resources.gd
tools/validate_enemy_strategy_profiles.gd
tools/validate_enemy_combat_controller.gd
tools/validate_zombie_big_stun_attack.gd
tools/validate_zombie_small_cross_attack.gd
tools/validate_zombie_axe_setup.gd
tools/validate_zombie_axe_owner_bound_pickup.gd
tools/validate_navigation_obstacle_test_scene.gd
tools/validate_render_layer_baseline.gd
tools/validate_firearm_controller_baseline.gd
```

## 第四步完成标准

第四步可以视为完成，当满足：

- 玩家现有攻击的伤害、冷却、输入模式、阶段、命中帧、目标上限和攻击移动规则来自 `AttackProfile`。
- 木棒和自动步枪的 `WeaponData` 不再承载主要战斗数值，只作为攻击 profile 入口。
- 敌人现有攻击动作都有 `EnemyAttackProfile` 资源。
- 特殊攻击选择权重和冷却由 profile / stats 数据驱动，而不是硬编码在具体敌人分支里。
- 文档记录迁移 fallback，避免后续误以为 fallback 是推荐入口。
- Player / Enemy 关键验证脚本通过。

## 后续入口

第五步建议从以下方向选一个进入：

1. 拆 `PlayerEquipmentController`，让装备/拾取/丢弃和 Player 主脚本解耦。
2. 拆 `PlayerVisualController`，让身体、手部、武器层级和偏移统一管理。
3. 给新枪械建立新的 `AttackProfile`，验证散弹枪或半自动枪的不同手感。
4. 将 Enemy 巡逻、攻击槽或导航参数继续迁移到数据资源。
