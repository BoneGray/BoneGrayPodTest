# GameZombieWorld Project Setup

Godot project root: `F:\GameDev\GameZombieWorld`

## Imported Art

The source art library is outside the Godot project:

- `F:\GameDev\ArtResource`

The first background TileSet has been copied into the project asset hierarchy:

- Source: `F:\GameDev\ArtResource\Tiles\Background_Bleak-Yellow_TileSet.png`
- Project asset: `res://assets/world/tiles/background/background_bleak_yellow_tileset.png`

## Project Folders

- `assets/`: runtime art, audio, and other imported assets.
- `assets/world/tiles/background/`: background terrain TileSet textures.
- `scenes/`: Godot scenes.
- `scripts/`: GDScript files.
- `resources/tiles/`: generated Godot TileSet resources.
- `resources/tile_rules/`: tile placement rule files.
- `docs/`: project notes and asset records.

## Current Main Scene

`res://scenes/tileset_preview.tscn` previews the copied `Background_Bleak-Yellow_TileSet` texture.
