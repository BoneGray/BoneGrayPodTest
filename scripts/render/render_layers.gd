class_name RenderLayers
extends RefCounted

## Terrain base layer: floor, grass, road, river, and other non-YSort ground materials.
const TERRAIN_Z := -100

## World shadow layer: building, tree, cloud, and other shadows above terrain but below YSort objects.
const SHADOW_Z := -50

## World YSort layer: player, enemies, pickups, trunks, wall bodies, cars, and other ground-sorted objects.
const WORLD_Y_SORT_Z := 0

## World effects layer: flying bullets, thrown weapons, muzzle flashes, hit effects, and ejected casings.
const WORLD_EFFECTS_Z := 50

## High overlay layer: tree canopies, roofs, ceilings, sky blockers, and fixed high-cover visuals.
const HIGH_OVERLAY_Z := 100

## UI layer: health bars, buttons, inventory, debug panels, and other interface content.
const UI_Z := 1000

## Character root world sorting layer. Character roots should participate in WorldActors YSort.
const CHARACTER_ROOT_Z := 0

## Character shadow layer, below the character body while still moving with the character.
const CHARACTER_SHADOW_Z := -2

## Character back equipment layer, such as hands or weapons behind the body when facing up.
const CHARACTER_BACK_EQUIPMENT_Z := -1

## Character body baseline layer.
const CHARACTER_BODY_Z := 0

## Character front equipment layer, such as hands or weapons in front when facing down or sideways.
const CHARACTER_FRONT_EQUIPMENT_Z := 0

## Character internal attack effect layer. Do not use it to overdraw other WorldActors objects.
const CHARACTER_ATTACK_EFFECT_Z := 0

## Ground pickup root world sorting layer. Pickups should share the character root YSort baseline.
const PICKUP_ROOT_Z := 0

## Projectile visual layer while flying, usually placed under WorldEffects.
const PROJECTILE_FLYING_Z := 0

## Projectile visual layer after landing; it should move to WorldActors and restore shared YSort.
const PROJECTILE_DROPPED_Z := 0
