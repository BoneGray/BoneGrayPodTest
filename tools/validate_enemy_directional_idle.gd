@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	if player_scene == null or enemy_scene == null:
		push_error("Could not load player or enemy scene.")
		quit(1)
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	root.add_child(enemy)
	player.set("keyboard_control_enabled", false)
	enemy.global_position = Vector2(100, 100)
	enemy.set("auto_acquire_target", false)

	var checks := {
		Vector2(0, 8): &"idle_down",
		Vector2(0, -8): &"idle_up",
		Vector2(8, 0): &"idle_side",
		Vector2(-8, 0): &"idle_side_left",
	}

	for offset in checks:
		player.global_position = enemy.global_position + offset
		enemy.set("current_direction", enemy.call("_direction_from_vector", offset))
		enemy.call("_play_idle")
		var sprite := enemy.get_node("Sprite") as AnimatedSprite2D
		var expected_animation: StringName = checks[offset]
		if sprite.animation != expected_animation:
			push_error("Enemy idle direction mismatch. Expected %s, got %s." % [expected_animation, sprite.animation])
			root.queue_free()
			quit(1)
			return

	print("Enemy directional idle is valid.")
	root.queue_free()
	quit()
