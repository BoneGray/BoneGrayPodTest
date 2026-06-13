@tool
extends SceneTree

const CharacterIntentScript = preload("res://scripts/characters/character_intent.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var intent := CharacterIntentScript.new()
	_assert_equal(intent.source, CharacterIntentScript.SOURCE_NONE, "default source")
	_assert_equal(intent.has_movement(), false, "default has no movement")
	_assert_equal(intent.normalized_move_vector(), Vector2.ZERO, "default normalized movement")

	intent.source = CharacterIntentScript.SOURCE_PLAYER_INPUT
	intent.move_vector = Vector2(4.0, 0.0)
	intent.face_direction = "side_left"
	intent.primary_attack_pressed = true
	intent.primary_attack_held = true
	intent.interact_pressed = true
	intent.requested_action = "attack_first"
	_assert_equal(intent.has_movement(), true, "movement detection")
	_assert_equal(intent.normalized_move_vector(), Vector2.RIGHT, "movement normalization")

	intent.clear()
	_assert_equal(intent.source, CharacterIntentScript.SOURCE_NONE, "cleared source")
	_assert_equal(intent.move_vector, Vector2.ZERO, "cleared movement")
	_assert_equal(intent.face_direction, "", "cleared face direction")
	_assert_equal(intent.primary_attack_pressed, false, "cleared pressed")
	_assert_equal(intent.primary_attack_held, false, "cleared held")
	_assert_equal(intent.interact_pressed, false, "cleared interact")
	_assert_equal(intent.target, null, "cleared target")
	_assert_equal(intent.requested_action, "", "cleared action")

	print("validate_character_intent_baseline: OK")
	quit()


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("%s expected %s, got %s" % [label, str(expected), str(actual)])
		quit(1)
