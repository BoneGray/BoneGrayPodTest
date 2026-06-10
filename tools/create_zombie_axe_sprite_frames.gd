@tool
extends SceneTree

const SOURCE_DIR := "res://assets/characters/enemies/zombie_axe"
const OUTPUT_PATH := "res://resources/characters/enemies/zombie_axe_sprite_frames.tres"

const ANIMATION_SPEEDS := {
	"idle": 4.0,
	"walk": 8.0,
	"attack_first": 10.0,
	"attack_second": 10.0,
	"attack_first_no_axe": 10.0,
	"death_first": 8.0,
	"death_second": 8.0,
	"death_first_no_axe": 8.0,
	"death_second_no_axe": 8.0,
	"pickup_axe": 8.0,
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var files := _collect_png_files(SOURCE_DIR)
	files.sort()

	for file_path in files:
		var frame_count := _extract_frame_count(file_path)
		if frame_count <= 0:
			continue

		var texture := load(file_path) as Texture2D
		if texture == null:
			push_warning("Could not load texture: %s" % file_path)
			continue

		var animation_name := _animation_name_from_path(file_path)
		frames.add_animation(animation_name)
		var action_name := _action_from_animation_name(animation_name)
		frames.set_animation_speed(animation_name, ANIMATION_SPEEDS.get(action_name, 8.0))
		frames.set_animation_loop(animation_name, action_name in ["idle", "walk"])

		var frame_width := texture.get_width() / frame_count
		var frame_height := texture.get_height()
		for frame_index in frame_count:
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = texture
			atlas_texture.region = Rect2(frame_index * frame_width, 0, frame_width, frame_height)
			frames.add_frame(animation_name, atlas_texture)

	var error := ResourceSaver.save(frames, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save SpriteFrames: %s" % error)
	else:
		print("Saved %s with %d animations." % [OUTPUT_PATH, frames.get_animation_names().size()])

	quit()


func _collect_png_files(path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Could not open source dir: %s" % path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			result.append(path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _extract_frame_count(path: String) -> int:
	var regex := RegEx.new()
	regex.compile("sheet(\\d+)")
	var match := regex.search(path.get_file().to_lower())
	if match == null:
		return 0
	return int(match.get_string(1))


func _animation_name_from_path(path: String) -> String:
	var base_name := path.get_file().get_basename().to_lower()
	var regex := RegEx.new()
	regex.compile("_sheet\\d+$")
	base_name = regex.sub(base_name, "", true)
	return base_name.trim_prefix("zombie_axe_")


func _action_from_animation_name(animation_name: String) -> String:
	var parts := animation_name.split("_", false)
	if parts.is_empty():
		return animation_name

	if parts[0] in ["idle", "walk"]:
		return parts[0]

	var supplement_start := 2
	if parts.size() >= 4 and parts[1] == "side" and parts[2] == "left":
		supplement_start = 3
	if supplement_start < parts.size():
		return "%s_%s" % [parts[0], "_".join(parts.slice(supplement_start))]
	return parts[0]
