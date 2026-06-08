# Development Guidelines

## 需求实现原则

- 新需求先按专业游戏开发的标准流程拆解，再决定具体实现。
- 优先区分系统职责，不把不同概念混在同一个节点或脚本里。
- 遇到 Godot 已有的标准节点、资源和调试能力时，优先使用引擎原生方案。
- 只有在原生方案不能满足玩法、调试或表现需求时，才添加额外自定义节点或脚本。
- 先说明关键概念差异，再实现。例如移动碰撞、受击范围、攻击范围应分别建模。
- 保持测试场景独立，让 `Player`、`Enemy`、地图、相机等对象可以拖拽组合验证。
- 任何会影响后续扩展的结构性改动，都要优先考虑标准结构，而不是只修眼前效果。

## Godot 结构约定

- 角色移动阻挡使用 `CharacterBody2D` 或合适的物理体配合 `CollisionShape2D`。
- 静态障碍使用 `StaticBody2D`、TileSet Physics Layer 或等价的 Godot 物理碰撞方案。
- 受击判断使用 `HitboxArea2D`，攻击判断使用 `AttackArea2D`。
- `AnimatedSprite2D` 只负责显示动画，不承担移动碰撞职责。
- `AnimationPlayer` 可以控制攻击帧、命中窗口和与动画强相关的状态。
- 调试碰撞优先使用 Godot 的可见碰撞形状，而不是额外绘制重复的调试节点。

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
- 这个实现会不会让后续敌人、地图、关卡或动画系统变难？
- 是否需要独立测试场景验证，而不是直接堆到主场景？
