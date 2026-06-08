extends Node

const SLOT_DIRECTIONS := [
	"side",
	"side_left",
	"down",
	"up",
]

const WAIT_RADIUS := 48.0

var _reservations := {}


func claim_slot(enemy: Node2D, target: Node2D, preferred_direction: String, excluded_directions: Array = []) -> String:
	if enemy == null or target == null:
		return preferred_direction

	_prune_invalid_reservations()

	var target_id := target.get_instance_id()
	var enemy_id := enemy.get_instance_id()
	if not _reservations.has(target_id):
		_reservations[target_id] = {}

	var target_reservations: Dictionary = _reservations[target_id]
	for direction in target_reservations:
		if target_reservations[direction] == enemy_id:
			return direction

	var ordered_directions := _get_ordered_directions(enemy, target, preferred_direction)
	for direction in ordered_directions:
		if direction in excluded_directions:
			continue
		if not target_reservations.has(direction):
			target_reservations[direction] = enemy_id
			return direction

	return ""


func get_wait_position(enemy: Node2D, target: Node2D) -> Vector2:
	if enemy == null or target == null:
		return Vector2.ZERO

	var angle := float(enemy.get_instance_id() % 360) * TAU / 360.0
	var offset := Vector2(cos(angle), sin(angle)) * WAIT_RADIUS
	return target.global_position + offset


func release_slot(enemy: Node) -> void:
	if enemy == null:
		return

	var enemy_id := enemy.get_instance_id()
	for target_id in _reservations.keys():
		var target_reservations: Dictionary = _reservations[target_id]
		for direction in target_reservations.keys():
			if target_reservations[direction] == enemy_id:
				target_reservations.erase(direction)
		if target_reservations.is_empty():
			_reservations.erase(target_id)


func _get_ordered_directions(enemy: Node2D, target: Node2D, preferred_direction: String) -> Array:
	var directions := SLOT_DIRECTIONS.duplicate()
	directions.sort_custom(func(a: String, b: String) -> bool:
		return _direction_cost(enemy, target, a, preferred_direction) < _direction_cost(enemy, target, b, preferred_direction)
	)
	return directions


func _direction_cost(enemy: Node2D, target: Node2D, direction: String, preferred_direction: String) -> float:
	var offset := _direction_to_vector(direction) * 16.0
	var slot_position := target.global_position - offset
	var cost := enemy.global_position.distance_squared_to(slot_position)
	if direction != preferred_direction:
		cost += 256.0
	return cost


func _direction_to_vector(direction: String) -> Vector2:
	if direction == "side":
		return Vector2.RIGHT
	if direction == "side_left":
		return Vector2.LEFT
	if direction == "up":
		return Vector2.UP
	return Vector2.DOWN


func _prune_invalid_reservations() -> void:
	for target_id in _reservations.keys():
		if not is_instance_id_valid(target_id):
			_reservations.erase(target_id)
			continue

		var target_reservations: Dictionary = _reservations[target_id]
		for direction in target_reservations.keys():
			var enemy_id: int = target_reservations[direction]
			if not is_instance_id_valid(enemy_id):
				target_reservations.erase(direction)
		if target_reservations.is_empty():
			_reservations.erase(target_id)
