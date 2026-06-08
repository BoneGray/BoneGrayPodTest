@tool
extends SceneTree

const SPRITE_FRAMES_PATH := "res://resources/characters/enemies/zombie_big_sprite_frames.tres"


func _initialize() -> void:
	var sprite_frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	if sprite_frames == null:
		push_error("Could not load SpriteFrames: %s" % SPRITE_FRAMES_PATH)
		quit(1)
		return

	var animation_names := sprite_frames.get_animation_names()
	animation_names.sort()
	print("Loaded %d animations from %s" % [animation_names.size(), SPRITE_FRAMES_PATH])
	for animation_name in animation_names:
		print("%s: %d frames, speed %.1f, loop %s" % [
			animation_name,
			sprite_frames.get_frame_count(animation_name),
			sprite_frames.get_animation_speed(animation_name),
			sprite_frames.get_animation_loop(animation_name),
		])

	quit()
