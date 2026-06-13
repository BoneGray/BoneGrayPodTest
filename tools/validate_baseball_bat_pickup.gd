@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const PICKUP_SCENE_PATH := "res://scenes/items/weapons/baseball_bat_pickup.tscn"
const WEAPON_DATA_PATH := "res://resources/equipment/weapons/baseball_bat/baseball_bat_data.tres"
const WEAPON_FRAMES_PATH := "res://resources/equipment/weapons/baseball_bat/baseball_bat_sprite_frames.tres"

const REQUIRED_ANIMATIONS := [
	"idle_down",
	"idle_side",
	"idle_side_left",
	"idle_up",
	"walk_down",
	"walk_side",
	"walk_side_left",
	"walk_up",
	"attack_down_first",
	"attack_side_first",
	"attack_side_left_first",
	"attack_up_first",
	"attack_down_second",
	"attack_side_second",
	"attack_side_left_second",
	"attack_up_second",
	"pickup_down",
	"pickup_side",
	"pickup_side_left",
	"pickup_up",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var pickup_scene := load(PICKUP_SCENE_PATH) as PackedScene
	var weapon_data := load(WEAPON_DATA_PATH) as Resource
	var weapon_frames := load(WEAPON_FRAMES_PATH) as SpriteFrames
	if player_scene == null or pickup_scene == null or weapon_data == null or weapon_frames == null:
		_fail(null, "Could not load baseball bat pickup dependencies.")
		return

	for animation_name in REQUIRED_ANIMATIONS:
		if not weapon_frames.has_animation(animation_name):
			_fail(null, "Missing baseball bat animation: %s" % animation_name)
			return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	var pickup := pickup_scene.instantiate() as Area2D
	if pickup == null:
		_fail(root, "Baseball bat pickup scene should instantiate as Area2D.")
		return
	pickup.position = Vector2(10000, 10000)
	root.add_child(pickup)
	await process_frame

	var pickup_sprite := pickup.get_node_or_null("Sprite") as Sprite2D
	var outline_root := pickup.get_node_or_null("OutlineSprites") as Node2D
	if pickup_sprite == null or outline_root == null:
		_fail(root, "Weapon pickup should create Sprite and OutlineSprites.")
		return
	if pickup_sprite.material != null:
		_fail(root, "Pickup Sprite should keep original colors without shader material.")
		return
	if outline_root.z_index < pickup_sprite.z_index:
		_fail(root, "OutlineSprites should stay on the same draw layer as the pickup sprite.")
		return
	if outline_root.get_child_count() != 8:
		_fail(root, "OutlineSprites should contain eight offset outline sprites.")
		return
	for child in outline_root.get_children():
		var outline_sprite := child as Sprite2D
		if outline_sprite == null or outline_sprite.material == null:
			_fail(root, "Every outline sprite should carry the outline shader material.")
			return
		if outline_sprite.z_index < pickup_sprite.z_index:
			_fail(root, "Outline sprite should not render below the map floor.")
			return

	pickup.queue_free()
	player.call("equip_weapon", weapon_data)
	await process_frame

	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if hands_sprite == null:
		_fail(root, "Player must have HandsSprite.")
		return
	if player.get("equipped_weapon") != weapon_data:
		_fail(root, "Player should keep the equipped weapon data.")
		return
	if hands_sprite.sprite_frames != weapon_frames:
		_fail(root, "Player HandsSprite should use baseball bat SpriteFrames after pickup.")
		return
	var primary_attack := weapon_data.get("primary_attack_profile") as Resource
	if primary_attack == null:
		_fail(root, "Baseball bat should define a primary AttackProfile.")
		return
	player.call("attack", "attack_first", "down")
	await process_frame
	if player.call("get_attack_power") != int(primary_attack.get("damage")):
		_fail(root, "Equipped baseball bat should use primary AttackProfile damage.")
		return
	if absf(float(player.call("get_attack_interval", primary_attack)) - float(primary_attack.get("manual_attack_lockout"))) > 0.001:
		_fail(root, "Equipped baseball bat should use primary AttackProfile manual attack lockout.")
		return

	print("Baseball bat pickup is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
