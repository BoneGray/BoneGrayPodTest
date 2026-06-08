@tool
extends SceneTree

const SCENE_PATH := "res://scenes/enemy_test_scene.tscn"


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

	var player := root.get_node_or_null("Player") as CharacterBody2D
	var enemies := root.find_children("Enemy*", "CharacterBody2D", false, false)
	if player == null or enemies.size() < 3:
		push_error("Enemy navigation runtime scene is incomplete.")
		root.queue_free()
		quit(1)
		return

	for enemy in enemies:
		if enemy.get("target") != player:
			push_error("%s did not acquire Player as target." % enemy.name)
			root.queue_free()
			quit(1)
			return

		var navigation_agent := enemy.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
		if navigation_agent == null:
			push_error("%s missing NavigationAgent2D." % enemy.name)
			root.queue_free()
			quit(1)
			return

		var velocity := enemy.get("velocity") as Vector2
		if velocity == Vector2.ZERO and enemy.global_position.distance_to(player.global_position) > enemy.get("stats").attack_range:
			push_error("%s did not start moving toward Player." % enemy.name)
			root.queue_free()
			quit(1)
			return

	print("Enemy navigation runtime is valid.")
	root.queue_free()
	quit()
