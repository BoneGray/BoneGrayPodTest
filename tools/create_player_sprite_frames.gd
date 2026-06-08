@tool
extends SceneTree

const SOURCE_DIR := "res://assets/characters/player/main"
const OUTPUT_PATH := "res://resources/characters/player/player_sprite_frames.tres"

const ANIMATION_SPEEDS := {
	"idle": 6.0,
	"walk": 10.0,
	"first_attack": 12.0,
	"second_attack": 12.0,
	"pickup": 8.0,
	"first_death": 8.0,
	"second_death": 8.0,
	"third_death": 8.0,
}

const FRAME_COUNT_OVERRIDES := {
	"Character_side_death2-Sheet6.png": 7,
	"Character_side_death3-Sheet6.png": 7,
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var files := _collect_character_png_files(SOURCE_DIR)
	files.sort()
	for file_path in files:
		_add_sheet(frames, file_path)

	var output_dir := ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	var error := ResourceSaver.save(frames, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save Player SpriteFrames: %s" % error)
	else:
		print("Saved %s with %d animations." % [OUTPUT_PATH, frames.get_animation_names().size()])
	quit()


func _collect_character_png_files(path: String) -> PackedStringArray:
	var result := PackedStringArray()
	_collect_recursive(path, result)
	return result


func _collect_recursive(path: String, result: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Could not open source dir: %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var child_path := path.path_join(file_name)
		if dir.current_is_dir():
			if file_name != "Gif":
				_collect_recursive(child_path, result)
		elif _is_body_sheet(file_name):
			result.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _is_body_sheet(file_name: String) -> bool:
	var lower_name := file_name.to_lower()
	return lower_name.get_extension() == "png" \
		and lower_name.begins_with("character_") \
		and not lower_name.contains("nohands") \
		and not lower_name.contains("no-hands")


func _add_sheet(frames: SpriteFrames, file_path: String) -> void:
	var texture := load(file_path) as Texture2D
	if texture == null:
		push_warning("Could not load texture: %s" % file_path)
		return

	var frame_count := _resolve_frame_count(file_path, texture.get_width())
	if frame_count <= 0:
		push_warning("Skipped file without frame count: %s" % file_path)
		return

	for animation_name in _animation_names_from_path(file_path):
		if frames.has_animation(animation_name):
			push_warning("Duplicate animation skipped: %s from %s" % [animation_name, file_path])
			continue

		frames.add_animation(animation_name)
		var action_name := _action_from_animation_name(animation_name)
		frames.set_animation_speed(animation_name, ANIMATION_SPEEDS.get(action_name, 8.0))
		frames.set_animation_loop(animation_name, action_name in ["idle", "walk"])

		var frame_width := int(texture.get_width() / frame_count)
		var frame_height := texture.get_height()
		for frame_index in frame_count:
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = texture
			atlas_texture.region = Rect2(frame_index * frame_width, 0, frame_width, frame_height)
			frames.add_frame(animation_name, atlas_texture)


func _resolve_frame_count(path: String, texture_width: int) -> int:
	var file_name := path.get_file()
	if FRAME_COUNT_OVERRIDES.has(file_name):
		return FRAME_COUNT_OVERRIDES[file_name]

	var frame_count := _extract_frame_count(path)
	if frame_count <= 0:
		return 0

	if texture_width % frame_count != 0:
		push_warning("%s width %d is not divisible by Sheet%d. Add a FRAME_COUNT_OVERRIDES entry if this animation slices wrong." % [file_name, texture_width, frame_count])
	return frame_count


func _extract_frame_count(path: String) -> int:
	var regex := RegEx.new()
	regex.compile("Sheet(\\d+)")
	var match := regex.search(path.get_file())
	if match == null:
		return 0
	return int(match.get_string(1))


func _animation_names_from_path(path: String) -> PackedStringArray:
	var base_name := path.get_file().get_basename()
	var regex := RegEx.new()
	regex.compile("-Sheet\\d+$")
	base_name = regex.sub(base_name, "", true)
	base_name = base_name.trim_prefix("Character_")

	var parts := base_name.split("_", false)
	if parts.size() < 2:
		return PackedStringArray([base_name.to_snake_case()])

	var direction := _normalize_direction(parts[0])
	var source_action := "_".join(parts.slice(1)).to_lower()
	var action_names := _normalize_actions(source_action)
	var animation_names := PackedStringArray()
	for action_name in action_names:
		animation_names.append("%s_%s" % [action_name, direction])
	return animation_names


func _normalize_direction(direction: String) -> String:
	match direction.to_lower():
		"side-left":
			return "side_left"
		"side":
			return "side"
		"down":
			return "down"
		"up":
			return "up"
		_:
			return direction.to_snake_case()


func _normalize_actions(source_action: String) -> PackedStringArray:
	if source_action == "idle":
		return PackedStringArray(["idle"])
	if source_action == "run":
		return PackedStringArray(["walk"])
	if source_action == "punch":
		return PackedStringArray(["first_attack", "second_attack"])
	if source_action == "pick-up":
		return PackedStringArray(["pickup"])
	if source_action == "death1":
		return PackedStringArray(["first_death"])
	if source_action == "death2":
		return PackedStringArray(["second_death"])
	if source_action == "death3":
		return PackedStringArray(["third_death"])
	return PackedStringArray([source_action.to_snake_case()])


func _action_from_animation_name(animation_name: String) -> String:
	for action in ANIMATION_SPEEDS.keys():
		if animation_name.begins_with("%s_" % action):
			return action
	return animation_name.get_slice("_", 0)
