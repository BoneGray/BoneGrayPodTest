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
	enemy.attack_slot_arrive_distance = 6.0
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(0, -15)
	enemy.set_target(player)

	var to_target := player.global_position - enemy.global_position
	enemy._update_attack_slot(to_target, 0.1)
	enemy.current_direction = enemy.attack_slot_direction
	enemy._sync_attack_area_to_direction()

	var attack := enemy._select_available_melee_attack()
	if attack == "":
		_fail(root, "Enemy should be able to start melee attack after arriving at the attack slot.")
		return

	print("Enemy arrived-slot melee attack is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
