extends RefCounted
class_name PlayerInputController

const CharacterIntentScript = preload("res://scripts/characters/character_intent.gd")

## Primary attack key. Current project default is J.
var primary_attack_key := KEY_J

## Interaction key. Current project default is E for pickup and drop.
var interact_key := KEY_E

## Reload key. Current project default is R for firearm reload.
var reload_key := KEY_R

## Reserved key. Current project keeps K empty and ignores it.
var unused_key := KEY_K

## Left movement keys.
var move_left_keys: Array[int] = [KEY_A, KEY_LEFT]

## Right movement keys.
var move_right_keys: Array[int] = [KEY_D, KEY_RIGHT]

## Up movement keys.
var move_up_keys: Array[int] = [KEY_W, KEY_UP]

## Down movement keys.
var move_down_keys: Array[int] = [KEY_S, KEY_DOWN]

var _primary_attack_pressed_this_frame := false
var _interact_pressed_this_frame := false
var _reload_pressed_this_frame := false


func apply_event(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if _matches_key(key_event, unused_key):
		return
	if _matches_key(key_event, primary_attack_key):
		_primary_attack_pressed_this_frame = true
		return
	if _matches_key(key_event, interact_key):
		_interact_pressed_this_frame = true
		return
	if _matches_key(key_event, reload_key):
		_reload_pressed_this_frame = true


func build_intent(clear_frame_flags := true) -> RefCounted:
	var intent := build_intent_from_values(
		get_movement_vector(),
		_primary_attack_pressed_this_frame,
		is_key_currently_pressed(primary_attack_key),
		_interact_pressed_this_frame,
		_reload_pressed_this_frame
	)
	if clear_frame_flags:
		clear_frame_flags()
	return intent


func build_intent_from_values(
		move_vector: Vector2,
		primary_attack_pressed: bool,
		primary_attack_held: bool,
		interact_pressed: bool,
		reload_pressed: bool = false
) -> RefCounted:
	var intent := CharacterIntentScript.new()
	intent.source = CharacterIntentScript.SOURCE_PLAYER_INPUT
	intent.move_vector = move_vector
	intent.face_direction = direction_from_vector(move_vector)
	intent.primary_attack_pressed = primary_attack_pressed
	intent.primary_attack_held = primary_attack_held
	intent.interact_pressed = interact_pressed
	intent.reload_pressed = reload_pressed
	return intent


func get_movement_vector() -> Vector2:
	var movement := Vector2.ZERO
	if any_key_currently_pressed(move_left_keys):
		movement.x -= 1.0
	if any_key_currently_pressed(move_right_keys):
		movement.x += 1.0
	if any_key_currently_pressed(move_up_keys):
		movement.y -= 1.0
	if any_key_currently_pressed(move_down_keys):
		movement.y += 1.0
	return movement


func direction_from_vector(direction_vector: Vector2) -> String:
	if direction_vector == Vector2.ZERO:
		return ""
	if absf(direction_vector.x) >= absf(direction_vector.y):
		if direction_vector.x < 0.0:
			return "side_left"
		return "side"
	if direction_vector.y < 0.0:
		return "up"
	return "down"


func clear_frame_flags() -> void:
	_primary_attack_pressed_this_frame = false
	_interact_pressed_this_frame = false
	_reload_pressed_this_frame = false


func any_key_currently_pressed(keys: Array[int]) -> bool:
	for key in keys:
		if is_key_currently_pressed(key):
			return true
	return false


func is_key_currently_pressed(key: int) -> bool:
	return Input.is_key_pressed(key) or Input.is_physical_key_pressed(key)


func _matches_key(key_event: InputEventKey, key: int) -> bool:
	return key_event.keycode == key or key_event.physical_keycode == key
