@tool
extends SceneTree

const EnemyCombatController = preload("res://scripts/enemies/enemy_combat_controller.gd")

var _selection_profiles := {}
var _available_actions: Array[String] = []


class StatusTarget:
	extends Node

	var applied_effect := ""
	var applied_duration := 0.0
	var applied_source: Node
	var stunned := false

	func apply_status_effect(effect_name: String, duration: float, source: Node) -> void:
		applied_effect = effect_name
		applied_duration = duration
		applied_source = source

	func is_stunned() -> bool:
		return stunned


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var combat := EnemyCombatController.new()
	combat.begin_attack("attack_first", {"type": "melee", "damage": 12})

	if combat.current_attack_action != "attack_first":
		_fail("EnemyCombatController did not store current attack action.")
		return
	if combat.current_attack_type != "melee":
		_fail("EnemyCombatController did not store current attack type.")
		return
	if combat.get_attack_damage(combat.current_attack_profile, 7) != 12:
		_fail("EnemyCombatController did not read profile damage.")
		return

	var hit_windows := {"attack_first": [Vector2(0.2, 0.4)]}
	combat.advance(0.1)
	if combat.is_in_hit_window(hit_windows):
		_fail("EnemyCombatController entered hit window too early.")
		return
	combat.advance(0.15)
	if not combat.is_in_hit_window(hit_windows):
		_fail("EnemyCombatController did not enter hit window.")
		return
	if not is_equal_approx(combat.get_recovery(), 0.0):
		_fail("EnemyCombatController returned unexpected default recovery.")
		return

	combat.begin_attack("attack_second", {"type": "projectile", "projectile_spawn_time": 0.3, "recovery": 0.45})
	if not is_equal_approx(combat.get_recovery(), 0.45):
		_fail("EnemyCombatController did not read attack recovery.")
		return
	if combat.should_spawn_projectile():
		_fail("EnemyCombatController spawned projectile too early.")
		return
	combat.advance(0.3)
	if not combat.should_spawn_projectile():
		_fail("EnemyCombatController did not spawn projectile on time.")
		return
	combat.mark_projectile_spawned()
	if combat.should_spawn_projectile():
		_fail("EnemyCombatController allowed duplicate projectile spawn.")
		return

	combat.begin_attack("attack_second", {"type": "cross", "hit_detection": "body_motion"})
	if not combat.uses_body_motion_hit_detection():
		_fail("EnemyCombatController did not detect body motion hit mode.")
		return
	if not combat.is_attack_motion_active(0.5):
		_fail("EnemyCombatController did not report active attack motion.")
		return

	if combat.attack_action_from_animation(&"attack_side_left_second") != "attack_second":
		_fail("EnemyCombatController parsed side-left attack animation incorrectly.")
		return
	if not combat.is_attack_animation(&"attack_down_first"):
		_fail("EnemyCombatController did not identify attack animation.")
		return
	if combat.is_attack_animation(&"idle_down"):
		_fail("EnemyCombatController misidentified idle animation as attack.")
		return
	if not combat.is_animation_hit_frame(&"attack_side_left_second", 7, {"attack_second": [7, 8]}):
		_fail("EnemyCombatController did not detect animation hit frame.")
		return
	if combat.is_animation_hit_frame(&"attack_side_left_second", 4, {"attack_second": [7, 8]}):
		_fail("EnemyCombatController reported wrong animation hit frame.")
		return

	var cooldown_profile := {"type": "cross", "special_cooldown": 2.0}
	combat.begin_attack("attack_second", cooldown_profile)
	if combat.is_independent_special_cooldown_ready("attack_second", cooldown_profile):
		_fail("EnemyCombatController did not start independent special cooldown.")
		return
	combat.advance_runtime(1.0)
	combat.reset()
	if combat.is_independent_special_cooldown_ready("attack_second", cooldown_profile):
		_fail("EnemyCombatController cleared special cooldown when only current attack runtime reset.")
		return
	combat.advance_runtime(1.0)
	if not combat.is_independent_special_cooldown_ready("attack_second", cooldown_profile):
		_fail("EnemyCombatController did not finish independent special cooldown.")
		return
	var ranged_cooldown_profile := {"type": "cross", "special_cooldown_min": 1.5, "special_cooldown_max": 3.0}
	combat.begin_attack("attack_second", ranged_cooldown_profile)
	combat.advance_runtime(1.49)
	if combat.is_independent_special_cooldown_ready("attack_second", ranged_cooldown_profile):
		_fail("EnemyCombatController should use special_cooldown_min before the random range is implemented.")
		return
	combat.reset(true)
	if not combat.is_independent_special_cooldown_ready("attack_second", cooldown_profile):
		_fail("EnemyCombatController did not clear strategy runtime on full reset.")
		return

	if not combat.is_profile_available_for_weapon_state({"requires_weapon": true}, true):
		_fail("EnemyCombatController rejected valid weapon profile.")
		return
	if combat.is_profile_available_for_weapon_state({"requires_no_weapon": true}, true):
		_fail("EnemyCombatController accepted no-weapon profile while armed.")
		return

	_selection_profiles = {
		"attack_zero": {"type": "melee", "selection_weight": 0.0},
		"attack_one": {"type": "melee", "selection_weight": 1.0},
		"attack_special": {"type": "cross", "selection_weight": 1.0},
	}
	_available_actions = ["attack_zero", "attack_one", "attack_special"]
	var selected_melee := combat.select_available_attack_by_type(
		_available_actions,
		_get_selection_profile,
		_is_selection_profile_available,
		_is_selection_action_available,
		true
	)
	if selected_melee != "attack_one":
		_fail("EnemyCombatController did not ignore zero-weight melee attacks.")
		return
	var selected_special := combat.select_available_attack_by_type(
		_available_actions,
		_get_selection_profile,
		_is_selection_profile_available,
		_is_selection_action_available,
		false
	)
	if selected_special != "attack_special":
		_fail("EnemyCombatController did not select the available weighted special attack.")
		return

	var target_for_weight := StatusTarget.new()
	var contextual_profile := {
		"type": "cross",
		"selection_weight": 1.0,
		"repeat_weight_multiplier": 0.5,
		"target_stunned_weight_multiplier": 3.0,
	}
	combat.begin_attack("attack_special", contextual_profile)
	var repeat_weight := combat.get_contextual_selection_weight("attack_special", contextual_profile, 1.0, 1.0, target_for_weight)
	if not is_equal_approx(repeat_weight, 0.5):
		_fail("EnemyCombatController did not apply repeat weight multiplier.")
		target_for_weight.free()
		return
	target_for_weight.stunned = true
	var stunned_repeat_weight := combat.get_contextual_selection_weight("attack_special", contextual_profile, 1.0, 1.0, target_for_weight)
	if not is_equal_approx(stunned_repeat_weight, 1.5):
		_fail("EnemyCombatController did not raise repeated special attack weight while target is stunned.")
		target_for_weight.free()
		return
	target_for_weight.free()

	var hit_target := Node.new()
	if combat.has_hit_target(hit_target):
		_fail("EnemyCombatController started with unexpected hit target.")
		hit_target.free()
		return
	combat.register_hit_target(hit_target)
	if not combat.has_hit_target(hit_target):
		_fail("EnemyCombatController did not register hit target.")
		hit_target.free()
		return
	hit_target.free()

	var status_target := StatusTarget.new()
	var source := Node.new()
	combat.apply_attack_status_effect(status_target, {"status_effect": "stunned", "status_duration": 0.8}, source)
	if status_target.applied_effect != "stunned" or not is_equal_approx(status_target.applied_duration, 0.8):
		_fail("EnemyCombatController did not apply status effect.")
		status_target.free()
		source.free()
		return
	status_target.free()
	source.free()

	print("EnemyCombatController validation passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _get_selection_profile(action_name: String) -> Dictionary:
	return _selection_profiles.get(action_name, {})


func _is_selection_profile_available(_profile: Dictionary) -> bool:
	return true


func _is_selection_action_available(action_name: String) -> bool:
	return action_name in _available_actions
