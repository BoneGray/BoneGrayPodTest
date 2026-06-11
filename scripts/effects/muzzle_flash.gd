extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	if not sprite.animation_finished.is_connected(_finish):
		sprite.animation_finished.connect(_finish)


func reset_pool_state() -> void:
	if sprite != null:
		sprite.stop()
		sprite.frame = 0
	modulate = Color.WHITE


func play(direction_name: String) -> void:
	var animation_name := "flash_side"
	if direction_name == "side_left":
		animation_name = "flash_side_left"
	elif direction_name == "up":
		animation_name = "flash_up"
	elif direction_name == "down":
		animation_name = "flash_down"

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
	else:
		_finish()


func _finish() -> void:
	if has_node("/root/EffectManager"):
		get_node("/root/EffectManager").recycle_effect(self)
	else:
		queue_free()
