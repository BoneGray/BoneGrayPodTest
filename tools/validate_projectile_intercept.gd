@tool
extends SceneTree

const AXE_PROJECTILE_SCENE_PATH := "res://scenes/projectiles/axe_projectile.tscn"
const BULLET_SCENE_PATH := "res://scenes/projectiles/player_bullet_projectile.tscn"
const BAT_ATTACK_PATH := "res://resources/equipment/weapons/baseball_bat/baseball_bat_primary_attack.tres"
const UNARMED_ATTACK_PATH := "res://resources/equipment/weapons/unarmed/unarmed_primary_attack.tres"
const GUN_ATTACK_PATH := "res://resources/equipment/weapons/gun/gun_primary_attack.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("Projectile intercept validation: loading resources.")
	var axe_scene := load(AXE_PROJECTILE_SCENE_PATH) as PackedScene
	var bullet_scene := load(BULLET_SCENE_PATH) as PackedScene
	var bat_attack := load(BAT_ATTACK_PATH) as Resource
	var unarmed_attack := load(UNARMED_ATTACK_PATH) as Resource
	var gun_attack := load(GUN_ATTACK_PATH) as Resource
	if axe_scene == null or bullet_scene == null or bat_attack == null or unarmed_attack == null or gun_attack == null:
		_fail(null, "Could not load projectile intercept validation resources.")
		return

	print("Projectile intercept validation: validating attack profiles.")
	if not _validate_attack_profiles(bat_attack, unarmed_attack, gun_attack):
		return

	var root := Node2D.new()
	get_root().add_child(root)

	print("Projectile intercept validation: validating bat intercept.")
	var bat_result = await _validate_bat_drops_axe(root, axe_scene, bat_attack, unarmed_attack)
	if not bat_result:
		return
	print("Projectile intercept validation: validating bullet intercept.")
	var bullet_result = await _validate_bullet_drops_axe(root, axe_scene, bullet_scene, gun_attack)
	if not bullet_result:
		return

	print("Projectile intercept validation passed.")
	root.queue_free()
	quit()


func _validate_attack_profiles(bat_attack: Resource, unarmed_attack: Resource, gun_attack: Resource) -> bool:
	if not bool(bat_attack.get("can_intercept_projectile")):
		_fail(null, "Baseball bat primary attack should be able to intercept projectiles.")
		return false
	var bat_tags := _tags_from_profile(bat_attack)
	if not ("bat" in bat_tags) or not ("melee" in bat_tags):
		_fail(null, "Baseball bat primary attack should expose melee and bat intercept tags.")
		return false
	if bool(unarmed_attack.get("can_intercept_projectile")):
		_fail(null, "Unarmed primary attack should not intercept axe projectiles by default.")
		return false
	var gun_tags := _tags_from_profile(gun_attack)
	if not bool(gun_attack.get("can_intercept_projectile")) or not ("bullet" in gun_tags):
		_fail(null, "Gun primary attack should expose bullet projectile intercept behavior.")
		return false
	return true


func _validate_bat_drops_axe(root: Node2D, axe_scene: PackedScene, bat_attack: Resource, unarmed_attack: Resource):
	var axe := _spawn_stationary_axe(root, axe_scene, Vector2.ZERO)
	await physics_frame

	if not bool(axe.call("can_be_intercepted_by", bat_attack, null)):
		_fail(root, "Flying axe should be interceptable by the baseball bat.")
		return false
	if bool(axe.call("can_be_intercepted_by", unarmed_attack, null)):
		_fail(root, "Flying axe should not be interceptable by unarmed attack.")
		return false

	var pickup_count_before := _count_axe_pickups(root)
	if not bool(axe.call("intercept_projectile", bat_attack, null)):
		_fail(root, "Baseball bat should intercept and drop the flying axe.")
		return false
	await process_frame
	await process_frame
	if _count_axe_pickups(root) <= pickup_count_before:
		_fail(root, "Intercepted axe should spawn a landed pickup.")
		return false
	return true


func _validate_bullet_drops_axe(root: Node2D, axe_scene: PackedScene, bullet_scene: PackedScene, gun_attack: Resource):
	var axe := _spawn_stationary_axe(root, axe_scene, Vector2(32, 0))
	var bullet := bullet_scene.instantiate() as Area2D
	if bullet == null:
		_fail(root, "Could not instantiate player bullet.")
		return false
	root.add_child(bullet)
	bullet.global_position = Vector2.ZERO
	bullet.call("launch", null, Vector2.RIGHT, gun_attack, "enemy")

	var pickup_count_before := _count_axe_pickups(root)
	for frame in 20:
		await physics_frame
		if _count_axe_pickups(root) > pickup_count_before:
			return true
		if not is_instance_valid(axe):
			return true

	_fail(root, "Player bullet should intercept and drop the flying axe.")
	return false


func _spawn_stationary_axe(root: Node2D, axe_scene: PackedScene, position: Vector2) -> Area2D:
	var axe := axe_scene.instantiate() as Area2D
	root.add_child(axe)
	axe.global_position = position
	axe.call("launch", null, Vector2.RIGHT, "side", {
		"projectile_speed": 1.0,
		"projectile_lifetime": 10.0,
		"damage": 8,
	})
	axe.set("speed", 0.0)
	return axe


func _count_axe_pickups(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child.name == "AxePickup":
			count += 1
	return count


func _tags_from_profile(profile: Resource) -> Array:
	var tags := []
	var configured_tags: Variant = profile.get("intercept_tags")
	for tag in configured_tags:
		tags.append(String(tag))
	return tags


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
