@tool
extends SceneTree

const SOURCE_DIR := "res://assets/characters/enemies/zombie_big"
const OUTPUT_PATH := "res://resources/characters/enemies/zombie_big_sprite_frames.tres"

const ANIMATION_SPEEDS := {
	"idle": 4.0,
	"walk": 8.0,
	"first_attack": 10.0,
	"second_attack": 12.0,
	"first_death": 8.0,
	"second_death": 8.0,
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var files := _collect_png_files(SOURCE_DIR)
	files.sort()

	for file_path in files:
		var frame_count := _extract_frame_count(file_path)
		if frame_count <= 0:
			push_warning("Skipped file without frame count: %s" % file_path)
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

	var output_dir := OUTPUT_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

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
	regex.compile("Sheet(\\d+)")
	var match := regex.search(path.get_file())
	if match == null:
		return 0
	return int(match.get_string(1))


func _animation_name_from_path(path: String) -> String:
	var base_name := path.get_file().get_basename()
	base_name = base_name.trim_prefix("Zombie_Big_")
	var regex := RegEx.new()
	regex.compile("-Sheet\\d+$")
	base_name = regex.sub(base_name, "", true)
	var parts := base_name.split("_", false, 1)
	if parts.size() != 2:
		return base_name.to_snake_case()

	var direction := _normalize_direction(parts[0])
	var action := _normalize_action(parts[1])
	return "%s_%s" % [action, direction]


func _action_from_animation_name(animation_name: String) -> String:
	for action in ANIMATION_SPEEDS.keys():
		if animation_name.begins_with("%s_" % action):
			return action
	return animation_name.get_slice("_", 0)


func _normalize_direction(direction: String) -> String:
	match direction:
		"Side-left":
			return "side_left"
		"Side":
			return "side"
		"Down":
			return "down"
		"Up":
			return "up"
		_:
			return direction.to_snake_case()


func _normalize_action(action: String) -> String:
	match action:
		"First-Attack":
			return "first_attack"
		"Second-Attack":
			return "second_attack"
		"First-Death":
			return "first_death"
		"Second-Death":
			return "second_death"
		"Idle":
			return "idle"
		"Walk":
			return "walk"
		_:
			return action.to_snake_case()
