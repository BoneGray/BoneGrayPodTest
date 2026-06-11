@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const GUN_DATA_PATH := "res://resources/equipment/weapons/gun/gun_data.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var effect_manager := get_root().get_node_or_null("EffectManager")
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var gun_data := load(GUN_DATA_PATH) as Resource
	if effect_manager == null or player_scene == null or gun_data == null:
		_fail(null, "Could not load automatic fire dependencies.")
		return

	effect_manager.reset_debug_counts()
	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	player.call("equip_weapon", gun_data)
	for frame in 30:
		await process_frame
	var animation_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.stop()
	player.call("_clear_attack_runtime_state")
	player.call("play_idle", "down")
	player.set("attack_cooldown_remaining", 0.0)
	await physics_frame

	var start_position := player.global_position
	var press := InputEventKey.new()
	press.keycode = KEY_J
	press.physical_keycode = KEY_J
	press.pressed = true
	player.call("_unhandled_input", press)
	Input.parse_input_event(press)
	var move_press := InputEventKey.new()
	move_press.keycode = KEY_D
	move_press.physical_keycode = KEY_D
	move_press.pressed = true
	Input.parse_input_event(move_press)
	for repeat_index in 4:
		player.set("attack_cooldown_remaining", 0.0)
		player.set("_primary_attack_repeat_ready", true)
		player.call("_try_repeat_held_attack")
		await physics_frame
	for frame in 10:
		await physics_frame
	var animation_during_attack := String(player.get_node("Sprite").animation)
	var direction_during_attack := String(player.get("current_direction"))

	var release := InputEventKey.new()
	release.keycode = KEY_J
	release.physical_keycode = KEY_J
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frame
	await physics_frame
	var position_after_attack_release := player.global_position
	for frame in 10:
		await physics_frame
	var moved_after_attack_release := player.global_position.x > position_after_attack_release.x
	var animation_after_attack_release := String(player.get_node("Sprite").animation)
	var state_after_attack_release := String(player.call("get_player_state"))

	var interact_press := InputEventKey.new()
	interact_press.keycode = KEY_E
	interact_press.physical_keycode = KEY_E
	interact_press.pressed = true
	player.call("_unhandled_input", interact_press)
	await process_frame
	var weapon_after_interact = player.get("equipped_weapon")

	var move_release := InputEventKey.new()
	move_release.keycode = KEY_D
	move_release.physical_keycode = KEY_D
	move_release.pressed = false
	Input.parse_input_event(move_release)

	if effect_manager.get_total_spawned("muzzle_flash") < 2:
		_fail(root, "Holding J should fire the automatic gun more than once.")
		return
	if player.global_position.x <= start_position.x:
		_fail(root, "Automatic gun should allow slower movement while the attack animation is playing.")
		return
	if not animation_during_attack.begins_with("attack_"):
		_fail(root, "Movement during automatic fire should not switch the player to walk animation.")
		return
	if direction_during_attack != "down":
		_fail(root, "Movement during automatic fire should keep the firing direction locked.")
		return
	if animation_after_attack_release.begins_with("attack_"):
		_fail(root, "Releasing J after repeat fire should cancel the locked attack animation.")
		return
	if state_after_attack_release == "attack":
		_fail(root, "Releasing J after repeat fire should leave attack state.")
		return
	if weapon_after_interact != null:
		_fail(root, "E should work after repeat fire and drop the equipped gun.")
		return
	if not moved_after_attack_release or player.get("current_direction") != "side":
		_fail(root, "Releasing J after repeat fire should restore normal movement and turning.")
		return

	print("Automatic gun fire is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
