@tool
extends RefCounted

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const DEFAULT_REQUIRED_ANIMATIONS := [
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
]


func validate_weapon_data(tree: SceneTree, weapon_data: Resource, weapon_path := "") -> String:
	var label := _weapon_label(weapon_data, weapon_path)
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if weapon_data == null:
		return "Could not load firearm weapon data: %s." % weapon_path
	var pickup_scene := load(String(weapon_data.get("pickup_scene_path"))) as PackedScene
	var frames := weapon_data.get("visual_sprite_frames") as SpriteFrames
	if player_scene == null or weapon_data == null or pickup_scene == null or frames == null:
		return "Could not load %s dependencies." % label

	var animation_error := _validate_required_animations(frames, label, DEFAULT_REQUIRED_ANIMATIONS)
	if animation_error != "":
		return animation_error

	var profile := weapon_data.get("primary_attack_profile") as Resource
	var profile_error := _validate_firearm_profile(profile, label)
	if profile_error != "":
		return profile_error

	var root := Node2D.new()
	tree.get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await tree.process_frame

	var pickup_error := _validate_pickup_scene(pickup_scene, label)
	if pickup_error != "":
		root.queue_free()
		return pickup_error

	player.call("equip_weapon", weapon_data)
	await tree.process_frame

	var visual_error := await _validate_equipped_visual(tree, player, weapon_data, frames, label)
	if visual_error != "":
		root.queue_free()
		return visual_error

	var attack_error := await _validate_projectile_attack(tree, root, player, weapon_data, profile, label)
	if attack_error != "":
		root.queue_free()
		return attack_error

	var rhythm_error := _validate_attack_rhythm(player, profile, label)
	if rhythm_error != "":
		root.queue_free()
		return rhythm_error

	root.queue_free()
	return ""


func _validate_required_animations(frames: SpriteFrames, label: String, animations: Array) -> String:
	for animation_name in animations:
		if not frames.has_animation(String(animation_name)):
			return "%s SpriteFrames should define %s." % [label, animation_name]
	return ""


func _validate_firearm_profile(profile: Resource, label: String) -> String:
	if profile == null:
		return "%s must have a primary attack profile." % label
	if String(profile.get("attack_type")) != "projectile":
		return "%s primary attack must be projectile." % label
	if String(profile.get("input_mode")) != "hold_repeat":
		return "%s primary attack should use hold_repeat." % label
	if String(profile.get("repeat_mode")) != "enabled":
		return "%s primary attack should enable repeat_mode." % label
	if float(profile.get("manual_attack_lockout")) <= 0.0:
		return "%s primary attack should define manual_attack_lockout." % label
	if float(profile.get("repeat_attack_cooldown")) <= 0.0:
		return "%s primary attack should define repeat_attack_cooldown." % label
	if profile.get("projectile_scene") == null:
		return "%s primary attack should configure projectile_scene." % label
	if profile.get("muzzle_flash_scene") == null:
		return "%s primary attack should configure muzzle_flash_scene." % label
	if profile.get("casing_scene") == null:
		return "%s primary attack should configure casing_scene." % label
	return ""


func _validate_pickup_scene(pickup_scene: PackedScene, label: String) -> String:
	var pickup := pickup_scene.instantiate() as Area2D
	if pickup == null:
		return "%s pickup scene should instantiate as Area2D." % label
	if pickup.z_index != 0:
		pickup.queue_free()
		return "%s pickup should stay on the WorldActors baseline z-index." % label
	pickup.queue_free()
	return ""


func _validate_equipped_visual(
	tree: SceneTree,
	player: CharacterBody2D,
	weapon_data: Resource,
	frames: SpriteFrames,
	label: String
) -> String:
	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if hands_sprite == null or hands_sprite.sprite_frames != frames:
		return "Player should equip %s visual SpriteFrames." % label

	var body_sprite := player.get_node("Sprite") as AnimatedSprite2D
	player.call("play_walk", "side")
	await tree.process_frame
	if hands_sprite.z_index < body_sprite.z_index:
		return "%s side visual should not render behind the player body." % label
	if hands_sprite.z_index == body_sprite.z_index and body_sprite.get_index() > hands_sprite.get_index():
		return "%s side visual should be after the player body when sharing the same z-index." % label

	player.call("play_walk", "up")
	await tree.process_frame
	if hands_sprite.z_index >= body_sprite.z_index:
		return "%s up visual should render behind the player body." % label

	return ""


func _validate_projectile_attack(
	tree: SceneTree,
	root: Node,
	player: CharacterBody2D,
	weapon_data: Resource,
	profile: Resource,
	label: String
) -> String:
	var expected_projectile_count := maxi(int(profile.get("projectile_count")), 1)

	player.call("play_idle", "side")
	await tree.process_frame

	var expected_muzzle_position: Vector2 = player.global_position + weapon_data.get("visual_offset_side") + _animation_visual_offset(weapon_data, "attack_side_first") + profile.get("muzzle_flash_offset_side")
	var expected_casing_position: Vector2 = player.global_position + weapon_data.get("visual_offset_side") + _animation_visual_offset(weapon_data, "attack_side_first") + profile.get("casing_offset_side")

	player.call("attack", "attack_first", "side")
	await tree.physics_frame

	var projectile_count := 0
	var muzzle_flash_count := 0
	var casing_count := 0
	var muzzle_flash_position := Vector2.ZERO
	var casing_position := Vector2.ZERO
	for child in root.get_children():
		if child is Area2D and child.has_method("launch"):
			projectile_count += 1
		if child.name == "GunMuzzleFlash":
			muzzle_flash_count += 1
			muzzle_flash_position = child.global_position
		if child.name == "GunBulletCasing":
			casing_count += 1
			casing_position = child.get_meta("spawn_position", child.global_position)

	if projectile_count != expected_projectile_count:
		return "%s primary attack should spawn %d projectile(s), got %d." % [label, expected_projectile_count, projectile_count]
	if muzzle_flash_count != 1:
		return "%s primary attack should spawn one muzzle flash effect." % label
	if muzzle_flash_position != expected_muzzle_position:
		return "%s muzzle flash should follow the attack animation weapon visual offset." % label
	if casing_count != 1:
		return "%s primary attack should spawn one casing effect." % label
	if casing_position != expected_casing_position:
		return "%s bullet casing should follow the attack animation weapon visual offset." % label
	return ""


func _weapon_label(weapon_data: Resource, weapon_path: String) -> String:
	if weapon_data != null:
		var display_name := String(weapon_data.get("display_name"))
		if display_name != "":
			return display_name
		var weapon_id := String(weapon_data.get("weapon_id"))
		if weapon_id != "":
			return weapon_id
	return weapon_path if weapon_path != "" else "Firearm"


func _validate_attack_rhythm(player: CharacterBody2D, profile: Resource, label: String) -> String:
	if absf(float(player.call("get_attack_interval", profile)) - float(profile.get("manual_attack_lockout"))) > 0.001:
		return "%s manual attack lockout should come from primary attack profile." % label
	if absf(float(player.call("get_attack_interval", profile, "repeat")) - float(profile.get("repeat_attack_cooldown"))) > 0.001:
		return "%s repeat attack interval should come from primary attack profile." % label
	return ""


func _animation_visual_offset(weapon_data: Resource, animation_name: String) -> Vector2:
	var animation_offsets = weapon_data.get("animation_visual_offsets")
	if not animation_offsets is Dictionary:
		return Vector2.ZERO

	var offset = animation_offsets.get(animation_name, animation_offsets.get(StringName(animation_name), Vector2.ZERO))
	if offset is Vector2:
		return offset
	return Vector2.ZERO
