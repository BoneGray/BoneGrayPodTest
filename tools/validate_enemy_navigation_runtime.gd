@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	if player_scene == null or enemy_scene == null:
		push_error("Could not load player or enemy scene.")
		quit(1)
		return

	var root := Node2D.new()
	root.name = "EnemyNavigationValidationRoot"
	var world_actors := Node2D.new()
	world_actors.name = "WorldActors"
	world_actors.y_sort_enabled = true
	root.add_child(world_actors)
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	player.name = "Player"
	world_actors.add_child(player)
	player.global_position = Vector2.ZERO

	var enemy := enemy_scene.instantiate() as CharacterBody2D
	enemy.name = "Enemy"
	world_actors.add_child(enemy)
	enemy.global_position = Vector2(96, 0)

	await process_frame
	await physics_frame
	await physics_frame
	await physics_frame

	if player == null or enemy == null:
		push_error("Enemy navigation runtime scene is incomplete.")
		root.queue_free()
		quit(1)
		return

	enemy.call("set_target", player)

	for i in 3:
		await physics_frame

	var moving_enemy_count := 0
	var targeted_enemy_count := 0
	if enemy.get("target") == player:
		targeted_enemy_count += 1

	var velocity := enemy.get("velocity") as Vector2
	if velocity != Vector2.ZERO:
		moving_enemy_count += 1

	if targeted_enemy_count < 1:
		push_error("At least one enemy should keep Player as target.")
		root.queue_free()
		quit(1)
		return

	if moving_enemy_count < 1:
		push_error("At least one enemy should start moving toward Player after acquiring target.")
		root.queue_free()
		quit(1)
		return

	print("Enemy navigation runtime is valid.")
	root.queue_free()
	quit()
