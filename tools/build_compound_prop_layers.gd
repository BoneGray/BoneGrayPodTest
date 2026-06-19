extends SceneTree

const SCENE_PATH := "res://scenes/Main.tscn"
const CompoundPropMarkerScript := preload("res://scripts/world/props/compound_prop_marker.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	_assert(scene != null, "Compound prop builder could not load target scene.")
	if _failed:
		return

	var root := scene.instantiate()
	root.name = "CompoundPropBuildRoot"
	get_root().add_child(root)
	await process_frame

	var markers: Array[Node] = []
	_collect_markers(root, markers)
	_assert(not markers.is_empty(), "No CompoundPropMarker nodes found in target scene.")
	if _failed:
		root.queue_free()
		return

	for marker_node in markers:
		_build_marker(root, marker_node as Node2D)
		if _failed:
			root.queue_free()
			return

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	_assert(pack_result == OK, "Compound prop builder could not pack target scene.")
	if _failed:
		root.queue_free()
		return

	var save_result := ResourceSaver.save(packed, SCENE_PATH)
	_assert(save_result == OK, "Compound prop builder could not save target scene.")
	if _failed:
		root.queue_free()
		return

	root.queue_free()
	print("build_compound_prop_layers: generated %d compound prop placement(s)." % markers.size())
	quit(0)


func _collect_markers(node: Node, markers: Array[Node]) -> void:
	if node.get_script() == CompoundPropMarkerScript:
		markers.append(node)
	for child in node.get_children():
		_collect_markers(child, markers)


func _build_marker(root: Node, marker: Node2D) -> void:
	var definition := marker.get("prop_definition") as Resource
	_assert(definition != null, "%s has no CompoundPropDefinition." % marker.name)
	if _failed:
		return

	var prefix := str(marker.call("get_generated_prefix"))
	var source_scene := definition.get("source_scene") as PackedScene
	_assert(source_scene != null, "%s has no source scene." % marker.name)
	if _failed:
		return
	_build_from_source(root, marker, definition, source_scene, prefix)


func _build_from_source(root: Node, marker: Node2D, definition: Resource, source_scene: PackedScene, prefix: String) -> void:
	var source := source_scene.instantiate() as Node2D
	_assert(source != null, "%s source scene should instantiate as Node2D." % marker.name)
	if _failed:
		return
	_create_source_part(root, marker, source.get_node_or_null("Shadow"), definition.get("shadow_parent_path") as NodePath, prefix + str(definition.get("shadow_name_suffix")))
	_create_source_part(root, marker, source.get_node_or_null("Trunk"), definition.get("sort_actor_parent_path") as NodePath, prefix + str(definition.get("sort_actor_name_suffix")))
	_create_source_part(root, marker, source.get_node_or_null("Canopy"), definition.get("overlay_parent_path") as NodePath, prefix + str(definition.get("overlay_name_suffix")))
	source.queue_free()


func _create_source_part(root: Node, marker: Node2D, source_node: Node, parent_path: NodePath, generated_name: String) -> void:
	_assert(source_node != null, "%s source scene is missing %s." % [marker.name, generated_name])
	if _failed:
		return
	var parent := root.get_node_or_null(parent_path) as Node2D
	_assert(parent != null, "Target layer %s does not exist for %s." % [parent_path, generated_name])
	if _failed:
		return

	var old_node := parent.get_node_or_null(generated_name)
	if old_node != null:
		parent.remove_child(old_node)
		old_node.queue_free()

	var part := source_node.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as Node2D
	_assert(part != null, "%s should instantiate as Node2D." % generated_name)
	if _failed:
		return

	part.name = generated_name
	part.z_index = 0
	parent.add_child(part)
	part.owner = root
	part.global_transform = marker.global_transform * (source_node as Node2D).transform
	_assign_owner_recursive(part, root)


func _assign_owner_recursive(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_assign_owner_recursive(child, owner_node)


func _assert(condition: bool, message: String) -> void:
	if condition or _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
