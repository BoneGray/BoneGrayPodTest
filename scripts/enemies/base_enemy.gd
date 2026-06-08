extends CharacterBody2D
class_name BaseEnemy

signal died(enemy: Node)
signal health_changed(current: int, maximum: int)
signal attack_hit(target: Node)

enum State {
	IDLE,
	CHASE,
	ATTACK,
	HURT,
	DEAD,
}

@export var stats: Resource
@export var target_group := "player"
@export var start_state := State.IDLE
@export var auto_acquire_target := true
@export var path_refresh_interval := 0.25
@export var use_navigation_agent := true
@export var use_separation := true
@export var damage_log_enabled := true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_collision_shape: CollisionShape2D = $BodyCollisionShape2D
@onready var hitbox_area: Area2D = $HitboxArea2D
@onready var attack_area: Area2D = $AttackArea2D
@onready var attack_shape: CollisionShape2D = $AttackArea2D/CollisionShape2D
@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hurt_flash_feedback: Node = get_node_or_null("HurtFlashFeedback")

var health := 1
var state := State.IDLE
var target: Node2D
var current_direction := "down"
var attack_cooldown_remaining := 0.0
var path_refresh_remaining := 0.0
var _hit_targets: Array[Node] = []


func _ready() -> void:
	state = start_state
	health = get_max_health()
	_set_attack_active(false)
	_play_idle()
	health_changed.emit(health, get_max_health())
	if auto_acquire_target:
		call_deferred("_acquire_target")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		return

	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	path_refresh_remaining = maxf(path_refresh_remaining - delta, 0.0)
	if target == null and auto_acquire_target:
		_acquire_target()

	if state == State.CHASE:
		_chase_target(delta)
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_apply_active_attack_hits()


func configure_stats(new_stats: Resource) -> void:
	stats = new_stats
	health = get_max_health()
	health_changed.emit(health, get_max_health())


func set_target(new_target: Node2D) -> void:
	target = new_target
	if state != State.DEAD:
		state = State.CHASE if target != null else State.IDLE
		path_refresh_remaining = 0.0


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	var actual_damage := maxi(amount - get_defense(), 1)
	health = maxi(health - actual_damage, 0)
	if damage_log_enabled:
		print("%s 被打到了，受到 %d 点伤害，剩余血量 %d/%d" % [get_display_name(), actual_damage, health, get_max_health()])
	health_changed.emit(health, get_max_health())
	_flash_hurt()
	if health == 0:
		die()


func die() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD
	velocity = Vector2.ZERO
	_set_attack_active(false)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("first_death_side"):
		sprite.play("first_death_side")
	else:
		hide()
	died.emit(self)


func can_attack() -> bool:
	return target != null and attack_cooldown_remaining == 0.0 and global_position.distance_to(target.global_position) <= get_attack_range()


func begin_attack(animation_name := "first_attack") -> void:
	if state == State.DEAD or not can_attack():
		return

	state = State.ATTACK
	attack_cooldown_remaining = get_attack_cooldown()
	_hit_targets.clear()
	animation_name = _directional_animation_name(animation_name)
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)


func get_max_health() -> int:
	return stats.max_health if stats != null else 30


func get_current_health() -> int:
	return health


func get_display_name() -> String:
	return stats.display_name if stats != null else name


func get_move_speed() -> float:
	return stats.move_speed if stats != null else 45.0


func get_defense() -> int:
	return stats.defense if stats != null else 0


func get_attack_power() -> int:
	return stats.attack_power if stats != null else 8


func get_detect_range() -> float:
	return stats.detect_range if stats != null else 96.0


func get_lose_target_range() -> float:
	return stats.lose_target_range if stats != null else 144.0


func get_attack_range() -> float:
	return stats.attack_range if stats != null else 18.0


func get_attack_cooldown() -> float:
	return stats.attack_cooldown if stats != null else 1.2


func get_separation_radius() -> float:
	return stats.separation_radius if stats != null else 16.0


func get_separation_strength() -> float:
	return stats.separation_strength if stats != null else 0.35


func _chase_target(_delta: float) -> void:
	if target == null:
		state = State.IDLE
		velocity = Vector2.ZERO
		_play_idle()
		return

	var to_target := target.global_position - global_position
	if to_target.length() > get_lose_target_range():
		set_target(null)
		velocity = Vector2.ZERO
		_play_idle()
		return

	if to_target.length() <= get_attack_range():
		velocity = Vector2.ZERO
		current_direction = _direction_from_vector(to_target)
		_play_idle()
		return

	var direction := _get_path_direction(to_target)
	if use_separation:
		var separation := _get_separation_direction()
		if separation != Vector2.ZERO:
			direction = (direction + separation * get_separation_strength()).normalized()

	velocity = direction * get_move_speed()
	current_direction = _direction_from_vector(direction)
	_play_walk(direction)


func _acquire_target() -> void:
	var candidates := _get_target_candidates()
	var closest: Node2D
	var detect_range_squared := get_detect_range() * get_detect_range()
	var closest_distance := detect_range_squared
	for candidate in candidates:
		var candidate_node := candidate as Node2D
		if candidate_node == null:
			continue
		var distance := global_position.distance_squared_to(candidate_node.global_position)
		if distance <= closest_distance:
			closest = candidate_node
			closest_distance = distance

	set_target(closest)


func _get_target_candidates() -> Array[Node]:
	var candidates := get_tree().get_nodes_in_group(target_group)
	if not candidates.is_empty():
		return candidates

	var fallback_candidates: Array[Node] = []
	_collect_group_nodes(get_tree().root, fallback_candidates)
	return fallback_candidates


func _collect_group_nodes(node: Node, results: Array[Node]) -> void:
	if node.is_in_group(target_group):
		results.append(node)
	for child in node.get_children():
		_collect_group_nodes(child, results)


func _get_path_direction(to_target: Vector2) -> Vector2:
	if navigation_agent == null or not use_navigation_agent:
		return to_target.normalized()

	if path_refresh_remaining == 0.0:
		navigation_agent.target_position = target.global_position
		path_refresh_remaining = path_refresh_interval

	if navigation_agent.is_navigation_finished():
		return to_target.normalized()

	var next_position := navigation_agent.get_next_path_position()
	var to_next_position := next_position - global_position
	if to_next_position == Vector2.ZERO:
		return to_target.normalized()
	return to_next_position.normalized()


func _get_separation_direction() -> Vector2:
	var separation := Vector2.ZERO
	var radius := get_separation_radius()
	if radius <= 0.0:
		return separation

	for node in get_tree().get_nodes_in_group("enemy"):
		var other := node as Node2D
		if other == null or other == self:
			continue
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance <= 0.0 or distance >= radius:
			continue
		var weight := 1.0 - distance / radius
		separation += offset.normalized() * weight

	return separation.normalized() if separation != Vector2.ZERO else Vector2.ZERO


func _set_attack_active(active: bool) -> void:
	attack_area.monitoring = active
	attack_shape.disabled = not active


func _apply_attack_hits() -> void:
	for body in attack_area.get_overlapping_bodies():
		_try_hit_target(body)
	for area in attack_area.get_overlapping_areas():
		_try_hit_target(area)


func _apply_active_attack_hits() -> void:
	if attack_area.monitoring and not attack_shape.disabled:
		_apply_attack_hits()


func _try_hit_target(candidate: Node) -> void:
	var hit_target := _resolve_hit_target(candidate)
	if hit_target == null or hit_target in _hit_targets:
		return

	_hit_targets.append(hit_target)
	if hit_target.has_method("take_damage"):
		hit_target.take_damage(get_attack_power())
	attack_hit.emit(hit_target)


func _resolve_hit_target(candidate: Node) -> Node:
	var current := candidate
	while current != null:
		if target_group == "" or current.is_in_group(target_group):
			return current
		current = current.get_parent()
	return null


func _play_idle() -> void:
	var animation_name := "idle_%s" % current_direction
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != StringName(animation_name) or not sprite.is_playing():
			sprite.play(animation_name)


func _play_walk(direction: Vector2) -> void:
	var animation_name := "walk_side"
	if absf(direction.x) >= absf(direction.y):
		animation_name = "walk_side_left" if direction.x < 0.0 else "walk_side"
	elif direction.y < 0.0:
		animation_name = "walk_up"
	else:
		animation_name = "walk_down"

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != StringName(animation_name) or not sprite.is_playing():
			sprite.play(animation_name)


func _direction_from_vector(direction: Vector2) -> String:
	if direction == Vector2.ZERO:
		return current_direction
	if absf(direction.x) >= absf(direction.y):
		return "side_left" if direction.x < 0.0 else "side"
	return "up" if direction.y < 0.0 else "down"


func _directional_animation_name(animation_name: String) -> String:
	if animation_name.ends_with("_up") or animation_name.ends_with("_down") or animation_name.ends_with("_side") or animation_name.ends_with("_side_left"):
		return animation_name
	return "%s_%s" % [animation_name, current_direction]


func _flash_hurt() -> void:
	if hurt_flash_feedback != null and hurt_flash_feedback.has_method("play"):
		if hurt_flash_feedback.play():
			return

	sprite.modulate = Color(1.0, 0.25, 0.25)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
