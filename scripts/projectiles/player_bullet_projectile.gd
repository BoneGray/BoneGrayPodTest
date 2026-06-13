extends Area2D

const ProjectileInterceptUtil = preload("res://scripts/combat/projectile_intercept.gd")

@export_group("Target")
## 子弹可命中的目标组名。玩家子弹通常命中 enemy。
@export var target_group := "enemy"

@export_group("Defaults")
## 默认飞行速度，单位为像素/秒。攻击配置可以覆盖该值。
@export var default_speed := 180.0
## 默认存在时间，单位为秒。超过该时间后子弹会销毁。
@export var default_lifetime := 0.8
## 默认伤害值。攻击配置可以覆盖该值。
@export var default_damage := 10
## 默认阻挡碰撞层掩码，用于判断墙体或障碍是否挡住子弹。
@export var default_blocked_by_mask := 1
## 命中墙体时从碰撞点向后退的距离，避免视觉上嵌入墙体。
@export var wall_backoff := 2.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

var owner_node: Node
var direction := Vector2.RIGHT
var speed := 180.0
var lifetime := 0.8
var damage := 10
var blocked_by_mask := 1
var elapsed := 0.0
var attack_profile: Resource
var _hit_targets: Array[Node] = []
var _blocked_on_launch := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func launch(source: Node, launch_direction: Vector2, attack_profile: Resource, override_target_group := "") -> void:
	owner_node = source
	self.attack_profile = attack_profile
	direction = launch_direction.normalized() if launch_direction != Vector2.ZERO else Vector2.RIGHT
	if attack_profile != null:
		speed = float(attack_profile.get("projectile_speed"))
		lifetime = float(attack_profile.get("projectile_lifetime"))
		damage = int(attack_profile.get("damage"))
		blocked_by_mask = int(attack_profile.get("projectile_blocked_by_mask"))
		wall_backoff = float(attack_profile.get("projectile_wall_backoff"))
	if speed <= 0.0:
		speed = default_speed
	if lifetime <= 0.0:
		lifetime = default_lifetime
	if damage <= 0:
		damage = default_damage
	if blocked_by_mask <= 0:
		blocked_by_mask = default_blocked_by_mask
	if override_target_group != "":
		target_group = override_target_group
	rotation = direction.angle()
	_blocked_on_launch = _spawn_would_hit_wall()
	set_meta("blocked_on_launch", _blocked_on_launch)


func _physics_process(delta: float) -> void:
	if _blocked_on_launch:
		return

	elapsed += delta
	var next_position := global_position + direction * speed * delta
	if _move_would_hit_wall(global_position, next_position):
		return

	global_position = next_position
	if elapsed >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(candidate: Node) -> void:
	if ProjectileInterceptUtil.try_intercept(candidate, attack_profile, owner_node) != null:
		queue_free()
		return

	var hit_target := _resolve_hit_target(candidate)
	if hit_target == null or hit_target in _hit_targets:
		return

	_hit_targets.append(hit_target)
	if hit_target.has_method("take_damage"):
		hit_target.take_damage(damage)
	queue_free()


func _move_would_hit_wall(from: Vector2, to: Vector2) -> bool:
	if blocked_by_mask <= 0:
		return false

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = blocked_by_mask
	query.hit_from_inside = true
	query.exclude = [get_rid()]
	if owner_node != null and is_instance_valid(owner_node) and owner_node is CollisionObject2D:
		query.exclude.append((owner_node as CollisionObject2D).get_rid())
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var hit_position := hit["position"] as Vector2
	var hit_normal := hit.get("normal", -direction) as Vector2
	_spawn_wall_impact(hit_position, hit_normal)
	global_position = hit_position - direction * wall_backoff
	queue_free()
	return true


func _spawn_would_hit_wall() -> bool:
	set_meta("launch_wall_probe_checked", true)
	if owner_node == null or not is_instance_valid(owner_node):
		set_meta("launch_wall_probe_reason", "missing_owner")
		return false

	var source := owner_node as Node2D
	if source == null:
		set_meta("launch_wall_probe_reason", "owner_not_node2d")
		return false

	var from := source.global_position
	set_meta("launch_wall_probe_from", from)
	set_meta("launch_wall_probe_to", global_position)
	if from.distance_squared_to(global_position) <= 0.01:
		set_meta("launch_wall_probe_reason", "zero_length")
		return false
	var hit_wall := _move_would_hit_wall(from, global_position)
	set_meta("launch_wall_probe_reason", "hit" if hit_wall else "clear")
	return hit_wall


func _spawn_wall_impact(hit_position: Vector2, hit_normal: Vector2) -> void:
	if attack_profile == null:
		return

	var wall_impact_scene := attack_profile.get("wall_impact_scene") as PackedScene
	if wall_impact_scene == null:
		return

	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return

	var impact := _spawn_effect_node(wall_impact_scene, parent, "bullet_impact", int(attack_profile.get("wall_impact_pool_limit")))
	if impact == null:
		return
	var impact_offset := float(attack_profile.get("wall_impact_offset"))
	impact.global_position = hit_position + hit_normal.normalized() * impact_offset
	if impact.has_method("configure"):
		impact.configure(hit_normal, float(attack_profile.get("wall_impact_hold_time")), float(attack_profile.get("wall_impact_fade_time")))


func _spawn_effect_node(effect_scene: PackedScene, parent: Node, category: String, limit: int) -> Node2D:
	var effect_manager := get_node_or_null("/root/EffectManager")
	if effect_manager != null and effect_manager.has_method("spawn_effect"):
		return effect_manager.spawn_effect(effect_scene, parent, category, limit) as Node2D
	var effect := effect_scene.instantiate() as Node2D
	if effect != null:
		parent.add_child(effect)
	return effect


func _resolve_hit_target(candidate: Node) -> Node:
	var current := candidate
	while current != null:
		if target_group == "" or current.is_in_group(target_group):
			return current
		current = current.get_parent()
	return null
