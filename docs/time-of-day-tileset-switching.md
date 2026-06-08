# Time Of Day TileSet Switching

场景：`res://scenes/myScene.tscn`

脚本：`res://scripts/time_of_day_tileset_switcher.gd`

## Buttons

运行 `myScene` 后，左上角会出现三个按钮：

- `早`：`res://resources/tiles/background_dark_green_tileset.tres`
- `中`：`res://resources/tiles/background_green_tileset.tres`
- `晚`：`res://resources/tiles/background_bleak_yellow_tileset.tres`

默认时间是 `晚`。

## Implementation

脚本会递归查找当前场景下所有 `TileMapLayer`，点击按钮时只替换这些层的 `tile_set`。

因为三张 TileSet 使用同一套 atlas 布局和 Terrain peering bits，所以现有 `tile_map_data` 不需要重画。

