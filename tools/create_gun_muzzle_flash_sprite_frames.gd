@tool
extends SceneTree

const OUTPUT_PATH := "res://resources/effects/weapons/gun/gun_muzzle_flash_sprite_frames.tres"

const SOURCES := {
	"flash_down": "res://assets/effects/weapons/gun/muzzle_flash/gun_muzzle_flash_down_sheet3.png",
	"flash_side": "res://assets/effects/weapons/gun/muzzle_flash/gun_muzzle_flash_side_sheet3.png",
	"flash_side_left": "res://assets/effects/weapons/gun/muzzle_flash/gun_muzzle_flash_side_left_sheet3.png",
	"flash_up": "res://assets/effects/weapons/gun/muzzle_flash/gun_muzzle_flash_up_sheet3.png",
}

const FRAME_COUNT := 3
const FPS := 18.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for animation_name in SOURCES:
		var texture := load(SOURCES[animation_name]) as Texture2D
		if texture == null:
			_fail("Could not load muzzle flash sheet: %s" % SOURCES[animation_name])
			return

		var frame_width := texture.get_width() / FRAME_COUNT
		var frame_height := texture.get_height()
		if frame_width <= 0 or texture.get_width() % FRAME_COUNT != 0:
			_fail("Muzzle flash sheet width must divide into three frames: %s" % SOURCES[animation_name])
			return

		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, FPS)
		frames.set_animation_loop(animation_name, false)

		for frame_index in FRAME_COUNT:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame_index * frame_width, 0, frame_width, frame_height)
			frames.add_frame(animation_name, atlas)

	var save_result := ResourceSaver.save(frames, OUTPUT_PATH)
	if save_result != OK:
		_fail("Could not save muzzle flash SpriteFrames: %s" % error_string(save_result))
		return

	print("Gun muzzle flash SpriteFrames generated.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
