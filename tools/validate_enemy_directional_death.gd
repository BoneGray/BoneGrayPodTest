@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not await _validate_death_animation("side", "side", [&"first_death_side", &"second_death_side"]):
		quit(1)
		return
	if not await _validate_death_animation("side_left", "side_left", [&"first_death_side_left", &"second_death_side_left"]):
		quit(1)
		return
	if not await _validate_death_animation("up", "side_left", [&"first_death_side_left", &"second_death_side_left"]):
		quit(1)
		return
	if not await _validate_death_animation("down", "side", [&"first_death_side", &"second_death_side"]):
		quit(1)
		return

	print("Enemy directional death is valid.")
	quit()


func _validate_death_animation(direction: String, last_horizontal: String, expected_animations: Array) -> bool:
	var scene := load(ENEMY_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load enemy scene.")
		return false

	var root := Node2D.new()
	var enemy := scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(enemy)

	await process_frame

	enemy.set("current_direction", direction)
	enemy.set("last_horizontal_direction", last_horizontal)
	enemy.call("take_damage", enemy.call("get_max_health"))

	var sprite := enemy.get_node("Sprite") as AnimatedSprite2D
	if not expected_animations.has(sprite.animation):
		push_error("Enemy death animation mismatch. Direction %s expected one of %s, got %s." % [direction, expected_animations, sprite.animation])
		root.queue_free()
		return false

	root.queue_free()
	return true
