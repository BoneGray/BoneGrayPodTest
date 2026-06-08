extends Node2D

@export var tileset_texture: Texture2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.04))

	var sprite := Sprite2D.new()
	sprite.texture = tileset_texture
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2(2.0, 2.0)
	add_child(sprite)
