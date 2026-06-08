@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load(PLAYER_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load player scene.")
		quit(1)
		return

	var root := Node2D.new()
	var player := scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(player)
	player.set("keyboard_control_enabled", false)

	await process_frame

	var stats := player.get("stats") as Resource
	if stats == null:
		push_error("Player stats resource is missing.")
		root.queue_free()
		quit(1)
		return

	if stats.max_health <= 0 or stats.move_speed <= 0.0 or stats.attack_power <= 0:
		push_error("Player stats values are invalid.")
		root.queue_free()
		quit(1)
		return

	if player.call("get_max_health") != stats.max_health:
		push_error("Player max health does not come from stats.")
		root.queue_free()
		quit(1)
		return

	if player.call("get_move_speed") != stats.move_speed:
		push_error("Player move speed does not come from stats.")
		root.queue_free()
		quit(1)
		return

	if player.call("get_attack_power") != stats.attack_power:
		push_error("Player attack power does not come from stats.")
		root.queue_free()
		quit(1)
		return

	player.call("take_damage", 15)
	var expected_health: int = stats.max_health - maxi(15 - stats.defense, 1)
	if player.get("health") != expected_health:
		push_error("Player take_damage did not update health correctly.")
		root.queue_free()
		quit(1)
		return

	if player.get("invincible_time_remaining") <= 0.0:
		push_error("Player invincible time was not applied after damage.")
		root.queue_free()
		quit(1)
		return

	print("Player stats are valid.")
	root.queue_free()
	quit()
