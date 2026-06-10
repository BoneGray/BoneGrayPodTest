@tool
extends SceneTree

const SOURCE_DIR := "res://assets/characters/player/main"
const OUTPUT_PATH := "res://resources/characters/player/player_sprite_frames.tres"
const NO_HANDS_OUTPUT_PATH := "res://resources/characters/player/player_no_hands_sprite_frames.tres"
const HANDS_OUTPUT_PATH := "res://resources/characters/player/player_hands_sprite_frames.tres"

const ANIMATION_SPEEDS := {
	"idle": 6.0,
	"walk": 10.0,
	"attack_first": 12.0,
	"attack_second": 12.0,
	"pickup": 8.0,
	"death_first": 8.0,
	"death_second": 8.0,
	"death_third": 8.0,
}

const FRAME_COUNT_OVERRIDES := {
	"player_body_death_side_second_sheet6.png": 7,
	"player_body_death_side_third_sheet6.png": 7,
	"player_body_no_hands_death_side_second_sheet6.png": 7,
	"player_body_no_hands_death_side_third_sheet6.png": 7,
}


func _initialize() -> void:
	_create_sprite_frames(OUTPUT_PATH, "full_body")
	_create_sprite_frames(NO_HANDS_OUTPUT_PATH, "no_hands_body")
	_create_sprite_frames(HANDS_OUTPUT_PATH, "hands")
	quit()


func _create_sprite_frames(output_path: String, sheet_kind: String) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var files := _collect_png_files(SOURCE_DIR, sheet_kind)
	files.sort()
	for file_path in files:
		_add_sheet(frames, file_path)

	var output_dir := ProjectSettings.globalize_path(output_path.get_base_dir())
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	var error := ResourceSaver.save(frames, output_path)
	if error != OK:
		push_error("Failed to save Player SpriteFrames %s: %s" % [output_path, error])
	else:
		print("Saved %s with %d animations." % [output_path, frames.get_animation_names().size()])


func _collect_png_files(path: String, sheet_kind: String) -> PackedStringArray:
	var result := PackedStringArray()
	_collect_recursive(path, result, sheet_kind)
	return result


func _collect_recursive(path: String, result: PackedStringArray, sheet_kind: String) -> void:
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
				_collect_recursive(child_path, result, sheet_kind)
		elif _is_sheet_kind(file_name, sheet_kind):
			result.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _is_sheet_kind(file_name: String, sheet_kind: String) -> bool:
	var lower_name := file_name.to_lower()
	if lower_name.get_extension() != "png":
		return false

	if sheet_kind == "full_body":
		return lower_name.begins_with("player_body_") and not lower_name.begins_with("player_body_no_hands_")
	if sheet_kind == "no_hands_body":
		return lower_name.begins_with("player_body_no_hands_")
	if sheet_kind == "hands":
		return lower_name.begins_with("player_hands_")
	return false


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
		push_warning("%s width %d is not divisible by sheet%d. Add a FRAME_COUNT_OVERRIDES entry if this animation slices wrong." % [file_name, texture_width, frame_count])
	return frame_count


func _extract_frame_count(path: String) -> int:
	var regex := RegEx.new()
	regex.compile("sheet(\\d+)")
	var match := regex.search(path.get_file().to_lower())
	if match == null:
		return 0
	return int(match.get_string(1))


func _animation_names_from_path(path: String) -> PackedStringArray:
	var base_name := path.get_file().get_basename().to_lower()
	var regex := RegEx.new()
	regex.compile("_sheet\\d+$")
	base_name = regex.sub(base_name, "", true)
	base_name = base_name.trim_prefix("player_body_no_hands_")
	base_name = base_name.trim_prefix("player_body_")
	base_name = base_name.trim_prefix("player_hands_")

	return _animation_names_from_parts(base_name.split("_", false))


func _animation_names_from_parts(parts: PackedStringArray) -> PackedStringArray:
	if parts.size() < 2:
		return PackedStringArray(["_".join(parts)])

	var action := parts[0]
	var direction := parts[1]
	var supplement_start := 2
	if parts.size() >= 3 and parts[1] == "side" and parts[2] == "left":
		direction = "side_left"
		supplement_start = 3

	var supplement := ""
	if supplement_start < parts.size():
		supplement = "_".join(parts.slice(supplement_start))

	if action == "attack" and supplement == "":
		return PackedStringArray(["attack_%s_first" % direction, "attack_%s_second" % direction])
	if action == "death" and supplement == "":
		supplement = "first"
	if supplement != "":
		return PackedStringArray(["%s_%s_%s" % [action, direction, supplement]])
	return PackedStringArray(["%s_%s" % [action, direction]])


func _action_from_animation_name(animation_name: String) -> String:
	var parts := animation_name.split("_", false)
	if parts.size() >= 3 and (parts[0] in ["attack", "death"]):
		return "%s_%s" % [parts[0], parts[parts.size() - 1]]
	return parts[0] if not parts.is_empty() else animation_name


func _animation_name(action: String, direction: String) -> String:
	var parts := action.split("_", false, 1)
	if parts.size() == 2 and (parts[0] in ["attack", "death"]):
		return "%s_%s_%s" % [parts[0], direction, parts[1]]
	return "%s_%s" % [action, direction]
