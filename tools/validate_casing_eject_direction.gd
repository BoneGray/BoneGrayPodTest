@tool
extends SceneTree

const FIREARM_CONTROLLER_PATH := "res://scripts/player/firearm_controller.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller_script := load(FIREARM_CONTROLLER_PATH) as Script
	if controller_script == null:
		_fail(null, "Could not load FirearmController script.")
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var controller: RefCounted = controller_script.new()

	if not _direction_can_eject_both_sides(controller, "up"):
		_fail(root, "Up casing ejection should randomly support both left and right fly-out.")
		return
	if not _direction_can_eject_both_sides(controller, "down"):
		_fail(root, "Down casing ejection should randomly support both left and right fly-out.")
		return
	if not _left_eject_spawn_offset_is_valid(controller, "up"):
		_fail(root, "Up left casing ejection should add a small left spawn offset.")
		return
	if not _left_eject_spawn_offset_is_valid(controller, "down"):
		_fail(root, "Down left casing ejection should add a small left spawn offset.")
		return

	print("Casing eject direction is valid.")
	root.queue_free()
	quit()


func _direction_can_eject_both_sides(controller: RefCounted, direction_name: String) -> bool:
	var saw_left := false
	var saw_right := false
	for attempt in 80:
		var eject_direction: Vector2 = controller.call("_casing_eject_direction", direction_name)
		if eject_direction.x < 0.0:
			saw_left = true
		elif eject_direction.x > 0.0:
			saw_right = true
		if saw_left and saw_right:
			return true
	return false


func _left_eject_spawn_offset_is_valid(controller: RefCounted, direction_name: String) -> bool:
	var left_offset: Vector2 = controller.call("_casing_left_eject_spawn_offset", direction_name, Vector2.LEFT)
	var right_offset: Vector2 = controller.call("_casing_left_eject_spawn_offset", direction_name, Vector2.RIGHT)
	return left_offset.x <= -2.0 and left_offset.x >= -4.0 and left_offset.y == 0.0 and right_offset == Vector2.ZERO


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
