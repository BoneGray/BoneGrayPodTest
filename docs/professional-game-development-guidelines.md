# 专业化游戏开发通用规范

这份文档用于 GameZombieWorld，也作为后续 Godot 小型商业项目的通用开发基线。目标不是把项目做复杂，而是避免同类需求反复用临时分支解决。

## 核心原则

- 先识别系统概念，再实现具体对象。不要因为当前只有一把武器、一个敌人或一个道具，就写成单对象专用流程。
- 新增场景图片或地图物体前，先判断它属于完整交互物体、普通实体物体、纯视觉装饰，还是批量背景/地形装饰；资源结构和性能成本必须跟分类匹配。
- 先确定玩法规则和可维护边界，再写代码。涉及攻击方式、AI 决策、装备差异、拾取规则、状态效果、数值平衡时，必须先讨论可玩性和规则。
- 具体差异优先放在 Resource 配置里，流程代码只读取配置并执行通用逻辑。
- 如果一个需求会影响后续同类内容扩展，应先补齐公共模型，再接入当前资源。
- 测试要覆盖公共流程，而不是只覆盖某一把武器、某一个敌人或某一个场景。
- 文件、脚本、场景和资源命名必须跟当前职责一致。职责迁移后，不允许继续保留会误导开发的旧名称。

## 通用开发流程

1. 定义概念
   - 这个需求属于角色、装备、物品、战斗、AI、地图、渲染层级、UI 还是存档？
   - 它是否有未来同类对象，例如更多武器、更多工具、更多消耗品、更多敌人？

2. 抽取公共模型
   - 公共身份字段放到基础 Resource。
   - 公共运行时行为放到基础脚本或控制器。
   - 差异字段放到子 Resource 或 profile。
   - 不同对象只通过配置和少量策略差异区分。

3. 接入当前内容
   - 当前资源只作为公共模型的一个实例。
   - 不允许为当前资源写绕过公共模型的专属流程，除非它确实是唯一特殊机制，并且已经记录原因。

4. 验证公共流程
   - 测试应扫描同类资源或同类场景。
   - 新增资源后，理想情况下只改配置，不改 Player、Enemy 或主场景分支。

5. 更新文档和 skill
   - 架构规则进入 `docs/`。
   - 对 Codex 后续行为有约束的规则进入 `.codex/skills/`。
   - 如果这条规则对未来项目也适用，同步进入通用 skill。

## 命名与职责同步

- 脚本名应描述它现在承担的职责，而不是历史来源。
- 场景引用、工具脚本、验证脚本和文档必须在重命名时同步更新。
- 当一个脚本从测试对象演化成正式系统入口时，应立即迁移到对应目录和命名，例如玩家主脚本应位于 `scripts/player/player.gd`。
- 不要保留“看起来还能用”的旧文件名、旧路径或旧注释；它们会让后续排查和扩展走错方向。

## 物品与拾取系统规范

所有可以进入玩家背包、被拾取、被丢弃、在世界中显示的对象，都应先被看作 `Item`，再细分为武器、工具、消耗品、材料、任务物品或弹药。

当前基线：

```text
ItemData
+-- WeaponData

PickupItem
```

职责划分：

- `ItemData`：所有物品的公共数据，包含 `item_id`、`display_name`、`item_type`、`world_texture`、`icon_texture`、`pickup_scene_path`、堆叠规则。
- `WeaponData`：武器专属数据，继承 `ItemData`，只保存武器类型、装备动画、偏移、攻击 profile 等武器字段。
- `PickupItem`：世界中的通用可拾取物脚本，读取 `item_data`，根据 `item_type` 路由到玩家的装备、背包、消耗、弹药等处理入口。

规则：

- 新增地上物品时，优先创建或复用 `ItemData` 子类，不要新建一套 `xxx_pickup.gd`。
- 新增武器时，只应新增 `WeaponData`、资源、动画和拾取场景配置，不应在 Player 里写这把武器的专属拾取分支。
- 新增工具、消耗品或弹药时，应扩展 `ItemData` 子类和玩家的通用 `pickup_item` 路由，而不是复制武器拾取逻辑。
- 世界拾取场景统一使用 `item_data` 属性。旧的 `weapon_data` 入口已经废弃，不允许在新代码、场景或测试中继续出现。
- 可拾取物的表现，例如描边、上下浮动、进入可拾取范围后的反馈，应放在 `PickupItem` 的通用属性里。

## 武器与攻击系统规范

- 武器是物品的一种，不是独立于物品系统的特殊对象。
- 攻击行为由 `AttackProfile` 描述，武器数据只引用 profile。
- 同类型武器应走同一个控制器。例如枪械统一走 firearm controller，差别通过手部动画、枪口偏移、射速、弹丸、弹壳、散射等配置体现。
- 不要为单把枪、单把近战武器写 Player 专属分支。除非这是经过讨论确认的特殊机制，并且有独立 profile 或 controller 表达。
- `hold_repeat` 枪械应使用独立的 firearm hold session 表达“按住攻击键期间仍处于持续射击语义”。射击动画可以短于连发间隔，但会话必须继续锁定开火方向、应用移动减速，并在松开攻击键、眩晕、死亡或切换/丢弃武器时清理。
- `manual_attack_lockout`、`repeat_attack_cooldown` 和 firearm hold session 是互补关系：前两个控制攻击节奏，session 控制长按期间的持续状态，不要用拉长动画或硬编码单把枪分支替代 session。
- 可拦截飞行物应作为通用 projectile 能力处理。攻击是否能拦截由攻击 profile 配置，投射物接受哪些拦截由投射物自身配置；不要为单个敌人的投掷物或单把武器写名字特判。

## 文档与 Skill 维护规则

- 项目内实现细节写入项目文档，例如 `docs/architecture.md`、`docs/player-refactor-design.md`、`docs/render-layer-guidelines.md`。
- 通用开发原则写入本文件，并同步到通用 skill。
- 当一次需求暴露出开发方式问题，例如“为了单把武器写死逻辑”，要同时修代码和修规则。
- 后续项目开工时，先读取通用 skill，再创建项目自己的开发规范。

## 反例

不要这样做：

```text
BaseballBatPickup.gd
GunPickup.gd
PistolPickup.gd
ShotgunPickup.gd
Player._try_pickup_gun()
Player._try_pickup_bat()
```

推荐这样做：

```text
ItemData.item_type = weapon
WeaponData.primary_attack_profile = ...
PickupItem.item_data = weapon_data
Player.pickup_item(item_data)
Player.equip_weapon(weapon_data)
```

这样后续新增手枪、散弹枪、工具、药品、钥匙时，优先只是增加配置和少量类型路由，而不是不断复制场景专属逻辑。
