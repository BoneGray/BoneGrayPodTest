@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const BAT_DATA_PATH := "res://resources/equipment/weapons/baseball_bat/baseball_bat_data.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var bat_data := load(BAT_DATA_PATH) as Resource
	if player_scene == null or bat_data == null:
		_fail(null, "Could not load generic primary attack dependencies.")
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	if not await _validate_no_held_repeat(player, "Unarmed"):
		_fail(root, "Unarmed tap_combo should not repeat from holding J.")
		return
	if not await _validate_short_press_cancel(player, "Unarmed"):
		_fail(root, "Unarmed short press buffer/cancel should work through its AttackProfile.")
		return
	if not await _validate_tap_combo_movement_does_not_cancel_startup(player, "Unarmed"):
		_fail(root, "Unarmed tap_combo movement should not cancel startup attacks.")
		return
	if not await _validate_tap_combo_movement_turns_attack_direction(player, "Unarmed"):
		_fail(root, "Unarmed tap_combo movement should turn the attack direction.")
		return
	if not await _validate_tap_combo_animation_finish_clears_cooldown(player, "Unarmed"):
		_fail(root, "Unarmed tap_combo should not stay locked by long lockout after animation finish.")
		return
	if not await _validate_walk_clears_attack_state(player, "Unarmed"):
		_fail(root, "Unarmed attack state should be cleared before walk animation can hit.")
		return
	player.call("equip_weapon", bat_data)
	await process_frame
	if not await _validate_no_held_repeat(player, "Baseball bat"):
		_fail(root, "Baseball bat tap_combo should not repeat from holding J.")
		return
	if not await _validate_short_press_cancel(player, "Baseball bat"):
		_fail(root, "Baseball bat short press buffer/cancel should work through its AttackProfile.")
		return
	if not await _validate_tap_combo_movement_does_not_cancel_startup(player, "Baseball bat"):
		_fail(root, "Baseball bat tap_combo movement should not cancel startup attacks.")
		return
	if not await _validate_tap_combo_movement_turns_attack_direction(player, "Baseball bat"):
		_fail(root, "Baseball bat tap_combo movement should turn the attack direction.")
		return
	if not await _validate_tap_combo_animation_finish_clears_cooldown(player, "Baseball bat"):
		_fail(root, "Baseball bat tap_combo should not stay locked by long lockout after animation finish.")
		return
	if not await _validate_walk_clears_attack_state(player, "Baseball bat"):
		_fail(root, "Baseball bat attack state should be cleared before walk animation can hit.")
		return

	print("Generic primary attack profile is valid.")
	root.queue_free()
	quit()


func _validate_no_held_repeat(player: CharacterBody2D, label: String) -> bool:
	await _force_idle(player)
	player.set("current_direction", "down")
	var press := InputEventKey.new()
	press.keycode = KEY_J
	press.physical_keycode = KEY_J
	press.pressed = true
	player.call("_unhandled_input", press)
	await process_frame
	player.set("attack_lockout_remaining", 0.0)

	Input.parse_input_event(press)
	for frame in 20:
		await physics_frame

	var repeated_from_hold := float(player.get("attack_lockout_remaining")) > 0.0

	_release_primary_attack()
	await physics_frame

	if repeated_from_hold:
		push_error("%s tap_combo repeated from holding J." % label)
		return false
	return true


func _validate_short_press_cancel(player: CharacterBody2D, label: String) -> bool:
	await _force_idle(player)

	player.set("current_direction", "down")
	player.call("_begin_primary_attack")
	await process_frame

	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	var animation_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.stop()
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("attack_down_first"):
		push_error("%s is missing attack_down_first for cancel validation." % label)
		return false

	player.set("attack_lockout_remaining", 99.0)
	sprite.animation = &"attack_down_first"
	sprite.frame = 0
	player.call("_buffer_primary_attack_input")
	await physics_frame
	if float(player.get("attack_lockout_remaining")) < 90.0:
		push_error("%s short press cancel triggered before the recovery frames." % label)
		return false

	var frame_count := sprite.sprite_frames.get_frame_count("attack_down_first")
	player.set("_primary_attack_buffer_time_remaining", 0.0)
	player.call("_begin_primary_attack")
	await process_frame
	if animation_player != null:
		animation_player.stop()
	player.set("attack_lockout_remaining", 99.0)
	sprite.animation = &"attack_down_first"
	sprite.frame = maxi(frame_count - 1, 0)
	player.set("_current_attack_hit_window_reached", false)
	player.call("_buffer_primary_attack_input")
	player.call("_try_consume_buffered_primary_attack")
	if float(player.get("attack_lockout_remaining")) < 90.0:
		push_error("%s short press cancel triggered before the hit window was reached." % label)
		return false

	player.set("_primary_attack_buffer_time_remaining", 0.0)
	player.call("_begin_primary_attack")
	await process_frame
	if animation_player != null:
		animation_player.stop()
	player.set("attack_lockout_remaining", 99.0)
	sprite.animation = &"attack_down_first"
	sprite.frame = 2
	player.call("_on_frame_changed")
	sprite.frame = maxi(frame_count - 1, 0)
	player.call("_buffer_primary_attack_input")
	var consumed := bool(player.call("_try_consume_buffered_primary_attack"))
	if float(player.get("attack_lockout_remaining")) >= 90.0:
		push_error("%s short press cancel did not trigger in the recovery frames." % label)
		return false

	_release_primary_attack()
	return true


func _validate_walk_clears_attack_state(player: CharacterBody2D, label: String) -> bool:
	await _force_idle(player)

	player.set("current_direction", "down")
	player.call("_begin_primary_attack")
	await process_frame
	player.call("_set_attack_active", true)
	player.call("play_walk", "side")
	await physics_frame

	var attack_area := player.get_node("AttackArea2D") as Area2D
	var attack_shape := player.get_node("AttackArea2D/CollisionShape2D") as CollisionShape2D
	if bool(player.get("_attack_active")):
		push_error("%s attack runtime state stayed active after switching to walk." % label)
		return false
	if attack_area.monitoring:
		push_error("%s AttackArea2D stayed monitoring after switching to walk." % label)
		return false
	if not attack_shape.disabled:
		push_error("%s attack CollisionShape2D stayed enabled after switching to walk." % label)
		return false
	return true


func _validate_tap_combo_movement_does_not_cancel_startup(player: CharacterBody2D, label: String) -> bool:
	await _force_idle(player)

	player.set("current_direction", "down")
	player.call("_begin_primary_attack")
	await process_frame

	var move_press := InputEventKey.new()
	move_press.keycode = KEY_A
	move_press.physical_keycode = KEY_A
	move_press.pressed = true
	Input.parse_input_event(move_press)
	await physics_frame

	var move_release := InputEventKey.new()
	move_release.keycode = KEY_A
	move_release.physical_keycode = KEY_A
	move_release.pressed = false
	Input.parse_input_event(move_release)

	if player.call("get_player_state") != "attack":
		push_error("%s tap_combo movement cancelled the attack state during startup." % label)
		return false
	if String(player.call("get_attack_phase")) == "none":
		push_error("%s tap_combo movement cleared the attack phase during startup." % label)
		return false
	if String(player.get("_current_attack_action")) == "":
		push_error("%s tap_combo movement cleared the attack action during startup." % label)
		return false
	return true


func _validate_tap_combo_movement_turns_attack_direction(player: CharacterBody2D, label: String) -> bool:
	await _force_idle(player)

	player.set("current_direction", "down")
	player.call("_begin_primary_attack")
	await process_frame

	player.call("_turn_current_attack_to_direction", "side_left")
	await process_frame

	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	var attack_area := player.get_node("AttackArea2D") as Area2D
	var attack_area_offsets := player.get("attack_area_offsets") as Dictionary
	var expected_position := attack_area_offsets.get("side_left", Vector2.ZERO) as Vector2
	if String(player.get("current_direction")) != "side_left":
		push_error("%s tap_combo movement did not turn current_direction to side_left." % label)
		return false
	if String(player.get("_current_attack_animation")) != "attack_side_left_first":
		push_error("%s tap_combo movement did not switch the current attack animation." % label)
		return false
	if String(sprite.animation) != "attack_side_left_first":
		push_error("%s tap_combo movement did not switch the body animation." % label)
		return false
	if not attack_area.position.is_equal_approx(expected_position):
		push_error("%s tap_combo movement did not move AttackArea2D to side_left." % label)
		return false
	return true


func _validate_tap_combo_animation_finish_clears_cooldown(player: CharacterBody2D, label: String) -> bool:
	await _force_idle(player)

	var attack_profile := player.call("_get_attack_profile", "attack_first") as Resource
	if attack_profile == null:
		push_error("%s is missing an attack profile for lockout validation." % label)
		return false

	var old_manual_lockout := float(attack_profile.get("manual_attack_lockout"))
	attack_profile.set("manual_attack_lockout", 10.0)
	player.call("_begin_primary_attack")
	await process_frame
	if float(player.get("attack_lockout_remaining")) < 9.0:
		attack_profile.set("manual_attack_lockout", old_manual_lockout)
		push_error("%s did not apply the long manual attack lockout at attack start." % label)
		return false

	player.call("_on_animation_player_finished", &"attack_down_first")
	await process_frame
	var lockout_after_finish := float(player.get("attack_lockout_remaining"))
	attack_profile.set("manual_attack_lockout", old_manual_lockout)
	if lockout_after_finish > 0.0:
		push_error("%s stayed lockout-locked after tap_combo animation finished." % label)
		return false
	return true


func _force_idle(player: CharacterBody2D) -> void:
	_release_primary_attack()
	_set_move_left_pressed(false)
	var animation_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.stop()
	player.call("_clear_attack_runtime_state")
	player.call("play_idle", "down")
	player.set("attack_lockout_remaining", 0.0)
	await physics_frame


func _release_primary_attack() -> void:
	var release := InputEventKey.new()
	release.keycode = KEY_J
	release.physical_keycode = KEY_J
	release.pressed = false
	Input.parse_input_event(release)


func _set_move_left_pressed(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_LEFT
	event.physical_keycode = KEY_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
