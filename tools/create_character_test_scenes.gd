@tool
extends SceneTree

const PLAYER_SPRITE_FRAMES_PATH := "res://resources/characters/player/player_sprite_frames.tres"
const ENEMY_SPRITE_FRAMES_PATH := "res://resources/characters/enemies/zombie_big_sprite_frames.tres"
const PLAYER_SCRIPT_PATH := "res://scripts/zombie_big_attack_controller.gd"
const PLAYER_STATS_PATH := "res://resources/characters/player/player_stats.tres"
const ENEMY_SCRIPT_PATH := "res://scripts/enemies/base_enemy.gd"
const ENEMY_STATS_PATH := "res://resources/characters/enemies/zombie_big_stats.tres"
const HURT_FLASH_SCRIPT_PATH := "res://scripts/combat/hurt_flash_feedback.gd"
const CAMERA_SCRIPT_PATH := "res://scripts/camera_follow_target.gd"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const COMBAT_TEST_SCENE_PATH := "res://scenes/combat_test_scene.tscn"
const ENEMY_TEST_SCENE_PATH := "res://scenes/enemy_test_scene.tscn"
const MAIN_SCENE_PATH := "res://scenes/myScene.tscn"

const PLAYER_ATTACK_HIT_FRAMES := {
	"first_attack": [2],
	"second_attack": [2],
}

const ENEMY_ATTACK_HIT_FRAMES := {
	"first_attack": [4],
	"second_attack": [7, 8],
}

const PLAYER_BODY_POSITION := Vector2(0, 3)
const PLAYER_BODY_SIZE := Vector2(8, 10)
const PLAYER_ATTACK_AREA_POSITION := Vector2(10, 1)
const PLAYER_ATTACK_AREA_SIZE := Vector2(12, 10)
const PLAYER_ATTACK_AREA_OFFSETS := {
	"side": Vector2(10, 1),
	"side_left": Vector2(-10, 1),
	"down": Vector2(0, 8),
	"up": Vector2(0, -7),
}
const PLAYER_HITBOX_POSITION := Vector2(0, 2)
const PLAYER_HITBOX_SIZE := Vector2(8, 14)

const ENEMY_BODY_POSITION := Vector2(0, 4)
const ENEMY_BODY_SIZE := Vector2(10, 12)
const ENEMY_ATTACK_AREA_POSITION := Vector2(14, 0)
const ENEMY_ATTACK_AREA_SIZE := Vector2(18, 14)
const ENEMY_ATTACK_AREA_OFFSETS := {
	"side": Vector2(14, 0),
	"side_left": Vector2(-14, 0),
	"down": Vector2(0, 14),
	"up": Vector2(0, -12),
}
const ENEMY_HITBOX_POSITION := Vector2(0, 2.5)
const ENEMY_HITBOX_SIZE := Vector2(8, 17)

const WORLD_COLLISION_LAYER := 1
const PLAYER_BODY_LAYER := 2
const ENEMY_BODY_LAYER := 4
const PLAYER_HITBOX_LAYER := 8
const ENEMY_HITBOX_LAYER := 16


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/characters"))

	var player_sprite_frames := load(PLAYER_SPRITE_FRAMES_PATH) as SpriteFrames
	var enemy_sprite_frames := load(ENEMY_SPRITE_FRAMES_PATH) as SpriteFrames
	var player_script := load(PLAYER_SCRIPT_PATH) as Script
	var player_stats := load(PLAYER_STATS_PATH) as Resource
	var enemy_script := load(ENEMY_SCRIPT_PATH) as Script
	var enemy_stats := load(ENEMY_STATS_PATH) as Resource
	var hurt_flash_script := load(HURT_FLASH_SCRIPT_PATH) as Script
	var camera_script := load(CAMERA_SCRIPT_PATH) as Script
	if player_sprite_frames == null or enemy_sprite_frames == null or player_script == null or player_stats == null or enemy_script == null or enemy_stats == null or hurt_flash_script == null or camera_script == null:
		push_error("Missing character scene dependency.")
		quit(1)
		return

	if not _save_scene(_create_player_scene(player_sprite_frames, player_script, player_stats, hurt_flash_script), PLAYER_SCENE_PATH):
		quit(1)
		return

	if not _save_scene(_create_enemy_scene(enemy_sprite_frames, enemy_script, enemy_stats, hurt_flash_script), ENEMY_SCENE_PATH):
		quit(1)
		return

	if not _create_combat_test_scene(camera_script):
		quit(1)
		return

	if not _create_enemy_test_scene(camera_script):
		quit(1)
		return

	if not _update_main_scene():
		quit(1)
		return

	print("Created standard Player, Enemy, and combat test scenes.")
	quit()


func _create_player_scene(sprite_frames: SpriteFrames, player_script: Script, player_stats: Resource, hurt_flash_script: Script) -> PackedScene:
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(player_script)
	player.collision_layer = PLAYER_BODY_LAYER
	player.collision_mask = WORLD_COLLISION_LAYER
	player.set("stats", player_stats)
	player.set("target_group", "enemy")
	player.set("camera_follow_enabled", false)
	player.add_to_group("player", true)

	_add_sprite(player, sprite_frames)
	_add_body_collision(player, PLAYER_BODY_POSITION, PLAYER_BODY_SIZE)
	_add_hitbox(player, PLAYER_HITBOX_LAYER, PLAYER_HITBOX_POSITION, PLAYER_HITBOX_SIZE)
	_add_attack_area(player, PLAYER_ATTACK_AREA_POSITION, PLAYER_ATTACK_AREA_SIZE, ENEMY_HITBOX_LAYER)
	_add_animation_player(player, sprite_frames, PLAYER_ATTACK_HIT_FRAMES, PLAYER_ATTACK_AREA_OFFSETS)
	_add_hurt_flash_feedback(player, hurt_flash_script)
	return _pack_root(player)


func _create_enemy_scene(sprite_frames: SpriteFrames, enemy_script: Script, enemy_stats: Resource, hurt_flash_script: Script) -> PackedScene:
	var enemy := CharacterBody2D.new()
	enemy.name = "Enemy"
	enemy.set_script(enemy_script)
	enemy.collision_layer = ENEMY_BODY_LAYER
	enemy.collision_mask = WORLD_COLLISION_LAYER
	enemy.set("stats", enemy_stats)
	enemy.set("target_group", "player")
	enemy.add_to_group("enemy", true)

	_add_sprite(enemy, sprite_frames)
	_add_body_collision(enemy, ENEMY_BODY_POSITION, ENEMY_BODY_SIZE)
	_add_hitbox(enemy, ENEMY_HITBOX_LAYER, ENEMY_HITBOX_POSITION, ENEMY_HITBOX_SIZE)
	_add_attack_area(enemy, ENEMY_ATTACK_AREA_POSITION, ENEMY_ATTACK_AREA_SIZE, PLAYER_HITBOX_LAYER)
	_add_navigation_agent(enemy)
	_add_animation_player(enemy, sprite_frames, ENEMY_ATTACK_HIT_FRAMES, ENEMY_ATTACK_AREA_OFFSETS)
	_add_hurt_flash_feedback(enemy, hurt_flash_script)
	return _pack_root(enemy)


func _add_sprite(root: Node, sprite_frames: SpriteFrames) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = sprite_frames
	sprite.animation = &"idle_down"
	sprite.centered = true
	root.add_child(sprite)
	sprite.owner = root


func _add_body_collision(root: Node, shape_position: Vector2, shape_size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = "BodyCollisionShape2D"
	shape.position = shape_position
	var rectangle := RectangleShape2D.new()
	rectangle.size = shape_size
	shape.shape = rectangle
	root.add_child(shape)
	shape.owner = root


func _add_attack_area(root: Node, area_position: Vector2, area_size: Vector2, target_hitbox_layer: int) -> void:
	var attack_area := Area2D.new()
	attack_area.name = "AttackArea2D"
	attack_area.position = area_position
	attack_area.collision_layer = 0
	attack_area.collision_mask = target_hitbox_layer
	attack_area.monitoring = false
	root.add_child(attack_area)
	attack_area.owner = root
	attack_area.set_meta("_edit_lock_", true)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = area_size
	shape.shape = rectangle
	shape.disabled = true
	attack_area.add_child(shape)
	shape.owner = root
	shape.set_meta("_edit_lock_", true)


func _add_hitbox(root: Node, hitbox_layer: int, shape_position: Vector2, shape_size: Vector2) -> void:
	var hitbox := Area2D.new()
	hitbox.name = "HitboxArea2D"
	hitbox.collision_layer = hitbox_layer
	hitbox.collision_mask = 0
	root.add_child(hitbox)
	hitbox.owner = root
	hitbox.set_meta("_edit_lock_", true)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.position = shape_position
	var rectangle := RectangleShape2D.new()
	rectangle.size = shape_size
	shape.shape = rectangle
	hitbox.add_child(shape)
	shape.owner = root
	shape.set_meta("_edit_lock_", true)


func _add_navigation_agent(root: Node) -> void:
	var navigation_agent := NavigationAgent2D.new()
	navigation_agent.name = "NavigationAgent2D"
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 12.0
	navigation_agent.radius = 8.0
	navigation_agent.avoidance_enabled = false
	root.add_child(navigation_agent)
	navigation_agent.owner = root


func _add_hurt_flash_feedback(root: Node, hurt_flash_script: Script) -> void:
	var feedback := Node.new()
	feedback.name = "HurtFlashFeedback"
	feedback.set_script(hurt_flash_script)
	root.add_child(feedback)
	feedback.owner = root
	feedback.set_meta("_edit_lock_", true)


func _add_animation_player(root: Node, sprite_frames: SpriteFrames, attack_hit_frames: Dictionary, attack_area_offsets: Dictionary) -> void:
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = NodePath("..")
	root.add_child(animation_player)
	animation_player.owner = root
	animation_player.set_meta("_edit_lock_", true)

	var library := AnimationLibrary.new()
	for animation_name in sprite_frames.get_animation_names():
		library.add_animation(animation_name, _create_animation(animation_name, sprite_frames, attack_hit_frames, attack_area_offsets))
	animation_player.add_animation_library("", library)


func _create_animation(animation_name: StringName, sprite_frames: SpriteFrames, attack_hit_frames: Dictionary, attack_area_offsets: Dictionary) -> Animation:
	var animation := Animation.new()
	var frame_count := sprite_frames.get_frame_count(animation_name)
	var speed := sprite_frames.get_animation_speed(animation_name)
	var length := maxf(float(frame_count) / speed, 0.1)
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if sprite_frames.get_animation_loop(animation_name) else Animation.LOOP_NONE

	_add_value_key(animation, NodePath("Sprite:animation"), 0.0, animation_name)
	_add_value_key(animation, NodePath("Sprite:playing"), 0.0, true)
	_add_value_key(animation, NodePath("AttackArea2D:position"), 0.0, _attack_area_position_for_animation(animation_name, attack_area_offsets))
	for frame_index in frame_count:
		_add_value_key(animation, NodePath("Sprite:frame"), float(frame_index) / speed, frame_index)

	var action_name := _action_from_animation(animation_name)
	if attack_hit_frames.has(action_name):
		_add_attack_area_keys(animation, action_name, speed, length, attack_hit_frames)
	else:
		_add_attack_state_keys(animation, 0.0, false)
	return animation


func _add_attack_area_keys(animation: Animation, action_name: String, speed: float, length: float, attack_hit_frames: Dictionary) -> void:
	_add_attack_state_keys(animation, 0.0, false)
	for hit_frame in attack_hit_frames[action_name]:
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
	if name.begins_with("first_attack_"):
		return "first_attack"
	if name.begins_with("second_attack_"):
		return "second_attack"
	return name


func _attack_area_position_for_animation(animation_name: StringName, attack_area_offsets: Dictionary) -> Vector2:
	var direction := _direction_from_animation(animation_name)
	return attack_area_offsets.get(direction, attack_area_offsets.get("side", Vector2.ZERO))


func _direction_from_animation(animation_name: StringName) -> String:
	var name := String(animation_name)
	if name.ends_with("_side_left"):
		return "side_left"
	if name.ends_with("_side"):
		return "side"
	if name.ends_with("_down"):
		return "down"
	if name.ends_with("_up"):
		return "up"
	return "side"


func _create_combat_test_scene(camera_script: Script) -> bool:
	var root := Node2D.new()
	root.name = "CombatTestScene"
	root.y_sort_enabled = true

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	camera.set_script(camera_script)
	camera.set("target_path", NodePath("../Player"))
	root.add_child(camera)
	camera.owner = root

	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	player.name = "Player"
	player.position = Vector2(120, 120)
	root.add_child(player)
	player.owner = root

	var enemy := (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	enemy.name = "Enemy"
	enemy.position = Vector2(176, 120)
	root.add_child(enemy)
	enemy.owner = root

	return _save_scene(_pack_root(root), COMBAT_TEST_SCENE_PATH)


func _create_enemy_test_scene(camera_script: Script) -> bool:
	var root := Node2D.new()
	root.name = "EnemyTestScene"
	root.y_sort_enabled = true

	_add_test_navigation_region(root)

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	camera.set_script(camera_script)
	camera.set("target_path", NodePath("../Player"))
	root.add_child(camera)
	camera.owner = root

	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	player.name = "Player"
	player.position = Vector2(120, 120)
	root.add_child(player)
	player.owner = root

	var enemy_positions := [
		Vector2(176, 112),
		Vector2(196, 128),
		Vector2(176, 144),
	]
	for index in enemy_positions.size():
		var enemy := (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
		enemy.name = "Enemy%d" % [index + 1]
		enemy.position = enemy_positions[index]
		root.add_child(enemy)
		enemy.owner = root

	return _save_scene(_pack_root(root), ENEMY_TEST_SCENE_PATH)


func _add_test_navigation_region(root: Node) -> void:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.vertices = PackedVector2Array([
		Vector2(40, 40),
		Vector2(280, 40),
		Vector2(280, 220),
		Vector2(40, 220),
	])
	navigation_polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = navigation_polygon
	root.add_child(region)
	region.owner = root


func _update_main_scene() -> bool:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load main scene.")
		return false

	var root := packed_scene.instantiate()
	root.set("y_sort_enabled", true)
	var container := root.get_node_or_null("Node")
	if container == null:
		push_error("Could not find Node in main scene.")
		root.queue_free()
		return false
	if container is Node2D:
		(container as Node2D).y_sort_enabled = true

	var old_position := Vector2(219, 166.75)
	var old_player := container.get_node_or_null("Player") as Node2D
	var old_zombie := container.get_node_or_null("ZmobieBig") as Node2D
	if old_player != null:
		old_position = old_player.position
	elif old_zombie != null:
		old_position = old_zombie.position

	for child in container.get_children():
		if child.name == "Player" or child.name == "ZmobieBig" or String(child.name).begins_with("Enemy"):
			container.remove_child(child)
			child.queue_free()

	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	player.name = "Player"
	player.position = old_position
	container.add_child(player)
	player.owner = root

	var enemy := (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	enemy.name = "Enemy"
	enemy.position = old_position + Vector2(64, 0)
	container.add_child(enemy)
	enemy.owner = root

	var output_scene := PackedScene.new()
	var error := output_scene.pack(root)
	if error != OK:
		push_error("Failed to pack main scene: %s" % error)
		root.queue_free()
		return false

	error = ResourceSaver.save(output_scene, MAIN_SCENE_PATH)
	root.queue_free()
	if error != OK:
		push_error("Failed to save main scene: %s" % error)
		return false
	return true


func _pack_root(root: Node) -> PackedScene:
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error != OK:
		push_error("Failed to pack scene root %s: %s" % [root.name, error])
	return scene


func _save_scene(scene: PackedScene, path: String) -> bool:
	var error := ResourceSaver.save(scene, path)
	if error != OK:
		push_error("Failed to save scene %s: %s" % [path, error])
		return false
	return true
