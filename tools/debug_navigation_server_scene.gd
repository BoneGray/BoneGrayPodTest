extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/navigation_obstacle_test_scene.tscn") as PackedScene
	var root := scene.instantiate()
	get_root().add_child(root)
	for _i in range(8):
		await physics_frame
	var navigation_map: RID = root.get_world_2d().navigation_map
	var from := Vector2(80, 80)
	var to := Vector2(360, 260)
	print("iteration=", NavigationServer2D.map_get_iteration_id(navigation_map))
	print("closest_from=", NavigationServer2D.map_get_closest_point(navigation_map, from))
	print("closest_to=", NavigationServer2D.map_get_closest_point(navigation_map, to))
	print("path_size=", NavigationServer2D.map_get_path(navigation_map, from, to, true).size())
	quit(0)
