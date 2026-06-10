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
		_fail(null, "Could not load enemy or player scene.")
		return

	var root := Node2D.new()
	var enemy := enemy_scene.instantiate() as BaseEnemy
	var player := player_scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(enemy)
	root.add_child(player)

	await process_frame

	enemy.use_navigation_agent = false
	enemy.use_separation = false
	enemy.attack_slot_timeout = 0.1
	enemy.attack_slot_arrive_distance = 0.1
	enemy.global_position = Vector2(0, -42)
	player.global_position = Vector2.ZERO
	enemy.set_target(player)

	for i in 20:
		var to_target := player.global_position - enemy.global_position
		enemy._update_attack_slot(to_target, 0.05)
		var to_slot: Vector2 = enemy.attack_slot_position - enemy.global_position
		if enemy._should_give_up_attack_slot(to_slot):
			_fail(root, "Enemy should keep the upper/down attack slot while making progress.")
			return
		enemy.global_position = enemy.global_position.move_toward(enemy.attack_slot_position, 1.0)

	if enemy.attack_slot_direction != "down":
		_fail(root, "Enemy above the player should prefer the down attack slot.")
		return

	for i in 5:
		var to_target := player.global_position - enemy.global_position
		enemy._update_attack_slot(to_target, 0.05)

	if enemy.attack_slot_stuck_elapsed <= 0.0:
		_fail(root, "Enemy should accumulate stuck time when no longer making progress.")
		return

	print("Enemy attack slot progress is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
