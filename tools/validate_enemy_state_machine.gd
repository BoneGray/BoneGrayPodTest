@tool
extends SceneTree

const EnemyStateMachine = preload("res://scripts/enemies/enemy_state_machine.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state_machine := EnemyStateMachine.new()
	state_machine.reset(EnemyStateMachine.IDLE)
	if not state_machine.is_state(EnemyStateMachine.IDLE):
		_fail("EnemyStateMachine did not reset to idle.")
		return

	if not state_machine.change_to(EnemyStateMachine.CHASE):
		_fail("EnemyStateMachine rejected chase transition.")
		return
	if not state_machine.is_state(EnemyStateMachine.CHASE):
		_fail("EnemyStateMachine did not enter chase.")
		return

	if not state_machine.change_to(EnemyStateMachine.DEAD):
		_fail("EnemyStateMachine rejected dead transition.")
		return
	if not state_machine.is_dead():
		_fail("EnemyStateMachine did not enter dead.")
		return
	if state_machine.change_to(EnemyStateMachine.IDLE):
		_fail("EnemyStateMachine allowed transition out of dead.")
		return
	if not state_machine.is_dead():
		_fail("EnemyStateMachine changed state after dead transition rejection.")
		return

	print("EnemyStateMachine validation passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
