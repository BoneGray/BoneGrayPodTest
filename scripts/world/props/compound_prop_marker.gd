@tool
extends Marker2D
class_name CompoundPropMarker

## 复合物体定义资源，用来告诉生成器要从源资源生成哪些分层部件。
@export var prop_definition: Resource

## 生成节点使用的稳定名称前缀；留空时使用 marker 节点名称。
@export var generated_name_prefix: String = ""

## 是否在编辑器中显示仅用于摆放参考的预览图，运行时不会参与正式层级。
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

	var scene_root := _find_scene_root()
	if scene_root == null:
		push_warning("%s could not find scene root for compound prop generation." % name)
		return

	var prefix := get_generated_prefix()
	var source_scene := prop_definition.get("source_scene") as PackedScene
	if source_scene == null:
		push_warning("%s has no source scene for compound prop generation." % name)
		return
	_generate_from_source_scene(scene_root, source_scene, prefix)


func _find_scene_root() -> Node:
	var scene_root: Node = self
	while scene_root.get_parent() != null and scene_root.get_parent() != get_tree().root:
		scene_root = scene_root.get_parent()
	if scene_root != self:
		return scene_root

	if get_tree().current_scene != null:
		return get_tree().current_scene
	if get_tree().root.get_child_count() > 0:
		return get_tree().root.get_child(0)
	return null


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
	var sort_actor_part := _create_source_part(
		scene_root,
		source.get_node_or_null("Trunk"),
		prop_definition.get("sort_actor_parent_path") as NodePath,
		prefix + str(prop_definition.get("sort_actor_name_suffix"))
	)
	var overlay_part := _create_source_part(
		scene_root,
		source.get_node_or_null("Canopy"),
		prop_definition.get("overlay_parent_path") as NodePath,
		prefix + str(prop_definition.get("overlay_name_suffix"))
	)
	var occlusion_part := _create_optional_source_part(
		scene_root,
		source.get_node_or_null("OcclusionFadeArea"),
		prop_definition.get("overlay_parent_path") as NodePath,
		prefix + str(prop_definition.get("occlusion_area_name_suffix"))
	)
	_link_overlay_occlusion_targets(overlay_part, sort_actor_part, occlusion_part)
	source.queue_free()


func _create_source_part(scene_root: Node, source_node: Node, parent_path: NodePath, generated_name: String) -> Node2D:
	if source_node == null:
		push_warning("%s source scene is missing %s." % [name, generated_name])
		return null

	var parent := scene_root.get_node_or_null(parent_path) as Node2D
	if parent == null:
		push_warning("%s could not find compound prop target layer %s." % [name, parent_path])
		return null

	var old_node := parent.get_node_or_null(generated_name)
	if old_node != null:
		parent.remove_child(old_node)
		old_node.queue_free()

	var part := source_node.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as Node2D
	if part == null:
		push_warning("%s source part %s did not duplicate as Node2D." % [name, generated_name])
		return null

	part.name = generated_name
	part.z_index = 0
	parent.add_child(part)
	part.global_transform = global_transform * (source_node as Node2D).transform
	return part


func _create_optional_source_part(scene_root: Node, source_node: Node, parent_path: NodePath, generated_name: String) -> Node2D:
	if source_node == null:
		return null
	return _create_source_part(scene_root, source_node, parent_path, generated_name)


func _link_overlay_occlusion_targets(overlay_part: Node2D, sort_actor_part: Node2D, occlusion_part: Node2D) -> void:
	if overlay_part == null:
		return

	var areas: Array[OcclusionFadeArea] = []
	if occlusion_part != null:
		areas.append_array(_find_occlusion_fade_areas(occlusion_part))
	else:
		areas.append_array(_find_occlusion_fade_areas(overlay_part))

	for area in areas:
		area.add_fade_target(overlay_part, float(prop_definition.get("overlay_faded_alpha")))
		if sort_actor_part != null and bool(prop_definition.get("fade_sort_actor_sprite_with_overlay")):
			var sort_actor_sprite := sort_actor_part.get_node_or_null("Sprite") as CanvasItem
			if sort_actor_sprite != null:
				var faded_alpha := float(prop_definition.get("sort_actor_sprite_faded_alpha"))
				area.add_fade_target(sort_actor_sprite, faded_alpha)


func _find_occlusion_fade_areas(root: Node) -> Array[OcclusionFadeArea]:
	var results: Array[OcclusionFadeArea] = []
	if root is OcclusionFadeArea:
		results.append(root)
	for child in root.get_children():
		results.append_array(_find_occlusion_fade_areas(child))
	return results
