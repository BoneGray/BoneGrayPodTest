# Character Controller Refactor Design

本文档定义“角色本体”和“控制来源”分离的第一阶段规则。目标是让同一个角色以后可以被玩家输入、敌人 AI、测试脚本或剧情控制器驱动，而不是把“谁在控制”写死在 `Player` 或 `BaseEnemy` 里。

## 目标

- 支持后续“玩家控制 Zombie Big，AI 控制当前 Player”这类角色互换测试。
- 支持未来八方向角色、不同可玩角色和不同 AI 角色复用同一套高层结构。
- 保留当前 `navigation_obstacle_test_scene` 的可玩手感，不为了重构改动现有战斗表现。
- 让输入、AI 决策、移动、攻击、装备、动画层级保持清晰边界。

## 非目标

- 第一阶段不做角色选择 UI。
- 第一阶段不让 Big / Small / Axe 使用玩家装备系统。
- 第一阶段不让 AI 主动拾取、切换或丢弃玩家武器。
- 第一阶段不把所有 Player / Enemy 代码一次性拆成最终形态。
- 第一阶段不迁移到完整八方向动画，只预留方向抽象入口。

## 标准结构

角色最终应逐步靠近下面的结构：

```text
CharacterActor
+-- CharacterStateMachine
+-- CharacterMovementController
+-- CharacterCombatController
+-- CharacterVisualController
+-- CharacterStats 或 CharacterDefinition
+-- CharacterEquipmentController 可选
+-- Controller
    +-- PlayerInputController
    +-- EnemyAIController
    +-- ScriptedController 可选
```

当前阶段允许 `Player` 主脚本和 `BaseEnemy` 继续承接部分旧职责，但新增逻辑应逐步迁移到“控制器产出意图，角色执行意图”的模式。

## CharacterIntent

`CharacterIntent` 是控制器和角色之间的共同语言。它只描述“这一帧或这一小段时间想做什么”，不直接执行移动、攻击、动画、伤害或拾取。

基础字段：

```text
source                 意图来源，例如 player_input / ai / scripted
move_vector            期望移动方向
face_direction         期望朝向，允许为空，空值表示由角色按现有规则决定
primary_attack_pressed 本帧是否按下主攻击
primary_attack_held    主攻击是否持续按住
interact_pressed       本帧是否交互
target                 AI 或脚本控制时的目标
requested_action       可选动作名，例如 attack_first / attack_second / retrieve_weapon
```

规则：

- `CharacterIntent` 不保存血量、冷却、动画名、命中目标列表或节点层级。
- `CharacterIntent` 不直接调用 `move_and_slide()`、`take_damage()`、`play()` 或装备接口。
- 控制器可以读取世界状态来决定意图，但角色本体仍负责判断当前状态是否允许执行该意图。
- 角色进入 `Dead` 后必须忽略所有非清理类意图。

## 控制器职责

`PlayerInputController` 负责：

- 读取键盘、手柄或后续输入映射。
- 生成移动、朝向、攻击、交互意图。
- 不直接造成伤害。
- 不直接切动画。
- 不直接改装备节点。

`EnemyAIController` 负责：

- 搜索目标、评估追击、巡逻、攻击、找回武器等决策。
- 选择期望移动方向、目标和攻击动作。
- 不直接播放攻击动画。
- 不直接写入角色速度、碰撞、命中区域或死亡清理。

`CharacterActor` 负责：

- 根据状态机判断意图是否可执行。
- 把意图交给移动、战斗、装备和视觉控制器。
- 统一清理攻击、移动、眩晕、死亡、拾取等运行时状态。

## 当前角色约束

第一批覆盖角色：

```text
Player
Zombie Big
Zombie Small
Zombie Axe
```

第一阶段能力约束：

- 玩家控制 `Player`：保持现有移动、攻击、拾取、丢弃和武器逻辑。
- AI 控制 `Player`：后续只要求移动、追击和使用当前攻击配置；暂不主动拾取或换武器。
- 玩家控制 `Zombie Big`：后续只要求移动和使用 Big 自身攻击；暂不使用玩家装备系统。
- AI 控制 Big / Small / Axe：保持当前敌人追击、攻击、特殊攻击和生命周期逻辑。

## 迁移顺序

1. 新增 `CharacterIntent`，建立控制器和角色之间的共同数据格式。
2. 让 `PlayerInputMap` 或后续 `PlayerInputController` 能生成 `CharacterIntent`，但先不改变现有 Player 行为。
3. 让 `BaseEnemy` 或后续 `EnemyAIController` 能生成 `CharacterIntent`，但先保留当前敌人行为。
4. 把 Player 主脚本中的输入读取逐步改成消费 `CharacterIntent`。
5. 把 Enemy 主脚本中的 AI 决策逐步改成消费 `CharacterIntent`。
6. 新建控制器互换测试场景，验证“玩家控制 Big / AI 控制 Player”。

当前落地状态：

- `scripts/characters/character_intent.gd` 已建立基础意图数据结构。
- `scripts/characters/controllers/player_input_controller.gd` 已建立玩家输入到 `CharacterIntent` 的镜像入口。
- 当前 `Player` 主脚本已通过 `PlayerInputController` 读取移动向量、方向转换、主攻击按下和交互按下。
- 当前 `Player` 主脚本仍保留原攻击和交互执行方法，`CharacterIntent` 只统一输入判断入口。

## 验证范围

第一阶段验证：

```text
tools/validate_character_intent_baseline.gd
tools/validate_player_input_controller.gd
tools/validate_player_consumes_input_intent.gd
tools/validate_navigation_obstacle_test_scene.gd
```

后续迁移验证：

```text
tools/validate_player_input_intent.gd
tools/validate_enemy_ai_intent.gd
tools/validate_controller_swap_demo.gd
```

## 讨论规则

后续如果出现以下需求，需要先讨论玩法和架构，再改代码：

- 某个敌人变成可操控角色。
- 某个玩家角色交给 AI 控制。
- 新增八方向动画或方向规则。
- 新增角色专属装备能力。
- AI 角色拾取、丢弃或切换玩家武器。
- 控制器需要绕过角色状态机直接执行动作。

默认原则：先定义能力边界和意图字段，再接入具体角色。
