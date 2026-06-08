# Terrain Random Demo

场景：`res://scenes/terrain_random_demo.tscn`

脚本：`res://scripts/terrain_random_demo.gd`

## 作用

这个场景使用 `res://resources/tiles/background_bleak_yellow_tileset.tres` 中已经设置好的 `Terrain Set 0 / Terrain 0`，随机生成一片地形。

核心调用：

```gdscript
terrain_layer.set_cells_terrain_connect(terrain_cells, 0, 0, false)
```

含义：

- `terrain_cells`：随机生成的地图格子集合。
- 第一个 `0`：Terrain Set 0。
- 第二个 `0`：Terrain 0。
- `false`：不要忽略空地形，让边界能根据空邻居自动选择边缘瓦块。

## 生成方式

- 先生成几个大块 blob。
- 再用一条弯曲路径把区域连接起来。
- 再加入几个随机小块。
- 最后随机咬掉一些边缘，让轮廓不那么方。

真正选哪个瓦块由 Godot 的 Terrain peering bits 决定，不是脚本手动指定 atlas 坐标。
