@tool
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const TREE_SOURCE_PATH := "res://scenes/world/props/trees/tree_yellow_split.tscn"
const TREE_MARKER_PATH := "res://scenes/world/props/trees/tree_yellow_placement_marker.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _validate_tree_source_prefab():
		return
	if not _validate_tree_marker():
		return
	if not _validate_main_tree_marker_layer():
		return

	print("Compound prop source marker flow is valid.")
	quit()


func _validate_tree_source_prefab() -> bool:
	var scene := load(TREE_SOURCE_PATH) as PackedScene
	if scene == null:
		return _fail("Could not load tree source prefab.")

	var tree := scene.instantiate() as Node2D
	if tree == null:
		return _fail("Tree source prefab should instantiate as Node2D.")
	if tree.get_script() != null:
		tree.queue_free()
		return _fail("Tree source prefab should not use a script to reparent layer nodes.")

	for node_path in ["Shadow", "Trunk", "Trunk/Sprite", "Trunk/CollisionShape2D", "Canopy"]:
		if tree.get_node_or_null(node_path) == null:
			tree.queue_free()
			return _fail("Tree source prefab should expose %s." % node_path)

	tree.queue_free()
	return true


func _validate_tree_marker() -> bool:
	var marker := _instantiate(TREE_MARKER_PATH)
	if marker == null:
		return false
	if marker.get_node_or_null("Preview") == null:
		marker.queue_free()
		return _fail("Tree marker should expose editor Preview.")
	var definition := marker.get("prop_definition") as Resource
	if definition == null or definition.get("source_scene") == null:
		marker.queue_free()
		return _fail("Tree marker should reference a definition with source_scene.")
	marker.queue_free()
	return true


func _validate_main_tree_marker_layer() -> bool:
	var scene := load(MAIN_SCENE_PATH) as PackedScene
	if scene == null:
		return _fail("Could not load Main scene.")

	var root := scene.instantiate()
	get_root().add_child(root)

	var shadow_layer := root.get_node_or_null("ShadowLayer/TreeShadowLayer")
	var world_actors := root.get_node_or_null("WorldActors")
	var canopy_layer := root.get_node_or_null("HighOverlay/TreeCanopyLayer")
	if shadow_layer == null or world_actors == null or canopy_layer == null:
		root.queue_free()
		return _fail("Main should expose TreeShadowLayer, WorldActors, and TreeCanopyLayer.")

	var marker_layer := root.get_node_or_null("CompoundPropMarkers")
	if marker_layer == null:
		root.queue_free()
		return _fail("Main should expose CompoundPropMarkers.")
	if world_actors.get_node_or_null("TreeYellowSplit") != null:
		root.queue_free()
		return _fail("Main should not place whole tree source prefabs directly under WorldActors.")

	root.queue_free()
	return true


func _instantiate(scene_path: String) -> Node:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		_fail("Could not load %s." % scene_path)
		return null
	return scene.instantiate()


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
