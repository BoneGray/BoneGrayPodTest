extends RefCounted
class_name FirearmController

const PCC = preload("res://scripts/player/player_combat_controller.gd")

var hold_session_active := false
var hold_session_direction := "side"
var reload_active := false
var reload_direction := "side"
var reload_time_remaining := 0.0
var reload_weapon_key := ""
var current_magazine_by_weapon := {}


func is_firearm_profile(attack_profile: Resource, equipped_weapon: Resource) -> bool:
	if attack_profile == null:
		return false
	if String(attack_profile.get("attack_type")) == PCC.ATTACK_TYPE_PROJECTILE:
		return true
	if equipped_weapon != null and String(equipped_weapon.get("weapon_type")) == "firearm":
		return true
	return false


func should_preserve_hold_repeat_input(
	attack_profile: Resource,
	equipped_weapon: Resource,
	repeat_enabled: bool,
	attack_key_pressed: bool
) -> bool:
	if not is_firearm_profile(attack_profile, equipped_weapon):
		return false
	if String(attack_profile.get("input_mode")) != PCC.INPUT_HOLD_REPEAT:
		return false
	if not repeat_enabled:
		return false
	return attack_key_pressed


func should_clear_lockout_after_animation(
	attack_profile: Resource,
	equipped_weapon: Resource,
	attack_key_pressed: bool
) -> bool:
	if not is_firearm_profile(attack_profile, equipped_weapon):
		return false
	if String(attack_profile.get("input_mode")) != PCC.INPUT_HOLD_REPEAT:
		return false
	return not attack_key_pressed


func can_use_hold_session(
	attack_profile: Resource,
	equipped_weapon: Resource,
	repeat_enabled: bool
) -> bool:
	if not is_firearm_profile(attack_profile, equipped_weapon):
		return false
	if String(attack_profile.get("input_mode")) != PCC.INPUT_HOLD_REPEAT:
		return false
	return repeat_enabled


func begin_hold_session(direction_name: String) -> void:
	hold_session_active = true
	hold_session_direction = direction_name if direction_name != "" else "side"


func end_hold_session() -> void:
	hold_session_active = false


func is_hold_session_active() -> bool:
	return hold_session_active


func get_hold_session_direction(fallback_direction := "side") -> String:
	return hold_session_direction if hold_session_active else fallback_direction


func is_magazine_enabled(equipped_weapon: Resource) -> bool:
	return equipped_weapon != null and String(equipped_weapon.get("weapon_type")) == "firearm" and get_magazine_size(equipped_weapon) > 0


func get_magazine_size(equipped_weapon: Resource) -> int:
	if equipped_weapon == null:
		return 0
	return maxi(int(equipped_weapon.get("magazine_size")), 0)


func get_current_ammo(equipped_weapon: Resource) -> int:
	if not is_magazine_enabled(equipped_weapon):
		return 0
	var weapon_key := _weapon_key(equipped_weapon)
	if not current_magazine_by_weapon.has(weapon_key):
		current_magazine_by_weapon[weapon_key] = get_magazine_size(equipped_weapon)
	return int(current_magazine_by_weapon[weapon_key])


func can_fire(equipped_weapon: Resource) -> bool:
	if reload_active:
		return false
	if not is_magazine_enabled(equipped_weapon):
		return true
	return get_current_ammo(equipped_weapon) > 0


func should_auto_reload(equipped_weapon: Resource) -> bool:
	return is_magazine_enabled(equipped_weapon) and bool(equipped_weapon.get("auto_reload_when_empty")) and get_current_ammo(equipped_weapon) <= 0


func can_manual_reload(equipped_weapon: Resource) -> bool:
	if reload_active or not is_magazine_enabled(equipped_weapon):
		return false
	return get_current_ammo(equipped_weapon) < get_magazine_size(equipped_weapon)


func is_magazine_full(equipped_weapon: Resource) -> bool:
	if not is_magazine_enabled(equipped_weapon):
		return false
	return get_current_ammo(equipped_weapon) >= get_magazine_size(equipped_weapon)


func consume_shot(equipped_weapon: Resource) -> void:
	if not is_magazine_enabled(equipped_weapon):
		return
	var weapon_key := _weapon_key(equipped_weapon)
	current_magazine_by_weapon[weapon_key] = maxi(get_current_ammo(equipped_weapon) - 1, 0)


func start_reload(equipped_weapon: Resource, direction_name: String, reload_duration: float) -> bool:
	if not is_magazine_enabled(equipped_weapon):
		return false
	reload_active = true
	reload_direction = direction_name if direction_name != "" else "side"
	reload_time_remaining = maxf(reload_duration, 0.0)
	reload_weapon_key = _weapon_key(equipped_weapon)
	end_hold_session()
	return true


func update_reload(delta: float, equipped_weapon: Resource) -> bool:
	if not reload_active:
		return false
	if reload_weapon_key != _weapon_key(equipped_weapon):
		cancel_reload()
		return false
	reload_time_remaining = maxf(reload_time_remaining - delta, 0.0)
	if reload_time_remaining > 0.0:
		return false
	return true


func finish_reload(equipped_weapon: Resource) -> void:
	if is_magazine_enabled(equipped_weapon):
		current_magazine_by_weapon[_weapon_key(equipped_weapon)] = get_magazine_size(equipped_weapon)
	reload_active = false
	reload_time_remaining = 0.0
	reload_weapon_key = ""


func cancel_reload() -> void:
	reload_active = false
	reload_time_remaining = 0.0
	reload_weapon_key = ""


func is_reloading() -> bool:
	return reload_active


func get_reload_direction(fallback_direction := "side") -> String:
	return reload_direction if reload_active else fallback_direction


func can_move_while_reloading(equipped_weapon: Resource) -> bool:
	return equipped_weapon != null and bool(equipped_weapon.get("can_move_while_reloading"))


func get_reload_move_speed_multiplier(equipped_weapon: Resource, fallback_multiplier: float) -> float:
	if equipped_weapon == null:
		return fallback_multiplier
	return clampf(float(equipped_weapon.get("reload_move_speed_multiplier")), 0.0, 1.0)


func execute_projectile_attack(
	source: Node2D,
	parent: Node,
	effect_manager: Node,
	attack_profile: Resource,
	animation_name: String,
	direction_name: String,
	target_group: String,
	spawn_position: Vector2,
	equipment_visual_offset: Vector2
) -> void:
	if source == null or parent == null or attack_profile == null:
		return

	var projectile_scene := attack_profile.get("projectile_scene") as PackedScene
	if projectile_scene == null:
		return

	var projectile_count := maxi(int(attack_profile.get("projectile_count")), 1)
	var spread_degrees := maxf(float(attack_profile.get("projectile_spread_degrees")), 0.0)
	var base_direction := _direction_vector_from_name(direction_name)
	for projectile_index in projectile_count:
		var projectile := projectile_scene.instantiate() as Node2D
		if projectile == null:
			continue

		parent.add_child(projectile)
		projectile.global_position = spawn_position
		if projectile.has_method("launch"):
			var projectile_direction := _spread_projectile_direction(base_direction, projectile_index, projectile_count, spread_degrees)
			projectile.launch(source, projectile_direction, attack_profile, target_group)

	_spawn_muzzle_flash(effect_manager, parent, source.global_position, attack_profile, direction_name, equipment_visual_offset)
	_spawn_bullet_casing(effect_manager, parent, source.global_position, attack_profile, direction_name, equipment_visual_offset)


func _weapon_key(equipped_weapon: Resource) -> String:
	if equipped_weapon == null:
		return ""
	if equipped_weapon.resource_path != "":
		return equipped_weapon.resource_path
	return str(equipped_weapon.get_instance_id())


func _spread_projectile_direction(base_direction: Vector2, projectile_index: int, projectile_count: int, spread_degrees: float) -> Vector2:
	if projectile_count <= 1 or spread_degrees <= 0.0:
		return base_direction

	var step := spread_degrees / float(projectile_count - 1)
	var angle_degrees := -spread_degrees * 0.5 + step * float(projectile_index)
	return base_direction.rotated(deg_to_rad(angle_degrees)).normalized()


func _spawn_muzzle_flash(
	effect_manager: Node,
	parent: Node,
	source_position: Vector2,
	attack_profile: Resource,
	direction_name: String,
	equipment_visual_offset: Vector2
) -> void:
	var muzzle_flash_scene := attack_profile.get("muzzle_flash_scene") as PackedScene
	if muzzle_flash_scene == null:
		return

	var muzzle_flash := _spawn_effect_node(effect_manager, muzzle_flash_scene, parent, "muzzle_flash", int(attack_profile.get("muzzle_flash_pool_limit")))
	if muzzle_flash == null:
		return
	muzzle_flash.global_position = source_position + equipment_visual_offset + _muzzle_flash_offset(attack_profile, direction_name)
	if muzzle_flash.has_method("play"):
		muzzle_flash.play(direction_name)


func _muzzle_flash_offset(attack_profile: Resource, direction_name: String) -> Vector2:
	if direction_name == "side_left":
		return attack_profile.get("muzzle_flash_offset_side_left")
	if direction_name == "up":
		return attack_profile.get("muzzle_flash_offset_up")
	if direction_name == "down":
		return attack_profile.get("muzzle_flash_offset_down")
	return attack_profile.get("muzzle_flash_offset_side")


func _spawn_bullet_casing(
	effect_manager: Node,
	parent: Node,
	source_position: Vector2,
	attack_profile: Resource,
	direction_name: String,
	equipment_visual_offset: Vector2
) -> void:
	var casing_scene := attack_profile.get("casing_scene") as PackedScene
	if casing_scene == null:
		return

	var casing := _spawn_effect_node(effect_manager, casing_scene, parent, "bullet_casing", int(attack_profile.get("casing_pool_limit")))
	if casing == null:
		return
	var eject_direction := _casing_eject_direction(direction_name)
	casing.global_position = source_position + equipment_visual_offset + _casing_offset(attack_profile, direction_name) + _casing_left_eject_spawn_offset(direction_name, eject_direction)
	casing.set_meta("spawn_position", casing.global_position)
	if casing.has_method("launch"):
		var eject_speed := float(attack_profile.get("casing_eject_speed"))
		var speed_variance := float(attack_profile.get("casing_speed_variance"))
		var varied_speed := eject_speed + randf_range(-speed_variance, speed_variance)
		casing.launch(eject_direction, varied_speed, float(attack_profile.get("casing_lifetime")))


func _casing_offset(attack_profile: Resource, direction_name: String) -> Vector2:
	if direction_name == "side_left":
		return attack_profile.get("casing_offset_side_left")
	if direction_name == "up":
		return attack_profile.get("casing_offset_up")
	if direction_name == "down":
		return attack_profile.get("casing_offset_down")
	return attack_profile.get("casing_offset_side")


func _casing_eject_direction(direction_name: String) -> Vector2:
	if direction_name == "side_left":
		return Vector2(1.0, -0.35)
	if direction_name == "side":
		return Vector2(-1.0, -0.35)
	if direction_name == "up":
		return Vector2(_random_casing_side(), randf_range(0.05, 0.35))
	return Vector2(_random_casing_side(), randf_range(-0.4, -0.1))


func _casing_left_eject_spawn_offset(direction_name: String, eject_direction: Vector2) -> Vector2:
	if not direction_name in ["up", "down"] or eject_direction.x >= 0.0:
		return Vector2.ZERO
	return Vector2(randf_range(-4.0, -2.0), 0.0)


func _random_casing_side() -> float:
	return -1.0 if randf() < 0.5 else 1.0


func _spawn_effect_node(effect_manager: Node, effect_scene: PackedScene, parent: Node, category: String, limit: int) -> Node2D:
	if effect_manager != null and effect_manager.has_method("spawn_effect"):
		return effect_manager.spawn_effect(effect_scene, parent, category, limit) as Node2D
	var effect := effect_scene.instantiate() as Node2D
	if effect != null:
		parent.add_child(effect)
	return effect


func _direction_vector_from_name(direction_name: String) -> Vector2:
	match direction_name:
		"side_left":
			return Vector2.LEFT
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		_:
			return Vector2.RIGHT
