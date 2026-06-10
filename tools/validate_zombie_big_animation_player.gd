@tool
extends SceneTree

const SCENE_PATH := "res://scenes/myScene.tscn"
const TEST_ANIMATION := &"attack_side_left_first"


func _initialize() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := scene.instantiate()
	var animation_player := root.get_node_or_null("Node/Player/AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		push_error("Missing AnimationPlayer")
		root.queue_free()
		quit(1)
		return

	var animation := animation_player.get_animation(TEST_ANIMATION)
	if animation == null:
		push_error("Missing animation: %s" % TEST_ANIMATION)
		root.queue_free()
		quit(1)
		return

	var frame_key_count := 0
	for track_index in animation.get_track_count():
		if animation.track_get_path(track_index) == NodePath("Sprite:frame"):
			frame_key_count = animation.track_get_key_count(track_index)
			break

	if frame_key_count <= 1:
		push_error("Frame track has only %d key(s)" % frame_key_count)
		root.queue_free()
		quit(1)
		return

	print("%s frame key count: %d" % [TEST_ANIMATION, frame_key_count])
	root.queue_free()
	quit()
