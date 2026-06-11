extends Resource
class_name EnemyStats

@export_group("Identity")
## 敌人在日志、调试信息和后续 UI 中显示的名称。
@export var display_name := "Enemy"

@export_group("Base Stats")
## 最大生命值。受到伤害降到 0 后进入死亡流程。
@export var max_health := 30
## 基础移动速度，单位为像素/秒。
@export var move_speed := 45.0
## 防御力。受到伤害时会从原始伤害中扣除，至少保留 1 点实际伤害。
@export var defense := 0
## 默认攻击力。当具体攻击配置没有覆盖伤害时使用。
@export var attack_power := 8

@export_group("Attack")
## 敌人可选择的攻击动作列表，例如 attack_first、attack_second。
@export var attack_actions: Array[String] = ["attack_first"]
## 攻击配置字典，用于定义每个攻击动作的类型、伤害、范围、冷却、特殊效果等。
@export var attack_profiles := {}
## 进入攻击判定的基础距离，单位为像素。
@export var attack_range := 18.0
## 攻击冷却时间，单位为秒。
@export var attack_cooldown := 1.2

@export_group("Detection")
## 发现玩家的距离，单位为像素。
@export var detect_range := 96.0
## 丢失目标的距离，单位为像素。通常应大于 detect_range，避免反复进出追击状态。
@export var lose_target_range := 144.0

@export_group("Movement")
## 抗击退能力，预留给后续击退系统。值越高越不容易被击退。
@export var knockback_resistance := 0.0
## 与其他敌人保持距离的半径，单位为像素。
@export var separation_radius := 16.0
## 敌人相互排开的力度。值越大，拥挤时分散越明显。
@export var separation_strength := 0.35
