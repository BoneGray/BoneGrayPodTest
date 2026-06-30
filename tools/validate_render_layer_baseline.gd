@tool
extends SceneTree

const RenderLayers := preload("res://scripts/render/render_layers.gd")
const SCENE_PATH := "res://scenes/Main.tscn"
const CHARACTER_SCENE_PATHS := [
	"res://scenes/characters/player.tscn",
	"res://scenes/characters/enemy.tscn",
	"res://scenes/characters/enemy_zombie_small.tscn",
	"res://scenes/characters/enemy_zombie_axe.tscn",
]
const PICKUP_SCENE_PATHS := [
	"res://scenes/items/weapons/baseball_bat_pickup.tscn",
	"res://scenes/items/weapons/gun_pickup.tscn",
	"res://scenes/items/weapons/pistol_pickup.tscn",
	"res://scenes/items/weapons/shotgun_pickup.tscn",
	"res://scenes/items/axe_pickup.tscn",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _validate_reusable_actor_scenes():
		return

	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load render layer baseline scene.")
		quit(1)
		return

	var root := scene.instantiate()
	get_root().add_child(root)
	current_scene = root

	await process_frame

	var terrain_layer := root.get_node_or_null("TerrainLayer") as Node2D
	var shadow_layer := root.get_node_or_null("ShadowLayer") as Node2D
	var world_actors := root.get_node_or_null("WorldActors") as Node2D
	var world_effects := root.get_node_or_null("WorldEffects") as Node2D
	var high_overlay := root.get_node_or_null("HighOverlay") as Node2D
	if terrain_layer == null or shadow_layer == null or world_actors == null or world_effects == null or high_overlay == null:
		_fail(root, "Main scene should expose TerrainLayer, ShadowLayer, WorldActors, WorldEffects, and HighOverlay.")
		return

	if terrain_layer.z_index != RenderLayers.TERRAIN_Z:
		_fail(root, "TerrainLayer should use RenderLayers.TERRAIN_Z.")
		return
	if shadow_layer.z_index != RenderLayers.SHADOW_Z:
		_fail(root, "ShadowLayer should use RenderLayers.SHADOW_Z.")
		return
	if not world_actors.y_sort_enabled or world_actors.z_index != RenderLayers.WORLD_Y_SORT_Z:
		_fail(root, "WorldActors should enable YSort and use RenderLayers.WORLD_Y_SORT_Z.")
		return
	if world_effects.z_index != RenderLayers.WORLD_EFFECTS_Z:
		_fail(root, "WorldEffects should use RenderLayers.WORLD_EFFECTS_Z.")
		return
	if high_overlay.z_index != RenderLayers.HIGH_OVERLAY_Z:
		_fail(root, "HighOverlay should use RenderLayers.HIGH_OVERLAY_Z.")
		return

	if terrain_layer.get_node_or_null("FloorLayer") == null:
		_fail(root, "FloorLayer should live under TerrainLayer and should not participate in WorldActors YSort.")
		return

	for node_name in ["Player", "BushYellowRound05Decor", "BushYellowRound03Decor", "BushYellowRound04Decor", "WallBodyLayer"]:
		var actor := world_actors.get_node_or_null(node_name) as Node2D
		if actor == null:
			_fail(root, "%s should live under WorldActors." % node_name)
			return
		if actor.z_index != RenderLayers.WORLD_Y_SORT_Z:
			_fail(root, "%s should keep the WorldActors baseline z-index." % node_name)
			return

	var player := world_actors.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		_fail(root, "Player should be available for character internal layer validation.")
		return

	var body_sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	var hands_sprite := player.get_node_or_null("HandsSprite") as AnimatedSprite2D
	if body_sprite == null or hands_sprite == null:
		_fail(root, "Player should keep Sprite and HandsSprite as internal visual layers.")
		return

	player.call("play_walk", "down")
	await process_frame
	if body_sprite.z_index != RenderLayers.CHARACTER_BODY_Z:
		_fail(root, "Player body should stay on the actor root sorting layer while facing down.")
		return
	if body_sprite.z_index > RenderLayers.CHARACTER_BODY_Z or hands_sprite.z_index > RenderLayers.CHARACTER_FRONT_EQUIPMENT_Z:
		_fail(root, "Player internal down-facing layers should stay inside the actor root sorting layer.")
		return
	if hands_sprite.z_index < body_sprite.z_index:
		_fail(root, "HandsSprite should not draw behind body while facing down.")
		return
	if body_sprite.get_index() > hands_sprite.get_index():
		_fail(root, "HandsSprite should be after Sprite when both use the same z-index.")
		return

	player.call("play_walk", "up")
	await process_frame
	if body_sprite.z_index != RenderLayers.CHARACTER_BODY_Z:
		_fail(root, "Player body should stay on the actor root sorting layer while facing up.")
		return
	if body_sprite.z_index > RenderLayers.CHARACTER_BODY_Z or hands_sprite.z_index > RenderLayers.CHARACTER_FRONT_EQUIPMENT_Z:
		_fail(root, "Player internal up-facing layers should stay inside the actor root sorting layer.")
		return
	if hands_sprite.z_index >= body_sprite.z_index:
		_fail(root, "HandsSprite should draw behind body while facing up.")
		return

	print("Render layer baseline is valid.")
	root.queue_free()
	quit()


func _validate_reusable_actor_scenes() -> bool:
	for scene_path in CHARACTER_SCENE_PATHS:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			push_error("Could not load character scene: %s" % scene_path)
			quit(1)
			return false

		var actor := scene.instantiate() as Node2D
		if actor == null:
			push_error("%s should instantiate as Node2D." % scene_path)
			quit(1)
			return false
		if actor.z_index != RenderLayers.CHARACTER_ROOT_Z:
			push_error("%s should keep character root z-index at RenderLayers.CHARACTER_ROOT_Z." % scene_path)
			actor.queue_free()
			quit(1)
			return false
		actor.queue_free()

	for scene_path in PICKUP_SCENE_PATHS:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			push_error("Could not load pickup scene: %s" % scene_path)
			quit(1)
			return false

		var pickup := scene.instantiate() as Node2D
		if pickup == null:
			push_error("%s should instantiate as Node2D." % scene_path)
			quit(1)
			return false
		if pickup.z_index != RenderLayers.PICKUP_ROOT_Z:
			push_error("%s should keep pickup root z-index at RenderLayers.PICKUP_ROOT_Z." % scene_path)
			pickup.queue_free()
			quit(1)
			return false
		pickup.queue_free()

	return true


func _fail(root: Node, message: String) -> void:
	push_error(message)
	root.queue_free()
	quit(1)
