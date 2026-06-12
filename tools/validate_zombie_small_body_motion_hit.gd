@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy_zombie_small.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if enemy_scene == null or player_scene == null:
		_fail(null, "Could not load Zombie Small or Player scene.")
		return

	var root := Node2D.new()
	var enemy := enemy_scene.instantiate() as BaseEnemy
	var player := player_scene.instantiate() as CharacterBody2D
	enemy.auto_acquire_target = false
	player.add_to_group("player")
	get_root().add_child(root)
	root.add_child(enemy)
	root.add_child(player)

	await process_frame

	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(40, 0)
	enemy.set_target(player)

	var player_health_before: int = player.get_current_health()
	enemy.begin_attack("attack_second")

	for i in 30:
		await physics_frame
		if player.get_current_health() < player_health_before:
			break

	if player.get_current_health() >= player_health_before:
		_fail(root, "Zombie Small cross attack should damage the player while the body passes through.")
		return

	var attack_area := enemy.get_node("AttackArea2D") as Area2D
	if attack_area.monitoring:
		_fail(root, "Zombie Small body-motion hit should not depend on AttackArea2D monitoring.")
		return

	print("Zombie Small body motion hit is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
