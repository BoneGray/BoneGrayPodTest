extends Resource
class_name CompoundPropDefinition

## Stable identifier for this compound prop type, such as "tree_yellow".
@export var prop_id: String = ""

## Complete source prefab used as the source of truth for editor preview and runtime layer generation.
@export var source_scene: PackedScene

## Scene-root relative path where the shadow part should be generated.
@export var shadow_parent_path: NodePath = ^"ShadowLayer"

## Scene-root relative path where the YSort actor part should be generated.
@export var sort_actor_parent_path: NodePath = ^"WorldActors"

## Scene-root relative path where the high overlay part should be generated.
@export var overlay_parent_path: NodePath = ^"HighOverlay"

## Name suffix appended to the marker name for the generated shadow node.
@export var shadow_name_suffix: String = "Shadow"

## Name suffix appended to the marker name for the generated YSort actor node.
@export var sort_actor_name_suffix: String = "Trunk"

## Name suffix appended to the marker name for the generated high overlay node.
@export var overlay_name_suffix: String = "Canopy"
