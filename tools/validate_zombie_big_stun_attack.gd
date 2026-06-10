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
		_fail(null, "Could not load Zombie Big or Player scene.")
		return

	var root := Node2D.new()
	var enemy := enemy_scene.instantiate() as BaseEnemy
	var player := player_scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(enemy)
	root.add_child(player)

	await process_frame

	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(0, 14)
	enemy.set_target(player)
	enemy.current_direction = "down"
	enemy._sync_attack_area_to_direction()
	enemy.begin_attack("attack_second")
	if enemy.current_attack_action != "attack_second":
		_fail(root, "Zombie Big should start attack_second for the stun validation.")
		return
	if String(enemy.current_attack_profile.get("status_effect", "")) != "stun":
		_fail(root, "Zombie Big attack_second should load a stun attack profile.")
		return

	for i in 40:
		await physics_frame
		if player.has_method("is_stunned") and player.is_stunned():
			break

	if not player.has_method("is_stunned") or not player.is_stunned():
		_fail(root, "Zombie Big attack_second should stun the player when it hits.")
		return

	print("Zombie Big stun attack is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
