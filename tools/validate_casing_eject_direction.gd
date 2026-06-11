@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail(null, "Could not load player scene.")
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	if not _direction_can_eject_both_sides(player, "up"):
		_fail(root, "Up casing ejection should randomly support both left and right fly-out.")
		return
	if not _direction_can_eject_both_sides(player, "down"):
		_fail(root, "Down casing ejection should randomly support both left and right fly-out.")
		return
	if not _left_eject_spawn_offset_is_valid(player, "up"):
		_fail(root, "Up left casing ejection should add a small left spawn offset.")
		return
	if not _left_eject_spawn_offset_is_valid(player, "down"):
		_fail(root, "Down left casing ejection should add a small left spawn offset.")
		return

	print("Casing eject direction is valid.")
	root.queue_free()
	quit()


func _direction_can_eject_both_sides(player: Node, direction_name: String) -> bool:
	player.set("current_direction", direction_name)
	var saw_left := false
	var saw_right := false
	for attempt in 80:
		var eject_direction: Vector2 = player.call("_casing_eject_direction")
		if eject_direction.x < 0.0:
			saw_left = true
		elif eject_direction.x > 0.0:
			saw_right = true
		if saw_left and saw_right:
			return true
	return false


func _left_eject_spawn_offset_is_valid(player: Node, direction_name: String) -> bool:
	player.set("current_direction", direction_name)
	var left_offset: Vector2 = player.call("_casing_left_eject_spawn_offset", Vector2.LEFT)
	var right_offset: Vector2 = player.call("_casing_left_eject_spawn_offset", Vector2.RIGHT)
	return left_offset.x <= -2.0 and left_offset.x >= -4.0 and left_offset.y == 0.0 and right_offset == Vector2.ZERO


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
