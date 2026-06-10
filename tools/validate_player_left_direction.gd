extends SceneTree

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")


func _init() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame

	player.play_walk("side_left")
	await process_frame
	_assert_direction(player, "side_left", "walk_side_left should keep side_left")

	player.play_idle(player.current_direction)
	await process_frame
	_assert_animation(player, "idle_side_left", "stopping after left walk should play idle_side_left")
	_assert_direction(player, "side_left", "idle_side_left should keep side_left")

	player.attack("attack_first", "side_left")
	await process_frame
	_assert_direction(player, "side_left", "left attack should start side_left")

	for index in 120:
		await process_frame
		var sprite: AnimatedSprite2D = player.get_node("Sprite")
		if String(sprite.animation).begins_with("idle_"):
			break

	_assert_animation(player, "idle_side_left", "left attack should finish as idle_side_left")
	_assert_direction(player, "side_left", "left attack should finish side_left")

	print("Player left direction validation passed")
	quit(0)


func _assert_direction(player: Node, expected: String, message: String) -> void:
	if player.current_direction != expected:
		push_error("%s: expected %s, got %s" % [message, expected, player.current_direction])
		quit(1)


func _assert_animation(player: Node, expected: String, message: String) -> void:
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	if String(sprite.animation) != expected:
		push_error("%s: expected %s, got %s" % [message, expected, sprite.animation])
		quit(1)
