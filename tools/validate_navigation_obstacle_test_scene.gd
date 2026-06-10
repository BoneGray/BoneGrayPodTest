@tool
extends SceneTree

const SCENE_PATH := "res://scenes/navigation_obstacle_test_scene.tscn"
const SMALL_STATS_PATH := "res://resources/characters/enemies/zombie_small_stats.tres"
const SMALL_SPRITE_FRAMES_PATH := "res://resources/characters/enemies/zombie_small_sprite_frames.tres"
const BIG_STATS_PATH := "res://resources/characters/enemies/zombie_big_stats.tres"
const BIG_SPRITE_FRAMES_PATH := "res://resources/characters/enemies/zombie_big_sprite_frames.tres"
const EXPECTED_OBSTACLE_COUNT := 7


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load navigation obstacle test scene.")
		quit(1)
		return

	var root := scene.instantiate()
	get_root().add_child(root)

	await process_frame
	await physics_frame
	await physics_frame

	var navigation_region := root.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	var player := root.get_node_or_null("Player") as CharacterBody2D
	var enemies := root.find_children("NavEnemy*", "CharacterBody2D", false, false)
	var big_enemies := root.find_children("NavBig*", "CharacterBody2D", false, false)
	var obstacles := root.find_children("*", "StaticBody2D", false, false)
	if navigation_region == null or player == null or enemies.size() < 1 or big_enemies.size() < 1:
		_fail(root, "Navigation obstacle test scene is missing required gameplay nodes.")
		return
	if obstacles.size() < EXPECTED_OBSTACLE_COUNT:
		_fail(root, "Navigation obstacle test scene does not have enough obstacle bodies.")
		return

	var navigation_polygon := navigation_region.navigation_polygon
	if navigation_polygon == null or navigation_polygon.get_polygon_count() == 0:
		_fail(root, "Navigation obstacle test scene does not have a baked navigation polygon.")
		return

	for obstacle in obstacles:
		if obstacle.collision_layer != 1:
			_fail(root, "%s is not on the world collision layer." % obstacle.name)
			return
		var visual := _find_polygon_visual(obstacle)
		if visual == null or visual.color.r < 0.8 or visual.color.g > 0.2:
			_fail(root, "%s does not have a red obstacle visual." % obstacle.name)
			return

	for enemy in enemies:
		if not _validate_enemy(root, enemy, player, SMALL_STATS_PATH, SMALL_SPRITE_FRAMES_PATH, "Zombie Small"):
			return

	for enemy in big_enemies:
		if not _validate_enemy(root, enemy, player, BIG_STATS_PATH, BIG_SPRITE_FRAMES_PATH, "Zombie Big"):
			return

	print("Navigation obstacle test scene is valid.")
	root.queue_free()
	quit()


func _validate_enemy(root: Node, enemy: CharacterBody2D, player: CharacterBody2D, stats_path: String, sprite_frames_path: String, display_name: String) -> bool:
	var agent := enemy.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if agent == null:
		_fail(root, "%s is missing NavigationAgent2D." % enemy.name)
		return false
	if not enemy.get("use_navigation_agent"):
		_fail(root, "%s does not enable NavigationAgent2D." % enemy.name)
		return false
	var stats := enemy.get("stats") as Resource
	if stats == null or stats.resource_path != stats_path:
		_fail(root, "%s should use %s stats resource." % [enemy.name, display_name])
		return false
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or sprite.sprite_frames.resource_path != sprite_frames_path:
		_fail(root, "%s should use %s SpriteFrames." % [enemy.name, display_name])
		return false
	if enemy.get("target") != player:
		_fail(root, "%s did not acquire Player as target." % enemy.name)
		return false
	return true


func _find_polygon_visual(node: Node) -> Polygon2D:
	for child in node.get_children():
		var polygon := child as Polygon2D
		if polygon != null:
			return polygon
	return null


func _fail(root: Node, message: String) -> void:
	push_error(message)
	root.queue_free()
	quit(1)
