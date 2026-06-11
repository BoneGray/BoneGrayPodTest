@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const GUN_DATA_PATH := "res://resources/equipment/weapons/gun/gun_data.tres"
const GUN_FRAMES_PATH := "res://resources/equipment/weapons/gun/gun_sprite_frames.tres"
const GUN_PICKUP_SCENE_PATH := "res://scenes/items/weapons/gun_pickup.tscn"

const REQUIRED_ANIMATIONS := [
	"idle_down",
	"idle_side",
	"idle_side_left",
	"idle_up",
	"walk_down",
	"walk_side",
	"walk_side_left",
	"walk_up",
	"pickup_down",
	"pickup_side",
	"pickup_side_left",
	"pickup_up",
	"attack_down_first",
	"attack_side_first",
	"attack_side_left_first",
	"attack_up_first",
	"reload_down",
	"reload_side",
	"reload_side_left",
	"reload_up",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var gun_data := load(GUN_DATA_PATH) as Resource
	var gun_frames := load(GUN_FRAMES_PATH) as SpriteFrames
	var gun_pickup_scene := load(GUN_PICKUP_SCENE_PATH) as PackedScene
	if player_scene == null or gun_data == null or gun_frames == null or gun_pickup_scene == null:
		_fail(null, "Could not load gun weapon dependencies.")
		return

	for animation_name in REQUIRED_ANIMATIONS:
		if not gun_frames.has_animation(animation_name):
			_fail(null, "Missing gun animation: %s" % animation_name)
			return

	var primary_profile := gun_data.get("primary_attack_profile") as Resource
	if primary_profile == null:
		_fail(null, "Gun must have a primary attack profile.")
		return
	if String(primary_profile.get("attack_type")) != "projectile":
		_fail(null, "Gun primary attack must be projectile.")
		return
	if primary_profile.get("muzzle_flash_scene") == null:
		_fail(null, "Gun primary attack should configure a muzzle flash scene.")
		return
	if primary_profile.get("casing_scene") == null:
		_fail(null, "Gun primary attack should configure a bullet casing scene.")
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	player.keyboard_control_enabled = false
	root.add_child(player)
	await process_frame

	var gun_pickup := gun_pickup_scene.instantiate() as Area2D
	if gun_pickup == null:
		_fail(root, "Gun pickup scene should instantiate as Area2D.")
		return
	gun_pickup.queue_free()
	player.call("equip_weapon", gun_data)
	await process_frame

	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if hands_sprite == null or hands_sprite.sprite_frames != gun_frames:
		_fail(root, "Player should equip gun visual SpriteFrames.")
		return

	var hands_base_position := player.get("_equipment_visual_base_position") as Vector2
	player.call("play_walk", "side")
	await process_frame
	if hands_sprite.position != hands_base_position + gun_data.get("visual_offset_side") + _animation_visual_offset(gun_data, "walk_side"):
		_fail(root, "Gun side visual should be offset downward to keep the player head visible.")
		return
	if hands_sprite.z_index <= player.get_node("Sprite").z_index:
		_fail(root, "Gun side visual should render in front of the player body.")
		return

	var original_animation_offsets = gun_data.get("animation_visual_offsets")
	gun_data.set("animation_visual_offsets", {StringName("walk_side"): Vector2(1, 1)})
	player.call("play_walk", "side")
	await process_frame
	if hands_sprite.position != hands_base_position + gun_data.get("visual_offset_side") + _animation_visual_offset(gun_data, "walk_side"):
		_fail(root, "Gun animation visual offset should stack with direction visual offset.")
		return
	gun_data.set("animation_visual_offsets", original_animation_offsets)

	player.call("play_walk", "down")
	await process_frame
	if hands_sprite.position != hands_base_position + gun_data.get("visual_offset_down") + _animation_visual_offset(gun_data, "walk_down"):
		_fail(root, "Gun down visual should be offset downward to keep the player head visible.")
		return

	player.call("play_walk", "up")
	await process_frame
	if hands_sprite.z_index >= player.get_node("Sprite").z_index:
		_fail(root, "Gun up visual should render behind the player body.")
		return

	player.call("play_idle", "side")
	await process_frame
	var expected_muzzle_position: Vector2 = player.global_position + gun_data.get("visual_offset_side") + _animation_visual_offset(gun_data, "attack_side_first") + primary_profile.get("muzzle_flash_offset_side")
	var expected_casing_position: Vector2 = player.global_position + gun_data.get("visual_offset_side") + _animation_visual_offset(gun_data, "attack_side_first") + primary_profile.get("casing_offset_side")
	player.call("attack", "attack_first", "side")
	await physics_frame

	var bullet_count := 0
	var muzzle_flash_count := 0
	var casing_count := 0
	var muzzle_flash_position := Vector2.ZERO
	var casing_position := Vector2.ZERO
	for child in root.get_children():
		if child.name == "PlayerBulletProjectile":
			bullet_count += 1
		if child.name == "GunMuzzleFlash":
			muzzle_flash_count += 1
			muzzle_flash_position = child.global_position
		if child.name == "GunBulletCasing":
			casing_count += 1
			casing_position = child.get_meta("spawn_position", child.global_position)
	if bullet_count != 1:
		_fail(root, "Gun primary attack should spawn one player bullet projectile.")
		return
	if muzzle_flash_count != 1:
		_fail(root, "Gun primary attack should spawn one muzzle flash effect.")
		return
	if muzzle_flash_position != expected_muzzle_position:
		_fail(root, "Gun muzzle flash should follow the attack animation weapon visual offset.")
		return
	if casing_count != 1:
		_fail(root, "Gun primary attack should spawn one bullet casing effect.")
		return
	if casing_position != expected_casing_position:
		_fail(root, "Gun bullet casing should follow the attack animation weapon visual offset.")
		return
	for frame in 120:
		await process_frame
	for child in root.get_children():
		if child.name == "GunBulletCasing":
			_fail(root, "Gun bullet casing should disappear after its fly-out animation.")
			return

	if absf(float(player.call("get_attack_cooldown")) - float(primary_profile.get("cooldown"))) > 0.001:
		_fail(root, "Gun attack cooldown should come from primary attack profile.")
		return

	print("Gun weapon logic is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)


func _animation_visual_offset(weapon_data: Resource, animation_name: String) -> Vector2:
	var animation_offsets = weapon_data.get("animation_visual_offsets")
	if not animation_offsets is Dictionary:
		return Vector2.ZERO

	var offset = animation_offsets.get(animation_name, animation_offsets.get(StringName(animation_name), Vector2.ZERO))
	if offset is Vector2:
		return offset
	return Vector2.ZERO
