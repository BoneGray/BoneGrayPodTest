@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if enemy_scene == null or player_scene == null:
		push_error("Could not load enemy or player scene.")
		quit(1)
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	player.name = "Player"
	player.position = Vector2.ZERO
	root.add_child(player)

	var enemy := enemy_scene.instantiate() as CharacterBody2D
	enemy.name = "Enemy"
	enemy.position = Vector2(24, 0)
	enemy.set("auto_acquire_target", true)
	enemy.set("idle_duration_min", 0.05)
	enemy.set("idle_duration_max", 0.06)
	enemy.set("patrol_duration_min", 0.3)
	enemy.set("patrol_duration_max", 0.35)
	root.add_child(enemy)

	await process_frame
	enemy.call("set_target", player)
	if enemy.get("target") != player:
		_fail(root, "Enemy should accept living Player as target.")
		return

	player.set("health", 1)
	player.call("take_damage", 999)
	if player.call("is_alive"):
		_fail(root, "Player should be dead after lethal damage.")
		return

	for i in 4:
		await physics_frame

	if enemy.get("target") != null:
		_fail(root, "Enemy should clear dead Player target.")
		return

	var state := int(enemy.get("state"))
	if state != enemy.State.IDLE:
		_fail(root, "Enemy should pause in idle before patrolling after Player dies.")
		return

	for i in 8:
		await physics_frame

	state = int(enemy.get("state"))
	if state != enemy.State.PATROL:
		_fail(root, "Enemy should enter patrol after the death pause.")
		return

	var velocity := enemy.get("velocity") as Vector2
	if velocity == Vector2.ZERO:
		_fail(root, "Enemy should move while patrolling after the death pause.")
		return

	print("Enemy clears dead target is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	root.queue_free()
	quit(1)
