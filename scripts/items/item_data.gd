extends Resource
class_name ItemData

@export_group("Identity")
## Stable item id used by save data, inventory, debug logs, and gameplay lookup.
@export var item_id := ""
## User-facing display name used by UI, debug panels, and logs.
@export var display_name := "Item"
## High-level item category used by pickup and inventory routing.
@export_enum("weapon", "tool", "consumable", "material", "quest", "ammo") var item_type := "weapon"

@export_group("Visual")
## Texture shown when the item is placed in the world.
@export var world_texture: Texture2D
## Texture used in inventory, HUD, or pickup prompts.
@export var icon_texture: Texture2D

@export_group("Pickup")
## Scene instantiated when the item is dropped or spawned as a world pickup.
@export_file("*.tscn") var pickup_scene_path := ""
## Whether multiple copies of this item can share one inventory slot.
@export var stackable := false
## Maximum stack count when stackable is enabled.
@export var max_stack := 1
