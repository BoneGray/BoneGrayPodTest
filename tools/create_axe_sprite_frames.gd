@tool
extends SceneTree

const SOURCE_DIR := "res://assets/characters/enemies/zombie_axe/axe"
const OUTPUT_PATH := "res://resources/characters/enemies/axe_sprite_frames.tres"

const ANIMATION_SPEEDS := {
	"thrown": 12.0,
	"landing": 10.0,
	"landed": 1.0,
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var files := _collect_png_files(SOURCE_DIR)
	files.sort()
	for file_path in files:
		var texture := load(file_path) as Texture2D
		if texture == null:
			continue

		var animation_name := _animation_name_from_path(file_path)
		var frame_count := _extract_frame_count(file_path)
		if frame_count <= 0:
			frame_count = 1

		_add_animation(frames, animation_name, texture, frame_count)
		if animation_name == "thrown_vertical":
			_add_animation(frames, "thrown_up", texture, frame_count)
			_add_animation(frames, "thrown_down", texture, frame_count)

	var error := ResourceSaver.save(frames, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save Axe SpriteFrames: %s" % error)
	else:
		print("Saved %s with %d animations." % [OUTPUT_PATH, frames.get_animation_names().size()])

	quit()


func _add_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, frame_count: int) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, ANIMATION_SPEEDS.get(animation_name.get_slice("_", 0), 8.0))
	frames.set_animation_loop(animation_name, animation_name.begins_with("thrown"))

	var frame_width := texture.get_width() / frame_count
	var frame_height := texture.get_height()
	for frame_index in frame_count:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = texture
		atlas_texture.region = Rect2(frame_index * frame_width, 0, frame_width, frame_height)
		frames.add_frame(animation_name, atlas_texture)


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
	var base_name := path.get_file().get_basename().to_lower().trim_prefix("axe_")
	var regex := RegEx.new()
	regex.compile("_sheet\\d+$")
	base_name = regex.sub(base_name, "", true)

	if base_name == "vertical_thrown":
		return "thrown_vertical"
	if base_name.ends_with("_thrown"):
		return "thrown_%s" % base_name.trim_suffix("_thrown")
	if base_name.ends_with("_landing"):
		return "landing_%s" % base_name.trim_suffix("_landing")
	if base_name.ends_with("_landed"):
		return "landed_%s" % base_name.trim_suffix("_landed")
	return base_name
