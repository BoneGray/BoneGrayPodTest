extends CharacterBody2D

@export var max_health := 30

@onready var sprite: AnimatedSprite2D = $Sprite

var health := max_health


func _ready() -> void:
	health = max_health
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_down"):
		sprite.play("idle_down")


func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	sprite.modulate = Color(1.0, 0.55, 0.55)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if health == 0:
		hide()
