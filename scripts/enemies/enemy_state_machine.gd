extends RefCounted
class_name EnemyStateMachine

const IDLE := 0
const CHASE := 1
const APPROACH_ATTACK_SLOT := 2
const ATTACK := 3
const HURT := 4
const DEAD := 5
const PATROL := 6

var current_state := IDLE


func reset(initial_state: int = IDLE) -> void:
	current_state = initial_state


func change_to(next_state: int) -> bool:
	if current_state == DEAD and next_state != DEAD:
		return false
	current_state = next_state
	return true


func is_state(expected_state: int) -> bool:
	return current_state == expected_state


func is_dead() -> bool:
	return current_state == DEAD


func is_attacking() -> bool:
	return current_state == ATTACK
