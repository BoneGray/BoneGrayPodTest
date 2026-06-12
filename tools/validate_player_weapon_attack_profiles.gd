@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const BAT_DATA_PATH := "res://resources/equipment/weapons/baseball_bat/baseball_bat_data.tres"
const GUN_DATA_PATH := "res://resources/equipment/weapons/gun/gun_data.tres"
const PISTOL_DATA_PATH := "res://resources/equipment/weapons/pistol/pistol_data.tres"
const SHOTGUN_DATA_PATH := "res://resources/equipment/weapons/shotgun/shotgun_data.tres"
const UNARMED_PRIMARY_PATH := "res://resources/equipment/weapons/unarmed/unarmed_primary_attack.tres"
const UNARMED_SECONDARY_PATH := "res://resources/equipment/weapons/unarmed/unarmed_secondary_attack.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var bat_data := load(BAT_DATA_PATH) as Resource
	var gun_data := load(GUN_DATA_PATH) as Resource
	var pistol_data := load(PISTOL_DATA_PATH) as Resource
	var shotgun_data := load(SHOTGUN_DATA_PATH) as Resource
	var unarmed_primary := load(UNARMED_PRIMARY_PATH) as Resource
	var unarmed_secondary := load(UNARMED_SECONDARY_PATH) as Resource
	if player_scene == null or bat_data == null or gun_data == null or pistol_data == null or shotgun_data == null or unarmed_primary == null or unarmed_secondary == null:
		_fail("Could not load player weapon attack profile dependencies.")
		return

	_assert_attack_profile(unarmed_primary, "Unarmed primary", {
		"input_mode": "tap_combo",
		"damage": 5,
		"cooldown": 0.35,
		"cancel_last_frames": 1,
		"startup_frames": [0, 1],
		"active_frames": [2],
		"recovery_frames": [3],
		"movement_rule": "slow_turn_to_input",
	})
	_assert_attack_profile(unarmed_secondary, "Unarmed secondary", {
		"animation_action": "attack_second",
		"damage": 10,
		"cooldown": 0.35,
		"startup_frames": [0, 1],
		"active_frames": [2],
		"recovery_frames": [3],
		"movement_rule": "slow_turn_to_input",
		"max_targets": 3,
	})
	_assert_profile(bat_data, "primary_attack_profile", {
		"attack_type": "melee",
		"input_mode": "tap_combo",
		"damage": 10,
		"cooldown": 0.65,
		"cancel_last_frames": 1,
		"startup_frames": [0, 1],
		"active_frames": [2],
		"recovery_frames": [3],
		"movement_rule": "slow_turn_to_input",
	})
	_assert_profile(bat_data, "secondary_attack_profile", {
		"attack_type": "melee",
		"animation_action": "attack_second",
		"damage": 16,
		"cooldown": 0.45,
		"startup_frames": [0, 1],
		"active_frames": [2],
		"recovery_frames": [3],
		"movement_rule": "slow_turn_to_input",
		"max_targets": 3,
	})
	_assert_profile(gun_data, "primary_attack_profile", {
		"attack_type": "projectile",
		"input_mode": "hold_repeat",
		"repeat_mode": "enabled",
		"hold_to_repeat_delay": 0.1,
		"damage": 12,
		"cooldown": 0.12,
		"cancel_last_frames": 0,
		"startup_frames": [0],
		"active_frames": [0],
		"movement_rule": "slow_locked_direction",
	})
	_assert_profile(pistol_data, "primary_attack_profile", {
		"attack_type": "projectile",
		"input_mode": "hold_repeat",
		"repeat_mode": "enabled",
		"hold_to_repeat_delay": 0.16,
		"damage": 18,
		"cooldown": 0.32,
		"cancel_last_frames": 0,
		"startup_frames": [0],
		"active_frames": [0],
		"movement_rule": "slow_locked_direction",
	})
	_assert_profile(shotgun_data, "primary_attack_profile", {
		"attack_type": "projectile",
		"input_mode": "hold_repeat",
		"repeat_mode": "enabled",
		"hold_to_repeat_delay": 0.28,
		"damage": 7,
		"cooldown": 0.85,
		"cancel_last_frames": 0,
		"startup_frames": [0],
		"active_frames": [0],
		"movement_rule": "slow_locked_direction",
		"projectile_count": 5,
		"projectile_spread_degrees": 22.0,
	})
	_assert_equal(int(bat_data.get("attack_power")), 0, "Bat attack_power should stay as migration fallback.")
	_assert_equal(float(bat_data.get("attack_cooldown")), 0.0, "Bat attack_cooldown should stay as migration fallback.")
	_assert_equal(bool(bat_data.get("repeat_while_held")), false, "Bat repeat_while_held should stay as migration fallback.")
	_assert_equal(int(gun_data.get("attack_power")), 0, "Gun attack_power should stay as migration fallback.")
	_assert_equal(float(gun_data.get("attack_cooldown")), 0.0, "Gun attack_cooldown should stay as migration fallback.")
	_assert_equal(bool(gun_data.get("repeat_while_held")), false, "Gun repeat_while_held should stay as migration fallback.")
	_assert_equal(int(pistol_data.get("attack_power")), 0, "Pistol attack_power should stay as migration fallback.")
	_assert_equal(float(pistol_data.get("attack_cooldown")), 0.0, "Pistol attack_cooldown should stay as migration fallback.")
	_assert_equal(bool(pistol_data.get("repeat_while_held")), false, "Pistol repeat_while_held should stay as migration fallback.")
	_assert_equal(int(shotgun_data.get("attack_power")), 0, "Shotgun attack_power should stay as migration fallback.")
	_assert_equal(float(shotgun_data.get("attack_cooldown")), 0.0, "Shotgun attack_cooldown should stay as migration fallback.")
	_assert_equal(bool(shotgun_data.get("repeat_while_held")), false, "Shotgun repeat_while_held should stay as migration fallback.")

	var root := Node2D.new()
	get_root().add_child(root)
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	player.call("equip_weapon", bat_data)
	await process_frame
	var bat_primary := bat_data.get("primary_attack_profile") as Resource
	if absf(float(player.call("get_attack_cooldown", bat_primary)) - 0.65) > 0.001:
		root.queue_free()
		_fail("Bat attack cooldown should come from its primary AttackProfile.")
		return

	player.call("equip_weapon", gun_data)
	await process_frame
	var gun_primary := gun_data.get("primary_attack_profile") as Resource
	if absf(float(player.call("get_attack_cooldown", gun_primary)) - 0.12) > 0.001:
		root.queue_free()
		_fail("Gun attack cooldown should come from its primary AttackProfile.")
		return
	if not bool(player.call("_is_repeat_attack_enabled", gun_primary)):
		root.queue_free()
		_fail("Gun hold-repeat should come from its primary AttackProfile.")
		return
	if absf(float(player.call("_get_hold_to_repeat_delay", gun_primary)) - 0.1) > 0.001:
		root.queue_free()
		_fail("Gun hold-repeat delay should come from its primary AttackProfile.")
		return
	player.call("attack", "attack_first", "side")
	await process_frame
	if String(player.call("_get_current_attack_movement_rule")) != "slow_locked_direction":
		root.queue_free()
		_fail("Gun attack movement rule should lock direction.")
		return

	player.call("equip_weapon", pistol_data)
	await process_frame
	var pistol_primary := pistol_data.get("primary_attack_profile") as Resource
	if absf(float(player.call("get_attack_cooldown", pistol_primary)) - 0.32) > 0.001:
		root.queue_free()
		_fail("Pistol attack cooldown should come from its primary AttackProfile.")
		return
	if not bool(player.call("_is_repeat_attack_enabled", pistol_primary)):
		root.queue_free()
		_fail("Pistol should enable hold-repeat.")
		return
	if absf(float(player.call("_get_hold_to_repeat_delay", pistol_primary)) - 0.16) > 0.001:
		root.queue_free()
		_fail("Pistol hold-repeat delay should come from its primary AttackProfile.")
		return

	player.call("equip_weapon", shotgun_data)
	await process_frame
	var shotgun_primary := shotgun_data.get("primary_attack_profile") as Resource
	if absf(float(player.call("get_attack_cooldown", shotgun_primary)) - 0.85) > 0.001:
		root.queue_free()
		_fail("Shotgun attack cooldown should come from its primary AttackProfile.")
		return
	if not bool(player.call("_is_repeat_attack_enabled", shotgun_primary)):
		root.queue_free()
		_fail("Shotgun should enable hold-repeat.")
		return
	if absf(float(player.call("_get_hold_to_repeat_delay", shotgun_primary)) - 0.28) > 0.001:
		root.queue_free()
		_fail("Shotgun hold-repeat delay should come from its primary AttackProfile.")
		return
	player.call("attack", "attack_first", "side")
	await process_frame
	if String(player.call("_get_current_attack_movement_rule")) != "slow_locked_direction":
		root.queue_free()
		_fail("Shotgun attack movement rule should lock direction.")
		return

	print("Player weapon attack profiles validation passed.")
	root.queue_free()
	quit()


func _assert_profile(weapon_data: Resource, profile_property: String, expected_values: Dictionary) -> void:
	var profile := weapon_data.get(profile_property) as Resource
	if profile == null:
		_fail("%s should define %s." % [weapon_data.get("display_name"), profile_property])
		return
	_assert_attack_profile(profile, "%s %s" % [weapon_data.get("display_name"), profile_property], expected_values)


func _assert_attack_profile(profile: Resource, label: String, expected_values: Dictionary) -> void:
	for key in expected_values:
		if profile.get(key) == null:
			_fail("%s should define %s." % [label, key])
			return
		_assert_equal(profile.get(key), expected_values[key], "%s has unexpected %s." % [label, key])


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual is float or expected is float:
		if is_equal_approx(float(actual), float(expected)):
			return
	elif actual is Array and expected is Array:
		if _arrays_equal(actual, expected):
			return
	elif actual == expected:
		return
	_fail(message)


func _arrays_equal(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if actual[index] != expected[index]:
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
