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

	if player.call("get_player_state") != "idle":
		_fail(root, "Player should start in idle state.")
		return

	player.call("play_walk", "side")
	if player.call("get_player_state") != "move":
		_fail(root, "play_walk should move the player into move state, got %s." % player.call("get_player_state"))
		return

	player.call("attack", "attack_first", "down")
	await process_frame
	if player.call("get_player_state") != "attack":
		_fail(root, "attack should move the player into attack state.")
		return
	if player.call("get_attack_phase") != "startup":
		_fail(root, "New attacks should start in startup phase.")
		return

	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	var animation_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.stop()
	sprite.animation = &"attack_down_first"
	sprite.frame = 2
	player.call("_on_frame_changed")
	if player.call("get_attack_phase") != "active":
		_fail(root, "Hit frames should move the current attack into active phase.")
		return

	sprite.frame = 3
	player.call("_on_frame_changed")
	if player.call("get_attack_phase") != "recovery":
		_fail(root, "Frames after the hit window should move the current attack into recovery.")
		return

	player.call("apply_status_effect", "stun", 0.2, null)
	await physics_frame
	if player.call("get_player_state") != "stunned":
		_fail(root, "Stun should interrupt the player into stunned state.")
		return

	for frame in 20:
		await physics_frame
	if player.call("get_player_state") != "idle":
		_fail(root, "Stun should return to idle after it expires.")
		return
	if String(sprite.animation).begins_with("attack_"):
		_fail(root, "Stun should clear locked attack animation after it expires.")
		return

	var attack_press := InputEventKey.new()
	attack_press.keycode = KEY_J
	attack_press.physical_keycode = KEY_J
	attack_press.pressed = true
	player.call("_unhandled_input", attack_press)
	await process_frame
	if player.call("get_player_state") != "attack":
		_fail(root, "Player should be able to attack again after stun expires.")
		return
	var attack_release := InputEventKey.new()
	attack_release.keycode = KEY_J
	attack_release.physical_keycode = KEY_J
	attack_release.pressed = false
	Input.parse_input_event(attack_release)
	player.call("_clear_attack_runtime_state")
	player.call("play_idle", "down")

	player.call("take_damage", 9999)
	await process_frame
	if player.call("get_player_state") != "dead":
		_fail(root, "Death should move the player into dead state.")
		return

	player.call("play_walk", "side")
	await process_frame
	if player.call("get_player_state") != "dead":
		_fail(root, "Dead state should not transition back to move.")
		return

	print("Player state machine is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
