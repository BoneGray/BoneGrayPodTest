extends RefCounted
class_name CharacterIntent

const SOURCE_NONE := "none"
const SOURCE_PLAYER_INPUT := "player_input"
const SOURCE_AI := "ai"
const SOURCE_SCRIPTED := "scripted"

## Produces this intent, such as player input, enemy AI, or a scripted sequence.
var source: String = SOURCE_NONE

## Desired movement direction. The character decides whether the current state may move.
var move_vector: Vector2 = Vector2.ZERO

## Desired facing direction. Leave empty to let the character keep its current facing rule.
var face_direction: String = ""

## True only on the frame the primary attack input is pressed.
var primary_attack_pressed: bool = false

## True while the primary attack input remains held.
var primary_attack_held: bool = false

## True only on the frame the interaction input is pressed.
var interact_pressed: bool = false

## Optional target for AI or scripted controllers.
var target: Node2D = null

## Optional named action request, for example attack_first, attack_second, or retrieve_weapon.
var requested_action: String = ""


func clear() -> void:
	source = SOURCE_NONE
	move_vector = Vector2.ZERO
	face_direction = ""
	primary_attack_pressed = false
	primary_attack_held = false
	interact_pressed = false
	target = null
	requested_action = ""


func has_movement() -> bool:
	return move_vector.length_squared() > 0.0


func normalized_move_vector() -> Vector2:
	if not has_movement():
		return Vector2.ZERO
	return move_vector.normalized()
