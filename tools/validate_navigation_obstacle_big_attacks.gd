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

	var big := root.get_node_or_null("NavBig1") as BaseEnemy
	if big == null:
		_fail(root, "Navigation obstacle test scene is missing NavBig1.")
		return

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
