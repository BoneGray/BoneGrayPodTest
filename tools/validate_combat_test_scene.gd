@tool
extends SceneTree

const SCENE_PATH := "res://scenes/combat_test_scene.tscn"


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

	if player.get_node_or_null("AttackArea2D") == null or enemy.get_node_or_null("HitboxArea2D") == null:
		push_error("Missing attack or hitbox nodes.")
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
