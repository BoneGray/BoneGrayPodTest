@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const SHOTGUN_DATA_PATH := "res://resources/equipment/weapons/shotgun/shotgun_data.tres"
const SHOTGUN_PICKUP_SCENE_PATH := "res://scenes/items/weapons/shotgun_pickup.tscn"
const SHOTGUN_FRAMES_PATH := "res://resources/equipment/weapons/shotgun/shotgun_sprite_frames.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var shotgun_data := load(SHOTGUN_DATA_PATH) as Resource
	var shotgun_pickup_scene := load(SHOTGUN_PICKUP_SCENE_PATH) as PackedScene
	var shotgun_frames := load(SHOTGUN_FRAMES_PATH) as SpriteFrames
	if player_scene == null or shotgun_data == null or shotgun_pickup_scene == null or shotgun_frames == null:
		_fail(null, "Could not load shotgun dependencies.")
		return

	for animation_name in ["idle_down", "idle_side", "idle_side_left", "idle_up", "attack_down_first", "attack_side_first", "attack_side_left_first", "attack_up_first"]:
		if not shotgun_frames.has_animation(animation_name):
			_fail(null, "Shotgun SpriteFrames should define %s." % animation_name)
			return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	var pickup := shotgun_pickup_scene.instantiate() as Area2D
	if pickup == null:
		_fail(root, "Shotgun pickup scene should instantiate as Area2D.")
		return
	if pickup.z_index != 0:
		_fail(root, "Shotgun pickup should stay on the WorldActors baseline z-index.")
		return
	pickup.queue_free()

	player.call("equip_weapon", shotgun_data)
	await process_frame

	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if hands_sprite == null or hands_sprite.sprite_frames != shotgun_frames:
		_fail(root, "Player should equip shotgun visual SpriteFrames.")
		return

	player.call("play_idle", "side")
	await process_frame
	player.call("attack", "attack_first", "side")
	await physics_frame

	var bullet_count := 0
	var muzzle_flash_count := 0
	var casing_count := 0
	for child in root.get_children():
		if child is Area2D and child.has_method("launch"):
			bullet_count += 1
		if String(child.name).begins_with("GunMuzzleFlash"):
			muzzle_flash_count += 1
		if String(child.name).begins_with("GunBulletCasing"):
			casing_count += 1

	if bullet_count != 5:
		_fail(root, "Shotgun primary attack should spawn five projectile pellets.")
		return
	if muzzle_flash_count != 1:
		_fail(root, "Shotgun primary attack should spawn one muzzle flash effect.")
		return
	if casing_count != 1:
		_fail(root, "Shotgun primary attack should spawn one casing effect.")
		return

	print("Shotgun weapon logic is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
