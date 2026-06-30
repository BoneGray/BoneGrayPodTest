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
	current_scene = root

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

	var water_layer := root.get_node_or_null("TerrainLayer/GroundTileLayer/fmWaterGroundLayer") as TileMapLayer
	_assert(water_layer != null, "Main scene has TerrainLayer/GroundTileLayer/fmWaterGroundLayer.")
	_assert(water_layer.get_used_cells().size() > 0, "WaterLayer has blocking cells.")

	var player := root.get_node_or_null("WorldActors/Player")
	_assert(player != null, "Player is under WorldActors.")
	print("player_position=", player.global_position)
	_assert(bounds.has_point(player.global_position), "Navigation polygon bounds include Player.")

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
