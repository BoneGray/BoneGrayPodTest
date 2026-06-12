@tool
extends SceneTree

const EnemyMovementController = preload("res://scripts/enemies/enemy_movement_controller.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var movement := EnemyMovementController.new()
	var direction := movement.get_path_direction(null, false, Vector2(10, 0), Vector2(3, 4), Vector2.ZERO, 0.25)
	if not direction.is_equal_approx(Vector2(0.6, 0.8)):
		_fail("EnemyMovementController did not normalize direct fallback direction.")
		return

	movement.path_refresh_remaining = 0.5
	movement.navigation_destination = Vector2(4, 5)
	movement.advance_path_refresh(0.2)
	if not is_equal_approx(movement.path_refresh_remaining, 0.3):
		_fail("EnemyMovementController did not advance path refresh timer.")
		return

	movement.reset_path()
	if movement.path_refresh_remaining != 0.0 or movement.navigation_destination != Vector2.INF:
		_fail("EnemyMovementController did not reset path runtime.")
		return

	var owner := Node2D.new()
	var neighbor := Node2D.new()
	owner.global_position = Vector2(10, 0)
	neighbor.global_position = Vector2(0, 0)
	var separation := movement.get_separation_direction([owner, neighbor], owner, 20.0)
	owner.free()
	neighbor.free()
	if not separation.is_equal_approx(Vector2.RIGHT):
		_fail("EnemyMovementController did not calculate separation direction.")
		return

	print("EnemyMovementController validation passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
