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
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	root.add_child(enemy)
	player.set("keyboard_control_enabled", false)
	enemy.global_position = Vector2(100, 100)

	var detect_range := enemy.call("get_detect_range") as float
	var lose_target_range := enemy.call("get_lose_target_range") as float

	player.global_position = enemy.global_position + Vector2(detect_range + 24.0, 0)
	await process_frame
	await physics_frame
	if enemy.get("target") != null:
		push_error("Enemy acquired target outside detect range.")
		root.queue_free()
		quit(1)
		return

	player.global_position = enemy.global_position + Vector2(detect_range - 8.0, 0)
	await physics_frame
	if enemy.get("target") != player:
		push_error("Enemy did not acquire target inside detect range.")
		root.queue_free()
		quit(1)
		return

	player.global_position = enemy.global_position + Vector2(lose_target_range + 24.0, 0)
	await physics_frame
	if enemy.get("target") != null:
		push_error("Enemy did not lose target outside lose target range.")
		root.queue_free()
		quit(1)
		return

	print("Enemy detection range is valid.")
	root.queue_free()
	quit()
