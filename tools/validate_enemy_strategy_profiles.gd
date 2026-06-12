@tool
extends SceneTree

const BIG_STATS_PATH := "res://resources/characters/enemies/zombie_big_stats.tres"
const SMALL_STATS_PATH := "res://resources/characters/enemies/zombie_small_stats.tres"
const AXE_STATS_PATH := "res://resources/characters/enemies/zombie_axe_stats.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var big := load(BIG_STATS_PATH)
	var small := load(SMALL_STATS_PATH)
	var axe := load(AXE_STATS_PATH)
	if big == null or small == null or axe == null:
		_fail("Could not load enemy strategy stats resources.")
		return

	_assert_equal(big.get("attack_selection_order"), "special_first", "Big should use the Normal special-first strategy.")
	_assert_profile_is_resource(big, "attack_first")
	_assert_profile(big, "attack_first", {
		"selection_weight": 1.0,
		"type": "melee",
	})
	_assert_profile_is_resource(big, "attack_second")
	_assert_profile(big, "attack_second", {
		"selection_weight": 0.55,
		"special_cooldown": 3.0,
		"repeat_weight_multiplier": 0.4,
		"target_stunned_weight_multiplier": 0.6,
		"status_effect": "stun",
	})

	_assert_equal(small.get("attack_selection_order"), "special_first", "Small should use the Normal special-first strategy.")
	_assert_profile_is_resource(small, "attack_first")
	_assert_profile(small, "attack_first", {
		"selection_weight": 1.0,
		"type": "melee",
	})
	_assert_profile_is_resource(small, "attack_second")
	_assert_profile(small, "attack_second", {
		"selection_weight": 1.0,
		"special_cooldown": 2.0,
		"repeat_weight_multiplier": 0.65,
		"target_stunned_weight_multiplier": 2.0,
		"type": "cross",
	})

	_assert_equal(axe.get("attack_selection_order"), "special_first", "Axe should use the Normal special-first strategy.")
	_assert_equal(axe.get("weapon_pickup_range"), 8.0, "Axe should define weapon pickup range in stats.")
	_assert_equal(axe.get("no_weapon_close_attack_range"), 26.0, "Axe should define no-weapon close attack range in stats.")
	_assert_equal(axe.get("weapon_retrieval_timeout"), 1.5, "Axe should define weapon retrieval timeout in stats.")
	_assert_equal(axe.get("weapon_retrieval_progress_epsilon"), 0.5, "Axe should define weapon retrieval progress epsilon in stats.")
	_assert_profile_is_resource(axe, "attack_first")
	_assert_profile(axe, "attack_first", {
		"selection_weight": 1.0,
		"requires_weapon": true,
		"type": "melee",
	})
	_assert_profile_is_resource(axe, "attack_first_no_axe")
	_assert_profile(axe, "attack_first_no_axe", {
		"selection_weight": 1.0,
		"requires_no_weapon": true,
		"type": "melee",
		"damage": 4,
	})
	_assert_profile_is_resource(axe, "attack_second")
	_assert_profile(axe, "attack_second", {
		"selection_weight": 0.75,
		"special_cooldown": 4.0,
		"repeat_weight_multiplier": 0.5,
		"target_stunned_weight_multiplier": 1.2,
		"type": "projectile",
		"requires_weapon": true,
	})

	print("Enemy strategy profiles validation passed.")
	quit()


func _assert_profile(stats: Resource, action_name: String, expected_values: Dictionary) -> void:
	var profiles: Variant = stats.get("attack_profiles")
	if not profiles is Dictionary or not profiles.has(action_name):
		_fail("%s should define %s profile." % [stats.get("display_name"), action_name])
		return

	var profile := _profile_to_dictionary(profiles[action_name])
	for key in expected_values:
		if not profile.has(key):
			_fail("%s %s should define %s." % [stats.get("display_name"), action_name, key])
			return
		_assert_equal(profile[key], expected_values[key], "%s %s has an unexpected %s value." % [stats.get("display_name"), action_name, key])


func _assert_profile_is_resource(stats: Resource, action_name: String) -> void:
	var profiles: Variant = stats.get("attack_profiles")
	if not profiles is Dictionary or not profiles.has(action_name):
		_fail("%s should define %s profile." % [stats.get("display_name"), action_name])
		return
	if not profiles[action_name] is Resource:
		_fail("%s %s should be resource-backed." % [stats.get("display_name"), action_name])


func _profile_to_dictionary(profile: Variant) -> Dictionary:
	if profile is Dictionary:
		return profile
	if profile is Resource and profile.has_method("to_dictionary"):
		var data: Variant = profile.to_dictionary()
		if data is Dictionary:
			return data
	return {}


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual is float or expected is float:
		if is_equal_approx(float(actual), float(expected)):
			return
	elif actual == expected:
		return
	_fail(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
