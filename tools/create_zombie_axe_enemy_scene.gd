@tool
extends SceneTree

const BASE_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const OUTPUT_SCENE_PATH := "res://scenes/characters/enemy_zombie_axe.tscn"
const STATS_PATH := "res://resources/characters/enemies/zombie_axe_stats.tres"
const SPRITE_FRAMES_PATH := "res://resources/characters/enemies/zombie_axe_sprite_frames.tres"

const ATTACK_HIT_FRAMES := {
	"attack_first": [3],
	"attack_first_no_axe": [3],
}

const ATTACK_AREA_OFFSETS := {
	"side": Vector2(13, 0),
	"side_left": Vector2(-13, 0),
	"down": Vector2(0, 12),
	"up": Vector2(0, -11),
}


func _initialize() -> void:
	var base_scene := load(BASE_SCENE_PATH) as PackedScene
	var stats := load(STATS_PATH) as Resource
	var sprite_frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	if base_scene == null or stats == null or sprite_frames == null:
		push_error("Could not load Zombie Axe scene inputs.")
		quit(1)
		return

	var root := base_scene.instantiate() as CharacterBody2D
	root.name = "EnemyZombieAxe"
	root.stats = stats
	root.attack_hit_frames = ATTACK_HIT_FRAMES.duplicate(true)
	root.attack_hit_windows = _attack_hit_windows_from_frames(sprite_frames)
	root.use_navigation_agent = true
	root.weapon_pickup_range = 8.0
	root.no_weapon_close_attack_range = 26.0

	var sprite := root.get_node("Sprite") as AnimatedSprite2D
	sprite.sprite_frames = sprite_frames
	sprite.animation = "idle_down"
	sprite.frame = 0

	_tune_collision_shapes(root)
	_rebuild_animation_player(root, sprite_frames)

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(root)
	if pack_error != OK:
		push_error("Failed to pack Zombie Axe scene: %s" % pack_error)
		root.queue_free()
		quit(1)
		return

	var save_error := ResourceSaver.save(packed_scene, OUTPUT_SCENE_PATH)
	if save_error != OK:
		push_error("Failed to save Zombie Axe scene: %s" % save_error)
	else:
		print("Saved %s." % OUTPUT_SCENE_PATH)

	root.queue_free()
	quit()


func _tune_collision_shapes(root: Node) -> void:
	var body_shape := root.get_node("BodyCollisionShape2D") as CollisionShape2D
	var hitbox_shape := root.get_node("HitboxArea2D/CollisionShape2D") as CollisionShape2D
	var attack_shape := root.get_node("AttackArea2D/CollisionShape2D") as CollisionShape2D

	body_shape.position = Vector2(0, 4)
	(body_shape.shape as RectangleShape2D).size = Vector2(9, 11)
	hitbox_shape.position = Vector2(0, 2)
	(hitbox_shape.shape as RectangleShape2D).size = Vector2(10, 15)
	(attack_shape.shape as RectangleShape2D).size = Vector2(18, 13)


func _rebuild_animation_player(root: Node, sprite_frames: SpriteFrames) -> void:
	var animation_player := root.get_node("AnimationPlayer") as AnimationPlayer
	animation_player.root_node = NodePath("..")

	if animation_player.has_animation_library(""):
		animation_player.remove_animation_library("")

	var library := AnimationLibrary.new()
	for animation_name in sprite_frames.get_animation_names():
		library.add_animation(animation_name, _create_animation(animation_name, sprite_frames))

	animation_player.add_animation_library("", library)


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
	var baseline_anchor := _baseline_anchor_for_animation(animation_name, sprite_frames)
	for frame_index in frame_count:
		var frame_time := clampf(float(frame_index) / speed, 0.0, length)
		_add_value_key(animation, NodePath("Sprite:frame"), frame_time, frame_index)
		_add_value_key(animation, NodePath("Sprite:position"), frame_time, _sprite_visual_offset(animation_name, frame_index, sprite_frames, baseline_anchor))

	var action_name := _action_from_animation(animation_name)
	if ATTACK_HIT_FRAMES.has(action_name):
		_add_attack_area_keys(animation, action_name, speed, length)
	else:
		_add_attack_state_keys(animation, 0.0, false)

	return animation


func _baseline_anchor_for_animation(animation_name: StringName, sprite_frames: SpriteFrames) -> Vector2:
	var direction := _direction_from_animation(animation_name)
	var idle_animation := StringName("idle_%s" % direction)
	if String(animation_name).ends_with("_no_axe") and sprite_frames.has_animation(StringName("idle_%s_no_axe" % direction)):
		idle_animation = StringName("idle_%s_no_axe" % direction)
	if not sprite_frames.has_animation(idle_animation):
		idle_animation = &"idle_side"
	return _frame_anchor(sprite_frames.get_frame_texture(idle_animation, 0))


func _sprite_visual_offset(animation_name: StringName, frame_index: int, sprite_frames: SpriteFrames, baseline_anchor: Vector2) -> Vector2:
	var frame_anchor := _frame_anchor(sprite_frames.get_frame_texture(animation_name, frame_index))
	return baseline_anchor - frame_anchor


func _frame_anchor(texture: Texture2D) -> Vector2:
	var atlas_texture := texture as AtlasTexture
	if atlas_texture == null or atlas_texture.atlas == null:
		return Vector2.ZERO

	var image := atlas_texture.atlas.get_image()
	if image == null:
		return Vector2.ZERO

	var region := atlas_texture.region
	var min_x := int(region.size.x)
	var min_y := int(region.size.y)
	var max_x := -1
	var max_y := -1
	for y in int(region.size.y):
		for x in int(region.size.x):
			var color := image.get_pixel(int(region.position.x) + x, int(region.position.y) + y)
			if color.a <= 0.05:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < 0:
		return Vector2.ZERO

	var bottom_center := Vector2((float(min_x) + float(max_x)) * 0.5, float(max_y))
	return bottom_center - region.size * 0.5


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


func _attack_hit_windows_from_frames(sprite_frames: SpriteFrames) -> Dictionary:
	var windows := {}
	for action_name in ATTACK_HIT_FRAMES.keys():
		var animation_name := _down_animation_for_action(action_name)
		var speed := sprite_frames.get_animation_speed(animation_name)
		var action_windows: Array[Vector2] = []
		for hit_frame in ATTACK_HIT_FRAMES[action_name]:
			action_windows.append(Vector2(float(hit_frame) / speed, float(hit_frame + 1) / speed))
		windows[action_name] = action_windows
	return windows


func _down_animation_for_action(action_name: String) -> String:
	return "attack_down_%s" % action_name.trim_prefix("attack_")


func _action_from_animation(animation_name: StringName) -> String:
	var name := String(animation_name)
	var parts := name.split("_", false)
	if parts.is_empty():
		return name

	if parts[0] in ["idle", "walk"]:
		return parts[0]

	var supplement_start := 2
	if parts.size() >= 4 and parts[1] == "side" and parts[2] == "left":
		supplement_start = 3
	if supplement_start < parts.size():
		return "%s_%s" % [parts[0], "_".join(parts.slice(supplement_start))]
	return parts[0]


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
	return "side"
