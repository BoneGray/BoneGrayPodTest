@tool
extends SceneTree

const SCENE_PATH := "res://scenes/myScene.tscn"
const WORLD_COLLISION_LAYER := 1
const PLAYER_BODY_LAYER := 2
const ENEMY_BODY_LAYER := 4


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

	var character_container := root.get_node_or_null("Node") as Node2D
	if not root.y_sort_enabled or character_container == null or not character_container.y_sort_enabled:
		push_error("Main scene must enable Y Sort for character draw order.")
		root.queue_free()
		quit(1)
		return

	if player.collision_layer != PLAYER_BODY_LAYER or player.collision_mask != WORLD_COLLISION_LAYER:
		push_error("Player body should only collide with world blocking.")
		root.queue_free()
		quit(1)
		return

	if enemy.collision_layer != ENEMY_BODY_LAYER or enemy.collision_mask != WORLD_COLLISION_LAYER:
		push_error("Enemy body should only collide with world blocking.")
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
