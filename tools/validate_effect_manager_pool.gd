@tool
extends SceneTree

const IMPACT_SCENE_PATH := "res://scenes/effects/projectiles/bullet_wall_impact.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var effect_manager := get_root().get_node_or_null("EffectManager")
	var impact_scene := load(IMPACT_SCENE_PATH) as PackedScene
	if effect_manager == null or impact_scene == null:
		_fail(null, "Could not load EffectManager or impact scene.")
		return

	var root := Node2D.new()
	get_root().add_child(root)

	for index in 5:
		var impact: Node2D = effect_manager.spawn_effect(impact_scene, root, "bullet_impact", 3)
		if impact == null:
			_fail(root, "EffectManager should spawn impact effects.")
			return

	if effect_manager.get_active_count("bullet_impact") != 3:
		_fail(root, "EffectManager should keep active effects under the configured limit.")
		return

	print("EffectManager pool is valid.")
	root.queue_free()
	quit()


func _fail(root: Node, message: String) -> void:
	push_error(message)
	if root != null:
		root.queue_free()
	quit(1)
