# Background TileSet Variants

三张背景 TileSet 使用同一套 atlas 布局和 Terrain 规则，只是颜色不同。

## Project Assets

- `res://assets/world/tiles/background/background_bleak_yellow_tileset.png`
- `res://assets/world/tiles/background/background_dark_green_tileset.png`
- `res://assets/world/tiles/background/background_green_tileset.png`

## Godot TileSet Resources

- `res://resources/tiles/background_bleak_yellow_tileset.tres`
- `res://resources/tiles/background_dark_green_tileset.tres`
- `res://resources/tiles/background_green_tileset.tres`

## Rule Source

`background_dark_green_tileset.tres` and `background_green_tileset.tres` were generated from `background_bleak_yellow_tileset.tres`.

They keep the same:

- atlas tile coordinates
- `Terrain Set 0`
- `Terrain 0`
- peering bits

Only the texture reference changes.

