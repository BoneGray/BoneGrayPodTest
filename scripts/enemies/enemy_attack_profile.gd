extends Resource
class_name EnemyAttackProfile

@export_group("Identity")
## 攻击动作名，例如 attack_first、attack_second、attack_first_no_axe。
@export var action_name := "attack_first"
## 攻击类型。当前敌人支持 melee、cross、leap、projectile。
@export_enum("melee", "cross", "leap", "projectile") var attack_type := "melee"

@export_group("Availability")
## 是否需要敌人当前持有武器。
@export var requires_weapon := false
## 是否需要敌人当前没有武器。
@export var requires_no_weapon := false
## 特殊攻击最小触发距离，单位为像素。小于 0 时不写入配置。
@export var min_range := -1.0
## 特殊攻击最大触发距离，单位为像素。小于 0 时不写入配置。
@export var max_range := -1.0
## 视线或投射物阻挡检测使用的碰撞层掩码。小于 0 时不写入配置。
@export var blocked_by_mask := -1

@export_group("Selection")
## 基础选择权重。值为 0 时，这个攻击不会被随机选择。
@export var selection_weight := 1.0
## 与上一次攻击相同时的权重倍率。
@export var repeat_weight_multiplier := 1.0
## 目标处于 stun 状态时的权重倍率。
@export var target_stunned_weight_multiplier := 1.0
## 独立特殊攻击冷却，单位为秒。小于等于 0 时不启用独立冷却。
@export var special_cooldown := 0.0
## 冷却范围下限。当前阶段如配置范围，先按该值作为固定冷却。
@export var special_cooldown_min := -1.0
## 冷却范围上限。预留给后续随机冷却。
@export var special_cooldown_max := -1.0

@export_group("Effect")
## 覆盖伤害。小于 0 时使用敌人默认 attack_power。
@export var damage := -1
## 攻击结束后的恢复时间，单位为秒。
@export var recovery := 0.0
## 命中后施加的状态效果，例如 stun。
@export var status_effect := ""
## 状态效果持续时间，单位为秒。
@export var status_duration := 0.0
## 是否在投射物生成后丢失武器。
@export var drop_weapon := false

@export_group("Motion")
## 运动型攻击的命中检测方式，例如 body_motion。
@export var hit_detection := ""
## cross 攻击穿越到目标另一侧的距离，单位为像素。小于 0 时不写入配置。
@export var cross_distance := -1.0
## cross 攻击位移持续时间，单位为秒。小于 0 时不写入配置。
@export var cross_duration := -1.0
## leap 攻击突进距离，单位为像素。小于 0 时不写入配置。
@export var leap_distance := -1.0
## leap 攻击突进持续时间，单位为秒。小于 0 时不写入配置。
@export var leap_duration := -1.0

@export_group("Projectile")
## 投射物场景路径。敌人投射物当前使用路径字符串，便于原有加载逻辑兼容。
@export_file("*.tscn") var projectile_scene := ""
## 投射物飞行速度，单位为像素/秒。小于 0 时不写入配置。
@export var projectile_speed := -1.0
## 投射物生命周期，单位为秒。小于 0 时不写入配置。
@export var projectile_lifetime := -1.0
## 投射物生成时间，单位为秒。小于 0 时不写入配置。
@export var projectile_spawn_time := -1.0
## 投射物生成偏移，单位为像素。小于 0 时不写入配置。
@export var projectile_spawn_offset := -1.0
## 投射物目标组。为空时使用投射物默认值。
@export var target_group := ""


func to_dictionary() -> Dictionary:
	var profile := {
		"type": attack_type,
		"selection_weight": selection_weight,
		"repeat_weight_multiplier": repeat_weight_multiplier,
		"target_stunned_weight_multiplier": target_stunned_weight_multiplier,
	}

	_put_if_true(profile, "requires_weapon", requires_weapon)
	_put_if_true(profile, "requires_no_weapon", requires_no_weapon)
	_put_if_non_negative_float(profile, "min_range", min_range)
	_put_if_non_negative_float(profile, "max_range", max_range)
	_put_if_non_negative_int(profile, "blocked_by_mask", blocked_by_mask)
	_put_if_positive_float(profile, "special_cooldown", special_cooldown)
	_put_if_non_negative_float(profile, "special_cooldown_min", special_cooldown_min)
	_put_if_non_negative_float(profile, "special_cooldown_max", special_cooldown_max)
	_put_if_non_negative_int(profile, "damage", damage)
	_put_if_positive_float(profile, "recovery", recovery)
	_put_if_not_empty(profile, "status_effect", status_effect)
	_put_if_positive_float(profile, "status_duration", status_duration)
	_put_if_true(profile, "drop_weapon", drop_weapon)
	_put_if_not_empty(profile, "hit_detection", hit_detection)
	_put_if_non_negative_float(profile, "cross_distance", cross_distance)
	_put_if_non_negative_float(profile, "cross_duration", cross_duration)
	_put_if_non_negative_float(profile, "leap_distance", leap_distance)
	_put_if_non_negative_float(profile, "leap_duration", leap_duration)
	_put_if_not_empty(profile, "projectile_scene", projectile_scene)
	_put_if_non_negative_float(profile, "projectile_speed", projectile_speed)
	_put_if_non_negative_float(profile, "projectile_lifetime", projectile_lifetime)
	_put_if_non_negative_float(profile, "projectile_spawn_time", projectile_spawn_time)
	_put_if_non_negative_float(profile, "projectile_spawn_offset", projectile_spawn_offset)
	_put_if_not_empty(profile, "target_group", target_group)
	return profile


func _put_if_true(profile: Dictionary, key: String, value: bool) -> void:
	if value:
		profile[key] = value


func _put_if_not_empty(profile: Dictionary, key: String, value: String) -> void:
	if value != "":
		profile[key] = value


func _put_if_positive_float(profile: Dictionary, key: String, value: float) -> void:
	if value > 0.0:
		profile[key] = value


func _put_if_non_negative_float(profile: Dictionary, key: String, value: float) -> void:
	if value >= 0.0:
		profile[key] = value


func _put_if_non_negative_int(profile: Dictionary, key: String, value: int) -> void:
	if value >= 0:
		profile[key] = value
