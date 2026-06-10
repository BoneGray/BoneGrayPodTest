@tool
extends SceneTree

const BIG_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const SMALL_SCENE_PATH := "res://scenes/characters/enemy_zombie_small.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var big_scene := load(BIG_SCENE_PATH) as PackedScene
	var small_scene := load(SMALL_SCENE_PATH) as PackedScene
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if big_scene == null or small_scene == null or player_scene == null:
		_fail(null, "Could not load test scenes.")
		return

	var root := Node2D.new()
	var player := player_scene.instantiate() as CharacterBody2D
	var small := small_scene.instantiate() as BaseEnemy
	var big := big_scene.instantiate() as BaseEnemy
	get_root().add_child(root)
	root.add_child(player)
	root.add_child(small)
	root.add_child(big)

	await process_frame

	player.global_position = Vector2.ZERO
	small.global_position = Vector2(-18, -8)
	big.global_position = Vector2(16, 0)
	small.use_navigation_agent = false
	big.use_navigation_agent = false
	small.use_separation = false
	big.use_separation = false
	small.set_target(player)
	big.set_target(player)

	small.begin_attack("attack_second")
	if small.state != BaseEnemy.State.ATTACK:
		_fail(root, "Small should start attacking for this validation.")
		return

	for i in 20:
		await physics_frame
		if big.state == BaseEnemy.State.ATTACK:
			break

	if big.state != BaseEnemy.State.ATTACK:
		_fail(root, "Big should attack when it is next to the player while Small attacks. State: %s, has_slot: %s, slot: %s, cooldown: %.2f" % [big.state, big.has_attack_slot, big.attack_slot_direction, big.attack_cooldown_remaining])
		return

	print("Big attacks while Small attacks validation passed.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
