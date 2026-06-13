@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const PISTOL_DATA_PATH := "res://resources/equipment/weapons/pistol/pistol_data.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var pistol_data := load(PISTOL_DATA_PATH) as Resource
	if player_scene == null or pistol_data == null:
		_fail(null, "Could not load hold-repeat lockout dependencies.")
		return

	var root := Node2D.new()
	get_root().add_child(root)
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	player.call("equip_weapon", pistol_data)
	await process_frame
	player.call("attack", "attack_first", "side")
	await process_frame

	var pistol_profile := pistol_data.get("primary_attack_profile") as Resource
	if String(pistol_profile.get("input_mode")) != "hold_repeat":
		_fail(root, "Pistol should use hold_repeat for this lockout regression test.")
		return

	player.set("attack_lockout_remaining", 10.0)
	player.call("_clear_attack_lockout_after_animation", pistol_profile)
	if float(player.get("attack_lockout_remaining")) > 0.0:
		_fail(root, "Released hold-repeat tap should clear lockout after animation finish.")
		return

	print("Hold-repeat tap lockout clear is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
