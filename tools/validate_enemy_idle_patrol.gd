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

	var enemy := enemy_scene.instantiate() as CharacterBody2D
	enemy.name = "Enemy"
	enemy.position = Vector2.ZERO
	enemy.set("auto_acquire_target", false)
	enemy.set("idle_duration_min", 0.02)
	enemy.set("idle_duration_max", 0.03)
	enemy.set("patrol_duration_min", 0.2)
	enemy.set("patrol_duration_max", 0.25)
	root.add_child(enemy)

	await process_frame
	for i in 8:
		await physics_frame

	if enemy.get("state") != enemy.State.PATROL:
		_fail(root, "Enemy should randomly enter patrol when it has no target.")
		return

	var patrol_velocity := enemy.get("velocity") as Vector2
	if patrol_velocity == Vector2.ZERO:
		_fail(root, "Enemy patrol should produce movement velocity.")
		return
	if patrol_velocity.length() < enemy.call("get_move_speed") * 0.55:
		_fail(root, "Enemy patrol speed should be large enough to be visible.")
		return

	var player := player_scene.instantiate() as CharacterBody2D
	player.name = "Player"
	player.position = Vector2(32, 0)
	root.add_child(player)
	enemy.call("set_target", player)

	await physics_frame
	if enemy.get("state") != enemy.State.CHASE and enemy.get("state") != enemy.State.APPROACH_ATTACK_SLOT:
		_fail(root, "Enemy should leave idle patrol when it gets a target.")
		return

	print("Enemy idle patrol is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	root.queue_free()
	quit(1)
