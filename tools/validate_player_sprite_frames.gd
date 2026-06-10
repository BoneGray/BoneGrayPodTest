@tool
extends SceneTree

const SPRITE_FRAMES_PATH := "res://resources/characters/player/player_sprite_frames.tres"
const NO_HANDS_SPRITE_FRAMES_PATH := "res://resources/characters/player/player_no_hands_sprite_frames.tres"
const HANDS_SPRITE_FRAMES_PATH := "res://resources/characters/player/player_hands_sprite_frames.tres"

const REQUIRED_ANIMATIONS := [
	"idle_down",
	"idle_side",
	"idle_side_left",
	"idle_up",
	"walk_down",
	"walk_side",
	"walk_side_left",
	"walk_up",
	"attack_down_first",
	"attack_side_first",
	"attack_side_left_first",
	"attack_up_first",
	"attack_down_second",
	"attack_side_second",
	"attack_side_left_second",
	"attack_up_second",
	"death_side_third",
	"death_side_left_third",
]


func _initialize() -> void:
	var frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	var no_hands_frames := load(NO_HANDS_SPRITE_FRAMES_PATH) as SpriteFrames
	var hands_frames := load(HANDS_SPRITE_FRAMES_PATH) as SpriteFrames
	if frames == null or no_hands_frames == null or hands_frames == null:
		push_error("Could not load Player SpriteFrames resources.")
		quit(1)
		return

	if not _validate_frames(frames, "full body"):
		quit(1)
		return
	if not _validate_frames(no_hands_frames, "no-hands body"):
		quit(1)
		return

	if no_hands_frames.get_frame_count("death_side_third") != 7:
		push_error("death_side_third must have 7 frames because its source sheet is mislabeled sheet6.")
		quit(1)
		return

	for animation_name in [
		"idle_down",
		"idle_side",
		"idle_side_left",
		"idle_up",
		"walk_down",
		"walk_side",
		"walk_side_left",
		"walk_up",
		"attack_down_first",
		"attack_side_first",
		"attack_side_left_first",
		"attack_up_first",
	]:
		if not hands_frames.has_animation(animation_name):
			push_error("Missing hands animation: %s" % animation_name)
			quit(1)
			return

	print("Player SpriteFrames resources are valid.")
	quit()


func _validate_frames(frames: SpriteFrames, label: String) -> bool:
	for animation_name in REQUIRED_ANIMATIONS:
		if not frames.has_animation(animation_name):
			push_error("Missing %s animation: %s" % [label, animation_name])
			return false
		if frames.get_frame_count(animation_name) <= 1:
			push_error("%s animation has too few frames: %s" % [label, animation_name])
			return false
	return true
