extends RefCounted
class_name EnemyMovementController

var path_refresh_remaining := 0.0
var navigation_destination := Vector2.INF


func reset_path() -> void:
	path_refresh_remaining = 0.0
	navigation_destination = Vector2.INF


func advance_path_refresh(delta: float) -> void:
	path_refresh_remaining = maxf(path_refresh_remaining - delta, 0.0)


func get_path_direction(
	navigation_agent: NavigationAgent2D,
	use_navigation_agent: bool,
	destination: Vector2,
	fallback_vector: Vector2,
	owner_position: Vector2,
	path_refresh_interval: float
) -> Vector2:
	if navigation_agent == null or not use_navigation_agent:
		return fallback_vector.normalized()

	if path_refresh_remaining == 0.0 or navigation_destination.distance_to(destination) > 1.0:
		navigation_destination = destination
		navigation_agent.target_position = destination
		path_refresh_remaining = path_refresh_interval

	if navigation_agent.is_navigation_finished():
		return fallback_vector.normalized()

	var next_position := navigation_agent.get_next_path_position()
	var to_next_position := next_position - owner_position
	if to_next_position == Vector2.ZERO:
		return fallback_vector.normalized()
	return to_next_position.normalized()


func get_separation_direction(enemy_nodes: Array[Node], owner: Node2D, radius: float) -> Vector2:
	var separation := Vector2.ZERO
	if owner == null or radius <= 0.0:
		return separation

	for node in enemy_nodes:
		var other := node as Node2D
		if other == null or other == owner:
			continue
		if other.has_method("is_alive") and not other.is_alive():
			continue
		var offset := owner.global_position - other.global_position
		var distance := offset.length()
		if distance <= 0.0 or distance >= radius:
			continue
		var weight := 1.0 - distance / radius
		separation += offset.normalized() * weight

	return separation.normalized() if separation != Vector2.ZERO else Vector2.ZERO
