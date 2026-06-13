@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const GUN_DATA_PATH := "res://resources/equipment/weapons/gun/gun_data.tres"
const GUN_PICKUP_SCENE_PATH := "res://scenes/items/weapons/gun_pickup.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var gun_data := load(GUN_DATA_PATH) as Resource
	var gun_pickup_scene := load(GUN_PICKUP_SCENE_PATH) as PackedScene
	if player_scene == null or gun_data == null or gun_pickup_scene == null:
		_fail(null, "Could not load player drop weapon dependencies.")
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	if bool(player.call("drop_current_weapon")):
		_fail(root, "Dropping with no weapon should do nothing.")
		return

	var pickup := gun_pickup_scene.instantiate() as Node2D
	root.add_child(pickup)
	pickup.global_position = player.global_position
	await physics_frame
	await physics_frame

	pickup.call("_on_body_entered", player)
	if not bool(pickup.get("_pickup_hint_active")):
		_fail(root, "Weapon pickup should use the active hint state while the player is in pickup range.")
		return
	pickup.call("_on_body_exited", player)
	if bool(pickup.get("_pickup_hint_active")):
		_fail(root, "Weapon pickup should return to the idle hint state when the player leaves pickup range.")
		return
	pickup.call("_on_body_entered", player)

	if player.get("equipped_weapon") != null:
		_fail(root, "Touching a weapon pickup should not equip it automatically.")
		return

	var unused_event := InputEventKey.new()
	unused_event.keycode = KEY_K
	unused_event.physical_keycode = KEY_K
	unused_event.pressed = true
	player.call("_unhandled_input", unused_event)
	await process_frame

	if player.get("equipped_weapon") != null:
		_fail(root, "Pressing K should be unused and must not equip a weapon.")
		return

	var pickup_event := InputEventKey.new()
	pickup_event.keycode = KEY_E
	pickup_event.physical_keycode = KEY_E
	pickup_event.pressed = true
	player.call("_unhandled_input", pickup_event)
	await process_frame

	if player.get("equipped_weapon") == null:
		_fail(root, "Pressing E near a weapon pickup should equip it.")
		return

	var drop_event := InputEventKey.new()
	drop_event.keycode = KEY_E
	drop_event.physical_keycode = KEY_E
	drop_event.pressed = true
	player.call("_unhandled_input", drop_event)
	await process_frame

	if player.get("equipped_weapon") != null:
		_fail(root, "Pressing E should clear the equipped weapon.")
		return
	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if hands_sprite == null or not hands_sprite.visible:
		_fail(root, "Dropping a weapon should restore the player's unarmed hands visual.")
		return
	if hands_sprite.sprite_frames != player.get("_unarmed_visual_sprite_frames"):
		_fail(root, "Dropping a weapon should switch HandsSprite back to the unarmed SpriteFrames.")
		return

	if bool(player.call("drop_current_weapon")):
		_fail(root, "Dropping again with no weapon should do nothing.")
		return

	var dropped_pickups := 0
	for child in root.get_children():
		if child == player:
			continue
		if child.get("item_data") == gun_data:
			dropped_pickups += 1

	if dropped_pickups != 1:
		_fail(root, "Dropping should spawn exactly one matching weapon pickup.")
		return

	print("Player drop weapon is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
