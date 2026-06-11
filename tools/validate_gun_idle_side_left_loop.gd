@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const GUN_DATA_PATH := "res://resources/equipment/weapons/gun/gun_data.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var gun_data := load(GUN_DATA_PATH) as Resource
	if player_scene == null or gun_data == null:
		_fail(null, "Could not load player scene or gun data.")
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	player.keyboard_control_enabled = false
	root.add_child(player)
	await process_frame

	player.call("equip_weapon", gun_data)
	for frame in 30:
		await process_frame
	player.call("play_idle", "side_left")
	for frame in 300:
		await process_frame

	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if hands_sprite == null or hands_sprite.animation != StringName("idle_side_left"):
		var actual_animation := "<missing>" if hands_sprite == null else String(hands_sprite.animation)
		_fail(root, "Gun side-left idle visual should keep looping on HandsSprite. actual=%s" % actual_animation)
		return

	print("Gun side-left idle loop is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
