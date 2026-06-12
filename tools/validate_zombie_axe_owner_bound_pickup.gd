@tool
extends SceneTree

const AXE_ENEMY_SCENE_PATH := "res://scenes/characters/enemy_zombie_axe.tscn"
const AXE_PICKUP_SCENE_PATH := "res://scenes/items/axe_pickup.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var enemy_scene := load(AXE_ENEMY_SCENE_PATH) as PackedScene
	var pickup_scene := load(AXE_PICKUP_SCENE_PATH) as PackedScene
	if enemy_scene == null or pickup_scene == null:
		_fail(null, "Could not load Axe enemy or Axe pickup scene.")
		return

	var root := Node2D.new()
	var owner_enemy := enemy_scene.instantiate() as BaseEnemy
	var other_enemy := enemy_scene.instantiate() as BaseEnemy
	var pickup := pickup_scene.instantiate() as Node2D
	if owner_enemy == null or other_enemy == null or pickup == null:
		_fail(root, "Could not instantiate Axe owner-bound validation nodes.")
		return

	owner_enemy.auto_acquire_target = false
	other_enemy.auto_acquire_target = false
	get_root().add_child(root)
	root.add_child(owner_enemy)
	root.add_child(other_enemy)
	root.add_child(pickup)

	await process_frame

	if pickup.has_method("configure"):
		pickup.configure(owner_enemy, "side")

	other_enemy.register_weapon_pickup(pickup)
	if other_enemy.weapon_pickup != null:
		_fail(root, "Another Axe enemy should not register a pickup owned by the throwing Axe.")
		return
	if not other_enemy.has_weapon:
		_fail(root, "Rejected foreign Axe pickup should not change another Axe weapon state.")
		return

	owner_enemy.register_weapon_pickup(pickup)
	if owner_enemy.weapon_pickup != pickup:
		_fail(root, "Throwing Axe should register its own landed pickup.")
		return
	if owner_enemy.has_weapon:
		_fail(root, "Throwing Axe should be unarmed while its pickup is registered.")
		return

	owner_enemy.deactivate()
	await process_frame
	if is_instance_valid(pickup):
		_fail(root, "Deactivating the owner Axe should clear its owner-bound pickup.")
		return

	print("Zombie Axe owner-bound pickup validation passed.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
