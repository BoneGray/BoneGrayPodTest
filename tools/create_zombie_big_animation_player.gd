@tool
extends SceneTree

const SCENE_PATH := "res://scenes/myScene.tscn"
const PLAYER_PATH := "Node/Player"

const ATTACK_HIT_FRAMES := {
	"attack_first": [2],
	"attack_second": [2],
}

const ATTACK_AREA_OFFSETS := {
	"side": Vector2(10, 1),
	"side_left": Vector2(-10, 1),
	"down": Vector2(0, 8),
	"up": Vector2(0, -7),
}


func _initialize() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := packed_scene.instantiate()
	var player := root.get_node_or_null(PLAYER_PATH) as CharacterBody2D
	if player == null:
		push_error("Missing player node: %s" % PLAYER_PATH)
		root.queue_free()
		quit(1)
		return

	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		push_error("Missing player Sprite node.")
		root.queue_free()
		quit(1)
		return

	var animation_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		player.add_child(animation_player)
		animation_player.owner = root

	animation_player.root_node = NodePath("..")
	var library := AnimationLibrary.new()

	var sprite_frames := sprite.sprite_frames
	for animation_name in sprite_frames.get_animation_names():
		var animation := _create_animation(animation_name, sprite_frames)
		library.add_animation(animation_name, animation)

	if animation_player.has_animation_library(""):
		animation_player.remove_animation_library("")
	animation_player.add_animation_library("", library)

	var output_scene := PackedScene.new()
	var pack_error := output_scene.pack(root)
	if pack_error != OK:
		push_error("Failed to pack scene: %s" % pack_error)
		root.queue_free()
		quit(1)
		return

	var error := ResourceSaver.save(output_scene, SCENE_PATH)
	if error != OK:
		push_error("Failed to save scene: %s" % error)
	else:
		print("Added AnimationPlayer with %d animations." % sprite_frames.get_animation_names().size())

	root.queue_free()
	quit()


func _create_animation(animation_name: StringName, sprite_frames: SpriteFrames) -> Animation:
	var animation := Animation.new()
	var frame_count := sprite_frames.get_frame_count(animation_name)
	var speed := sprite_frames.get_animation_speed(animation_name)
	var length := maxf(float(frame_count) / speed, 0.1)
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if sprite_frames.get_animation_loop(animation_name) else Animation.LOOP_NONE

	_add_value_key(animation, NodePath("Sprite:animation"), 0.0, animation_name)
	_add_value_key(animation, NodePath("Sprite:playing"), 0.0, true)
	_add_value_key(animation, NodePath("AttackArea2D:position"), 0.0, _attack_area_position_for_animation(animation_name))
	for frame_index in frame_count:
		var frame_time := clampf(float(frame_index) / speed, 0.0, length)
		_add_value_key(animation, NodePath("Sprite:frame"), frame_time, frame_index)

	var action_name := _action_from_animation(animation_name)
	if ATTACK_HIT_FRAMES.has(action_name):
		_add_attack_area_keys(animation, action_name, speed, length)
	else:
		_add_attack_state_keys(animation, 0.0, false)

	return animation


func _add_attack_area_keys(animation: Animation, action_name: String, speed: float, length: float) -> void:
	_add_attack_state_keys(animation, 0.0, false)
	for hit_frame in ATTACK_HIT_FRAMES[action_name]:
		var start_time := clampf(float(hit_frame) / speed, 0.0, length)
		var end_time := clampf(float(hit_frame + 1) / speed, 0.0, length)
		_add_attack_state_keys(animation, start_time, true)
		_add_attack_state_keys(animation, end_time, false)
	_add_attack_state_keys(animation, length, false)


func _add_attack_state_keys(animation: Animation, time: float, active: bool) -> void:
	_add_value_key(animation, NodePath("AttackArea2D:monitoring"), time, active)
	_add_value_key(animation, NodePath("AttackArea2D/CollisionShape2D:disabled"), time, not active)


func _add_value_key(animation: Animation, path: NodePath, time: float, value: Variant) -> void:
	var track_index := _get_or_add_value_track(animation, path)
	animation.track_insert_key(track_index, time, value)


func _get_or_add_value_track(animation: Animation, path: NodePath) -> int:
	for track_index in animation.get_track_count():
		if animation.track_get_path(track_index) == path:
			return track_index

	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, path)
	animation.value_track_set_update_mode(track_index, Animation.UPDATE_DISCRETE)
	return track_index


func _action_from_animation(animation_name: StringName) -> String:
	var name := String(animation_name)
	var parts := name.split("_", false)
	if parts.size() >= 3 and (parts[0] in ["attack", "death"]):
		return "%s_%s" % [parts[0], parts[parts.size() - 1]]
	return parts[0] if not parts.is_empty() else name


func _attack_area_position_for_animation(animation_name: StringName) -> Vector2:
	var direction := _direction_from_animation(animation_name)
	return ATTACK_AREA_OFFSETS.get(direction, ATTACK_AREA_OFFSETS["side"])


func _direction_from_animation(animation_name: StringName) -> String:
	var name := String(animation_name)
	var parts := name.split("_", false)
	if parts.size() >= 4 and parts[1] == "side" and parts[2] == "left":
		return "side_left"
	if parts.size() >= 2 and parts[1] == "side":
		return "side"
	if parts.size() >= 2 and parts[1] == "down":
		return "down"
	if parts.size() >= 2 and parts[1] == "up":
		return "up"
	if name.ends_with("_side_left"):
		return "side_left"
	if name.ends_with("_side"):
		return "side"
	if name.ends_with("_down"):
		return "down"
	if name.ends_with("_up"):
		return "up"
	return "side"
