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

	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(-28, 24)
	enemy.call("set_target", player)

	var previous_direction := ""
	var direction_changes := 0
	var previous_position := enemy.global_position
	var backwards_steps := 0

	for i in 45:
		await physics_frame
		var current_direction := String(enemy.get("attack_slot_direction"))
		if enemy.get("state") == 2 and enemy.get("has_attack_slot"):
			if previous_direction != "" and previous_direction != current_direction:
				direction_changes += 1
			previous_direction = current_direction

		var previous_distance := previous_position.distance_to(player.global_position)
		var current_distance := enemy.global_position.distance_to(player.global_position)
		if enemy.get("state") != 3 and current_distance > previous_distance + 1.0:
			backwards_steps += 1
		previous_position = enemy.global_position

	if direction_changes > 0:
		push_error("Single close enemy should keep its attack slot direction stable. Direction changes: %d" % direction_changes)
		root.queue_free()
		quit(1)
		return

	if backwards_steps > 3:
		push_error("Single close enemy should not repeatedly move away from the player. Backwards steps: %d" % backwards_steps)
		root.queue_free()
		quit(1)
		return

	print("Single close enemy stability is valid.")
	root.queue_free()
	quit()
