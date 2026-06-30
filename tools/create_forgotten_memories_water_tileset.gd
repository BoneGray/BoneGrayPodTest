extends SceneTree

const SOURCE_TEXTURE := "res://assets/world/tiles/forgotten_memories/tileset_water_forgotten_memories_sheet6.png"
const OUTPUT_TILESET := "res://resources/tiles/fm_water_tileset.tres"
const TILE_SIZE := Vector2i(32, 32)
const FRAME_COUNT := 6
const FRAME_DURATION := 0.16


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_TEXTURE))
	if image == null or image.is_empty():
		push_error("Failed to load water tileset image: %s" % SOURCE_TEXTURE)
		quit(1)
		return

	var texture: Texture2D = load(SOURCE_TEXTURE)
	if texture == null:
		push_error("Failed to load water tileset texture: %s" % SOURCE_TEXTURE)
		quit(1)
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE

	var atlas_columns := image.get_width() / TILE_SIZE.x
	var atlas_rows := image.get_height() / TILE_SIZE.y
	var created_tiles := 0

	for tile_y in range(atlas_rows):
		for tile_x in range(0, atlas_columns - FRAME_COUNT + 1, FRAME_COUNT):
			if not _animation_strip_has_pixels(image, Vector2i(tile_x, tile_y)):
				continue

			var atlas_coords := Vector2i(tile_x, tile_y)
			source.create_tile(atlas_coords)
			source.set_tile_animation_columns(atlas_coords, FRAME_COUNT)
			source.set_tile_animation_frames_count(atlas_coords, FRAME_COUNT)
			source.set_tile_animation_speed(atlas_coords, 1.0)
			for frame_index in range(FRAME_COUNT):
				source.set_tile_animation_frame_duration(atlas_coords, frame_index, FRAME_DURATION)
			created_tiles += 1

	tile_set.add_source(source, 0)

	var error := ResourceSaver.save(tile_set, OUTPUT_TILESET)
	if error != OK:
		push_error("Failed to save water TileSet %s: %s" % [OUTPUT_TILESET, error_string(error)])
		quit(1)
		return

	print("Created %s with %d animated 32x32 water tiles." % [OUTPUT_TILESET, created_tiles])
	quit()


func _animation_strip_has_pixels(image: Image, start_tile: Vector2i) -> bool:
	var start_pixel := start_tile * TILE_SIZE
	var end_pixel := start_pixel + Vector2i(TILE_SIZE.x * FRAME_COUNT, TILE_SIZE.y)

	for y in range(start_pixel.y, end_pixel.y):
		for x in range(start_pixel.x, end_pixel.x):
			if image.get_pixel(x, y).a > 0.0:
				return true

	return false
