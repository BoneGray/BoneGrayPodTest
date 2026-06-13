@tool
extends SceneTree

const SCENE_PATH := "res://scenes/navigation_obstacle_test_scene.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load enemy test scene.")
		quit(1)
		return

	var root := scene.instantiate()
	get_root().add_child(root)

	await process_frame

	var world_actors := root.get_node_or_null("WorldActors")
	var player := world_actors.get_node_or_null("Player") as CharacterBody2D if world_actors != null else null
	var enemies := _find_enemy_bodies(root)
	if world_actors == null or player == null:
		push_error("Navigation obstacle test scene should contain WorldActors and Player.")
		root.queue_free()
		quit(1)
		return

	var enemy_scene := load("res://scenes/characters/enemy.tscn") as PackedScene
	while enemies.size() < 5:
		var extra_enemy := enemy_scene.instantiate() as CharacterBody2D
		extra_enemy.name = "EnemyExtra%s" % enemies.size()
		world_actors.add_child(extra_enemy)
		enemies.append(extra_enemy)

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


func _find_enemy_bodies(root: Node) -> Array:
	var enemies := []
	for body in root.find_children("*", "CharacterBody2D", true, false):
		if body.is_in_group("enemy"):
			enemies.append(body)
	return enemies
