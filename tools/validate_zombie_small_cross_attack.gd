@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy_zombie_small.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if enemy_scene == null or player_scene == null:
		push_error("Could not load Zombie Small or Player scene.")
		quit(1)
		return

	var root := Node2D.new()
	var enemy := enemy_scene.instantiate() as BaseEnemy
	var player := player_scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(enemy)
	root.add_child(player)

	await process_frame

	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(40, 0)
	enemy.set_target(player)
	var start_position := enemy.global_position
	enemy.begin_attack("attack_second")

	if enemy.get("current_attack_type") != "cross":
		_fail(root, "Zombie Small attack_second should enter cross attack type.")
		return

	for i in 30:
		await physics_frame

	var moved_distance := start_position.distance_to(enemy.global_position)
	if moved_distance < 40.0:
		_fail(root, "Zombie Small cross attack should move the enemy body through the target. Moved %.2f." % moved_distance)
		return

	if enemy.global_position.x <= player.global_position.x:
		_fail(root, "Zombie Small cross attack should end on the opposite side of the player.")
		return

	for i in 30:
		await physics_frame

	if enemy.get("current_direction") != "side_left":
		_fail(root, "Zombie Small cross attack should turn back toward the player after passing through.")
		return

	var sprite := enemy.get_node("Sprite") as AnimatedSprite2D
	if sprite.position != Vector2.ZERO:
		_fail(root, "Zombie Small cross attack should reset Sprite.position after returning to idle.")
		return

	print("Zombie Small cross attack is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	root.queue_free()
	quit(1)
