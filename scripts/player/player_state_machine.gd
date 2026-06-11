extends RefCounted
class_name PlayerStateMachine

const IDLE := "idle"
const MOVE := "move"
const ATTACK := "attack"
const PICKUP := "pickup"
const STUNNED := "stunned"
const DEAD := "dead"

var current_state := IDLE
var previous_state := ""


func reset(initial_state := IDLE) -> void:
	previous_state = ""
	current_state = initial_state


func can_change_to(next_state: String) -> bool:
	if next_state == current_state:
		return true
	if current_state == DEAD:
		return false
	if next_state == DEAD:
		return true
	if next_state == STUNNED:
		return current_state != DEAD

	match current_state:
		IDLE:
			return next_state in [MOVE, ATTACK, PICKUP]
		MOVE:
			return next_state in [IDLE, ATTACK]
		ATTACK:
			return next_state in [IDLE, MOVE, STUNNED, DEAD]
		PICKUP:
			return next_state in [IDLE, MOVE, STUNNED, DEAD]
		STUNNED:
			return next_state in [IDLE, DEAD]
		_:
			return false


func change_to(next_state: String) -> bool:
	if not can_change_to(next_state):
		return false
	previous_state = current_state
	current_state = next_state
	return true


func is_state(state_name: String) -> bool:
	return current_state == state_name


func blocks_input() -> bool:
	return current_state in [STUNNED, DEAD]


func blocks_attack() -> bool:
	return current_state in [PICKUP, STUNNED, DEAD]


func blocks_interaction() -> bool:
	return current_state in [ATTACK, STUNNED, DEAD]
