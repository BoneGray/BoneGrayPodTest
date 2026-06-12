@tool
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const NO_HANDS_SPRITE_FRAMES_PATH := "res://resources/characters/player/player_no_hands_sprite_frames.tres"
const HANDS_SPRITE_FRAMES_PATH := "res://resources/characters/player/player_hands_sprite_frames.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var no_hands_frames := load(NO_HANDS_SPRITE_FRAMES_PATH) as SpriteFrames
	var hands_frames := load(HANDS_SPRITE_FRAMES_PATH) as SpriteFrames
	if player_scene == null or no_hands_frames == null or hands_frames == null:
		push_error("Could not load player layered visual dependencies.")
		quit(1)
		return

	var root := Node2D.new()
	get_root().add_child(root)

	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)

	await process_frame

	var body_sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if body_sprite == null or hands_sprite == null:
		_fail(root, "Player must have Sprite and HandsSprite.")
		return
	if body_sprite.sprite_frames != no_hands_frames:
		_fail(root, "Player Sprite should use no-hands body SpriteFrames.")
		return
	if hands_sprite.sprite_frames != hands_frames:
		_fail(root, "Player HandsSprite should use hands SpriteFrames.")
		return

	player.call("play_walk", "side")
	await process_frame
	if hands_sprite.animation != body_sprite.animation or hands_sprite.frame != body_sprite.frame:
		_fail(root, "HandsSprite should sync walk animation and frame.")
		return
	if body_sprite.z_index != 0:
		_fail(root, "Player body should stay on the actor root sorting layer for side-facing animations.")
		return
	if hands_sprite.z_index < body_sprite.z_index:
		_fail(root, "HandsSprite should not draw behind the body for side-facing animations.")
		return
	if hands_sprite.z_index > 0 or body_sprite.z_index > 0:
		_fail(root, "Player internal visual layers should not rise above the actor root sorting layer.")
		return
	if body_sprite.get_index() > hands_sprite.get_index():
		_fail(root, "HandsSprite should be after Sprite in the player scene tree when sharing the same z-index.")
		return

	player.call("play_walk", "up")
	await process_frame
	if body_sprite.z_index != 0:
		_fail(root, "Player body should stay on the actor root sorting layer while facing up.")
		return
	if hands_sprite.z_index >= body_sprite.z_index:
		_fail(root, "HandsSprite should draw behind the body for up-facing animations.")
		return
	if hands_sprite.z_index > 0 or body_sprite.z_index > 0:
		_fail(root, "Player internal visual layers should stay within the actor root sorting layer while facing up.")
		return

	player.call("attack", "attack_first", "down")
	await process_frame
	if hands_sprite.animation != body_sprite.animation or not hands_sprite.visible:
		_fail(root, "HandsSprite should sync attack animation.")
		return
	if body_sprite.z_index != 0:
		_fail(root, "Player body should stay on the actor root sorting layer for down-facing attacks.")
		return
	if hands_sprite.z_index < body_sprite.z_index:
		_fail(root, "HandsSprite should not draw behind the body for down-facing attacks.")
		return
	if hands_sprite.z_index > 0 or body_sprite.z_index > 0:
		_fail(root, "Player internal attack layers should not rise above the actor root sorting layer.")
		return

	player.call("clear_weapon_visual")
	await process_frame
	if not hands_sprite.visible or hands_sprite.sprite_frames != hands_frames:
		_fail(root, "clear_weapon_visual should restore the unarmed HandsSprite visuals.")
		return

	player.call("equip_weapon_visual", hands_frames)
	await process_frame
	if hands_sprite.sprite_frames != hands_frames or not hands_sprite.visible:
		_fail(root, "equip_weapon_visual should restore HandsSprite visuals.")
		return

	print("Player layered weapon visual is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	root.queue_free()
	quit(1)
