# Enemy 数据资源化收尾审计

本文件用于判断 `BaseEnemy` 当前剩余导出属性应该继续留在场景节点上，还是迁移到 `EnemyStats` / 后续 `EnemyDefinition` 中。

原则：

- 如果数值描述敌人的玩法性格，应进入数据资源。
- 如果数值描述测试场景、节点接线、调试开关或临时运行方式，应留在场景节点。
- 不要一次性搬迁全部字段；按风险从低到高分批。

## 已经进入 EnemyStats 的字段

这些字段已经适合继续保留在 `EnemyStats` 中：

```text
display_name
max_health
move_speed
defense
attack_power
attack_actions
attack_profiles
attack_range
attack_cooldown
attack_selection_order
default_attack_weight
special_attack_weight_multiplier
melee_attack_weight_multiplier
detect_range
lose_target_range
knockback_resistance
separation_radius
separation_strength
weapon_pickup_range
no_weapon_close_attack_range
weapon_retrieval_timeout
weapon_retrieval_progress_epsilon
```

## 建议迁移到 EnemyStats 的字段

这些字段会影响敌人玩法差异，后续加新敌人时很可能需要单独调整，因此建议逐步迁移：

| 当前字段 | 建议归属 | 原因 | 迁移优先级 |
| --- | --- | --- | --- |
| `idle_patrol_enabled` | `EnemyStats` | 是否会巡逻属于敌人性格 | 中 |
| `idle_duration_min` / `idle_duration_max` | `EnemyStats` | 待机节奏会影响压迫感 | 中 |
| `patrol_duration_min` / `patrol_duration_max` | `EnemyStats` | 巡逻距离和频率属于敌人行为差异 | 中 |
| `patrol_speed_scale` | `EnemyStats` | 巡逻速度可区分快慢型敌人 | 中 |
| `attack_slot_start_range_padding` | `EnemyStats` 或 AttackSlot config | 不同体型敌人进入围攻的距离可能不同 | 中 |
| `attack_slot_exit_range_padding` | `EnemyStats` 或 AttackSlot config | 影响是否持续保留攻击槽 | 中 |
| `attack_slot_arrive_distance` | `EnemyStats` 或 AttackSlot config | 大体型/小体型敌人到位容差可能不同 | 中 |
| `attack_slot_timeout` | `EnemyStats` 或 AttackSlot config | 影响围攻重选频率 | 中 |
| `attack_slot_progress_epsilon` | `EnemyStats` 或 AttackSlot config | 影响卡住判断 | 低 |
| `attack_slot_reachable_distance` | `EnemyStats` 或 AttackSlot config | 影响绕障碍攻击位判断 | 中 |
| `direct_chase_range` | `EnemyStats` 或 Movement config | 近距离追击方式属于移动行为 | 中 |

## 建议保留在场景节点上的字段

这些字段更像场景接线、调试开关或当前原型运行方式，不建议现在迁入 `EnemyStats`：

| 当前字段 | 保留原因 |
| --- | --- |
| `stats` | 节点引用数据资源本身，应继续留在节点上 |
| `target_group` | 测试场景或阵营系统可能会覆盖，后续更适合进入 Faction/Team 系统 |
| `start_state` | 主要服务测试场景和调试摆放 |
| `auto_acquire_target` | 主要服务验证脚本和特殊场景控制 |
| `path_refresh_interval` | 当前和 NavigationAgent2D 运行方式绑定，先留在节点上 |
| `use_navigation_agent` | 当前仍处在寻路方案验证阶段，先留在节点上 |
| `use_separation` | 场景压测时常需要开关，先留在节点上 |
| `damage_log_enabled` | 纯调试开关 |
| `attack_blocked_by_mask` | 当前依赖场景碰撞层配置，后续若做统一 Layer 规范再迁移 |

## 推荐迁移顺序

1. **Axe 找回武器参数**
   已完成第一批迁移：`weapon_pickup_range`、`no_weapon_close_attack_range`、`weapon_retrieval_timeout`、`weapon_retrieval_progress_epsilon` 已进入 `EnemyStats`，`BaseEnemy` 保留节点导出值作为旧场景 fallback。

2. **巡逻参数**
   再迁移 idle / patrol 相关字段。它们能让 Big、Small、Axe 在脱战后的性格不同，但不影响战斗命中逻辑。

3. **攻击槽参数**
   最后迁移攻击槽参数。攻击槽会影响多敌人围攻、障碍绕行和攻击提交，改动时需要跑更多验证。

4. **Navigation / Line Of Sight 参数**
   暂不迁移。等寻路方案稳定后，再决定是放进 `EnemyStats`、场景配置，还是单独做 `EnemyMovementConfig`。

## 当前不建议做的事

- 不要一次性把 `BaseEnemy` 所有导出属性搬进 `EnemyStats`。
- 不要为了数据化而破坏现有场景可调试性。
- 不要在攻击槽系统还没有完全收敛前大改围攻参数来源。
- 不要把碰撞层 mask 提前数据化到敌人资源里，除非项目先统一碰撞层命名和用途。
