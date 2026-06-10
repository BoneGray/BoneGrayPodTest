extends Resource
class_name EnemyStats

@export var display_name := "Enemy"
@export var max_health := 30
@export var move_speed := 45.0
@export var defense := 0
@export var attack_power := 8
@export var attack_actions: Array[String] = ["attack_first"]
@export var attack_profiles := {}
@export var detect_range := 96.0
@export var lose_target_range := 144.0
@export var attack_range := 18.0
@export var attack_cooldown := 1.2
@export var knockback_resistance := 0.0
@export var separation_radius := 16.0
@export var separation_strength := 0.35
