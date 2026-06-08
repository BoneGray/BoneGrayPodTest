@tool
extends SceneTree

const SCENE_PATH := "res://scenes/myScene.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := scene.instantiate()
	get_root().add_child(root)

	await process_frame
	await process_frame

	var player := root.get_node_or_null("Node/Player") as CharacterBody2D
	if player == null:
		push_error("Missing Node/Player")
		root.queue_free()
		quit(1)
		return

	var enemy := root.get_node_or_null("Node/Enemy") as CharacterBody2D
	if enemy == null:
		push_error("Missing Node/Enemy")
		root.queue_free()
		quit(1)
		return

	var ui := root.get_node_or_null("TimeOfDayUI")
	if ui == null:
		push_error("Missing TimeOfDayUI")
		root.queue_free()
		quit(1)
		return

	var buttons := ui.find_children("*", "Button", true, false)
	if buttons.size() != 3:
		push_error("Expected 3 time buttons, found %d" % buttons.size())
		root.queue_free()
		quit(1)
		return

	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or not sprite.is_playing():
		push_error("Player animation is not playing")
		root.queue_free()
		quit(1)
		return

	print("Main scene runtime is valid. Animation: %s, buttons: %d" % [sprite.animation, buttons.size()])
	root.queue_free()
	quit()
