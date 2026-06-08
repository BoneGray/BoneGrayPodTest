@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const ENEMY_TEST_SCENE_PATH := "res://scenes/enemy_test_scene.tscn"
const WORLD_COLLISION_LAYER := 1
const ENEMY_BODY_LAYER := 4
const PLAYER_HITBOX_LAYER := 8
const ENEMY_HITBOX_LAYER := 16


func _initialize() -> void:
	if not _validate_enemy_scene():
		quit(1)
		return
	if not _validate_enemy_test_scene():
		quit(1)
		return

	print("Base enemy setup is valid.")
	quit()


func _validate_enemy_scene() -> bool:
	var scene := load(ENEMY_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load enemy scene.")
		return false

	var enemy := scene.instantiate() as CharacterBody2D
	if enemy == null:
		push_error("Enemy root must be CharacterBody2D.")
		return false

	var required_nodes := [
		"Sprite",
		"BodyCollisionShape2D",
		"HitboxArea2D",
		"HitboxArea2D/CollisionShape2D",
		"AttackArea2D",
		"AttackArea2D/CollisionShape2D",
		"NavigationAgent2D",
		"AnimationPlayer",
		"HurtFlashFeedback",
	]

	for node_path in required_nodes:
		if enemy.get_node_or_null(node_path) == null:
			push_error("Enemy missing node: %s" % node_path)
			enemy.queue_free()
			return false

	if not enemy.is_in_group("enemy"):
		push_error("Enemy must be in enemy group.")
		enemy.queue_free()
		return false

	if enemy.collision_layer != ENEMY_BODY_LAYER or enemy.collision_mask != WORLD_COLLISION_LAYER:
		push_error("Enemy body collision must only block against the world layer.")
		enemy.queue_free()
		return false

	var hitbox := enemy.get_node("HitboxArea2D") as Area2D
	var attack_area := enemy.get_node("AttackArea2D") as Area2D
	if hitbox.collision_layer != ENEMY_HITBOX_LAYER or hitbox.collision_mask != 0:
		push_error("Enemy hitbox must use the enemy hitbox layer only.")
		enemy.queue_free()
		return false

	if hitbox.is_in_group("enemy"):
		push_error("Enemy hitbox must not use the enemy actor group.")
		enemy.queue_free()
		return false

	if attack_area.collision_layer != 0 or attack_area.collision_mask != PLAYER_HITBOX_LAYER:
		push_error("Enemy attack area must only scan the player hitbox layer.")
		enemy.queue_free()
		return false

	var navigation_agent := enemy.get_node("NavigationAgent2D") as NavigationAgent2D
	if navigation_agent == null or navigation_agent.avoidance_enabled:
		push_error("Enemy NavigationAgent2D must exist with avoidance disabled by default.")
		enemy.queue_free()
		return false

	if enemy.get("use_navigation_agent"):
		push_error("Enemy should keep NavigationAgent2D disabled by default.")
		enemy.queue_free()
		return false

	var stats := enemy.get("stats") as Resource
	if stats == null:
		push_error("Enemy stats resource is missing.")
		enemy.queue_free()
		return false

	if stats.max_health <= 0 or stats.move_speed <= 0.0 or stats.attack_power <= 0:
		push_error("Enemy stats values are invalid.")
		enemy.queue_free()
		return false

	if stats.detect_range <= stats.attack_range or stats.lose_target_range < stats.detect_range:
		push_error("Enemy detection ranges are invalid.")
		enemy.queue_free()
		return false

	enemy.queue_free()
	return true


func _validate_enemy_test_scene() -> bool:
	var scene := load(ENEMY_TEST_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load enemy test scene.")
		return false

	var root := scene.instantiate()
	var player := root.get_node_or_null("Player") as CharacterBody2D
	var enemies := root.find_children("Enemy*", "CharacterBody2D", false, false)
	if root is Node2D and not (root as Node2D).y_sort_enabled:
		push_error("Enemy test scene must enable Y Sort.")
		root.queue_free()
		return false

	if player == null:
		push_error("Enemy test scene missing Player.")
		root.queue_free()
		return false

	if enemies.size() < 3:
		push_error("Enemy test scene should contain at least 3 enemies.")
		root.queue_free()
		return false

	root.queue_free()
	return true
