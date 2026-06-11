extends RefCounted
class_name PlayerCombatController

const INPUT_SINGLE_PRESS := "single_press"
const INPUT_TAP_COMBO := "tap_combo"
const INPUT_HOLD_REPEAT := "hold_repeat"

const ATTACK_TYPE_MELEE := "melee"
const ATTACK_TYPE_PROJECTILE := "projectile"

const PHASE_NONE := "none"
const PHASE_STARTUP := "startup"
const PHASE_ACTIVE := "active"
const PHASE_RECOVERY := "recovery"
const PHASE_FINISHED := "finished"

var default_hit_frames := {
	"attack_first": [2],
	"attack_second": [2],
}

var default_target_limits := {
	"attack_first": 1,
	"attack_second": 3,
}

var current_attack_profile: Resource
var current_attack_action := ""
var current_attack_animation := ""
var current_attack_phase := ""
var current_attack_hit_window_reached := false
var hit_targets: Array[Node] = []
var primary_attack_hold_time := 0.0
var primary_attack_repeat_ready := false
var primary_attack_buffer_time_remaining := 0.0
var primary_attack_repeat_active := false


func begin_attack(attack_profile: Resource, action: String, animation_name: String, startup_phase: String) -> void:
	current_attack_profile = attack_profile
	current_attack_action = action
	current_attack_animation = animation_name
	current_attack_phase = startup_phase
	current_attack_hit_window_reached = false
	hit_targets.clear()


func clear_runtime(none_phase: String) -> void:
	current_attack_profile = null
	current_attack_action = ""
	current_attack_animation = ""
	current_attack_phase = none_phase
	current_attack_hit_window_reached = false
	hit_targets.clear()
	clear_primary_attack_input_state()


func clear_primary_attack_input_state() -> void:
	primary_attack_hold_time = 0.0
	primary_attack_repeat_ready = false
	primary_attack_buffer_time_remaining = 0.0
	primary_attack_repeat_active = false


func clear_primary_attack_hold_state() -> void:
	primary_attack_hold_time = 0.0
	primary_attack_repeat_ready = false
	primary_attack_repeat_active = false


func set_primary_attack_buffer_time(buffer_time: float) -> void:
	primary_attack_buffer_time_remaining = maxf(buffer_time, 0.0)


func update_primary_attack_buffer(delta: float) -> void:
	if primary_attack_buffer_time_remaining <= 0.0:
		return
	primary_attack_buffer_time_remaining = maxf(primary_attack_buffer_time_remaining - delta, 0.0)


func has_primary_attack_buffer() -> bool:
	return primary_attack_buffer_time_remaining > 0.0


func update_primary_attack_hold_state(delta: float, can_repeat: bool, hold_to_repeat_delay: float) -> void:
	if not can_repeat:
		clear_primary_attack_hold_state()
		return

	primary_attack_hold_time += delta
	primary_attack_repeat_ready = primary_attack_hold_time >= maxf(hold_to_repeat_delay, 0.0)
	if primary_attack_repeat_ready:
		primary_attack_repeat_active = true


func set_primary_attack_repeat_ready(ready: bool) -> void:
	primary_attack_repeat_ready = ready
	if not ready:
		primary_attack_repeat_active = false


func set_primary_attack_repeat_active(active: bool) -> void:
	primary_attack_repeat_active = active


func is_primary_attack_repeat_ready() -> bool:
	return primary_attack_repeat_ready


func set_attack_phase(phase: String) -> void:
	current_attack_phase = phase


func update_attack_animation(animation_name: String) -> void:
	current_attack_animation = animation_name


func mark_hit_window_reached() -> void:
	current_attack_hit_window_reached = true


func clear_hit_targets() -> void:
	hit_targets.clear()


func get_hit_count() -> int:
	return hit_targets.size()


func has_hit_target(target: Node) -> bool:
	return target in hit_targets


func register_hit_target(target: Node) -> void:
	if target != null and not target in hit_targets:
		hit_targets.append(target)


func can_hit_more_targets(max_targets: int) -> bool:
	return max_targets <= 0 or hit_targets.size() < max_targets


func is_current_melee_hit_frame_active(
	attack_active: bool,
	sprite_animation: StringName,
	sprite_frame: int,
	action_from_animation: String
) -> bool:
	if not attack_active:
		return false
	if current_attack_phase != "active":
		return false
	if current_attack_action == "" or current_attack_profile == null:
		return false
	if action_from_animation != current_attack_action:
		return false
	if get_profile_attack_type(current_attack_profile) != ATTACK_TYPE_MELEE:
		return false

	var hit_frames := get_attack_hit_frames(current_attack_profile, current_attack_action)
	return sprite_frame in hit_frames


func collect_new_hit_targets(candidates: Array[Node], max_targets: int) -> Array[Node]:
	var new_hit_targets: Array[Node] = []
	if not can_hit_more_targets(max_targets):
		return new_hit_targets

	for candidate in candidates:
		if candidate == null or has_hit_target(candidate) or candidate in new_hit_targets:
			continue
		register_hit_target(candidate)
		new_hit_targets.append(candidate)
		if not can_hit_more_targets(max_targets):
			break
	return new_hit_targets


func get_attack_power(attack_profile: Resource, equipped_weapon: Resource, fallback_attack_power: int) -> int:
	if attack_profile != null:
		var profile_damage := int(attack_profile.get("damage"))
		if profile_damage > 0:
			return profile_damage

	if equipped_weapon != null:
		var weapon_attack_power := int(equipped_weapon.get("attack_power"))
		if weapon_attack_power > 0:
			return weapon_attack_power
	return fallback_attack_power


func get_attack_profile(equipped_weapon: Resource, unarmed_primary: Resource, unarmed_secondary: Resource, action: String) -> Resource:
	if equipped_weapon == null:
		if action == "attack_second":
			return unarmed_secondary
		return unarmed_primary

	if action == "attack_second":
		return equipped_weapon.get("secondary_attack_profile") as Resource
	return equipped_weapon.get("primary_attack_profile") as Resource


func get_profile_animation_action(attack_profile: Resource, fallback_action: String) -> String:
	if attack_profile == null:
		return fallback_action

	var animation_action := String(attack_profile.get("animation_action"))
	return animation_action if animation_action != "" else fallback_action


func get_profile_attack_type(attack_profile: Resource) -> String:
	if attack_profile == null:
		return ATTACK_TYPE_MELEE
	return String(attack_profile.get("attack_type"))


func get_attack_input_mode(attack_profile: Resource, equipped_weapon: Resource) -> String:
	if attack_profile == null:
		return INPUT_SINGLE_PRESS

	var input_mode := String(attack_profile.get("input_mode"))
	if input_mode in [INPUT_TAP_COMBO, INPUT_HOLD_REPEAT]:
		return input_mode
	if get_profile_attack_type(attack_profile) == ATTACK_TYPE_PROJECTILE:
		return INPUT_HOLD_REPEAT
	if equipped_weapon != null and String(equipped_weapon.get("weapon_type")) == "firearm":
		return INPUT_HOLD_REPEAT
	if equipped_weapon == null or String(equipped_weapon.get("weapon_type")) == "melee":
		return INPUT_TAP_COMBO
	return INPUT_SINGLE_PRESS


func get_attack_hit_frames(attack_profile: Resource, action_name: String) -> Array:
	if attack_profile != null:
		var profile_hit_frames := attack_profile.get("hit_frames") as Array
		if profile_hit_frames != null and not profile_hit_frames.is_empty():
			return profile_hit_frames
	return default_hit_frames.get(action_name, [])


func get_attack_max_targets(attack_profile: Resource, action: String) -> int:
	if attack_profile != null:
		var profile_max_targets := int(attack_profile.get("max_targets"))
		if profile_max_targets != 0:
			return profile_max_targets
	return default_target_limits.get(action, 1)


func get_last_hit_frame(hit_frames: Array) -> int:
	var last_hit_frame := -1
	for hit_frame in hit_frames:
		last_hit_frame = maxi(last_hit_frame, int(hit_frame))
	return last_hit_frame


func get_first_hit_frame(hit_frames: Array) -> int:
	var first_hit_frame := 999999
	for hit_frame in hit_frames:
		first_hit_frame = mini(first_hit_frame, int(hit_frame))
	return first_hit_frame


func get_attack_input_buffer_time(attack_profile: Resource) -> float:
	if attack_profile == null:
		return 0.0
	return maxf(float(attack_profile.get("input_buffer_time")), 0.0)


func get_attack_cancel_last_frames(attack_profile: Resource) -> int:
	if attack_profile == null:
		return 0
	return maxi(int(attack_profile.get("cancel_last_frames")), 0)


func get_attack_cooldown(attack_profile: Resource, equipped_weapon: Resource, fallback_cooldown: float) -> float:
	var input_mode := get_attack_input_mode(attack_profile, equipped_weapon)
	if input_mode != INPUT_HOLD_REPEAT and equipped_weapon != null:
		var weapon_attack_cooldown := float(equipped_weapon.get("attack_cooldown"))
		if weapon_attack_cooldown > 0.0:
			return weapon_attack_cooldown

	if attack_profile != null:
		var profile_cooldown := float(attack_profile.get("cooldown"))
		if profile_cooldown > 0.0:
			return profile_cooldown

	if equipped_weapon != null:
		var fallback_weapon_attack_cooldown := float(equipped_weapon.get("attack_cooldown"))
		if fallback_weapon_attack_cooldown > 0.0:
			return fallback_weapon_attack_cooldown
	return fallback_cooldown


func get_attack_start_cooldown(attack_profile: Resource, equipped_weapon: Resource, fallback_cooldown: float) -> float:
	if attack_profile != null:
		var profile_cooldown := float(attack_profile.get("cooldown"))
		if profile_cooldown > 0.0:
			return profile_cooldown

	if equipped_weapon != null:
		var weapon_attack_cooldown := float(equipped_weapon.get("attack_cooldown"))
		if weapon_attack_cooldown > 0.0:
			return weapon_attack_cooldown
	return fallback_cooldown


func is_repeat_attack_enabled(attack_profile: Resource, equipped_weapon: Resource, unarmed_repeat_while_held: bool) -> bool:
	if attack_profile == null:
		return false

	var repeat_mode := String(attack_profile.get("repeat_mode"))
	if repeat_mode == "enabled":
		return true
	if repeat_mode == "disabled":
		return false
	if equipped_weapon != null:
		return bool(equipped_weapon.get("repeat_while_held"))
	return unarmed_repeat_while_held


func get_hold_to_repeat_delay(attack_profile: Resource, equipped_weapon: Resource, fallback_delay: float) -> float:
	if attack_profile != null:
		var profile_delay := float(attack_profile.get("hold_to_repeat_delay"))
		if profile_delay >= 0.0:
			return profile_delay
	if equipped_weapon != null:
		return maxf(float(equipped_weapon.get("hold_to_repeat_delay")), 0.0)
	return maxf(fallback_delay, 0.0)
