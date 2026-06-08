@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load(ENEMY_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load enemy scene.")
		quit(1)
		return

	var root := Node2D.new()
	var enemy := scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(enemy)

	await process_frame

	var default_collision_layer := enemy.collision_layer
	var default_collision_mask := enemy.collision_mask
	var default_position := Vector2(64, 96)

	enemy.call("take_damage", enemy.call("get_max_health"))

	var hitbox := enemy.get_node("HitboxArea2D") as Area2D
	var attack_area := enemy.get_node("AttackArea2D") as Area2D
	var attack_shape := enemy.get_node("AttackArea2D/CollisionShape2D") as CollisionShape2D

	if enemy.is_in_group("enemy"):
		push_error("Dead enemy should leave the enemy active group.")
		root.queue_free()
		quit(1)
		return

	if enemy.is_physics_processing():
		push_error("Dead enemy should stop physics processing.")
		root.queue_free()
		quit(1)
		return

	if enemy.collision_layer != 0 or enemy.collision_mask != 0:
		push_error("Dead enemy body collision should be disabled.")
		root.queue_free()
		quit(1)
		return

	if hitbox.monitoring or hitbox.monitorable:
		push_error("Dead enemy hitbox should be disabled.")
		root.queue_free()
		quit(1)
		return

	if attack_area.monitoring or not attack_shape.disabled:
		push_error("Dead enemy attack area should be disabled.")
		root.queue_free()
		quit(1)
		return

	enemy.call("activate", default_position)
	await process_frame

	if not enemy.call("is_alive"):
		push_error("Activated enemy should be alive.")
		root.queue_free()
		quit(1)
		return

	if enemy.global_position != default_position:
		push_error("Activated enemy should move to the spawn position.")
		root.queue_free()
		quit(1)
		return

	if enemy.call("get_current_health") != enemy.call("get_max_health"):
		push_error("Activated enemy should restore health.")
		root.queue_free()
		quit(1)
		return

	if not enemy.is_visible_in_tree():
		push_error("Activated enemy should be visible.")
		root.queue_free()
		quit(1)
		return

	if not enemy.is_in_group("enemy"):
		push_error("Activated enemy should rejoin the enemy active group.")
		root.queue_free()
		quit(1)
		return

	if not enemy.is_physics_processing():
		push_error("Activated enemy should resume physics processing.")
		root.queue_free()
		quit(1)
		return

	if enemy.collision_layer != default_collision_layer or enemy.collision_mask != default_collision_mask:
		push_error("Activated enemy body collision should be restored.")
		root.queue_free()
		quit(1)
		return

	if not hitbox.monitorable:
		push_error("Activated enemy hitbox should be targetable.")
		root.queue_free()
		quit(1)
		return

	if attack_area.monitoring or not attack_shape.disabled:
		push_error("Activated enemy attack area should start disabled.")
		root.queue_free()
		quit(1)
		return

	enemy.call("deactivate")
	await process_frame

	if enemy.is_visible_in_tree():
		push_error("Deactivated enemy should be hidden.")
		root.queue_free()
		quit(1)
		return

	if enemy.is_in_group("enemy"):
		push_error("Deactivated enemy should leave the enemy active group.")
		root.queue_free()
		quit(1)
		return

	if enemy.is_physics_processing():
		push_error("Deactivated enemy should stop physics processing.")
		root.queue_free()
		quit(1)
		return

	if enemy.collision_layer != 0 or enemy.collision_mask != 0:
		push_error("Deactivated enemy body collision should be disabled.")
		root.queue_free()
		quit(1)
		return

	if hitbox.monitoring or hitbox.monitorable:
		push_error("Deactivated enemy hitbox should be disabled.")
		root.queue_free()
		quit(1)
		return

	if attack_area.monitoring or not attack_shape.disabled:
		push_error("Deactivated enemy attack area should be disabled.")
		root.queue_free()
		quit(1)
		return

	print("Enemy lifecycle inactive, activate, and deactivate states are valid.")
	root.queue_free()
	quit()
