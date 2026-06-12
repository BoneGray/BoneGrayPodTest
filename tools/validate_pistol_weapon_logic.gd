@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const PISTOL_DATA_PATH := "res://resources/equipment/weapons/pistol/pistol_data.tres"
const PISTOL_PICKUP_SCENE_PATH := "res://scenes/items/weapons/pistol_pickup.tscn"
const PISTOL_FRAMES_PATH := "res://resources/equipment/weapons/pistol/pistol_sprite_frames.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var pistol_data := load(PISTOL_DATA_PATH) as Resource
	var pistol_pickup_scene := load(PISTOL_PICKUP_SCENE_PATH) as PackedScene
	var pistol_frames := load(PISTOL_FRAMES_PATH) as SpriteFrames
	if player_scene == null or pistol_data == null or pistol_pickup_scene == null or pistol_frames == null:
		_fail(null, "Could not load pistol dependencies.")
		return

	for animation_name in ["idle_down", "idle_side", "idle_side_left", "idle_up", "attack_down_first", "attack_side_first", "attack_side_left_first", "attack_up_first"]:
		if not pistol_frames.has_animation(animation_name):
			_fail(null, "Pistol SpriteFrames should define %s." % animation_name)
			return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	var pickup := pistol_pickup_scene.instantiate() as Area2D
	if pickup == null:
		_fail(root, "Pistol pickup scene should instantiate as Area2D.")
		return
	if pickup.z_index != 0:
		_fail(root, "Pistol pickup should stay on the WorldActors baseline z-index.")
		return
	pickup.queue_free()

	player.call("equip_weapon", pistol_data)
	await process_frame

	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if hands_sprite == null or hands_sprite.sprite_frames != pistol_frames:
		_fail(root, "Player should equip pistol visual SpriteFrames.")
		return

	player.call("play_walk", "side")
	await process_frame
	var body_sprite := player.get_node("Sprite") as AnimatedSprite2D
	if hands_sprite.z_index < body_sprite.z_index:
		_fail(root, "Pistol side visual should not render behind the player body.")
		return
	if hands_sprite.z_index == body_sprite.z_index and body_sprite.get_index() > hands_sprite.get_index():
		_fail(root, "Pistol side visual should be after the player body when sharing the same z-index.")
		return

	player.call("play_idle", "side")
	await process_frame
	player.call("attack", "attack_first", "side")
	await physics_frame

	var bullet_count := 0
	var muzzle_flash_count := 0
	var casing_count := 0
	for child in root.get_children():
		if child.name == "PistolBulletProjectile":
			bullet_count += 1
		if child.name == "GunMuzzleFlash":
			muzzle_flash_count += 1
		if child.name == "GunBulletCasing":
			casing_count += 1

	if bullet_count != 1:
		_fail(root, "Pistol primary attack should spawn one pistol bullet projectile.")
		return
	if muzzle_flash_count != 1:
		_fail(root, "Pistol primary attack should spawn one muzzle flash effect.")
		return
	if casing_count != 1:
		_fail(root, "Pistol primary attack should spawn one casing effect.")
		return

	print("Pistol weapon logic is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
