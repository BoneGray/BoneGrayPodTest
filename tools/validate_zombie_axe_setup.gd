@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy_zombie_axe.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const AXE_PROJECTILE_SCENE_PATH := "res://scenes/projectiles/axe_projectile.tscn"
const ZOMBIE_AXE_FRAMES_PATH := "res://resources/characters/enemies/zombie_axe_sprite_frames.tres"
const AXE_FRAMES_PATH := "res://resources/characters/enemies/axe_sprite_frames.tres"


func _initialize() -> void:
	var zombie_frames := load(ZOMBIE_AXE_FRAMES_PATH) as SpriteFrames
	var axe_frames := load(AXE_FRAMES_PATH) as SpriteFrames
	_assert(zombie_frames != null, "Zombie Axe SpriteFrames loads.")
	_assert(axe_frames != null, "Axe SpriteFrames loads.")

	for animation_name in [
		"idle_down",
		"walk_side_left",
		"attack_down_first",
		"attack_down_second",
		"attack_down_first_no_axe",
		"idle_down_no_axe",
		"pickup_down_axe",
	]:
		_assert(zombie_frames.has_animation(animation_name), "Zombie Axe has %s." % animation_name)

	for animation_name in ["thrown_side", "thrown_side_left", "thrown_up", "thrown_down", "landed_side"]:
		_assert(axe_frames.has_animation(animation_name), "Axe has %s." % animation_name)

	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	_assert(enemy_scene != null, "Zombie Axe scene loads.")
	_assert(player_scene != null, "Player scene loads.")

	var enemy := enemy_scene.instantiate() as BaseEnemy
	var player := player_scene.instantiate() as Node2D
	_assert(enemy.use_navigation_agent, "Zombie Axe enables NavigationAgent2D by default.")
	player.add_to_group("player")
	player.global_position = Vector2(90, 0)
	enemy.global_position = Vector2.ZERO
	enemy.auto_acquire_target = false
	enemy.use_navigation_agent = false
	enemy.current_direction = "side"
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	_assert(is_equal_approx(enemy.get_weapon_pickup_range(), 8.0), "Zombie Axe reads weapon pickup range from stats.")
	_assert(is_equal_approx(enemy.get_no_weapon_close_attack_range(), 26.0), "Zombie Axe reads no-weapon close attack range from stats.")
	_assert(is_equal_approx(enemy.get_weapon_retrieval_timeout(), 1.5), "Zombie Axe reads weapon retrieval timeout from stats.")
	enemy.set_target(player)

	enemy.begin_attack("attack_second")
	_assert(enemy.state == BaseEnemy.State.ATTACK, "Zombie Axe starts projectile attack.")
	await _physics_frames(40)
	_assert(not enemy.has_weapon, "Zombie Axe loses weapon after projectile spawn.")

	await _physics_frames(80)
	_assert(enemy.weapon_pickup != null and is_instance_valid(enemy.weapon_pickup), "Projectile registers landed axe pickup.")

	var dropped_weapon := enemy.weapon_pickup
	enemy.set_target(null)
	enemy.global_position = dropped_weapon.global_position + Vector2(-24, 0)
	await _physics_frames(12)
	_assert(enemy.state != BaseEnemy.State.PATROL, "Zombie Axe does not patrol while its axe is on the ground.")
	_assert(enemy.global_position.distance_to(dropped_weapon.global_position) < 24.0, "Zombie Axe retrieves axe while disengaged.")

	enemy.global_position = enemy.weapon_pickup.global_position
	enemy._update_weapon_retrieval()
	_assert(enemy.has_weapon, "Zombie Axe can pick the axe back up.")

	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(90, 0)
	enemy.current_direction = "side"
	enemy.set_target(player)
	var wall := _create_wall(Vector2(45, 0), Vector2(12, 72))
	root.add_child(wall)
	await physics_frame
	_assert(not enemy.can_attack("attack_second"), "Zombie Axe cannot throw axe through a wall.")
	enemy.begin_attack("attack_second")
	_assert(enemy.state != BaseEnemy.State.ATTACK, "Zombie Axe does not start projectile attack through a wall.")
	enemy._update_combat_movement(0.1)
	_assert(enemy.state == BaseEnemy.State.CHASE, "Zombie Axe keeps chasing instead of staring through a wall.")
	_assert(enemy.velocity != Vector2.ZERO, "Zombie Axe keeps moving when attack line is blocked.")
	wall.queue_free()

	await _validate_projectile_lands_before_wall()

	enemy.queue_free()
	player.queue_free()
	print("Zombie Axe setup validation passed.")
	quit()


func _physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _validate_projectile_lands_before_wall() -> void:
	var projectile_scene := load(AXE_PROJECTILE_SCENE_PATH) as PackedScene
	_assert(projectile_scene != null, "Axe projectile scene loads.")

	var wall := _create_wall(Vector2(48, 96), Vector2(16, 64))
	root.add_child(wall)
	var projectile := projectile_scene.instantiate() as Node2D
	root.add_child(projectile)
	projectile.global_position = Vector2(0, 96)
	projectile.launch(null, Vector2.RIGHT, "side", {
		"blocked_by_mask": 1,
		"damage": 10,
		"projectile_lifetime": 2.0,
		"projectile_speed": 180.0,
	})

	await _physics_frames(25)
	var pickup := root.get_node_or_null("AxePickup") as Node2D
	_assert(pickup != null, "Axe projectile spawns pickup after hitting wall.")
	if pickup == null:
		return
	_assert(pickup.global_position.x < 40.0, "Axe pickup lands before the wall, not inside it.")
	pickup.queue_free()
	wall.queue_free()


func _create_wall(position: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = "ValidationWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.global_position = position
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision_shape.shape = rectangle
	wall.add_child(collision_shape)
	return wall


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
