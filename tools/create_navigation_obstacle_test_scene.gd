@tool
extends SceneTree

const SCENE_PATH := "res://scenes/navigation_obstacle_test_scene.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const CAMERA_SCRIPT_PATH := "res://scripts/camera_follow_target.gd"

const WORLD_COLLISION_LAYER := 1
const OBSTACLE_COLOR := Color(0.9, 0.08, 0.06, 0.9)
const FLOOR_COLOR := Color(0.23, 0.23, 0.23, 1.0)
const NAVIGATION_OBSTACLE_MARGIN := 12.0

const WALKABLE_RECT := Rect2(56, 56, 368, 248)
const WALL_RECTS := [
	Rect2(40, 40, 400, 16),
	Rect2(40, 304, 400, 16),
	Rect2(40, 40, 16, 280),
	Rect2(424, 40, 16, 280),
]
const INNER_OBSTACLE_RECTS := [
	Rect2(168, 96, 40, 104),
	Rect2(272, 176, 96, 32),
	Rect2(312, 72, 32, 64),
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var camera_script := load(CAMERA_SCRIPT_PATH) as Script
	if player_scene == null or enemy_scene == null or camera_script == null:
		push_error("Could not load required scenes or scripts.")
		quit(1)
		return

	var root := Node2D.new()
	root.name = "NavigationObstacleTestScene"
	root.y_sort_enabled = true

	_add_floor(root)
	_add_navigation_region(root)
	for index in WALL_RECTS.size():
		_add_obstacle(root, "OuterObstacle%d" % [index + 1], WALL_RECTS[index])
	for index in INNER_OBSTACLE_RECTS.size():
		_add_obstacle(root, "InnerObstacle%d" % [index + 1], INNER_OBSTACLE_RECTS[index])

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(2.5, 2.5)
	camera.position_smoothing_enabled = true
	camera.set_script(camera_script)
	camera.set("target_path", NodePath("../Player"))
	root.add_child(camera)
	camera.owner = root

	var player := player_scene.instantiate() as CharacterBody2D
	player.name = "Player"
	player.position = Vector2(156, 144)
	player.set("camera_follow_enabled", false)
	root.add_child(player)
	player.owner = root

	var enemy_positions := [
		Vector2(220, 144),
		Vector2(156, 88),
		Vector2(104, 176),
	]
	for index in enemy_positions.size():
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		enemy.name = "NavEnemy%d" % [index + 1]
		enemy.position = enemy_positions[index]
		enemy.set("use_navigation_agent", true)
		root.add_child(enemy)
		enemy.owner = root

	var packed_scene := PackedScene.new()
	var pack_result := packed_scene.pack(root)
	if pack_result != OK:
		push_error("Could not pack navigation obstacle test scene.")
		quit(1)
		return

	var save_result := ResourceSaver.save(packed_scene, SCENE_PATH)
	if save_result != OK:
		push_error("Could not save navigation obstacle test scene.")
		quit(1)
		return

	print("Navigation obstacle test scene created.")
	root.queue_free()
	await process_frame
	quit()


func _add_floor(root: Node) -> void:
	var floor := Polygon2D.new()
	floor.name = "Floor"
	floor.polygon = PackedVector2Array([
		WALKABLE_RECT.position,
		Vector2(WALKABLE_RECT.end.x, WALKABLE_RECT.position.y),
		WALKABLE_RECT.end,
		Vector2(WALKABLE_RECT.position.x, WALKABLE_RECT.end.y),
	])
	floor.color = FLOOR_COLOR
	root.add_child(floor)
	floor.owner = root


func _add_navigation_region(root: Node) -> void:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.add_outline(_rect_to_polygon(WALKABLE_RECT))
	for obstacle_rect in INNER_OBSTACLE_RECTS:
		navigation_polygon.add_outline(_rect_to_polygon(obstacle_rect.grow(NAVIGATION_OBSTACLE_MARGIN)))
	navigation_polygon.make_polygons_from_outlines()
	region.navigation_polygon = navigation_polygon
	root.add_child(region)
	region.owner = root


func _add_obstacle(root: Node, base_name: String, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "%sBody" % base_name
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = WORLD_COLLISION_LAYER
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)
	shape.owner = root

	var visual := Polygon2D.new()
	visual.name = "%sVisual" % base_name
	visual.polygon = PackedVector2Array([
		-rect.size * 0.5,
		Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
		rect.size * 0.5,
		Vector2(-rect.size.x * 0.5, rect.size.y * 0.5),
	])
	visual.color = OBSTACLE_COLOR
	body.add_child(visual)
	visual.owner = root


func _rect_to_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
