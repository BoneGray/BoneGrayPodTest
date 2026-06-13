@tool
extends SceneTree

const PLAYER_SCRIPT_PATH := "res://scripts/player/player.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if source.is_empty():
		_fail("Player source should be readable.")
		return
	_require(source.find("res://scripts/characters/controllers/player_input_controller.gd") != -1, "Player should preload PlayerInputController.")
	_require(source.find("var _player_input_controller := PIC.new()") != -1, "Player should own a PlayerInputController instance.")
	_require(source.find("return _player_input_controller.get_movement_vector()") != -1, "Player movement should read through PlayerInputController.")
	_require(source.find("return _player_input_controller.direction_from_vector(direction_vector)") != -1, "Player direction conversion should read through PlayerInputController.")
	_require(source.find("_player_input_controller.apply_event(event)") != -1, "Player input events should be mirrored into PlayerInputController.")
	_require(source.find("var input_intent := _player_input_controller.build_intent()") != -1, "Player should build CharacterIntent for input events.")
	_require(source.find("input_intent.interact_pressed") != -1, "Player interact event should be read from CharacterIntent.")
	_require(source.find("input_intent.primary_attack_pressed") != -1, "Player attack event should be read from CharacterIntent.")
	_require(source.find("PlayerInputMap") == -1, "Player should not depend on PlayerInputMap after intent event migration.")
	_require(source.find("_input_map") == -1, "Player should not keep the old input map instance after intent event migration.")
	_require(source.find("_handle_primary_attack_pressed()") != -1, "Player should still keep existing primary attack execution path in this stage.")
	_require(source.find("_handle_interact_pressed()") != -1, "Player should still keep existing interact execution path in this stage.")

	print("Player input intent consumption bridge is valid.")
	quit()


func _require(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
