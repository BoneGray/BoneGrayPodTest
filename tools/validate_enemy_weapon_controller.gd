@tool
extends SceneTree

const EnemyWeaponController = preload("res://scripts/enemies/enemy_weapon_controller.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var weapon := EnemyWeaponController.new()
	if not weapon.has_weapon or weapon.has_valid_pickup():
		_fail("EnemyWeaponController did not start armed without pickup.")
		return

	weapon.mark_unarmed()
	if weapon.has_weapon:
		_fail("EnemyWeaponController did not mark unarmed state.")
		return

	var pickup := Node2D.new()
	get_root().add_child(pickup)
	if not weapon.register_pickup(pickup):
		_fail("EnemyWeaponController did not accept a valid pickup.")
		pickup.queue_free()
		return
	if weapon.has_weapon or not weapon.has_valid_pickup():
		_fail("EnemyWeaponController did not register pickup.")
		pickup.queue_free()
		return

	weapon.update_retrieval_progress(10.0, 0.5, 0.5)
	weapon.update_retrieval_progress(10.2, 0.5, 0.5)
	if not is_equal_approx(weapon.weapon_retrieval_elapsed, 0.5):
		_fail("EnemyWeaponController did not accumulate retrieval elapsed time.")
		pickup.queue_free()
		return
	if not weapon.is_retrieval_stuck(0.4):
		_fail("EnemyWeaponController did not report stuck retrieval.")
		pickup.queue_free()
		return
	if not weapon.should_retrieve_weapon(40.0, 24.0):
		_fail("EnemyWeaponController did not request distant weapon retrieval.")
		pickup.queue_free()
		return
	if weapon.should_retrieve_weapon(12.0, 24.0):
		_fail("EnemyWeaponController requested retrieval while close enough to attack.")
		pickup.queue_free()
		return
	if not weapon.should_retrieve_without_target():
		_fail("EnemyWeaponController did not request retrieval without target.")
		pickup.queue_free()
		return

	var collected := weapon.collect_pickup()
	if collected != pickup or not weapon.has_weapon or weapon.has_valid_pickup():
		_fail("EnemyWeaponController did not collect pickup.")
		pickup.queue_free()
		return
	pickup.queue_free()

	var owner := Node.new()
	var other_owner := Node.new()
	var owned_pickup := OwnedPickup.new()
	owned_pickup.owner_node = owner
	get_root().add_child(owned_pickup)
	if weapon.register_pickup(owned_pickup, other_owner):
		_fail("EnemyWeaponController accepted a pickup owned by another enemy.")
		owned_pickup.queue_free()
		owner.free()
		other_owner.free()
		return
	if not weapon.register_pickup(owned_pickup, owner):
		_fail("EnemyWeaponController rejected a pickup owned by the expected enemy.")
		owned_pickup.queue_free()
		owner.free()
		other_owner.free()
		return
	owned_pickup.queue_free()
	owner.free()
	other_owner.free()

	weapon.reset(false)
	if weapon.has_weapon:
		_fail("EnemyWeaponController did not reset to unarmed state.")
		return

	print("EnemyWeaponController validation passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


class OwnedPickup:
	extends Node2D

	var owner_node: Node

	func is_owned_by(candidate: Node) -> bool:
		return owner_node == candidate
