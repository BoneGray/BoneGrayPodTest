@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy_zombie_small.tscn"
const STATS_PATH := "res://resources/characters/enemies/zombie_small_stats.tres"
const SPRITE_FRAMES_PATH := "res://resources/characters/enemies/zombie_small_sprite_frames.tres"


func _initialize() -> void:
	var scene := load(ENEMY_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load Zombie Small enemy scene.")
		quit(1)
		return

	var enemy := scene.instantiate() as BaseEnemy
	if enemy == null:
		push_error("Zombie Small scene root should be BaseEnemy.")
		quit(1)
		return

	get_root().add_child(enemy)
	await process_frame

	var stats := enemy.stats as Resource
	if stats == null or stats.resource_path != STATS_PATH:
		_fail(enemy, "Zombie Small should use its stats resource.")
		return

	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or sprite.sprite_frames.resource_path != SPRITE_FRAMES_PATH:
		_fail(enemy, "Zombie Small should use its SpriteFrames resource.")
		return

	var animation_player := enemy.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		_fail(enemy, "Zombie Small should have AnimationPlayer.")
		return

	for animation_name in sprite.sprite_frames.get_animation_names():
		if not animation_player.has_animation(animation_name):
			_fail(enemy, "Missing AnimationPlayer animation: %s" % animation_name)
			return
		var animation := animation_player.get_animation(animation_name)
		if animation.track_get_key_count(_find_track(animation, NodePath("Sprite:frame"))) != sprite.sprite_frames.get_frame_count(animation_name):
			_fail(enemy, "%s frame track count does not match SpriteFrames." % animation_name)
			return

	if enemy.get_display_name() != "Zombie Small":
		_fail(enemy, "Zombie Small display name was not configured.")
		return

	print("Zombie Small enemy scene is valid.")
	enemy.queue_free()
	quit()


func _find_track(animation: Animation, path: NodePath) -> int:
	for track_index in animation.get_track_count():
		if animation.track_get_path(track_index) == path:
			return track_index
	return -1


func _fail(enemy: Node, message: String) -> void:
	push_error(message)
	enemy.queue_free()
	quit(1)
