@tool
extends SceneTree

const SCENE_PATH := "res://scenes/combat_test_scene.tscn"
const WORLD_COLLISION_LAYER := 1
const PLAYER_BODY_LAYER := 2
const ENEMY_BODY_LAYER := 4
const PLAYER_HITBOX_LAYER := 8
const ENEMY_HITBOX_LAYER := 16


func _initialize() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := scene.instantiate()
	var camera := root.get_node_or_null("Camera2D") as Camera2D
	var player := root.get_node_or_null("Player") as CharacterBody2D
	var enemy := root.get_node_or_null("Enemy") as CharacterBody2D
	if camera == null or player == null or enemy == null:
		push_error("Combat test scene must contain Camera2D, Player, and Enemy.")
		root.queue_free()
		quit(1)
		return

	if not root.y_sort_enabled:
		push_error("Combat test scene must enable Y Sort for character draw order.")
		root.queue_free()
		quit(1)
		return

	if not player.is_in_group("player") or not enemy.is_in_group("enemy"):
		push_error("Player or Enemy group is missing.")
		root.queue_free()
		quit(1)
		return

	if player.get_node_or_null("Sprite") == null or enemy.get_node_or_null("Sprite") == null:
		push_error("Missing Sprite nodes.")
		root.queue_free()
		quit(1)
		return

	if player.get_node_or_null("BodyCollisionShape2D") == null or enemy.get_node_or_null("BodyCollisionShape2D") == null:
		push_error("Missing body collision nodes.")
		root.queue_free()
		quit(1)
		return

	if enemy.get_node_or_null("NavigationAgent2D") == null:
		push_error("Enemy missing NavigationAgent2D.")
		root.queue_free()
		quit(1)
		return

	if player.get_node_or_null("AttackArea2D") == null or enemy.get_node_or_null("HitboxArea2D") == null:
		push_error("Missing attack or hitbox nodes.")
		root.queue_free()
		quit(1)
		return

	if player.collision_layer != PLAYER_BODY_LAYER or player.collision_mask != WORLD_COLLISION_LAYER:
		push_error("Player body should only collide with world blocking.")
		root.queue_free()
		quit(1)
		return

	if enemy.collision_layer != ENEMY_BODY_LAYER or enemy.collision_mask != WORLD_COLLISION_LAYER:
		push_error("Enemy body should only collide with world blocking.")
		root.queue_free()
		quit(1)
		return

	var player_attack := player.get_node("AttackArea2D") as Area2D
	var player_hitbox := player.get_node("HitboxArea2D") as Area2D
	var enemy_attack := enemy.get_node("AttackArea2D") as Area2D
	var enemy_hitbox := enemy.get_node("HitboxArea2D") as Area2D
	if player_attack.collision_mask != ENEMY_HITBOX_LAYER or enemy_attack.collision_mask != PLAYER_HITBOX_LAYER:
		push_error("Attack areas must target hitbox layers.")
		root.queue_free()
		quit(1)
		return

	if player_hitbox.collision_layer != PLAYER_HITBOX_LAYER or enemy_hitbox.collision_layer != ENEMY_HITBOX_LAYER:
		push_error("Hitbox areas must expose dedicated hitbox layers.")
		root.queue_free()
		quit(1)
		return

	if player_hitbox.is_in_group("player") or enemy_hitbox.is_in_group("enemy"):
		push_error("Hitbox areas must not use actor target groups.")
		root.queue_free()
		quit(1)
		return

	if player.get_node_or_null("AttackArea2D/DebugShape") != null:
		push_error("AttackArea2D/DebugShape should be removed.")
		root.queue_free()
		quit(1)
		return

	if player.get_node_or_null("HitboxArea2D/HitboxVisibleShape") != null or enemy.get_node_or_null("HitboxArea2D/HitboxVisibleShape") != null:
		push_error("HitboxVisibleShape should be removed.")
		root.queue_free()
		quit(1)
		return

	print("Combat test scene is valid: Camera2D, Player, Enemy.")
	root.queue_free()
	quit()
