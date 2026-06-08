extends SceneTree

const TEMPLATE_TILESET := "res://resources/tiles/background_bleak_yellow_tileset.tres"
const VARIANTS := [
	{
		"texture": "res://assets/world/tiles/background/background_dark_green_tileset.png",
		"tileset": "res://resources/tiles/background_dark_green_tileset.tres",
	},
	{
		"texture": "res://assets/world/tiles/background/background_green_tileset.png",
		"tileset": "res://resources/tiles/background_green_tileset.tres",
	},
]

func _initialize() -> void:
	var template := load(TEMPLATE_TILESET) as TileSet
	if template == null:
		push_error("Could not load template TileSet: " + TEMPLATE_TILESET)
		quit(1)
		return

	for variant in VARIANTS:
		_create_variant(template, variant["texture"], variant["tileset"])

	quit()

func _create_variant(template: TileSet, texture_path: String, tileset_path: String) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_error("Could not load texture: " + texture_path)
		quit(1)
		return

	var tile_set := template.duplicate(true) as TileSet
	var source := tile_set.get_source(0) as TileSetAtlasSource
	if source == null:
		push_error("Template TileSet source 0 is not an atlas source.")
		quit(1)
		return

	source.texture = texture

	var err := ResourceSaver.save(tile_set, tileset_path)
	if err != OK:
		push_error("Could not save TileSet: " + tileset_path)
		quit(1)
		return

	print("Created TileSet variant: " + tileset_path)
