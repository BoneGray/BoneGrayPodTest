# Project Notes

This document keeps compact project records that are useful but not broad development rules.
Use `docs/development-guidelines.md` for workflow rules and `docs/gameplay-design.md` for gameplay decisions.

## Project Setup

Godot project root:

- `F:\GameDev\GameZombieWorld`

Source art library outside the Godot project:

- `F:\GameDev\ArtResource`

Common project folders:

- `assets/`: runtime art, audio, and imported assets.
- `assets/world/tiles/background/`: background terrain TileSet textures.
- `scenes/`: Godot scenes.
- `scripts/`: GDScript files.
- `resources/`: generated Godot resources.
- `resources/tiles/`: generated Godot TileSet resources.
- `resources/tile_rules/`: tile placement rule files.
- `docs/`: project notes, design notes, and development rules.
- `tools/`: local generation and validation scripts.

Asset import note:

- Source art outside the Godot project may keep vendor naming.
- Runtime assets copied into `assets/` should follow the naming rules in `docs/development-guidelines.md`.
- For animated sprite sheets, prefer file names like `zombie_big_attack_down_second_sheet15.png`.
- Generated Godot animation names should remove the object prefix and use names like `attack_down_second`.
- For terrain, buildings, props, UI, and effects, use the general image naming format from `docs/development-guidelines.md`.
- New small runtime PNGs should be evaluated for an existing atlas before being referenced directly.

## Current Pickup Atlas

Ground pickup weapon icons currently use an append-only atlas.

Atlas files:

- `res://assets/equipment/pickups/pickup_items_atlas.png`
- `res://assets/equipment/pickups/pickup_items_atlas_manifest.json`

AtlasTexture resources:

- `res://resources/equipment/pickups/baseball_bat_world_texture.tres`
- `res://resources/equipment/pickups/gun_world_texture.tres`
- `res://resources/equipment/pickups/pistol_world_texture.tres`
- `res://resources/equipment/pickups/shotgun_world_texture.tres`

Rules:

- Existing atlas regions are stable and should not be repacked.
- New pickup PNGs, such as food, bandages, or ammo, should be appended to the current atlas unless a new category atlas is intentionally created.
- `WeaponData.world_texture`, `ItemData.world_texture`, and pickup scenes should reference the `.tres` AtlasTexture resources, not the old scattered PNGs.

## Background TileSet Variants

Three background TileSets use the same atlas layout and Terrain rules. They only differ by color.

Project assets:

- `res://assets/world/tiles/background/tileset_terrain_background_bleak_yellow_tile16.png`
- `res://assets/world/tiles/background/tileset_terrain_background_dark_green_tile16.png`
- `res://assets/world/tiles/background/tileset_terrain_background_green_tile16.png`

Godot TileSet resources:

- `res://resources/tiles/background_bleak_yellow_tileset.tres`
- `res://resources/tiles/background_dark_green_tileset.tres`
- `res://resources/tiles/background_green_tileset.tres`

Rule source:

- `background_dark_green_tileset.tres` and `background_green_tileset.tres` were generated from `background_bleak_yellow_tileset.tres`.
- They keep the same atlas tile coordinates, `Terrain Set 0`, `Terrain 0`, and peering bits.
- Only the texture reference changes.

## Forgotten Memories TileSets

Imported terrain experiment assets:

- `res://assets/world/tiles/forgotten_memories/tileset_environment_forgotten_memories.png`
- `res://assets/world/tiles/forgotten_memories/tileset_water_forgotten_memories_sheet6.png`

Generated TileSet resources:

- `res://resources/tiles/forgotten_memories_water_tileset.tres`

Water animation rules:

- Tile size is `32x32`.
- Keep this water source at native size; direct downscaling to `16x16` makes the water detail noisy.
- Water tiles use 6 horizontal frames.
- Animation starts are placed at atlas columns `0, 6, 12, 18, 24` where the 6-frame strip has visible pixels.
- Each frame duration is `0.16` seconds.
- Use `res://resources/tiles/forgotten_memories_water_tileset.tres` for this water layer.
- Regenerate with `res://tools/create_forgotten_memories_water_tileset.gd` when the water sheet changes.

Navigation rule:

- TileMap layers that represent blocking terrain, such as rivers, pits, lava, or other impassable ground, must also feed a `NavigationRegion2D`.
- Use `res://scripts/world/tilemap_navigation_region_builder.gd` when the blocking information can come from a `TileMapLayer`.
- The builder reads TileSet physics collision by default, so decorative or shoreline cells without physics collision can remain walkable.
- Only disable `use_tile_physics_as_blockers` when the whole configured `TileMapLayer` is intentionally a pure blocker layer.
- Tune `margin_cells` per scene to decide how far around the blocking TileMap enemies can pathfind.
- Tune `blocker_padding_cells` when enemies move too close to the edge of water, walls, or other blocking terrain.

## Current Gameplay Test Scene

Current maintained gameplay scene:

- `res://scenes/navigation_obstacle_test_scene.tscn`

Scene generator:

- `res://tools/create_navigation_obstacle_test_scene.gd`

Validation:

- `res://tools/validate_navigation_obstacle_test_scene.gd`
- `res://tools/validate_render_layer_baseline.gd`
- `res://tools/validate_navigation_obstacle_big_attacks.gd`

Rules:

- The scene uses `TerrainLayer`, `WorldActors`, `WorldEffects`, and `HighOverlay`.
- Player, Big, Small, Axe, pickups, and obstacle bodies live under `WorldActors` so they follow the current YSort layer rules.
- Deleted legacy scenes such as `myScene`, `combat_test_scene`, `terrain_random_demo`, and `floor_only_random_map` are not maintained.
- Do not restore old root-level YSort test scenes; rebuild old experiments inside the current scene structure if the feature returns.

## Archived Prototypes

Earlier time-of-day TileSet switching and random terrain demos were removed with their old scenes. They are kept here only as history:

- Time-of-day switching should be rebuilt inside the current maintained scene structure if needed.
- Terrain random demos should use the current `TerrainLayer / WorldActors / WorldEffects / HighOverlay` structure if needed.
