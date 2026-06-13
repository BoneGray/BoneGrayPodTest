@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const FIREARM_WEAPONS := {
	"res://resources/equipment/weapons/gun/gun_data.tres": 30,
	"res://resources/equipment/weapons/pistol/pistol_data.tres": 15,
	"res://resources/equipment/weapons/shotgun/shotgun_data.tres": 8,
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		_fail("Player scene should load.")
		return

	for weapon_path in FIREARM_WEAPONS.keys():
		var weapon_data := load(String(weapon_path)) as Resource
		var expected_magazine_size := int(FIREARM_WEAPONS[weapon_path])
		var error := await _validate_weapon_reload(player_scene, weapon_data, String(weapon_path), expected_magazine_size)
		if error != "":
			_fail(error)
			return

	print("Firearm reload logic is valid.")
	quit()


func _validate_weapon_reload(
	player_scene: PackedScene,
	weapon_data: Resource,
	weapon_path: String,
	expected_magazine_size: int
) -> String:
	if weapon_data == null:
		return "Could not load firearm weapon data: %s." % weapon_path
	if String(weapon_data.get("weapon_type")) != "firearm":
		return "%s should be a firearm." % weapon_path
	if int(weapon_data.get("magazine_size")) != expected_magazine_size:
		return "%s magazine_size should be %d." % [weapon_path, expected_magazine_size]

	var root := Node2D.new()
	get_root().add_child(root)
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	player.call("equip_weapon", weapon_data)
	await process_frame
	await _wait_until_not_pickup(player, 1.0)
	player.call("play_idle", "side")
	await process_frame
	if int(player.call("get_current_weapon_magazine_size")) != expected_magazine_size:
		root.queue_free()
		return "%s equipped magazine size should be %d." % [weapon_path, expected_magazine_size]
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size:
		root.queue_free()
		return "%s should start with a full magazine." % weapon_path

	for shot_index in expected_magazine_size:
		player.call("attack", "attack_first", "side")
		await physics_frame
		var expected_ammo := expected_magazine_size - shot_index - 1
		if int(player.call("get_current_weapon_ammo")) != expected_ammo:
			root.queue_free()
			return "%s should consume one ammo per shot. Expected %d after shot %d." % [weapon_path, expected_ammo, shot_index + 1]

	player.call("attack", "attack_first", "side")
	await process_frame

	var frames := weapon_data.get("visual_sprite_frames") as SpriteFrames
	var reload_duration := _reload_duration(frames, "reload_side")
	if reload_duration > 0.0:
		if not bool(player.call("is_reloading_weapon")):
			root.queue_free()
			return "%s should enter reload when firing with an empty magazine." % weapon_path
		if String(player.call("get_player_state")) != "reload":
			root.queue_free()
			return "%s should use the reload player state while reloading. state=%s animation=%s reloading=%s" % [
				weapon_path,
				String(player.call("get_player_state")),
				String(player.get_node("Sprite").animation),
				str(player.call("is_reloading_weapon")),
			]
		if int(player.call("get_current_weapon_ammo")) != 0:
			root.queue_free()
			return "%s should not refill before reload animation time completes." % weapon_path
		player.call("attack", "attack_first", "side")
		await physics_frame
		if int(player.call("get_current_weapon_ammo")) != 0 or not bool(player.call("is_reloading_weapon")):
			root.queue_free()
			return "%s should not fire or refill early while reload is active." % weapon_path
		await _wait_seconds(reload_duration + 0.1)
	else:
		await physics_frame

	if bool(player.call("is_reloading_weapon")):
		root.queue_free()
		return "%s reload should finish after its reload animation time." % weapon_path
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size:
		root.queue_free()
		return "%s should refill to full magazine after reload." % weapon_path

	var manual_reload_error := await _validate_manual_reload(player, weapon_data, weapon_path, expected_magazine_size, reload_duration)
	if manual_reload_error != "":
		root.queue_free()
		return manual_reload_error

	if reload_duration > 0.0:
		var resume_error := await _validate_hold_repeat_resume_after_reload(player, weapon_data, weapon_path, expected_magazine_size, reload_duration)
		if resume_error != "":
			root.queue_free()
			return resume_error
		var direction_lock_error := await _validate_hold_repeat_reload_direction_lock(player, weapon_data, weapon_path, expected_magazine_size, reload_duration)
		if direction_lock_error != "":
			root.queue_free()
			return direction_lock_error
		var pending_error := await _validate_reload_input_pending_until_shot_consumes_ammo(player, weapon_data, weapon_path, expected_magazine_size, reload_duration)
		if pending_error != "":
			root.queue_free()
			return pending_error

	root.queue_free()
	return ""


func _validate_manual_reload(
	player: CharacterBody2D,
	_weapon_data: Resource,
	weapon_path: String,
	expected_magazine_size: int,
	reload_duration: float
) -> String:
	player.call("play_idle", "side")
	player.set("attack_lockout_remaining", 0.0)
	player.call("attack", "attack_first", "side")
	await physics_frame
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size - 1:
		return "%s should consume ammo before manual reload validation." % weapon_path

	_stop_player_animation(player)
	player.call("_clear_attack_runtime_state")
	player.set("attack_lockout_remaining", 0.0)
	player.call("_play_idle_animation_immediate", "side")
	player.call("play_idle", "side")
	await physics_frame
	_press_key(player, KEY_R, false)
	await physics_frame
	await _wait_until_reload_started(player, 1.0)
	if reload_duration > 0.0 and not bool(player.call("is_reloading_weapon")) and int(player.call("get_current_weapon_ammo")) != expected_magazine_size:
		return "%s should start manual reload from R after a partial magazine shot. state=%s ammo=%d buffered=%s" % [
			weapon_path,
			String(player.call("get_player_state")),
			int(player.call("get_current_weapon_ammo")),
			str(player.get("_firearm_reload_buffered")),
		]
	await _wait_until_reload_finished_or_full(player, expected_magazine_size, maxf(reload_duration + 0.4, 1.2))
	if bool(player.call("is_reloading_weapon")):
		return "%s manual reload should finish." % weapon_path
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size:
		return "%s manual reload should refill the magazine." % weapon_path
	return ""


func _validate_hold_repeat_resume_after_reload(
	player: CharacterBody2D,
	_weapon_data: Resource,
	weapon_path: String,
	expected_magazine_size: int,
	reload_duration: float
) -> String:
	player.call("play_idle", "side")
	player.set("attack_lockout_remaining", 0.0)
	_press_key(player, KEY_J, true)
	await physics_frame
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size - 1:
		_release_key(KEY_J)
		return "%s should fire once before buffered reload resume validation." % weapon_path
	_press_key(player, KEY_R, false)
	await physics_frame
	if bool(player.call("is_reloading_weapon")):
		_release_key(KEY_J)
		return "%s should buffer R during the current shot instead of interrupting it immediately." % weapon_path

	await _wait_until_reload_started(player, 1.0)
	if not bool(player.call("is_reloading_weapon")):
		_release_key(KEY_J)
		return "%s should enter reload after the current shot finishes." % weapon_path

	await _wait_seconds(reload_duration + 0.08)
	if bool(player.call("is_reloading_weapon")):
		_release_key(KEY_J)
		return "%s should finish buffered reload." % weapon_path
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size - 1:
		_release_key(KEY_J)
		return "%s should resume held fire after reload and consume one new shot. ammo=%d state=%s hold=%s direction=%s resume=%s resume_weapon=%s" % [
			weapon_path,
			int(player.call("get_current_weapon_ammo")),
			String(player.call("get_player_state")),
			str(Input.is_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_J)),
			String(player.get("current_direction")),
			str(player.get("_firearm_reload_resume_hold_repeat")),
			str(player.get("_firearm_reload_resume_weapon")),
		]
	_release_key(KEY_J)
	await physics_frame
	return ""


func _validate_hold_repeat_reload_direction_lock(
	player: CharacterBody2D,
	_weapon_data: Resource,
	weapon_path: String,
	expected_magazine_size: int,
	reload_duration: float
) -> String:
	_release_key(KEY_J)
	_release_key(KEY_W)
	await physics_frame
	var prepare_error := await _prepare_full_magazine(player, weapon_path, expected_magazine_size, reload_duration)
	if prepare_error != "":
		return prepare_error
	player.call("play_idle", "side")
	player.set("attack_lockout_remaining", 0.0)
	_press_key(player, KEY_J, true)
	await physics_frame
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size - 1:
		_release_key(KEY_J)
		return "%s should fire before reload direction-lock validation." % weapon_path

	_press_key(player, KEY_W, true)
	for frame in 12:
		await physics_frame
	if String(player.get("current_direction")) != "side":
		_release_key(KEY_J)
		_release_key(KEY_W)
		return "%s should keep pre-reload fire direction while moving during held fire. expected=side actual=%s" % [
			weapon_path,
			String(player.get("current_direction")),
		]

	_press_key(player, KEY_R, false)
	await physics_frame
	await _wait_until_reload_started(player, 1.0)
	if not bool(player.call("is_reloading_weapon")):
		_release_key(KEY_J)
		_release_key(KEY_W)
		return "%s should start reload for direction-lock validation." % weapon_path

	await _wait_seconds(reload_duration + 0.08)

	if bool(player.call("is_reloading_weapon")):
		_release_key(KEY_J)
		_release_key(KEY_W)
		return "%s should finish reload during direction-lock validation." % weapon_path
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size - 1:
		_release_key(KEY_J)
		_release_key(KEY_W)
		return "%s should resume held fire after moving during reload." % weapon_path
	if String(player.get("current_direction")) != "side":
		_release_key(KEY_J)
		_release_key(KEY_W)
		return "%s should keep pre-reload fire direction after reload. expected=side actual=%s" % [
			weapon_path,
			String(player.get("current_direction")),
		]

	var y_before_resume_move := player.global_position.y
	for frame in 12:
		await physics_frame
	var y_after_resume_move := player.global_position.y
	_release_key(KEY_W)
	if y_after_resume_move >= y_before_resume_move - 0.5:
		_release_key(KEY_J)
		return "%s should keep moving while held fire resumes after reload. y_before=%.2f y_after=%.2f state=%s animation=%s lockout=%.3f repeat_ready=%s repeat_active=%s" % [
			weapon_path,
			y_before_resume_move,
			y_after_resume_move,
			String(player.call("get_player_state")),
			String((player.get_node("Sprite") as AnimatedSprite2D).animation),
			float(player.get("attack_lockout_remaining")),
			str(player.get("_primary_attack_repeat_ready")),
			str(player.get("_primary_attack_repeat_active")),
		]

	_release_key(KEY_J)
	await physics_frame
	return ""


func _prepare_full_magazine(player: CharacterBody2D, weapon_path: String, expected_magazine_size: int, reload_duration: float) -> String:
	if int(player.call("get_current_weapon_ammo")) == expected_magazine_size:
		return ""
	player.call("_clear_attack_runtime_state")
	player.set("attack_lockout_remaining", 0.0)
	player.call("play_idle", "side")
	_press_key(player, KEY_R, false)
	await _wait_until_reload_finished_or_full(player, expected_magazine_size, maxf(reload_duration + 0.4, 1.2))
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size:
		return "%s should prepare a full magazine before direction-lock validation." % weapon_path
	return ""


func _validate_reload_input_pending_until_shot_consumes_ammo(
	player: CharacterBody2D,
	weapon_data: Resource,
	weapon_path: String,
	expected_magazine_size: int,
	reload_duration: float
) -> String:
	_release_key(KEY_J)
	_release_key(KEY_W)
	await physics_frame
	var prepare_error := await _prepare_full_magazine(player, weapon_path, expected_magazine_size, reload_duration)
	if prepare_error != "":
		return prepare_error

	player.call("play_idle", "side")
	player.set("attack_lockout_remaining", 0.0)
	player.call("attack", "attack_first", "side")
	await physics_frame
	var firearm_controller = player.get("_firearm_controller")
	firearm_controller.current_magazine_by_weapon[weapon_data.resource_path] = expected_magazine_size
	_press_key(player, KEY_R, false)
	await physics_frame
	if not bool(player.get("_firearm_reload_buffered")):
		return "%s should buffer R while the current shot is locked even if ammo is not yet reloadable." % weapon_path

	firearm_controller.current_magazine_by_weapon[weapon_data.resource_path] = expected_magazine_size - 1
	await _wait_until_reload_started(player, 1.0)
	if not bool(player.call("is_reloading_weapon")):
		return "%s should consume pending R after the shot makes the magazine reloadable." % weapon_path
	await _wait_until_reload_finished_or_full(player, expected_magazine_size, maxf(reload_duration + 0.4, 1.2))
	if int(player.call("get_current_weapon_ammo")) != expected_magazine_size:
		return "%s pending R reload should refill the magazine." % weapon_path
	return ""


func _reload_duration(frames: SpriteFrames, animation_name: String) -> float:
	if frames == null or not frames.has_animation(animation_name):
		return 0.0
	var speed := frames.get_animation_speed(animation_name)
	if speed <= 0.0:
		return 0.0
	return float(frames.get_frame_count(animation_name)) / float(speed)


func _wait_seconds(seconds: float) -> void:
	var remaining := maxf(seconds, 0.0)
	while remaining > 0.0:
		await physics_frame
		remaining -= 1.0 / 60.0


func _wait_until_reload_started(player: CharacterBody2D, timeout_seconds: float) -> void:
	var remaining := maxf(timeout_seconds, 0.0)
	while remaining > 0.0 and not bool(player.call("is_reloading_weapon")):
		await physics_frame
		remaining -= 1.0 / 60.0


func _wait_until_reload_finished_or_full(player: CharacterBody2D, expected_magazine_size: int, timeout_seconds: float) -> void:
	var remaining := maxf(timeout_seconds, 0.0)
	while remaining > 0.0:
		if not bool(player.call("is_reloading_weapon")) and int(player.call("get_current_weapon_ammo")) == expected_magazine_size:
			return
		await physics_frame
		remaining -= 1.0 / 60.0


func _wait_until_not_pickup(player: CharacterBody2D, timeout_seconds: float) -> void:
	var remaining := maxf(timeout_seconds, 0.0)
	while remaining > 0.0 and String(player.call("get_player_state")) == "pickup":
		await physics_frame
		remaining -= 1.0 / 60.0


func _press_key(player: CharacterBody2D, key: int, keep_pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	player.call("_unhandled_input", event)
	if keep_pressed:
		Input.parse_input_event(event)


func _release_key(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)


func _stop_player_animation(player: CharacterBody2D) -> void:
	var animation_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.stop()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
