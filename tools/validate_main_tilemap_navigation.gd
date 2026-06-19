extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/Main.tscn") as PackedScene
	_assert(scene != null, "Main scene can be loaded.")

	var root := scene.instantiate()
	root.name = "ValidationMain"
	get_root().add_child(root)

	var navigation_region := root.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	_assert(navigation_region != null, "Main scene has NavigationRegion2D.")
	_assert(navigation_region.has_method("rebuild_navigation_polygon"), "NavigationRegion2D uses tilemap builder.")
	for _i in range(8):
		await process_frame
		if navigation_region.navigation_polygon != null and navigation_region.navigation_polygon.get_polygon_count() > 0:
			break

	var navigation_polygon := navigation_region.navigation_polygon
	_assert(navigation_polygon != null, "Navigation polygon is generated.")
	_assert(navigation_polygon.get_polygon_count() > 0, "Navigation polygon contains walkable cells.")
	var bounds := Rect2()
	for vertex in navigation_polygon.vertices:
		if bounds == Rect2():
			bounds = Rect2(vertex, Vector2.ZERO)
		else:
			bounds = bounds.expand(vertex)
	print("nav_bounds=", bounds, " polygons=", navigation_polygon.get_polygon_count())
	for _i in range(4):
		await physics_frame

	var water_layer := root.get_node_or_null("TerrainLayer/WaterLayer") as TileMapLayer
	_assert(water_layer != null, "Main scene has TerrainLayer/WaterLayer.")
	_assert(water_layer.get_used_cells().size() > 0, "WaterLayer has blocking cells.")

	var player := root.get_node_or_null("WorldActors/Player")
	_assert(player != null, "Player is under WorldActors.")

	var axe := root.get_node_or_null("WorldActors/EnemyZombieAxe")
	_assert(axe != null, "Axe enemy is under WorldActors.")
	_assert(bool(axe.get("use_navigation_agent")), "Axe enemy uses NavigationAgent2D.")

	var agent := axe.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	_assert(agent != null, "Axe enemy has NavigationAgent2D.")
	var navigation_map: RID = root.get_world_2d().navigation_map
	print("agent_map=", agent.get_navigation_map(), " world_map=", navigation_map)
	for _i in range(8):
		await physics_frame
		if NavigationServer2D.map_get_iteration_id(navigation_map) > 0:
			break
	_assert(NavigationServer2D.map_get_iteration_id(navigation_map) > 0, "Navigation map has synchronized.")
	var axe_closest := NavigationServer2D.map_get_closest_point(navigation_map, axe.global_position)
	var player_closest := NavigationServer2D.map_get_closest_point(navigation_map, player.global_position)
	var path := NavigationServer2D.map_get_path(navigation_map, axe.global_position, player.global_position, true)
	print("player_position=", player.global_position, " axe_position=", axe.global_position)
	print("axe_closest=", axe_closest, " player_closest=", player_closest)
	print("axe_distance=", axe.global_position.distance_to(axe_closest), " player_distance=", player.global_position.distance_to(player_closest), " path_size=", path.size())
	_assert(axe.global_position.distance_to(axe_closest) <= 16.0, "Axe starts near the navigation map.")
	_assert(player.global_position.distance_to(player_closest) <= 16.0, "Player starts near the navigation map.")
	_assert(path.size() >= 2, "Navigation path from Axe to Player can be generated.")

	if _failed:
		return
	print("validate_main_tilemap_navigation: OK")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition or _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
