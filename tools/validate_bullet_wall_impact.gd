@tool
extends SceneTree

const BULLET_SCENE_PATH := "res://scenes/projectiles/player_bullet_projectile.tscn"
const GUN_ATTACK_PATH := "res://resources/equipment/weapons/gun/gun_primary_attack.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bullet_scene := load(BULLET_SCENE_PATH) as PackedScene
	var attack_profile := load(GUN_ATTACK_PATH) as Resource
	if bullet_scene == null or attack_profile == null:
		_fail(null, "Could not load bullet scene or gun attack profile.")
		return
	if attack_profile.get("wall_impact_scene") == null:
		_fail(null, "Gun attack profile should configure wall impact scene.")
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(24, 0)
	root.add_child(wall)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 32)
	shape.shape = rect
	wall.add_child(shape)

	var bullet := bullet_scene.instantiate() as Area2D
	root.add_child(bullet)
	bullet.global_position = Vector2.ZERO
	bullet.call("launch", null, Vector2.RIGHT, attack_profile, "enemy")

	for frame in 20:
		await physics_frame

	var impact_count := 0
	for child in root.get_children():
		if child.name == "BulletWallImpact":
			impact_count += 1

	if impact_count != 1:
		_fail(root, "Bullet should spawn one wall impact when blocked by a wall.")
		return

	print("Bullet wall impact is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
