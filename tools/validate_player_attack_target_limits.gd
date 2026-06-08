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
	root.add_child(player)
	player.global_position = Vector2(100, 100)
	player.set("keyboard_control_enabled", false)
	player.set("attack_log_enabled", false)
	player.set_physics_process(false)

	var enemy_positions := [
		Vector2(108, 100),
		Vector2(111, 100),
		Vector2(114, 100),
	]
	for index in enemy_positions.size():
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		enemy.name = "Enemy%d" % [index + 1]
		enemy.global_position = enemy_positions[index]
		enemy.set("auto_acquire_target", false)
		enemy.set("damage_log_enabled", false)
		root.add_child(enemy)

	await process_frame
	await physics_frame

	var attack_area := player.get_node("AttackArea2D") as Area2D
	var attack_shape := player.get_node("AttackArea2D/CollisionShape2D") as CollisionShape2D
	attack_area.position = Vector2(10, 1)
	attack_area.monitoring = true
	attack_shape.disabled = false

	await physics_frame

	var targets := player.call("_collect_attack_hit_targets") as Array
	if targets.size() < 3:
		push_error("Expected at least 3 attack candidates, found %d." % targets.size())
		root.queue_free()
		quit(1)
		return

	player.set_meta("current_attack_action", "first_attack")
	if player.call("_get_current_attack_max_targets") != 1:
		push_error("First attack should hit only 1 target.")
		root.queue_free()
		quit(1)
		return
	player.call("_reset_current_attack_hits")
	attack_area.monitoring = true
	attack_shape.disabled = false
	await physics_frame
	for index in 3:
		player.call("_apply_attack_hits")
	if player.call("_get_current_attack_hit_count") != 1:
		push_error("First attack should only damage 1 target across the whole attack.")
		root.queue_free()
		quit(1)
		return

	player.set_meta("current_attack_action", "second_attack")
	if player.call("_get_current_attack_max_targets") != 3:
		push_error("Second attack should support 3 targets.")
		root.queue_free()
		quit(1)
		return
	player.call("_reset_current_attack_hits")
	attack_area.monitoring = true
	attack_shape.disabled = false
	await physics_frame
	for index in 3:
		player.call("_apply_attack_hits")
	if player.call("_get_current_attack_hit_count") != 3:
		push_error("Second attack should be able to damage 3 targets.")
		root.queue_free()
		quit(1)
		return

	print("Player attack target limits are valid.")
	root.queue_free()
	quit()
