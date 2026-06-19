extends Resource
class_name CompoundPropDefinition

## 复合物体类型的稳定标识，例如 "tree_yellow"。
@export var prop_id: String = ""

## 完整源场景，用作编辑器预览和运行时分层生成的唯一来源。
@export var source_scene: PackedScene

## 阴影部分生成到的场景根节点相对路径。
@export var shadow_parent_path: NodePath = ^"ShadowLayer"

## 参与 YSort 的主体部分生成到的场景根节点相对路径。
@export var sort_actor_parent_path: NodePath = ^"WorldActors"

## 高层覆盖部分生成到的场景根节点相对路径。
@export var overlay_parent_path: NodePath = ^"HighOverlay"

## 生成阴影节点时追加到 marker 名称后的后缀。
@export var shadow_name_suffix: String = "Shadow"

## 生成 YSort 主体节点时追加到 marker 名称后的后缀。
@export var sort_actor_name_suffix: String = "Trunk"

## 生成高层覆盖节点时追加到 marker 名称后的后缀。
@export var overlay_name_suffix: String = "Canopy"

## 生成遮挡淡化区域节点时追加到 marker 名称后的后缀。
@export var occlusion_area_name_suffix: String = "OcclusionFadeArea"

## 遮挡区域生效时，高层覆盖视觉节点淡化到的透明度。
@export_range(0.0, 1.0, 0.01) var overlay_faded_alpha := 0.45

## 高层遮挡区域生效时，是否同时淡化生成的 YSort 主体 Sprite。
@export var fade_sort_actor_sprite_with_overlay := false

## 遮挡区域生效时，生成的 YSort 主体 Sprite 淡化到的透明度。
@export_range(0.0, 1.0, 0.01) var sort_actor_sprite_faded_alpha := 0.72
