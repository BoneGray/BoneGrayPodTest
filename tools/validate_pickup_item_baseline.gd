@tool
extends SceneTree

const PICKUP_SCENE_ROOT := "res://scenes/items/weapons"
const WEAPON_DATA_ROOT := "res://resources/equipment/weapons"
const PICKUP_ITEM_SCRIPT := preload("res://scripts/items/pickup_item.gd")
const ITEM_DATA_SCRIPT := preload("res://scripts/items/item_data.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pickup_paths := _find_paths(PICKUP_SCENE_ROOT, "_pickup.tscn")
	if pickup_paths.is_empty():
		_fail("No pickup scenes found under %s." % PICKUP_SCENE_ROOT)
		return

	for pickup_path in pickup_paths:
		var packed_scene := load(pickup_path) as PackedScene
		if packed_scene == null:
			_fail("Could not load pickup scene: %s" % pickup_path)
			return
		var pickup := packed_scene.instantiate()
		if pickup == null:
			_fail("Could not instantiate pickup scene: %s" % pickup_path)
			return
		if not _script_inherits(pickup, PICKUP_ITEM_SCRIPT):
			_fail("%s should use PickupItem or a PickupItem-compatible script." % pickup_path)
			pickup.queue_free()
			return
		var item_data := pickup.get("item_data") as Resource
		if item_data == null:
			_fail("%s should assign item_data." % pickup_path)
			pickup.queue_free()
			return
		if not _script_inherits(item_data, ITEM_DATA_SCRIPT):
			_fail("%s item_data should inherit ItemData." % pickup_path)
			pickup.queue_free()
			return
		if String(item_data.get("item_type")) != "weapon":
			_fail("%s weapon pickup should use item_type weapon." % pickup_path)
			pickup.queue_free()
			return
		pickup.queue_free()

	var weapon_data_paths := _find_paths(WEAPON_DATA_ROOT, "_data.tres")
	for weapon_path in weapon_data_paths:
		var weapon_data := load(weapon_path) as Resource
		if weapon_data == null:
			_fail("Could not load weapon data: %s" % weapon_path)
			return
		if not _script_inherits(weapon_data, ITEM_DATA_SCRIPT):
			_fail("%s should inherit ItemData." % weapon_path)
			return
		if String(weapon_data.get("item_type")) != "weapon":
			_fail("%s should keep item_type weapon." % weapon_path)
			return
		if String(weapon_data.get("pickup_scene_path")) == "":
			_fail("%s should define pickup_scene_path." % weapon_path)
			return

	print("Pickup item baseline is valid.")
	quit()


func _find_paths(root_path: String, suffix: String) -> Array[String]:
	var paths: Array[String] = []
	_collect_paths(root_path, suffix, paths)
	paths.sort()
	return paths


func _collect_paths(path: String, suffix: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var child_path := path.path_join(file_name)
		if dir.current_is_dir():
			_collect_paths(child_path, suffix, paths)
		elif file_name.ends_with(suffix):
			paths.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _script_inherits(object: Object, expected_script: Script) -> bool:
	if object == null or expected_script == null:
		return false

	var script := object.get_script() as Script
	while script != null:
		if script == expected_script or script.resource_path == expected_script.resource_path:
			return true
		script = script.get_base_script()
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
