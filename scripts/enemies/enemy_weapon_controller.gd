extends RefCounted
class_name EnemyWeaponController

var has_weapon := true
var weapon_pickup: Node2D
var weapon_retrieval_elapsed := 0.0
var weapon_retrieval_last_distance := INF


func reset(armed := true) -> void:
	has_weapon = armed
	weapon_pickup = null
	weapon_retrieval_elapsed = 0.0
	weapon_retrieval_last_distance = INF


func mark_unarmed() -> void:
	has_weapon = false


func register_pickup(pickup: Node2D, expected_owner: Node = null) -> bool:
	if pickup == null or not is_instance_valid(pickup):
		return false
	if expected_owner != null and pickup.has_method("is_owned_by") and not pickup.is_owned_by(expected_owner):
		return false
	weapon_pickup = pickup
	has_weapon = false
	weapon_retrieval_elapsed = 0.0
	weapon_retrieval_last_distance = INF
	return true


func has_valid_pickup() -> bool:
	return weapon_pickup != null and is_instance_valid(weapon_pickup) and weapon_pickup.is_inside_tree()


func clear_pickup(free_existing := false, armed := true) -> void:
	if free_existing and has_valid_pickup():
		weapon_pickup.queue_free()
	weapon_pickup = null
	has_weapon = armed
	weapon_retrieval_elapsed = 0.0
	weapon_retrieval_last_distance = INF


func collect_pickup() -> Node2D:
	var pickup := weapon_pickup
	weapon_pickup = null
	has_weapon = true
	weapon_retrieval_elapsed = 0.0
	weapon_retrieval_last_distance = INF
	return pickup


func update_retrieval_progress(distance: float, delta: float, progress_epsilon: float) -> void:
	if weapon_retrieval_last_distance == INF or distance < weapon_retrieval_last_distance - progress_epsilon:
		weapon_retrieval_elapsed = 0.0
		weapon_retrieval_last_distance = distance
		return

	weapon_retrieval_elapsed += delta


func is_retrieval_stuck(timeout: float) -> bool:
	return timeout > 0.0 and weapon_retrieval_elapsed >= timeout


func should_retrieve_weapon(distance_to_target: float, close_attack_range: float) -> bool:
	if has_weapon or not has_valid_pickup():
		return false
	return distance_to_target > close_attack_range


func should_retrieve_without_target() -> bool:
	return not has_weapon and has_valid_pickup()
