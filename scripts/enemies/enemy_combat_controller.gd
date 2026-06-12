extends RefCounted
class_name EnemyCombatController

var attack_elapsed := 0.0
var current_attack_action := ""
var current_attack_type := "melee"
var current_attack_profile := {}
var projectile_attack_spawned := false
var hit_targets: Array[Node] = []
var runtime_elapsed := 0.0
var special_attack_last_used := {}
var last_attack_action := ""


func reset(clear_strategy_runtime := false) -> void:
	attack_elapsed = 0.0
	current_attack_action = ""
	current_attack_type = "melee"
	current_attack_profile = {}
	projectile_attack_spawned = false
	hit_targets.clear()
	if clear_strategy_runtime:
		runtime_elapsed = 0.0
		special_attack_last_used.clear()
		last_attack_action = ""


func begin_attack(action_name: String, profile: Dictionary) -> void:
	attack_elapsed = 0.0
	current_attack_action = action_name
	current_attack_profile = profile
	current_attack_type = String(profile.get("type", "melee"))
	projectile_attack_spawned = false
	hit_targets.clear()
	mark_attack_used(action_name, profile)
	last_attack_action = action_name


func advance_runtime(delta: float) -> void:
	runtime_elapsed += delta


func advance(delta: float) -> void:
	attack_elapsed += delta


func mark_attack_used(action_name: String, profile: Dictionary) -> void:
	if not has_independent_special_cooldown(profile):
		return
	special_attack_last_used[action_name] = runtime_elapsed


func is_independent_special_cooldown_ready(action_name: String, profile: Dictionary) -> bool:
	var cooldown := get_independent_special_cooldown(profile)
	if cooldown <= 0.0:
		return true
	if not special_attack_last_used.has(action_name):
		return true
	var last_used := float(special_attack_last_used[action_name])
	return runtime_elapsed - last_used >= cooldown


func has_independent_special_cooldown(profile: Dictionary) -> bool:
	return get_independent_special_cooldown(profile) > 0.0


func get_independent_special_cooldown(profile: Dictionary) -> float:
	if profile.has("special_cooldown_min"):
		return maxf(float(profile.get("special_cooldown_min", 0.0)), 0.0)
	if profile.has("special_cooldown"):
		return maxf(float(profile.get("special_cooldown", 0.0)), 0.0)
	return 0.0


func mark_projectile_spawned() -> void:
	projectile_attack_spawned = true


func should_spawn_projectile() -> bool:
	if current_attack_type != "projectile" or projectile_attack_spawned:
		return false

	var spawn_time := float(current_attack_profile.get("projectile_spawn_time", 0.35))
	return attack_elapsed >= spawn_time


func get_recovery() -> float:
	return float(current_attack_profile.get("recovery", 0.0))


func is_in_hit_window(hit_windows: Dictionary) -> bool:
	if not hit_windows.has(current_attack_action):
		return false

	var windows: Array = hit_windows[current_attack_action]
	for window in windows:
		if attack_elapsed >= window.x and attack_elapsed <= window.y:
			return true
	return false


func uses_body_motion_hit_detection() -> bool:
	return String(current_attack_profile.get("hit_detection", "")) == "body_motion"


func is_attack_motion_active(leap_duration: float) -> bool:
	if not current_attack_type in ["leap", "cross"]:
		return false
	if leap_duration <= 0.0:
		return false
	return attack_elapsed <= leap_duration


func get_active_profile(profile_provider: Callable) -> Dictionary:
	if not current_attack_profile.is_empty():
		return current_attack_profile
	if current_attack_action != "" and profile_provider.is_valid():
		var profile: Variant = profile_provider.call(current_attack_action)
		if profile is Dictionary:
			return profile
	return {}


func get_attack_damage(attack_profile: Dictionary, fallback_damage: int) -> int:
	if attack_profile.has("damage"):
		return int(attack_profile["damage"])
	return fallback_damage


func apply_attack_status_effect(hit_target: Node, attack_profile: Dictionary, source: Node) -> void:
	var status_effect := String(attack_profile.get("status_effect", ""))
	if status_effect == "" or not hit_target.has_method("apply_status_effect"):
		return

	var duration := float(attack_profile.get("status_duration", 0.0))
	if duration <= 0.0:
		return

	hit_target.apply_status_effect(status_effect, duration, source)


func select_attack_action(actions: Array[String], action_available: Callable, fallback_action := "attack_first") -> String:
	var available_actions: Array[String] = []
	for action in actions:
		if action_available.is_valid() and action_available.call(action):
			available_actions.append(action)
	if available_actions.is_empty():
		return fallback_action
	return available_actions.pick_random()


func select_available_attack_by_type(
	actions: Array[String],
	profile_provider: Callable,
	profile_available: Callable,
	action_available: Callable,
	wants_melee: bool,
	default_weight := 1.0,
	weight_multiplier := 1.0,
	target: Node = null
) -> String:
	var available_actions: Array[Dictionary] = []
	for action in actions:
		if not profile_provider.is_valid():
			continue
		var profile: Variant = profile_provider.call(action)
		if not profile is Dictionary:
			continue
		var is_melee := String(profile.get("type", "melee")) == "melee"
		if is_melee != wants_melee:
			continue
		if profile_available.is_valid() and not profile_available.call(profile):
			continue
		if action_available.is_valid() and action_available.call(action):
			var weight := get_contextual_selection_weight(action, profile, default_weight, weight_multiplier, target)
			if weight > 0.0:
				available_actions.append({
					"action": action,
					"weight": weight,
				})
	if available_actions.is_empty():
		return ""
	return _pick_weighted_action(available_actions)


func get_contextual_selection_weight(
	action_name: String,
	profile: Dictionary,
	default_weight: float,
	weight_multiplier: float,
	target: Node = null
) -> float:
	var weight := maxf(float(profile.get("selection_weight", default_weight)) * weight_multiplier, 0.0)
	if weight <= 0.0:
		return 0.0

	if action_name == last_attack_action:
		weight *= maxf(float(profile.get("repeat_weight_multiplier", 1.0)), 0.0)

	if target != null and target.has_method("is_stunned") and target.is_stunned():
		weight *= maxf(float(profile.get("target_stunned_weight_multiplier", 1.0)), 0.0)

	return weight


func _pick_weighted_action(weighted_actions: Array[Dictionary]) -> String:
	var total_weight := 0.0
	for entry in weighted_actions:
		total_weight += float(entry.get("weight", 0.0))
	if total_weight <= 0.0:
		return ""

	var roll := randf() * total_weight
	var running_weight := 0.0
	for entry in weighted_actions:
		running_weight += float(entry.get("weight", 0.0))
		if roll <= running_weight:
			return String(entry.get("action", ""))
	return String(weighted_actions.back().get("action", ""))


func is_profile_available_for_weapon_state(profile: Dictionary, has_weapon: bool) -> bool:
	if bool(profile.get("requires_weapon", false)) and not has_weapon:
		return false
	if bool(profile.get("requires_no_weapon", false)) and has_weapon:
		return false
	return true


func is_attack_animation(animation_name: StringName) -> bool:
	return String(animation_name).begins_with("attack_")


func attack_action_from_animation(animation_name: StringName) -> String:
	var name := String(animation_name)
	var parts := name.split("_", false)
	if parts.size() >= 3 and parts[0] == "attack":
		var supplement_start := 2
		if parts.size() >= 4 and parts[1] == "side" and parts[2] == "left":
			supplement_start = 3
		if supplement_start < parts.size():
			return "attack_%s" % "_".join(parts.slice(supplement_start))
	return name


func is_animation_hit_frame(animation_name: StringName, frame: int, hit_frames: Dictionary) -> bool:
	var action_name := attack_action_from_animation(animation_name)
	if not hit_frames.has(action_name):
		return false
	var frames: Array = hit_frames[action_name]
	return frame in frames


func has_hit_target(target: Node) -> bool:
	return target in hit_targets


func register_hit_target(target: Node) -> void:
	if target != null and not has_hit_target(target):
		hit_targets.append(target)
