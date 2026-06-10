@tool
extends SceneTree

const SPRITE_FRAMES_PATH := "res://resources/characters/enemies/zombie_small_sprite_frames.tres"
const EXPECTED_FRAMES := {
	"attack_down_first": 4,
	"attack_down_second": 11,
	"attack_side_first": 4,
	"attack_side_left_first": 4,
	"attack_side_left_second": 11,
	"attack_side_second": 11,
	"attack_up_first": 4,
	"attack_up_second": 11,
	"death_side_first": 6,
	"death_side_left_first": 6,
	"death_side_left_second": 7,
	"death_side_second": 7,
	"idle_down": 6,
	"idle_side": 6,
	"idle_side_left": 6,
	"idle_up": 6,
	"walk_down": 6,
	"walk_side": 6,
	"walk_side_left": 6,
	"walk_up": 6,
}


func _initialize() -> void:
	var frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	if frames == null:
		push_error("Could not load %s" % SPRITE_FRAMES_PATH)
		quit(1)
		return

	var ok := true
	var animation_names := frames.get_animation_names()
	for animation_name in EXPECTED_FRAMES.keys():
		if not frames.has_animation(animation_name):
			push_error("Missing animation: %s" % animation_name)
			ok = false
			continue
		if frames.get_frame_count(animation_name) != EXPECTED_FRAMES[animation_name]:
			push_error("%s frame count mismatch: expected %d, got %d" % [
				animation_name,
				EXPECTED_FRAMES[animation_name],
				frames.get_frame_count(animation_name),
			])
			ok = false
		var should_loop: bool = animation_name.begins_with("idle_") or animation_name.begins_with("walk_")
		if frames.get_animation_loop(animation_name) != should_loop:
			push_error("%s loop mismatch." % animation_name)
			ok = false

	if animation_names.size() != EXPECTED_FRAMES.size():
		push_error("Animation count mismatch: expected %d, got %d" % [EXPECTED_FRAMES.size(), animation_names.size()])
		ok = false

	if ok:
		print("Zombie Small SpriteFrames resource is valid.")
		quit()
	else:
		quit(1)
