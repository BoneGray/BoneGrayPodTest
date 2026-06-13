extends "res://scripts/items/item_data.gd"
class_name WeaponData

@export_group("Identity")
## Stable weapon id used by weapon-specific gameplay, save migration, and debug lookup.
@export var weapon_id := ""
## Weapon category. Melee and firearm currently share pickup/equipment flow but use different attack profiles.
@export_enum("melee", "firearm") var weapon_type := "melee"

@export_group("Visual")
## SpriteFrames used by the player's hand/equipment layer after this weapon is equipped.
@export var visual_sprite_frames: SpriteFrames
## Equipment visual offset when the character faces down.
@export var visual_offset_down := Vector2.ZERO
## Equipment visual offset when the character faces up.
@export var visual_offset_up := Vector2.ZERO
## Equipment visual offset when the character faces right.
@export var visual_offset_side := Vector2.ZERO
## Equipment visual offset when the character faces left.
@export var visual_offset_side_left := Vector2.ZERO
## Extra per-animation equipment offsets. Keys use full animation names such as idle_down or attack_side_first.
@export var animation_visual_offsets := {}

@export_group("Attack")
## Primary attack profile, usually triggered by J.
@export var primary_attack_profile: Resource
## Secondary attack profile reserved for future weapon-specific actions.
@export var secondary_attack_profile: Resource

@export_group("Firearm")
## Number of shots available before a firearm must reload. Values of 0 or less mean the weapon does not use a magazine.
@export var magazine_size := 0
## Whether pressing attack with an empty magazine should start reloading automatically.
@export var auto_reload_when_empty := true
## Whether the player can move while this firearm is reloading.
@export var can_move_while_reloading := true
## Movement speed multiplier while this firearm reloads.
@export_range(0.0, 1.0, 0.05) var reload_move_speed_multiplier := 0.45
