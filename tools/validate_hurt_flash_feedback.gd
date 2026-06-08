@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const HURT_COLOR := Color(1.0, 0.25, 0.25)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not await _validate_character(PLAYER_SCENE_PATH, "Player"):
		quit(1)
		return
	if not await _validate_character(ENEMY_SCENE_PATH, "Enemy"):
		quit(1)
		return

	print("Hurt flash feedback is valid.")
	quit()


func _validate_character(scene_path: String, label: String) -> bool:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("Could not load %s scene." % label)
		return false

	var root := Node2D.new()
	var character := scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(character)

	await process_frame

	var sprite := character.get_node_or_null("Sprite") as AnimatedSprite2D
	var feedback := character.get_node_or_null("HurtFlashFeedback")
	if sprite == null or feedback == null or not feedback.has_method("play"):
		push_error("%s missing hurt flash feedback setup." % label)
		root.queue_free()
		return false

	character.call("take_damage", 1)
	if sprite.modulate != HURT_COLOR:
		push_error("%s did not flash red on damage." % label)
		root.queue_free()
		return false

	await create_timer(0.2).timeout
	if sprite.modulate != Color.WHITE:
		push_error("%s did not restore sprite color after hurt flash." % label)
		root.queue_free()
		return false

	root.queue_free()
	return true
