@tool
extends SceneTree

const FIREARM_CONTROLLER_PATH := "res://scripts/player/firearm_controller.gd"
const FIREARM_CONTROLLER_SOURCE_PATH := "res://scripts/player/firearm_controller.gd"
const FIREARM_WEAPON_PATHS := [
	"res://resources/equipment/weapons/gun/gun_data.tres",
	"res://resources/equipment/weapons/pistol/pistol_data.tres",
	"res://resources/equipment/weapons/shotgun/shotgun_data.tres",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller_script := load(FIREARM_CONTROLLER_PATH) as Script
	if controller_script == null:
		_fail("FirearmController script should load.")
		return

	var source := FileAccess.get_file_as_string(FIREARM_CONTROLLER_SOURCE_PATH)
	if source.is_empty():
		_fail("FirearmController source should be readable.")
		return
	for forbidden_text in ["weapon_id", "gun_primary", "pistol", "shotgun"]:
		if source.find(forbidden_text) != -1:
			_fail("FirearmController must not branch by a specific weapon name: %s." % forbidden_text)
			return

	var controller: RefCounted = controller_script.new()
	for weapon_path in FIREARM_WEAPON_PATHS:
		var weapon_data := load(weapon_path) as Resource
		if weapon_data == null:
			_fail("Could not load firearm data: %s." % weapon_path)
			return
		if String(weapon_data.get("weapon_type")) != "firearm":
			_fail("%s should declare weapon_type firearm." % weapon_path)
			return
		var attack_profile := weapon_data.get("primary_attack_profile") as Resource
		if attack_profile == null:
			_fail("%s should define a primary attack profile." % weapon_path)
			return
		if not controller.is_firearm_profile(attack_profile, weapon_data):
			_fail("FirearmController should recognize projectile firearm profile: %s." % weapon_path)
			return
		if not controller.should_preserve_hold_repeat_input(attack_profile, weapon_data, true, true):
			_fail("FirearmController should preserve held repeat input while J is pressed: %s." % weapon_path)
			return
		if controller.should_preserve_hold_repeat_input(attack_profile, weapon_data, true, false):
			_fail("FirearmController should not preserve repeat input after release: %s." % weapon_path)
			return
		if not controller.should_clear_cooldown_after_animation(attack_profile, weapon_data, false):
			_fail("FirearmController should clear firearm cooldown after tap-release: %s." % weapon_path)
			return

	print("FirearmController baseline is valid.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
