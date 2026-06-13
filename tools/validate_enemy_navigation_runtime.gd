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
	await physics_frame
	await physics_frame
	await physics_frame

	var world_actors := root.get_node_or_null("WorldActors")
	var player := world_actors.get_node_or_null("Player") as CharacterBody2D if world_actors != null else null
	var enemies := _find_enemy_bodies(root)
	if world_actors == null or player == null or enemies.is_empty():
		push_error("Enemy navigation runtime scene is incomplete.")
		root.queue_free()
		quit(1)
		return

	for enemy in enemies:
		enemy.global_position = player.global_position + Vector2(96, 0)
		enemy.call("set_target", player)

	for i in 3:
		await physics_frame

	var moving_enemy_count := 0
	var targeted_enemy_count := 0
	for enemy in enemies:
		if enemy.get("target") != player:
			continue
		targeted_enemy_count += 1

		var velocity := enemy.get("velocity") as Vector2
		if velocity == Vector2.ZERO and enemy.global_position.distance_to(player.global_position) > enemy.get("stats").attack_range:
			continue
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


func _find_enemy_bodies(root: Node) -> Array:
	var enemies := []
	for body in root.find_children("*", "CharacterBody2D", true, false):
		if body.is_in_group("enemy"):
			enemies.append(body)
	return enemies
