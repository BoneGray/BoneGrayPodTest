@tool
extends SceneTree

const BULLET_SCENE_PATH := "res://scenes/projectiles/player_bullet_projectile.tscn"
const GUN_ATTACK_PATH := "res://resources/equipment/weapons/gun/gun_primary_attack.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bullet_scene := load(BULLET_SCENE_PATH) as PackedScene
	var attack_profile := load(GUN_ATTACK_PATH) as Resource
	if bullet_scene == null or attack_profile == null:
		_fail(null, "Could not load bullet scene or gun attack profile.")
		return
	if attack_profile.get("wall_impact_scene") == null:
		_fail(null, "Gun attack profile should configure wall impact scene.")
		return

	var root := Node2D.new()
	get_root().add_child(root)
	var effect_manager := get_root().get_node_or_null("EffectManager")
	if effect_manager != null and effect_manager.has_method("reset_debug_counts"):
		effect_manager.reset_debug_counts()

	var directions := {
		"right": Vector2.RIGHT,
		"left": Vector2.LEFT,
		"down": Vector2.DOWN,
		"up": Vector2.UP,
	}
	for direction_name in directions:
		var direction := directions[direction_name] as Vector2
		if not await _validate_travel_hits_wall(root, bullet_scene, attack_profile, direction_name, direction):
			return
		if not await _validate_spawn_probe_hits_wall(root, bullet_scene, attack_profile, direction_name, direction):
			return

	print("Bullet wall impact is valid.")
	root.queue_free()
	quit()


func _validate_travel_hits_wall(root: Node2D, bullet_scene: PackedScene, attack_profile: Resource, direction_name: String, direction: Vector2) -> bool:
	var wall := _create_wall(direction * 24.0, direction)
	root.add_child(wall)
	await physics_frame
	await physics_frame

	var before_count := _count_impacts(root)
	var bullet := bullet_scene.instantiate() as Area2D
	root.add_child(bullet)
	bullet.global_position = Vector2.ZERO
	bullet.call("launch", null, direction, attack_profile, "enemy")

	for frame in 20:
		await physics_frame

	var after_count := _count_impacts(root)
	wall.queue_free()
	if after_count - before_count != 1:
		_fail(root, "Bullet should spawn one wall impact when travelling %s into a wall." % direction_name)
		return false
	return true


func _validate_spawn_probe_hits_wall(root: Node2D, bullet_scene: PackedScene, attack_profile: Resource, direction_name: String, direction: Vector2) -> bool:
	var owner := CharacterBody2D.new()
	owner.name = "ProjectileOwner"
	owner.collision_layer = 2
	owner.collision_mask = 1
	root.add_child(owner)
	owner.global_position = Vector2.ZERO

	var wall := _create_wall(direction * 8.0, direction)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	if not _ray_hits_wall(root, Vector2.ZERO, direction * 16.0):
		_fail(root, "Validation ray should hit the %s wall before checking bullet launch." % direction_name)
		return false

	var before_count := _count_impacts(root)
	var bullet := bullet_scene.instantiate() as Area2D
	root.add_child(bullet)
	bullet.global_position = direction * 16.0
	bullet.call("launch", owner, direction, attack_profile, "enemy")
	var blocked_on_launch := bool(bullet.get_meta("blocked_on_launch", false))
	var probe_reason := String(bullet.get_meta("launch_wall_probe_reason", "missing_meta"))

	for frame in 3:
		await physics_frame

	var after_count := _count_impacts(root)
	wall.queue_free()
	owner.queue_free()
	if after_count - before_count != 1:
		_fail(root, "Bullet should hit the wall on launch when %s spawn point is behind or inside the wall. blocked_on_launch=%s reason=%s" % [direction_name, blocked_on_launch, probe_reason])
		return false
	return true


func _create_wall(position: Vector2, direction: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = "ValidationWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.global_position = position

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if absf(direction.x) > absf(direction.y):
		rect.size = Vector2(8, 32)
	else:
		rect.size = Vector2(32, 8)
	shape.shape = rect
	wall.add_child(shape)
	return wall


func _count_impacts(root: Node) -> int:
	var effect_manager := get_root().get_node_or_null("EffectManager")
	if effect_manager != null and effect_manager.has_method("get_total_spawned"):
		return int(effect_manager.get_total_spawned("bullet_impact"))

	var impact_count := 0
	for child in root.get_children():
		if child.name == "BulletWallImpact":
			impact_count += 1
	return impact_count


func _ray_hits_wall(root: Node2D, from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	query.hit_from_inside = true
	return not root.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
