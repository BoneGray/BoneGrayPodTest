@tool
extends SceneTree

const BIG_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const SMALL_SCENE_PATH := "res://scenes/characters/enemy_zombie_small.tscn"
const AXE_SCENE_PATH := "res://scenes/characters/enemy_zombie_axe.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _validate_enemy_profile(BIG_SCENE_PATH, "attack_first", {
		"type": "melee",
		"selection_weight": 1.0,
	})
	await _validate_enemy_profile(BIG_SCENE_PATH, "attack_second", {
		"type": "melee",
		"selection_weight": 0.55,
		"special_cooldown": 3.0,
		"status_effect": "stun",
	})
	await _validate_enemy_profile(SMALL_SCENE_PATH, "attack_first", {
		"type": "melee",
		"selection_weight": 1.0,
	})
	await _validate_enemy_profile(SMALL_SCENE_PATH, "attack_second", {
		"type": "cross",
		"min_range": 12.0,
		"max_range": 56.0,
		"hit_detection": "body_motion",
		"cross_distance": 18.0,
	})
	await _validate_enemy_profile(AXE_SCENE_PATH, "attack_first", {
		"type": "melee",
		"selection_weight": 1.0,
		"requires_weapon": true,
	})
	await _validate_enemy_profile(AXE_SCENE_PATH, "attack_first_no_axe", {
		"type": "melee",
		"selection_weight": 1.0,
		"requires_no_weapon": true,
		"damage": 4,
	})
	await _validate_enemy_profile(AXE_SCENE_PATH, "attack_second", {
		"type": "projectile",
		"requires_weapon": true,
		"damage": 10,
		"projectile_scene": "res://scenes/projectiles/axe_projectile.tscn",
		"drop_weapon": true,
	})

	print("Enemy attack profile resource validation passed.")
	quit()


func _validate_enemy_profile(scene_path: String, action_name: String, expected_values: Dictionary) -> void:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		_fail("Could not load enemy scene: %s" % scene_path)
		return

	var enemy := scene.instantiate() as BaseEnemy
	if enemy == null:
		_fail("Could not instantiate BaseEnemy from: %s" % scene_path)
		return
	root.add_child(enemy)
	await process_frame

	var profile := enemy.get_attack_profile(action_name)
	for key in expected_values:
		if not profile.has(key):
			enemy.queue_free()
			_fail("%s %s should include %s." % [scene_path, action_name, key])
			return
		if not _values_equal(profile[key], expected_values[key]):
			enemy.queue_free()
			_fail("%s %s has unexpected %s value." % [scene_path, action_name, key])
			return

	enemy.queue_free()


func _values_equal(actual: Variant, expected: Variant) -> bool:
	if actual is float or expected is float:
		return is_equal_approx(float(actual), float(expected))
	return actual == expected


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
