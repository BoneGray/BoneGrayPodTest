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
	root.name = "AttackSlotValidationRoot"
	var world_actors := Node2D.new()
	world_actors.name = "WorldActors"
	world_actors.y_sort_enabled = true
	root.add_child(world_actors)
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	player.name = "Player"
	world_actors.add_child(player)
	player.global_position = Vector2.ZERO

	var enemies := []
	for i in 5:
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		enemy.name = "EnemyExtra%s" % i
		world_actors.add_child(enemy)
		enemies.append(enemy)

	await process_frame

	for enemy in enemies:
		enemy.global_position = player.global_position + Vector2(36, 0)
		enemy.call("set_target", player)

	for i in 10:
		await physics_frame

	var assigned_directions := {}
	var waiting_count := 0
	for enemy in enemies:
		if enemy.get("state") != 2 and enemy.get("state") != 3:
			push_error("%s should enter attack slot or attack state." % enemy.name)
			root.queue_free()
			quit(1)
			return

		if not enemy.get("has_attack_slot"):
			waiting_count += 1
			continue

		var direction := String(enemy.get("attack_slot_direction"))
		if assigned_directions.has(direction):
			push_error("Multiple enemies claimed the same attack slot direction: %s" % direction)
			root.queue_free()
			quit(1)
			return
		assigned_directions[direction] = true

	if assigned_directions.size() < 3:
		push_error("Enemies should claim distinct attack slots.")
		root.queue_free()
		quit(1)
		return

	if assigned_directions.size() > 4:
		push_error("No more than four active attack slots should be claimed.")
		root.queue_free()
		quit(1)
		return

	if waiting_count < 1:
		push_error("Extra enemies should wait outside active attack slots.")
		root.queue_free()
		quit(1)
		return

	print("Enemy attack slot manager is valid.")
	root.queue_free()
	quit()
