extends Node2D

const DEFAULT_TILESET_PATH := "res://resources/tiles/background_bleak_yellow_tileset.tres"
const MAP_WIDTH := 96
const MAP_HEIGHT := 64
const TERRAIN_SET := 0
const TERRAIN_ID := 0

@export_group("TileSet")
## 用于随机生成地板的 TileSet 资源，要求已配置 Terrain Set 0 / Terrain 0。
@export_file("*.tres") var tileset_path := DEFAULT_TILESET_PATH

@export_group("Generation")
## 随机种子。为 0 时使用当前时间；填写固定值可以复现同一张地图。
@export var random_seed := 0
## 生成地图的整体格子偏移，用于让随机地板区域居中显示。
@export var map_offset := Vector2i(-48, -32)

var rng := RandomNumberGenerator.new()
var floor_layer: TileMapLayer


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.06, 0.06))
	rng.seed = random_seed if random_seed != 0 else Time.get_unix_time_from_system()
	_create_floor_layer()
	_generate_floor()


func _create_floor_layer() -> void:
	floor_layer = TileMapLayer.new()
	floor_layer.name = "FloorOnlyRandom"
	floor_layer.tile_set = load(tileset_path)
	add_child(floor_layer)


func _generate_floor() -> void:
	var cells := _generate_floor_cells()
	floor_layer.set_cells_terrain_connect(cells, TERRAIN_SET, TERRAIN_ID, false)


func _generate_floor_cells() -> Array[Vector2i]:
	var cells: Dictionary = {}

	_add_blob(cells, Vector2i(36, 30), 24, 15)
	_add_blob(cells, Vector2i(58, 28), 18, 13)
	_add_blob(cells, Vector2i(50, 42), 30, 10)
	_add_path(cells, Vector2i(10, 45), Vector2i(86, 20), 5)
	_add_path(cells, Vector2i(18, 18), Vector2i(78, 50), 4)

	for i in 12:
		var center := Vector2i(rng.randi_range(10, MAP_WIDTH - 10), rng.randi_range(8, MAP_HEIGHT - 8))
		_add_blob(cells, center, rng.randi_range(5, 11), rng.randi_range(3, 8))

	_remove_edge_bites(cells, 46)

	var result: Array[Vector2i] = []
	for cell: Vector2i in cells.keys():
		if _in_bounds(cell):
			result.append(cell + map_offset)
	return result


func _add_blob(cells: Dictionary, center: Vector2i, radius_x: int, radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell):
				continue

			var normalized := Vector2(
				float(x - center.x) / float(maxi(radius_x, 1)),
				float(y - center.y) / float(maxi(radius_y, 1))
			)
			var edge_noise := rng.randf_range(-0.16, 0.16)
			if normalized.length() <= 1.0 + edge_noise:
				cells[cell] = true


func _add_path(cells: Dictionary, start: Vector2i, end: Vector2i, radius: int) -> void:
	var from := Vector2(start)
	var to := Vector2(end)
	var steps := int(from.distance_to(to) * 2.0)
	for i in range(steps + 1):
		var t := float(i) / float(maxi(steps, 1))
		var point := from.lerp(to, t)
		point.y += sin(t * TAU * 1.7) * 4.0
		point.x += cos(t * TAU * 1.2) * 3.0

		for y in range(int(point.y) - radius, int(point.y) + radius + 1):
			for x in range(int(point.x) - radius, int(point.x) + radius + 1):
				var cell := Vector2i(x, y)
				if _in_bounds(cell) and Vector2(x - point.x, y - point.y).length() <= radius:
					cells[cell] = true


func _remove_edge_bites(cells: Dictionary, count: int) -> void:
	var edge_cells: Array[Vector2i] = []
	for cell: Vector2i in cells.keys():
		if _is_edge_cell(cells, cell):
			edge_cells.append(cell)
	if edge_cells.is_empty():
		return

	for i in count:
		var bite_center := edge_cells[rng.randi_range(0, edge_cells.size() - 1)]
		var radius := rng.randi_range(1, 3)
		for y in range(bite_center.y - radius, bite_center.y + radius + 1):
			for x in range(bite_center.x - radius, bite_center.x + radius + 1):
				var cell := Vector2i(x, y)
				if cells.has(cell) and Vector2(x - bite_center.x, y - bite_center.y).length() <= radius:
					cells.erase(cell)


func _is_edge_cell(cells: Dictionary, cell: Vector2i) -> bool:
	for neighbor in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not cells.has(cell + neighbor):
			return true
	return false


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_WIDTH and cell.y < MAP_HEIGHT
