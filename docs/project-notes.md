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

## Time Of Day TileSet Switching

Scene:

- `res://scenes/myScene.tscn`

Script:

- `res://scripts/time_of_day_tileset_switcher.gd`

Buttons:

- `早`: `res://resources/tiles/background_dark_green_tileset.tres`
- `中`: `res://resources/tiles/background_green_tileset.tres`
- `晚`: `res://resources/tiles/background_bleak_yellow_tileset.tres`

Default time is `晚`.

The script recursively finds all `TileMapLayer` nodes under the current scene and replaces their `tile_set`.
Because the three TileSets share the same atlas layout and Terrain peering bits, existing `tile_map_data` does not need to be repainted.

## Terrain Random Demo

Scene:

- `res://scenes/terrain_random_demo.tscn`

Script:

- `res://scripts/terrain_random_demo.gd`

The scene uses `res://resources/tiles/background_bleak_yellow_tileset.tres` with `Terrain Set 0 / Terrain 0` to generate random terrain.

Core call:

```gdscript
terrain_layer.set_cells_terrain_connect(terrain_cells, 0, 0, false)
```

Meaning:

- `terrain_cells`: generated map cell collection.
- First `0`: Terrain Set 0.
- Second `0`: Terrain 0.
- `false`: do not ignore empty terrain, so borders can choose edge tiles based on empty neighbors.

Generation method:

- Generate several large blobs.
- Connect regions with a curved path.
- Add a few random small blobs.
- Randomly cut some edge cells to avoid a square outline.

The final tile choice is made by Godot Terrain peering bits, not by manually assigning atlas coordinates in script.
