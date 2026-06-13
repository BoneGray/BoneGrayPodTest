@tool
extends SceneTree

const RUNNER = preload("res://tools/firearm_weapon_test_runner.gd")
const WEAPON_ROOT := "res://resources/equipment/weapons"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var firearm_paths := _find_firearm_weapon_data_paths(WEAPON_ROOT)
	if firearm_paths.is_empty():
		_fail("No firearm WeaponData resources found under %s." % WEAPON_ROOT)
		return

	var runner := RUNNER.new()
	for weapon_path in firearm_paths:
		var weapon_data := load(weapon_path) as Resource
		var error := await runner.validate_weapon_data(self, weapon_data, weapon_path)
		if error != "":
			_fail(error)
			return

	print("Firearm weapon logic is valid for %d weapon(s)." % firearm_paths.size())
	quit()


func _find_firearm_weapon_data_paths(root_path: String) -> Array[String]:
	var paths: Array[String] = []
	_collect_firearm_weapon_data_paths(root_path, paths)
	paths.sort()
	return paths


func _collect_firearm_weapon_data_paths(path: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_collect_firearm_weapon_data_paths(child_path, paths)
		elif entry.ends_with(".tres"):
			var resource := load(child_path) as Resource
			if resource != null and _resource_has_property(resource, "weapon_type") and String(resource.get("weapon_type")) == "firearm":
				paths.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _resource_has_property(resource: Resource, property_name: String) -> bool:
	for property in resource.get_property_list():
		if String(property.get("name")) == property_name:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
