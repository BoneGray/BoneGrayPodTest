@tool
extends SceneTree

const SOURCE_DIR := "res://assets/equipment/weapons/gun"
const OUTPUT_PATH := "res://resources/equipment/weapons/gun/gun_sprite_frames.tres"

const ANIMATION_SPEEDS := {
	"idle": 6.0,
	"walk": 10.0,
	"pickup": 8.0,
	"attack_first": 14.0,
	"attack_second": 14.0,
	"shoot": 14.0,
	"reload": 10.0,
	"death_first": 8.0,
}

const FRAME_EDGE_TRIMS := {
	"gun_shoot_side_sheet3.png": Rect2(1, 0, 0, 0),
	"gun_shoot_side_left_sheet3.png": Rect2(0, 0, 1, 0),
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var files := _collect_png_files(SOURCE_DIR)
	files.sort()
	for file_path in files:
		_add_sheet(frames, file_path)

	var output_dir := ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	var error := ResourceSaver.save(frames, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save Gun SpriteFrames: %s" % error)
		quit(1)
		return

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
		var child_path := path.path_join(file_name)
		if not dir.current_is_dir() and _is_animation_sheet(file_name):
			result.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _is_animation_sheet(file_name: String) -> bool:
	var lower_name := file_name.to_lower()
	return lower_name.get_extension() == "png" and lower_name.contains("_sheet")


func _add_sheet(frames: SpriteFrames, file_path: String) -> void:
	var texture := load(file_path) as Texture2D
	if texture == null:
		push_warning("Could not load texture: %s" % file_path)
		return

	var frame_count := _extract_frame_count(file_path)
	if frame_count <= 0:
		push_warning("Skipped file without frame count: %s" % file_path)
		return

	if texture.get_width() % frame_count != 0:
		push_warning("%s width %d is not divisible by sheet%d." % [file_path.get_file(), texture.get_width(), frame_count])

	var frame_width := int(texture.get_width() / frame_count)
	var frame_height := texture.get_height()
	for animation_name in _animation_names_from_path(file_path):
		if frames.has_animation(animation_name):
			push_warning("Duplicate animation skipped: %s from %s" % [animation_name, file_path])
			continue

		frames.add_animation(animation_name)
		var action_name := _action_from_animation_name(animation_name)
		frames.set_animation_speed(animation_name, ANIMATION_SPEEDS.get(action_name, 8.0))
		frames.set_animation_loop(animation_name, action_name in ["idle", "walk"])

		for frame_index in frame_count:
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = texture
			atlas_texture.filter_clip = true
			var edge_trim: Rect2 = FRAME_EDGE_TRIMS.get(file_path.get_file(), Rect2())
			atlas_texture.region = Rect2(
				frame_index * frame_width + edge_trim.position.x,
				edge_trim.position.y,
				frame_width - edge_trim.position.x - edge_trim.size.x,
				frame_height - edge_trim.position.y - edge_trim.size.y
			)
			atlas_texture.margin = edge_trim
			frames.add_frame(animation_name, atlas_texture)


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
	base_name = base_name.trim_prefix("gun_")

	if base_name.begins_with("idle_") and base_name.ends_with("_run"):
		var direction := base_name.trim_prefix("idle_").trim_suffix("_run")
		return PackedStringArray(["idle_%s" % direction, "walk_%s" % direction, "pickup_%s" % direction])

	var parts := base_name.split("_", false)
	if parts.size() < 2:
		return PackedStringArray([base_name])

	var action := parts[0]
	var direction := parts[1]
	if parts.size() >= 3 and parts[1] == "side" and parts[2] == "left":
		direction = "side_left"

	if action == "shoot":
		return PackedStringArray(["shoot_%s" % direction, "attack_%s_first" % direction, "attack_%s_second" % direction])
	if action == "death":
		return PackedStringArray(["death_%s_first" % direction])
	return PackedStringArray(["%s_%s" % [action, direction]])


func _action_from_animation_name(animation_name: String) -> String:
	var parts := animation_name.split("_", false)
	if parts.size() >= 3 and (parts[0] in ["attack", "death"]):
		return "%s_%s" % [parts[0], parts[parts.size() - 1]]
	return parts[0] if not parts.is_empty() else animation_name
