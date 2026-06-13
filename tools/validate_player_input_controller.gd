@tool
extends SceneTree

const PlayerInputControllerScript = preload("res://scripts/characters/controllers/player_input_controller.gd")
const CharacterIntentScript = preload("res://scripts/characters/character_intent.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller := PlayerInputControllerScript.new()

	var idle_intent := controller.build_intent_from_values(Vector2.ZERO, false, false, false)
	_assert_equal(idle_intent.source, CharacterIntentScript.SOURCE_PLAYER_INPUT, "source")
	_assert_equal(idle_intent.move_vector, Vector2.ZERO, "idle movement")
	_assert_equal(idle_intent.face_direction, "", "idle direction")

	var left_intent := controller.build_intent_from_values(Vector2.LEFT, false, false, false)
	_assert_equal(left_intent.face_direction, "side_left", "left direction")

	var right_intent := controller.build_intent_from_values(Vector2.RIGHT, false, false, false)
	_assert_equal(right_intent.face_direction, "side", "right direction")

	var up_intent := controller.build_intent_from_values(Vector2.UP, false, false, false)
	_assert_equal(up_intent.face_direction, "up", "up direction")

	var down_intent := controller.build_intent_from_values(Vector2.DOWN, false, false, false)
	_assert_equal(down_intent.face_direction, "down", "down direction")

	var horizontal_priority := controller.build_intent_from_values(Vector2(-1.0, 1.0), false, false, false)
	_assert_equal(horizontal_priority.face_direction, "side_left", "horizontal priority direction")

	var attack_intent := controller.build_intent_from_values(Vector2.RIGHT, true, true, false)
	_assert_equal(attack_intent.primary_attack_pressed, true, "attack pressed")
	_assert_equal(attack_intent.primary_attack_held, true, "attack held")
	_assert_equal(attack_intent.interact_pressed, false, "attack does not interact")

	var interact_intent := controller.build_intent_from_values(Vector2.ZERO, false, false, true)
	_assert_equal(interact_intent.interact_pressed, true, "interact pressed")
	var reload_intent := controller.build_intent_from_values(Vector2.ZERO, false, false, false, true)
	_assert_equal(reload_intent.reload_pressed, true, "reload pressed")

	var attack_event := InputEventKey.new()
	attack_event.keycode = KEY_J
	attack_event.physical_keycode = KEY_J
	attack_event.pressed = true
	controller.apply_event(attack_event)
	var event_intent := controller.build_intent(false)
	_assert_equal(event_intent.primary_attack_pressed, true, "event attack pressed")
	controller.clear_frame_flags()
	var cleared_intent := controller.build_intent(false)
	_assert_equal(cleared_intent.primary_attack_pressed, false, "cleared attack pressed")

	var unused_event := InputEventKey.new()
	unused_event.keycode = KEY_K
	unused_event.physical_keycode = KEY_K
	unused_event.pressed = true
	controller.apply_event(unused_event)
	var unused_intent := controller.build_intent(false)
	_assert_equal(unused_intent.primary_attack_pressed, false, "unused key attack")
	_assert_equal(unused_intent.interact_pressed, false, "unused key interact")

	var reload_event := InputEventKey.new()
	reload_event.keycode = KEY_R
	reload_event.physical_keycode = KEY_R
	reload_event.pressed = true
	controller.apply_event(reload_event)
	var reload_event_intent := controller.build_intent(false)
	_assert_equal(reload_event_intent.reload_pressed, true, "event reload pressed")

	print("PlayerInputController baseline is valid.")
	quit()


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("%s expected %s, got %s" % [label, str(expected), str(actual)])
		quit(1)
