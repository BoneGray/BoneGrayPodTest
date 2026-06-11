extends Node

@export_group("Limits")
## 同时存在的枪口火焰上限。超过上限时会回收最旧的枪口火焰。
@export var muzzle_flash_limit := 20
## 同时存在的弹壳上限。超过上限时会回收最旧的弹壳。
@export var bullet_casing_limit := 40
## 同时存在的弹孔上限。超过上限时会回收最旧的弹孔。
@export var bullet_impact_limit := 50

const CATEGORY_MUZZLE_FLASH := "muzzle_flash"
const CATEGORY_BULLET_CASING := "bullet_casing"
const CATEGORY_BULLET_IMPACT := "bullet_impact"

var _pools := {}
var _active_by_category := {}
var _scene_path_by_node := {}
var _category_by_node := {}
var _total_spawned_by_category := {}


func spawn_effect(effect_scene: PackedScene, parent: Node, category := "", limit := -1) -> Node2D:
	if effect_scene == null or parent == null:
		return null

	var scene_path := effect_scene.resource_path
	var effect := _take_from_pool(scene_path) as Node2D
	if effect == null:
		effect = effect_scene.instantiate() as Node2D
	if effect == null:
		return null

	if effect.get_parent() != null:
		effect.get_parent().remove_child(effect)
	parent.add_child(effect)

	effect.show()
	effect.process_mode = Node.PROCESS_MODE_INHERIT
	_scene_path_by_node[effect] = scene_path
	if category != "":
		_total_spawned_by_category[category] = int(_total_spawned_by_category.get(category, 0)) + 1
	_register_active(effect, category, limit)
	if effect.has_method("reset_pool_state"):
		effect.reset_pool_state()
	return effect


func recycle_effect(effect: Node) -> void:
	if effect == null or not is_instance_valid(effect):
		return

	_unregister_active(effect)
	var scene_path := String(_scene_path_by_node.get(effect, ""))
	if scene_path == "":
		effect.queue_free()
		return

	if effect.has_method("on_recycled"):
		effect.on_recycled()
	effect.hide()
	effect.process_mode = Node.PROCESS_MODE_DISABLED
	if effect.get_parent() != null:
		effect.get_parent().remove_child(effect)
	add_child(effect)

	if not _pools.has(scene_path):
		_pools[scene_path] = []
	(_pools[scene_path] as Array).append(effect)


func get_default_limit(category: String) -> int:
	if category == CATEGORY_MUZZLE_FLASH:
		return muzzle_flash_limit
	if category == CATEGORY_BULLET_CASING:
		return bullet_casing_limit
	if category == CATEGORY_BULLET_IMPACT:
		return bullet_impact_limit
	return -1


func get_active_count(category: String) -> int:
	return (_active_by_category.get(category, []) as Array).size()


func get_pool_count(scene_path: String) -> int:
	return (_pools.get(scene_path, []) as Array).size()


func get_total_spawned(category: String) -> int:
	return int(_total_spawned_by_category.get(category, 0))


func reset_debug_counts() -> void:
	_total_spawned_by_category.clear()


func _take_from_pool(scene_path: String) -> Node:
	var pool := _pools.get(scene_path, []) as Array
	while not pool.is_empty():
		var effect := pool.pop_back() as Node
		if effect != null and is_instance_valid(effect):
			return effect
	return null


func _register_active(effect: Node, category: String, limit: int) -> void:
	if category == "":
		return

	if limit < 0:
		limit = get_default_limit(category)
	if not _active_by_category.has(category):
		_active_by_category[category] = []

	var active := _active_by_category[category] as Array
	active.append(effect)
	_category_by_node[effect] = category

	while limit >= 0 and active.size() > limit:
		var oldest := active.pop_front() as Node
		_category_by_node.erase(oldest)
		recycle_effect(oldest)


func _unregister_active(effect: Node) -> void:
	var category := String(_category_by_node.get(effect, ""))
	if category == "":
		return

	var active := _active_by_category.get(category, []) as Array
	active.erase(effect)
	_category_by_node.erase(effect)
