@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const FIREARM_CASES := [
	{
		"label": "Gun",
		"path": "res://resources/equipment/weapons/gun/gun_data.tres",
		"min_hold_seconds": 0.9,
		"expect_locked_direction": true,
	},
	{
		"label": "Pistol",
		"path": "res://resources/equipment/weapons/pistol/pistol_data.tres",
		"min_hold_seconds": 0.75,
		"expect_locked_direction": true,
	},
	{
		"label": "Shotgun",
		"path": "res://resources/equipment/weapons/shotgun/shotgun_data.tres",
		"min_hold_seconds": 1.45,
		"expect_locked_direction": true,
	},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var effect_manager := get_root().get_node_or_null("EffectManager")
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if effect_manager == null or player_scene == null:
		_fail(null, "Could not load firearm hold-repeat dependencies.")
		return

	for firearm_case in FIREARM_CASES:
		if not await _validate_firearm_case(player_scene, effect_manager, firearm_case):
			return

	print("All firearm hold-repeat behavior is valid.")
	quit()


func _validate_firearm_case(player_scene: PackedScene, effect_manager: Node, firearm_case: Dictionary) -> bool:
	var weapon_data := load(String(firearm_case["path"])) as Resource
	if weapon_data == null:
		_fail(null, "Could not load %s weapon data." % firearm_case["label"])
		return false

	var primary_attack := weapon_data.get("primary_attack_profile") as Resource
	if primary_attack == null:
		_fail(null, "%s should define a primary attack profile." % firearm_case["label"])
		return false
	if String(primary_attack.get("input_mode")) != "hold_repeat":
		_fail(null, "%s should use hold_repeat." % firearm_case["label"])
		return false
	if not bool(primary_attack.get("repeat_mode") == "enabled"):
		_fail(null, "%s should enable repeat_mode." % firearm_case["label"])
		return false

	if not await _validate_firearm_hold_repeat_mode(player_scene, effect_manager, weapon_data, firearm_case, false, false):
		return false
	if not await _validate_firearm_hold_repeat_mode(player_scene, effect_manager, weapon_data, firearm_case, true, false):
		return false
	if not await _validate_firearm_hold_repeat_mode(player_scene, effect_manager, weapon_data, firearm_case, false, true):
		return false
	if not await _validate_firearm_hold_session_direction_lock(player_scene, effect_manager, weapon_data, firearm_case):
		return false
	return true


func _validate_firearm_hold_repeat_mode(
	player_scene: PackedScene,
	effect_manager: Node,
	weapon_data: Resource,
	firearm_case: Dictionary,
	move_while_firing: bool,
	equip_via_pickup: bool
) -> bool:
	effect_manager.reset_debug_counts()
	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	if equip_via_pickup:
		if not await _equip_weapon_via_pickup(root, player, weapon_data):
			_fail(root, "%s should be equipped through its pickup scene." % firearm_case["label"])
			return false
	else:
		player.call("equip_weapon", weapon_data)
	await process_frame
	if equip_via_pickup:
		for frame in 30:
			await physics_frame
	player.call("play_idle", "side")
	player.set("attack_lockout_remaining", 0.0)
	await physics_frame

	var press := InputEventKey.new()
	press.keycode = KEY_J
	press.physical_keycode = KEY_J
	press.pressed = true
	player.call("_unhandled_input", press)
	Input.parse_input_event(press)

	var move_press := InputEventKey.new()
	if move_while_firing:
		move_press.keycode = KEY_D
		move_press.physical_keycode = KEY_D
		move_press.pressed = true
		Input.parse_input_event(move_press)

	var frame_count := int(ceil(float(firearm_case["min_hold_seconds"]) * 60.0))
	for frame in frame_count:
		await physics_frame

	var muzzle_flash_count := int(effect_manager.get_total_spawned("muzzle_flash"))
	if muzzle_flash_count < 2:
		var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
		var mode_label := _hold_repeat_mode_label(move_while_firing, equip_via_pickup)
		var debug_parts := [
			"mode=%s" % mode_label,
			"muzzle_flashes=%d" % muzzle_flash_count,
			"lockout=%.3f" % float(player.get("attack_lockout_remaining")),
			"repeat_ready=%s" % str(player.get("_primary_attack_repeat_ready")),
			"repeat_active=%s" % str(player.get("_primary_attack_repeat_active")),
			"state=%s" % String(player.call("get_player_state")),
			"animation=%s" % (String(sprite.animation) if sprite != null else "<missing>"),
			"frame=%d" % (sprite.frame if sprite != null else -1),
			"locked=%s" % str(player.call("_is_locked_animation")),
		]
		_release_hold_repeat_inputs(move_while_firing)
		_fail(root, "%s should fire more than once while J is held. %s." % [firearm_case["label"], ", ".join(debug_parts)])
		return false

	if move_while_firing and bool(firearm_case["expect_locked_direction"]) and String(player.get("current_direction")) != "side":
		_release_hold_repeat_inputs(move_while_firing)
		_fail(root, "%s should keep firing direction while moving during hold-repeat." % firearm_case["label"])
		return false

	_release_hold_repeat_inputs(move_while_firing)
	await physics_frame

	root.queue_free()
	return true


func _equip_weapon_via_pickup(root: Node2D, player: CharacterBody2D, weapon_data: Resource) -> bool:
	var pickup_scene_path := String(weapon_data.get("pickup_scene_path"))
	var pickup_scene := load(pickup_scene_path) as PackedScene
	if pickup_scene == null:
		return false

	var pickup := pickup_scene.instantiate() as Node2D
	if pickup == null:
		return false

	root.add_child(pickup)
	pickup.global_position = player.global_position
	await physics_frame

	var pickup_event := InputEventKey.new()
	pickup_event.keycode = KEY_E
	pickup_event.physical_keycode = KEY_E
	pickup_event.pressed = true
	player.call("_unhandled_input", pickup_event)
	await physics_frame

	var release := InputEventKey.new()
	release.keycode = KEY_E
	release.physical_keycode = KEY_E
	release.pressed = false
	player.call("_unhandled_input", release)
	await physics_frame

	return player.get("equipped_weapon") == weapon_data


func _validate_firearm_hold_session_direction_lock(
	player_scene: PackedScene,
	effect_manager: Node,
	weapon_data: Resource,
	firearm_case: Dictionary
) -> bool:
	effect_manager.reset_debug_counts()
	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	player.call("equip_weapon", weapon_data)
	await process_frame
	player.call("play_idle", "side")
	player.set("attack_lockout_remaining", 0.0)
	await physics_frame

	var press := InputEventKey.new()
	press.keycode = KEY_J
	press.physical_keycode = KEY_J
	press.pressed = true
	player.call("_unhandled_input", press)
	Input.parse_input_event(press)

	for frame in 24:
		await physics_frame

	var move_up := InputEventKey.new()
	move_up.keycode = KEY_W
	move_up.physical_keycode = KEY_W
	move_up.pressed = true
	Input.parse_input_event(move_up)

	for frame in 24:
		await physics_frame

	if bool(firearm_case["expect_locked_direction"]) and String(player.get("current_direction")) != "side":
		_release_key(KEY_J)
		_release_key(KEY_W)
		_fail(root, "%s should keep locked fire direction during hold-repeat cooldown while moving up." % firearm_case["label"])
		return false

	_release_key(KEY_J)
	_release_key(KEY_W)
	await physics_frame

	root.queue_free()
	return true


func _hold_repeat_mode_label(move_while_firing: bool, equip_via_pickup: bool) -> String:
	if equip_via_pickup:
		return "stationary_after_pickup"
	return "moving" if move_while_firing else "stationary"


func _release_hold_repeat_inputs(release_movement: bool) -> void:
	_release_key(KEY_J)
	if not release_movement:
		return
	_release_key(KEY_D)


func _release_key(key: int) -> void:
	var release := InputEventKey.new()
	release.keycode = key
	release.physical_keycode = key
	release.pressed = false
	Input.parse_input_event(release)


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
