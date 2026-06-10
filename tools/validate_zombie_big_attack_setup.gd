@tool
extends SceneTree

const SCENE_PATH := "res://scenes/myScene.tscn"

const REQUIRED_PLAYER_ANIMATIONS := [
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
]

const EXPECTED_PLAYER_HITBOX_SIZE := Vector2(8, 14)
const EXPECTED_PLAYER_HITBOX_POSITION := Vector2(0, 2)
const EXPECTED_PLAYER_ATTACK_SIZE := Vector2(12, 10)
const EXPECTED_PLAYER_ATTACK_POSITION := Vector2(10, 1)
const EXPECTED_PLAYER_ATTACK_POSITIONS := {
	"attack_side_first": Vector2(10, 1),
	"attack_side_left_first": Vector2(-10, 1),
	"attack_down_first": Vector2(0, 8),
	"attack_up_first": Vector2(0, -7),
	"attack_side_second": Vector2(10, 1),
	"attack_side_left_second": Vector2(-10, 1),
	"attack_down_second": Vector2(0, 8),
	"attack_up_second": Vector2(0, -7),
}
const EXPECTED_PLAYER_BODY_SIZE := Vector2(8, 10)
const EXPECTED_PLAYER_BODY_POSITION := Vector2(0, 3)


func _initialize() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := scene.instantiate()
	var player := root.get_node_or_null("Node/Player") as CharacterBody2D
	if player == null:
		push_error("Missing Node/Player")
		quit(1)
		return

	var required_nodes := [
		"Sprite",
		"BodyCollisionShape2D",
		"AnimationPlayer",
		"AttackArea2D",
		"AttackArea2D/CollisionShape2D",
		"HitboxArea2D",
		"HitboxArea2D/CollisionShape2D",
		"HurtFlashFeedback",
	]

	for node_path in required_nodes:
		if player.get_node_or_null(node_path) == null:
			push_error("Missing Node/Player/%s" % node_path)
			root.queue_free()
			quit(1)
			return

	var animation_player := player.get_node("AnimationPlayer") as AnimationPlayer
	var stats := player.get("stats") as Resource
	if stats == null:
		push_error("Player stats resource is missing.")
		root.queue_free()
		quit(1)
		return

	for animation_name in REQUIRED_PLAYER_ANIMATIONS:
		if not animation_player.has_animation(animation_name):
			push_error("Missing Player AnimationPlayer animation: %s" % animation_name)
			root.queue_free()
			quit(1)
			return

	for animation_name in EXPECTED_PLAYER_ATTACK_POSITIONS.keys():
		if not _animation_has_attack_area_position(animation_player.get_animation(animation_name), EXPECTED_PLAYER_ATTACK_POSITIONS[animation_name]):
			push_error("Player attack animation %s has wrong AttackArea2D position." % animation_name)
			root.queue_free()
			quit(1)
			return

	var enemy := root.get_node_or_null("Node/Enemy")
	if enemy == null or not (enemy is CharacterBody2D) or not enemy.is_in_group("enemy"):
		push_error("Missing enemy test target or enemy group")
		root.queue_free()
		quit(1)
		return

	if player.get_node_or_null("AttackArea2D/DebugShape") != null:
		push_error("AttackArea2D/DebugShape should be removed")
		root.queue_free()
		quit(1)
		return

	if player.get_node_or_null("HitboxArea2D/HitboxVisibleShape") != null:
		push_error("HitboxVisibleShape should be removed")
		root.queue_free()
		quit(1)
		return

	var hitbox_shape := player.get_node("HitboxArea2D/CollisionShape2D") as CollisionShape2D
	var hitbox_rectangle := hitbox_shape.shape as RectangleShape2D
	if hitbox_rectangle == null or hitbox_rectangle.size != EXPECTED_PLAYER_HITBOX_SIZE or hitbox_shape.position != EXPECTED_PLAYER_HITBOX_POSITION:
		push_error("Player hitbox does not match expected body bounds.")
		root.queue_free()
		quit(1)
		return

	var attack_area := player.get_node("AttackArea2D") as Area2D
	var attack_shape := player.get_node("AttackArea2D/CollisionShape2D") as CollisionShape2D
	var attack_rectangle := attack_shape.shape as RectangleShape2D
	if attack_rectangle == null or attack_rectangle.size != EXPECTED_PLAYER_ATTACK_SIZE or attack_area.position != EXPECTED_PLAYER_ATTACK_POSITION:
		push_error("Player attack area does not match expected punch bounds.")
		root.queue_free()
		quit(1)
		return

	var body_shape := player.get_node("BodyCollisionShape2D") as CollisionShape2D
	var body_rectangle := body_shape.shape as RectangleShape2D
	if body_rectangle == null or body_rectangle.size != EXPECTED_PLAYER_BODY_SIZE or body_shape.position != EXPECTED_PLAYER_BODY_POSITION:
		push_error("Player body collision does not match expected movement bounds.")
		root.queue_free()
		quit(1)
		return

	print("Player attack setup is valid.")
	root.queue_free()
	quit()


func _animation_has_attack_area_position(animation: Animation, expected_position: Vector2) -> bool:
	if animation == null:
		return false

	for track_index in animation.get_track_count():
		if animation.track_get_path(track_index) != NodePath("AttackArea2D:position"):
			continue
		if animation.track_get_key_count(track_index) == 0:
			return false
		return animation.track_get_key_value(track_index, 0) == expected_position
	return false
