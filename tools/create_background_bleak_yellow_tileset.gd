extends SceneTree

const TILE_SIZE := Vector2i(16, 16)
const ATLAS_COLUMNS := 24
const ATLAS_ROWS := 17
const TEXTURE_PATH := "res://assets/world/tiles/background/tileset_terrain_background_bleak_yellow_tile16.png"
const TILESET_PATH := "res://resources/tiles/background_bleak_yellow_tileset.tres"

func _initialize() -> void:
	var texture := load(TEXTURE_PATH)
	if texture == null:
		push_error("Could not load texture: " + TEXTURE_PATH)
		quit(1)
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = TILE_SIZE

	for y in ATLAS_ROWS:
		for x in ATLAS_COLUMNS:
			atlas.create_tile(Vector2i(x, y))

	tile_set.add_source(atlas, 0)

	var err := ResourceSaver.save(tile_set, TILESET_PATH)
	if err != OK:
		push_error("Could not save TileSet: " + TILESET_PATH)
		quit(1)
		return

	print("Created TileSet: " + TILESET_PATH)
	quit()
