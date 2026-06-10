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
		_fail(null, "Could not load Zombie Small or Player scene.")
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
	enemy.begin_attack("attack_second")

	for i in 10:
		await physics_frame

	var death_position := enemy.global_position
	enemy.take_damage(enemy.get_current_health())
	await process_frame

	if enemy.global_position.distance_to(death_position) > 0.01:
		_fail(root, "Zombie Small death should not move the body root after lethal damage.")
		return

	if enemy.get("current_attack_type") != "melee":
		_fail(root, "Zombie Small death should clear active special attack type.")
		return

	var animation_player := enemy.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null or not String(animation_player.current_animation).begins_with("death_"):
		_fail(root, "Zombie Small death should play death animation through AnimationPlayer.")
		return

	print("Zombie Small death alignment is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
