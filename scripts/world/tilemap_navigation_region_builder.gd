extends NavigationRegion2D
class_name TileMapNavigationRegionBuilder

## 用作导航阻挡来源的 TileMapLayer。该图层上有瓦块的位置会被视为不可走区域。
@export_node_path("TileMapLayer") var blocker_tilemap_path: NodePath

## 是否只把 TileSet 物理碰撞瓦块视为导航阻挡。开启后会忽略没有碰撞的装饰瓦块。
@export var use_tile_physics_as_blockers := true

## 每个瓦块细分成多少个导航采样格。值越大，半水半岸等局部碰撞瓦块越精准，但生成成本更高。
@export_range(1, 8, 1) var navigation_subdivisions := 4

## 在阻挡图层外额外生成多少格可走区域。值越大，敌人能在阻挡区域周围更远处寻路。
@export_range(1, 64, 1) var margin_cells := 12

## 阻挡瓦块向外膨胀的格数。用于避免角色路径贴着水边、墙边或障碍边缘走得太近。
@export_range(0, 4, 1) var blocker_padding_cells := 1

## 是否在运行时进入场景时自动重建导航多边形。地图瓦块有变化时应开启。
@export var rebuild_on_ready := true

var _pending_ready_rebuild := false


func _ready() -> void:
	if rebuild_on_ready:
		_pending_ready_rebuild = true
		set_physics_process(true)
	else:
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not _pending_ready_rebuild:
		set_physics_process(false)
		return
	_pending_ready_rebuild = false
	rebuild_navigation_polygon()
	set_physics_process(false)


func rebuild_navigation_polygon() -> void:
	var blocker_tilemap := get_node_or_null(blocker_tilemap_path) as TileMapLayer
	if blocker_tilemap == null or blocker_tilemap.tile_set == null:
		navigation_polygon = null
		return

	var tile_used_rect := blocker_tilemap.get_used_rect()
	if tile_used_rect.size == Vector2i.ZERO:
		navigation_polygon = null
		return

	var subdivision := maxi(navigation_subdivisions, 1)
	var fine_margin := margin_cells * subdivision
	var used_rect := Rect2i(
		tile_used_rect.position * subdivision - Vector2i(fine_margin, fine_margin),
		tile_used_rect.size * subdivision + Vector2i(fine_margin * 2, fine_margin * 2)
	)
	var blocked_cells := _build_blocked_fine_cells(blocker_tilemap, subdivision)
	var padded_blocked_cells := _build_padded_blocked_cells(blocked_cells)
	var generated_navigation_polygon := _build_navigation_polygon_from_blockers(
		blocker_tilemap,
		used_rect,
		padded_blocked_cells,
		subdivision
	)
	navigation_polygon = generated_navigation_polygon
	bake_navigation_polygon(false)
	enabled = false
	enabled = true
	_sync_navigation_polygon_to_server()


func _sync_navigation_polygon_to_server() -> void:
	if not is_inside_tree() or navigation_polygon == null:
		return
	var navigation_map := get_world_2d().navigation_map
	var region_rid: RID = get_region_rid()
	NavigationServer2D.region_set_map(region_rid, navigation_map)
	NavigationServer2D.region_set_transform(region_rid, global_transform)
	NavigationServer2D.region_set_navigation_polygon(region_rid, navigation_polygon)
	NavigationServer2D.region_set_enabled(region_rid, true)
	NavigationServer2D.map_force_update(navigation_map)


func _is_blocked(cell: Vector2i, blocked_cells: Dictionary) -> bool:
	var padding := blocker_padding_cells * maxi(navigation_subdivisions, 1)
	for offset_x in range(-padding, padding + 1):
		for offset_y in range(-padding, padding + 1):
			if blocked_cells.has(cell + Vector2i(offset_x, offset_y)):
				return true
	return false


func _build_padded_blocked_cells(blocked_cells: Dictionary) -> Dictionary:
	var padded_blocked_cells := {}
	for cell: Vector2i in blocked_cells.keys():
		if _is_blocked(cell, blocked_cells):
			padded_blocked_cells[cell] = true
		var padding := blocker_padding_cells * maxi(navigation_subdivisions, 1)
		for offset_x in range(-padding, padding + 1):
			for offset_y in range(-padding, padding + 1):
				padded_blocked_cells[cell + Vector2i(offset_x, offset_y)] = true
	return padded_blocked_cells


func _build_blocked_fine_cells(tilemap: TileMapLayer, subdivision: int) -> Dictionary:
	var blocked_cells := {}
	for tile_cell in tilemap.get_used_cells():
		if use_tile_physics_as_blockers:
			_add_physics_blocked_fine_cells(tilemap, tile_cell, subdivision, blocked_cells)
		else:
			_add_full_tile_blocked_fine_cells(tile_cell, subdivision, blocked_cells)
	return blocked_cells


func _add_full_tile_blocked_fine_cells(tile_cell: Vector2i, subdivision: int, blocked_cells: Dictionary) -> void:
	var fine_origin := tile_cell * subdivision
	for x in range(subdivision):
		for y in range(subdivision):
			blocked_cells[fine_origin + Vector2i(x, y)] = true


func _add_physics_blocked_fine_cells(
	tilemap: TileMapLayer,
	tile_cell: Vector2i,
	subdivision: int,
	blocked_cells: Dictionary
) -> void:
	var tile_data := tilemap.get_cell_tile_data(tile_cell)
	if tile_data == null or tilemap.tile_set.get_physics_layers_count() <= 0:
		return

	var polygon_count := tile_data.get_collision_polygons_count(0)
	if polygon_count <= 0:
		return

	var tile_size := Vector2(tilemap.tile_set.tile_size)
	var fine_origin := tile_cell * subdivision
	for x in range(subdivision):
		for y in range(subdivision):
			var sample := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(subdivision)
			var local_sample := sample * tile_size - tile_size * 0.5
			if _is_point_inside_tile_collision(tile_data, local_sample, polygon_count):
				blocked_cells[fine_origin + Vector2i(x, y)] = true


func _is_point_inside_tile_collision(tile_data: TileData, local_point: Vector2, polygon_count: int) -> bool:
	for polygon_index in range(polygon_count):
		var points := tile_data.get_collision_polygon_points(0, polygon_index)
		if Geometry2D.is_point_in_polygon(local_point, points):
			return true
	return false


func _build_navigation_polygon_from_blockers(
	tilemap: TileMapLayer,
	used_rect: Rect2i,
	blocked_cells: Dictionary,
	subdivision: int
) -> NavigationPolygon:
	var generated_navigation_polygon := NavigationPolygon.new()
	generated_navigation_polygon.add_outline(_rect_to_navigation_outline(tilemap, used_rect, subdivision))
	for outline in _build_walkable_outlines(tilemap, blocked_cells, subdivision):
		generated_navigation_polygon.add_outline(outline)
	generated_navigation_polygon.make_polygons_from_outlines()
	if generated_navigation_polygon.get_polygon_count() == 0 and not blocked_cells.is_empty():
		generated_navigation_polygon = _build_navigation_polygon_from_blocker_bounds(
			tilemap,
			used_rect,
			blocked_cells,
			subdivision
		)
	return generated_navigation_polygon


func _build_navigation_polygon_from_blocker_bounds(
	tilemap: TileMapLayer,
	used_rect: Rect2i,
	blocked_cells: Dictionary,
	subdivision: int
) -> NavigationPolygon:
	var generated_navigation_polygon := NavigationPolygon.new()
	generated_navigation_polygon.add_outline(_rect_to_navigation_outline(tilemap, used_rect, subdivision))
	generated_navigation_polygon.add_outline(_rect_to_navigation_outline(
		tilemap,
		_get_cell_bounds(blocked_cells),
		subdivision
	))
	generated_navigation_polygon.make_polygons_from_outlines()
	return generated_navigation_polygon


func _get_cell_bounds(cells: Dictionary) -> Rect2i:
	var first := true
	var min_cell := Vector2i.ZERO
	var max_cell := Vector2i.ZERO
	for cell: Vector2i in cells.keys():
		if first:
			first = false
			min_cell = cell
			max_cell = cell
			continue
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)


func _rect_to_navigation_outline(tilemap: TileMapLayer, rect: Rect2i, subdivision: int) -> PackedVector2Array:
	var top_left := rect.position
	var top_right := rect.position + Vector2i(rect.size.x, 0)
	var bottom_right := rect.position + rect.size
	var bottom_left := rect.position + Vector2i(0, rect.size.y)
	return PackedVector2Array([
		_grid_point_to_region_local(tilemap, top_left, subdivision),
		_grid_point_to_region_local(tilemap, top_right, subdivision),
		_grid_point_to_region_local(tilemap, bottom_right, subdivision),
		_grid_point_to_region_local(tilemap, bottom_left, subdivision),
	])


func _merge_cells_into_rectangles(walkable_cells: Dictionary) -> Array[Rect2i]:
	var rows := {}
	for cell: Vector2i in walkable_cells.keys():
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)

	var rectangles: Array[Rect2i] = []
	var active_rectangles := {}
	var sorted_rows := rows.keys()
	sorted_rows.sort()

	for y: int in sorted_rows:
		var row_spans := _build_row_spans(rows[y])
		var next_active_rectangles := {}
		for span: Vector2i in row_spans:
			var key := "%d:%d" % [span.x, span.y]
			if active_rectangles.has(key):
				var rect: Rect2i = active_rectangles[key]
				rect.size.y += 1
				next_active_rectangles[key] = rect
			else:
				next_active_rectangles[key] = Rect2i(
					Vector2i(span.x, y),
					Vector2i(span.y - span.x + 1, 1)
				)

		for key in active_rectangles.keys():
			if not next_active_rectangles.has(key):
				rectangles.append(active_rectangles[key])
		active_rectangles = next_active_rectangles

	for rect in active_rectangles.values():
		rectangles.append(rect)

	return rectangles


func _build_row_spans(row_values: Array) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	if row_values.is_empty():
		return spans

	row_values.sort()
	var start: int = row_values[0]
	var previous: int = row_values[0]
	for index in range(1, row_values.size()):
		var current: int = row_values[index]
		if current == previous + 1:
			previous = current
			continue
		spans.append(Vector2i(start, previous))
		start = current
		previous = current
	spans.append(Vector2i(start, previous))
	return spans


func _get_or_add_vertex_index(
	tilemap: TileMapLayer,
	grid_point: Vector2i,
	subdivision: int,
	vertices: PackedVector2Array,
	vertex_indices: Dictionary
) -> int:
	if vertex_indices.has(grid_point):
		return vertex_indices[grid_point]

	var index := vertices.size()
	vertices.append(_grid_point_to_region_local(tilemap, grid_point, subdivision))
	vertex_indices[grid_point] = index
	return index


func _build_walkable_outlines(
	tilemap: TileMapLayer,
	walkable_cells: Dictionary,
	subdivision: int
) -> Array[PackedVector2Array]:
	var edges := {}
	for cell in walkable_cells.keys():
		_add_boundary_edges_for_cell(cell, walkable_cells, edges)

	var outlines: Array[PackedVector2Array] = []
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var current := start
		var outline := PackedVector2Array()
		var safety := 0

		while safety < 100000:
			safety += 1
			outline.append(_grid_point_to_region_local(tilemap, current, subdivision))
			if not edges.has(current):
				break
			var next_points: Array = edges[current]
			var next: Vector2i = next_points.pop_back()
			if next_points.is_empty():
				edges.erase(current)
			current = next
			if current == start:
				break

		if current == start and outline.size() >= 3:
			outlines.append(outline)

	return outlines


func _add_boundary_edges_for_cell(cell: Vector2i, walkable_cells: Dictionary, edges: Dictionary) -> void:
	var top_left := cell
	var top_right := cell + Vector2i.RIGHT
	var bottom_right := cell + Vector2i.ONE
	var bottom_left := cell + Vector2i.DOWN

	if not walkable_cells.has(cell + Vector2i.UP):
		_add_edge(edges, top_left, top_right)
	if not walkable_cells.has(cell + Vector2i.RIGHT):
		_add_edge(edges, top_right, bottom_right)
	if not walkable_cells.has(cell + Vector2i.DOWN):
		_add_edge(edges, bottom_right, bottom_left)
	if not walkable_cells.has(cell + Vector2i.LEFT):
		_add_edge(edges, bottom_left, top_left)


func _add_edge(edges: Dictionary, start: Vector2i, end: Vector2i) -> void:
	if not edges.has(start):
		edges[start] = []
	edges[start].append(end)


func _grid_point_to_region_local(tilemap: TileMapLayer, point: Vector2i, subdivision: int) -> Vector2:
	var half_size := Vector2(tilemap.tile_set.tile_size) * 0.5
	var fine_cell_size := Vector2(tilemap.tile_set.tile_size) / float(subdivision)
	var local_origin := tilemap.map_to_local(Vector2i.ZERO) - half_size
	var local_point := local_origin + Vector2(point) * fine_cell_size
	return to_local(tilemap.to_global(local_point))
