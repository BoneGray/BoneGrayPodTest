extends Area2D

@export var pickup_scene: PackedScene
@export var target_group := "player"
@export var default_speed := 120.0
@export var default_lifetime := 0.8
@export var default_damage := 8
@export var default_blocked_by_mask := 1
@export var wall_landing_backoff := 6.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var owner_enemy: Node
var direction := Vector2.RIGHT
var travel_direction_name := "side"
var speed := 120.0
var lifetime := 0.8
var damage := 8
var blocked_by_mask := 1
var elapsed := 0.0
var has_landed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func launch(source_enemy: Node, launch_direction: Vector2, direction_name: String, attack_profile: Dictionary) -> void:
	owner_enemy = source_enemy
	direction = launch_direction.normalized() if launch_direction != Vector2.ZERO else Vector2.RIGHT
	travel_direction_name = direction_name
	speed = float(attack_profile.get("projectile_speed", default_speed))
	lifetime = float(attack_profile.get("projectile_lifetime", default_lifetime))
	damage = int(attack_profile.get("damage", default_damage))
	blocked_by_mask = int(attack_profile.get("blocked_by_mask", default_blocked_by_mask))
	target_group = String(attack_profile.get("target_group", target_group))
	_play_thrown_animation()


func _physics_process(delta: float) -> void:
	if has_landed:
		return

	elapsed += delta
	var next_position := global_position + direction * speed * delta
	if _move_would_hit_wall(global_position, next_position):
		return
	global_position = next_position
	if elapsed >= lifetime:
		_land()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(candidate: Node) -> void:
	if has_landed:
		return

	var hit_target := _resolve_hit_target(candidate)
	if hit_target != null:
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(damage)
		_land()
		return

	if candidate is StaticBody2D or candidate is TileMapLayer:
		_land_against_wall()


func _move_would_hit_wall(from: Vector2, to: Vector2) -> bool:
	if blocked_by_mask <= 0:
		return false

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = blocked_by_mask
	query.exclude = [get_rid()]
	if owner_enemy != null and is_instance_valid(owner_enemy) and owner_enemy is CollisionObject2D:
		query.exclude.append((owner_enemy as CollisionObject2D).get_rid())
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	global_position = (hit["position"] as Vector2) - direction * wall_landing_backoff
	_land()
	return true


func _land_against_wall() -> void:
	global_position -= direction * wall_landing_backoff
	_land()


func _resolve_hit_target(candidate: Node) -> Node:
	var current := candidate
	while current != null:
		if target_group == "" or current.is_in_group(target_group):
			return current
		current = current.get_parent()
	return null


func _land() -> void:
	if has_landed:
		return

	has_landed = true
	set_physics_process(false)
	call_deferred("_finish_landing")


func _finish_landing() -> void:
	monitoring = false
	monitorable = false
	collision_shape.disabled = true

	var pickup := _spawn_pickup()
	if owner_enemy != null and is_instance_valid(owner_enemy) and owner_enemy.has_method("register_weapon_pickup"):
		owner_enemy.register_weapon_pickup(pickup)
	queue_free()


func _spawn_pickup() -> Node2D:
	if pickup_scene == null:
		return null

	var pickup := pickup_scene.instantiate() as Node2D
	if pickup == null:
		return null

	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(pickup)
	pickup.global_position = global_position
	if pickup.has_method("configure"):
		pickup.configure(owner_enemy, travel_direction_name)
	return pickup


func _play_thrown_animation() -> void:
	if sprite.sprite_frames == null:
		return

	var animation_name := "thrown_side"
	if travel_direction_name == "side_left":
		animation_name = "thrown_side_left"
	elif travel_direction_name == "up":
		animation_name = "thrown_up"
	elif travel_direction_name == "down":
		animation_name = "thrown_down"

	if not sprite.sprite_frames.has_animation(animation_name) and travel_direction_name in ["up", "down"]:
		animation_name = "thrown_vertical"
	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
