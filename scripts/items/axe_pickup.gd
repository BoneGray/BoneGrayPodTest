extends Area2D

@onready var sprite: AnimatedSprite2D = $Sprite

var owner_enemy: Node
var facing_direction := "side"


func configure(source_enemy: Node, direction_name: String) -> void:
	owner_enemy = source_enemy
	facing_direction = direction_name
	_play_landed_animation()


func is_owned_by(candidate: Node) -> bool:
	return owner_enemy == candidate


func _ready() -> void:
	_play_landed_animation()


func _play_landed_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var animation_name := "landed_side"
	if facing_direction == "side_left":
		animation_name = "landed_side_left"
	elif facing_direction == "up":
		animation_name = "landed_up"
	elif facing_direction == "down":
		animation_name = "landed_down"

	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
