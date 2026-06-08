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
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	var player := player_scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(enemy)
	root.add_child(player)

	await process_frame

	var stats := enemy.get("stats").duplicate() as Resource
	stats.attack_range = 64.0
	enemy.call("configure_stats", stats)
	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(-30, 30)
	enemy.call("set_target", player)

	var start_position := enemy.global_position
	for i in 3:
		await physics_frame

	var enemy_state: int = enemy.get("state")
	if enemy.global_position == start_position and enemy_state != 3:
		push_error("Enemy should keep aligning when target is inside range but outside the active attack lane. State: %s, direction: %s, can_attack: %s, distance: %.2f" % [enemy.get("state"), enemy.get("current_direction"), enemy.call("can_attack"), enemy.global_position.distance_to(player.global_position)])
		root.queue_free()
		quit(1)
		return

	if enemy.global_position.y <= start_position.y and enemy_state != 3:
		push_error("Enemy should move downward to align with a lower-left target instead of sticking in place.")
		root.queue_free()
		quit(1)
		return

	print("Enemy attack alignment is valid.")
	root.queue_free()
	quit()
