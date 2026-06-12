@tool
extends SceneTree

const SCENE_PATH := "res://scenes/navigation_obstacle_test_scene.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail(null, "Could not load navigation obstacle test scene.")
		return

	var root := scene.instantiate()
	get_root().add_child(root)
	await process_frame

	var player := root.get_node_or_null("WorldActors/Player") as CharacterBody2D
	var big := root.get_node_or_null("WorldActors/NavBig1") as BaseEnemy
	if player == null or big == null:
		_fail(root, "Navigation obstacle test scene is missing Player or NavBig1.")
		return
	for enemy_path in ["WorldActors/EnemyZombieAxe", "WorldActors/NavEnemy1"]:
		var enemy := root.get_node_or_null(enemy_path)
		if enemy != null:
			enemy.queue_free()

	player.global_position = Vector2(156, 144)
	big.global_position = Vector2(184, 144)
	big.set("use_navigation_agent", true)
	big.call("set_target", player)
	await physics_frame

	for i in 120:
		await physics_frame
		if big.state == BaseEnemy.State.ATTACK:
			print("Navigation obstacle Big attack opening is valid.")
			root.queue_free()
			quit()
			return

	_fail(root, "NavBig1 should enter attack from the opening test position.")


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
