extends Resource
class_name PlayerStats

@export_group("Identity")
## 玩家角色在日志、调试信息和后续 UI 中显示的名称。
@export var display_name := "Player"

@export_group("Base Stats")
## 最大生命值。受到伤害降到 0 后进入死亡流程。
@export var max_health := 100
## 基础移动速度，单位为像素/秒。
@export var move_speed := 90.0
## 防御力。受到伤害时会从原始伤害中扣除，至少保留 1 点实际伤害。
@export var defense := 0

@export_group("Attack")
## 默认攻击力。当当前武器没有覆盖攻击力时使用。
@export var attack_power := 10
## 默认攻击冷却时间，单位为秒。当当前武器没有覆盖冷却时使用。
@export var attack_cooldown := 0.35

@export_group("Damage")
## 受伤后的无敌时间，单位为秒，用于避免短时间内连续吃到多次伤害。
@export var invincible_time := 0.35
