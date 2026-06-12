@tool
extends SceneTree

const RenderLayers := preload("res://scripts/render/render_layers.gd")

const SCENE_PATH := "res://scenes/navigation_obstacle_test_scene.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const AXE_ENEMY_SCENE_PATH := "res://scenes/characters/enemy_zombie_axe.tscn"
const SMALL_ENEMY_SCENE_PATH := "res://scenes/characters/enemy_zombie_small.tscn"
const BIG_ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const BASEBALL_BAT_PICKUP_SCENE_PATH := "res://scenes/items/weapons/baseball_bat_pickup.tscn"
const GUN_PICKUP_SCENE_PATH := "res://scenes/items/weapons/gun_pickup.tscn"
const PISTOL_PICKUP_SCENE_PATH := "res://scenes/items/weapons/pistol_pickup.tscn"
const SHOTGUN_PICKUP_SCENE_PATH := "res://scenes/items/weapons/shotgun_pickup.tscn"
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
var NAVIGATION_VERTICES := PackedVector2Array([
	Vector2(424, 56),
	Vector2(424, 304),
	Vector2(380, 220),
	Vector2(380, 164),
	Vector2(356, 148),
	Vector2(260, 164),
	Vector2(300, 148),
	Vector2(56, 304),
	Vector2(260, 220),
	Vector2(220, 212),
	Vector2(156, 212),
	Vector2(56, 56),
	Vector2(156, 84),
	Vector2(356, 60),
	Vector2(300, 60),
	Vector2(220, 84),
])
var NAVIGATION_POLYGONS := [
	PackedInt32Array([0, 1, 2, 3]),
	PackedInt32Array([4, 3, 5, 6]),
	PackedInt32Array([2, 1, 7, 8]),
	PackedInt32Array([9, 8, 7, 10]),
	PackedInt32Array([10, 7, 11, 12]),
	PackedInt32Array([0, 3, 4, 13]),
	PackedInt32Array([11, 0, 13, 14]),
	PackedInt32Array([12, 11, 14, 15]),
	PackedInt32Array([15, 14, 6, 5]),
	PackedInt32Array([9, 15, 5, 8]),
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dependencies := _load_dependencies()
	if dependencies.is_empty():
		quit(1)
		return

	var root := Node2D.new()
	root.name = "NavigationObstacleTestScene"

	var terrain_layer := _add_layer(root, "TerrainLayer", RenderLayers.TERRAIN_Z, false)
	var world_actors := _add_layer(root, "WorldActors", RenderLayers.WORLD_Y_SORT_Z, true)
	var world_effects := _add_layer(root, "WorldEffects", RenderLayers.WORLD_EFFECTS_Z, false)
	var high_overlay := _add_layer(root, "HighOverlay", RenderLayers.HIGH_OVERLAY_Z, false)

	_add_floor(terrain_layer, root)
	_add_navigation_region(root)
	for index in WALL_RECTS.size():
		_add_obstacle(world_actors, root, "OuterObstacle%d" % [index + 1], WALL_RECTS[index])
	for index in INNER_OBSTACLE_RECTS.size():
		_add_obstacle(world_actors, root, "InnerObstacle%d" % [index + 1], INNER_OBSTACLE_RECTS[index])

	_add_camera(root, dependencies["camera_script"])
	_add_player(world_actors, root, dependencies["player_scene"], Vector2(110, 149))
	_add_enemy(world_actors, root, dependencies["axe_enemy_scene"], "EnemyZombieAxe", Vector2(398, 282))
	_add_enemy(world_actors, root, dependencies["small_enemy_scene"], "NavEnemy1", Vector2(318, 244))
	_add_enemy(world_actors, root, dependencies["big_enemy_scene"], "NavBig1", Vector2(356, 244))

	_add_pickup(world_actors, root, dependencies["baseball_bat_pickup_scene"], "BaseballBatPickup", Vector2(259, 266))
	_add_pickup(world_actors, root, dependencies["gun_pickup_scene"], "GunPickup", Vector2(101, 197))
	_add_pickup(world_actors, root, dependencies["pistol_pickup_scene"], "PistolPickup", Vector2(139, 197))
	_add_pickup(world_actors, root, dependencies["shotgun_pickup_scene"], "ShotgunPickup", Vector2(177, 197))

	world_effects.owner = root
	high_overlay.owner = root

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


func _load_dependencies() -> Dictionary:
	var dependencies := {
		"player_scene": load(PLAYER_SCENE_PATH) as PackedScene,
		"axe_enemy_scene": load(AXE_ENEMY_SCENE_PATH) as PackedScene,
		"small_enemy_scene": load(SMALL_ENEMY_SCENE_PATH) as PackedScene,
		"big_enemy_scene": load(BIG_ENEMY_SCENE_PATH) as PackedScene,
		"baseball_bat_pickup_scene": load(BASEBALL_BAT_PICKUP_SCENE_PATH) as PackedScene,
		"gun_pickup_scene": load(GUN_PICKUP_SCENE_PATH) as PackedScene,
		"pistol_pickup_scene": load(PISTOL_PICKUP_SCENE_PATH) as PackedScene,
		"shotgun_pickup_scene": load(SHOTGUN_PICKUP_SCENE_PATH) as PackedScene,
		"camera_script": load(CAMERA_SCRIPT_PATH) as Script,
	}
	for key in dependencies:
		if dependencies[key] == null:
			push_error("Could not load navigation scene dependency: %s" % key)
			return {}
	return dependencies


func _add_layer(root: Node, layer_name: String, z_index: int, y_sort_enabled: bool) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.z_index = z_index
	layer.y_sort_enabled = y_sort_enabled
	root.add_child(layer)
	layer.owner = root
	return layer


func _add_floor(terrain_layer: Node, owner: Node) -> void:
	var floor := Polygon2D.new()
	floor.name = "Floor"
	floor.polygon = PackedVector2Array([
		WALKABLE_RECT.position,
		Vector2(WALKABLE_RECT.end.x, WALKABLE_RECT.position.y),
		WALKABLE_RECT.end,
		Vector2(WALKABLE_RECT.position.x, WALKABLE_RECT.end.y),
	])
	floor.color = FLOOR_COLOR
	terrain_layer.add_child(floor)
	floor.owner = owner


func _add_navigation_region(root: Node) -> void:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.vertices = NAVIGATION_VERTICES
	for polygon in NAVIGATION_POLYGONS:
		navigation_polygon.add_polygon(polygon)
	navigation_polygon.add_outline(_rect_to_polygon(WALKABLE_RECT))
	for obstacle_rect in INNER_OBSTACLE_RECTS:
		navigation_polygon.add_outline(_rect_to_polygon(obstacle_rect.grow(NAVIGATION_OBSTACLE_MARGIN)))
	region.navigation_polygon = navigation_polygon
	root.add_child(region)
	region.owner = root


func _add_obstacle(world_actors: Node, owner: Node, base_name: String, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "%sBody" % base_name
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = WORLD_COLLISION_LAYER
	body.collision_mask = 0
	body.z_index = RenderLayers.WORLD_Y_SORT_Z
	world_actors.add_child(body)
	body.owner = owner

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)
	shape.owner = owner

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
	visual.owner = owner


func _add_camera(root: Node, camera_script: Script) -> void:
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(2.5, 2.5)
	camera.position_smoothing_enabled = true
	camera.set_script(camera_script)
	camera.set("target_path", NodePath("../WorldActors/Player"))
	root.add_child(camera)
	camera.owner = root


func _add_player(world_actors: Node, owner: Node, player_scene: PackedScene, player_position: Vector2) -> void:
	var player := player_scene.instantiate() as CharacterBody2D
	player.name = "Player"
	player.position = player_position
	player.set("camera_follow_enabled", false)
	world_actors.add_child(player)
	player.owner = owner


func _add_enemy(world_actors: Node, owner: Node, enemy_scene: PackedScene, enemy_name: String, enemy_position: Vector2) -> void:
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	enemy.name = enemy_name
	enemy.position = enemy_position
	enemy.set("use_navigation_agent", true)
	world_actors.add_child(enemy)
	enemy.owner = owner


func _add_pickup(world_actors: Node, owner: Node, pickup_scene: PackedScene, pickup_name: String, pickup_position: Vector2) -> void:
	var pickup := pickup_scene.instantiate() as Node2D
	pickup.name = pickup_name
	pickup.position = pickup_position
	world_actors.add_child(pickup)
	pickup.owner = owner


func _rect_to_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
