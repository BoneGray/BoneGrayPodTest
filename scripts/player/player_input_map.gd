extends RefCounted
class_name PlayerInputMap

var primary_attack_key := KEY_J
var interact_key := KEY_E
var unused_key := KEY_K


func is_key_pressed(event: InputEvent, key: int) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == key or key_event.physical_keycode == key


func is_primary_attack_pressed(event: InputEvent) -> bool:
	return is_key_pressed(event, primary_attack_key)


func is_interact_pressed(event: InputEvent) -> bool:
	return is_key_pressed(event, interact_key)


func is_unused_pressed(event: InputEvent) -> bool:
	return is_key_pressed(event, unused_key)
