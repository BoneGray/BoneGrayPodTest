@tool
extends Marker2D
class_name CompoundPropMarker

## Compound prop definition that tells the builder which layer parts to generate.
@export var prop_definition: Resource

## Optional stable prefix for generated nodes. When empty, the marker node name is used.
@export var generated_name_prefix: String = ""

## Shows a visual-only preview in the editor so level layout is not blind.
@export var preview_visible: bool = true:
	set(value):
		preview_visible = value
		_sync_preview_visibility()

const PREVIEW_NODE_NAME := "Preview"


func _ready() -> void:
	if Engine.is_editor_hint():
		_sync_preview_visibility()
		return

	_generate_layer_parts()
	_remove_preview()


func get_generated_prefix() -> String:
	if generated_name_prefix.strip_edges() != "":
		return generated_name_prefix.strip_edges()
	return name


func _sync_preview_visibility() -> void:
	var preview := get_node_or_null(PREVIEW_NODE_NAME) as CanvasItem
	if preview == null:
		return
	if Engine.is_editor_hint():
		preview.visible = preview_visible
	else:
		preview.visible = false


func _remove_preview() -> void:
	var preview := get_node_or_null(PREVIEW_NODE_NAME)
	if preview != null:
		preview.queue_free()


func _generate_layer_parts() -> void:
	if prop_definition == null:
		push_warning("%s has no compound prop definition." % name)
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root.get_child(0)
	if scene_root == null:
		push_warning("%s could not find scene root for compound prop generation." % name)
		return

	var prefix := get_generated_prefix()
	var source_scene := prop_definition.get("source_scene") as PackedScene
	if source_scene == null:
		push_warning("%s has no source scene for compound prop generation." % name)
		return
	_generate_from_source_scene(scene_root, source_scene, prefix)


func _generate_from_source_scene(scene_root: Node, source_scene: PackedScene, prefix: String) -> void:
	var source := source_scene.instantiate() as Node2D
	if source == null:
		push_warning("%s source scene did not instantiate as Node2D." % name)
		return

	_create_source_part(
		scene_root,
		source.get_node_or_null("Shadow"),
		prop_definition.get("shadow_parent_path") as NodePath,
		prefix + str(prop_definition.get("shadow_name_suffix"))
	)
	_create_source_part(
		scene_root,
		source.get_node_or_null("Trunk"),
		prop_definition.get("sort_actor_parent_path") as NodePath,
		prefix + str(prop_definition.get("sort_actor_name_suffix"))
	)
	_create_source_part(
		scene_root,
		source.get_node_or_null("Canopy"),
		prop_definition.get("overlay_parent_path") as NodePath,
		prefix + str(prop_definition.get("overlay_name_suffix"))
	)
	source.queue_free()


func _create_source_part(scene_root: Node, source_node: Node, parent_path: NodePath, generated_name: String) -> void:
	if source_node == null:
		push_warning("%s source scene is missing %s." % [name, generated_name])
		return

	var parent := scene_root.get_node_or_null(parent_path) as Node2D
	if parent == null:
		push_warning("%s could not find compound prop target layer %s." % [name, parent_path])
		return

	var old_node := parent.get_node_or_null(generated_name)
	if old_node != null:
		parent.remove_child(old_node)
		old_node.queue_free()

	var part := source_node.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as Node2D
	if part == null:
		push_warning("%s source part %s did not duplicate as Node2D." % [name, generated_name])
		return

	part.name = generated_name
	part.z_index = 0
	parent.add_child(part)
	part.global_transform = global_transform * (source_node as Node2D).transform

