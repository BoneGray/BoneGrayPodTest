@tool
extends SceneTree

const SPRITE_FRAMES_PATH := "res://resources/characters/player/player_sprite_frames.tres"

const REQUIRED_ANIMATIONS := [
	"idle_down",
	"idle_side",
	"idle_side_left",
	"idle_up",
	"walk_down",
	"walk_side",
	"walk_side_left",
	"walk_up",
	"first_attack_down",
	"first_attack_side",
	"first_attack_side_left",
	"first_attack_up",
	"second_attack_down",
	"second_attack_side",
	"second_attack_side_left",
	"second_attack_up",
	"third_death_side",
	"third_death_side_left",
]


func _initialize() -> void:
	var frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	if frames == null:
		push_error("Could not load Player SpriteFrames.")
		quit(1)
		return

	for animation_name in REQUIRED_ANIMATIONS:
		if not frames.has_animation(animation_name):
			push_error("Missing player animation: %s" % animation_name)
			quit(1)
			return
		if frames.get_frame_count(animation_name) <= 1:
			push_error("Player animation has too few frames: %s" % animation_name)
			quit(1)
			return

	if frames.get_frame_count("third_death_side") != 7:
		push_error("third_death_side must have 7 frames because its source sheet is mislabeled Sheet6.")
		quit(1)
		return

	print("Player SpriteFrames is valid with %d animations." % frames.get_animation_names().size())
	quit()
