extends Node2D

const TILESET_PATH := "res://resources/tiles/background_bleak_yellow_tileset.tres"
const MAP_WIDTH := 80
const MAP_HEIGHT := 48
const TERRAIN_SET := 0
const TERRAIN_ID := 0

var rng := RandomNumberGenerator.new()
var terrain_layer: TileMapLayer

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.04))
	rng.seed = Time.get_unix_time_from_system()

	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain0Random"
	terrain_layer.tile_set = load(TILESET_PATH)
	add_child(terrain_layer)

	var terrain_cells := _generate_terrain_cells()
	terrain_layer.set_cells_terrain_connect(terrain_cells, TERRAIN_SET, TERRAIN_ID, false)

func _generate_terrain_cells() -> Array[Vector2i]:
	var cells: Dictionary = {}

	_add_blob(cells, Vector2i(20, 18), 13, 8)
	_add_blob(cells, Vector2i(36, 20), 11, 7)
	_add_blob(cells, Vector2i(50, 15), 9, 6)
	_add_blob(cells, Vector2i(43, 29), 14, 6)
	_add_path(cells, Vector2i(9, 31), Vector2i(66, 19), 3)

	for i in 8:
		var center := Vector2i(rng.randi_range(8, MAP_WIDTH - 8), rng.randi_range(6, MAP_HEIGHT - 8))
		_add_blob(cells, center, rng.randi_range(3, 7), rng.randi_range(2, 5))

	_remove_random_bites(cells, 34)

	var result: Array[Vector2i] = []
	for cell in cells.keys():
		if _in_bounds(cell):
			result.append(cell)
	return result

func _add_blob(cells: Dictionary, center: Vector2i, radius_x: int, radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell):
				continue

			var n := Vector2(
				float(x - center.x) / float(max(radius_x, 1)),
				float(y - center.y) / float(max(radius_y, 1))
			)
			var rough_edge := rng.randf_range(-0.18, 0.18)
			if n.length() <= 1.0 + rough_edge:
				cells[cell] = true

func _add_path(cells: Dictionary, start: Vector2i, end: Vector2i, radius: int) -> void:
	var from := Vector2(start)
	var to := Vector2(end)
	var steps := int(from.distance_to(to) * 2.0)
	for i in range(steps + 1):
		var t := float(i) / float(max(steps, 1))
		var point := from.lerp(to, t)
		point.y += sin(t * TAU * 2.0) * 5.0

		for y in range(int(point.y) - radius, int(point.y) + radius + 1):
			for x in range(int(point.x) - radius, int(point.x) + radius + 1):
				var cell := Vector2i(x, y)
				if _in_bounds(cell) and Vector2(x - point.x, y - point.y).length() <= radius:
					cells[cell] = true

func _remove_random_bites(cells: Dictionary, count: int) -> void:
	var keys := cells.keys()
	if keys.is_empty():
		return

	for i in count:
		var bite_center: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var radius := rng.randi_range(1, 3)
		for y in range(bite_center.y - radius, bite_center.y + radius + 1):
			for x in range(bite_center.x - radius, bite_center.x + radius + 1):
				var cell := Vector2i(x, y)
				if cells.has(cell) and Vector2(x - bite_center.x, y - bite_center.y).length() <= radius:
					cells.erase(cell)

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_WIDTH and cell.y < MAP_HEIGHT
