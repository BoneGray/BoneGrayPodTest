@tool
extends SceneTree

const ENEMY_SCENE_PATH := "res://scenes/characters/enemy.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if enemy_scene == null or player_scene == null:
		push_error("Could not load enemy or player scene.")
		quit(1)
		return

	var root := Node2D.new()
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	var player := player_scene.instantiate() as CharacterBody2D
	get_root().add_child(root)
	root.add_child(enemy)
	root.add_child(player)

	await process_frame

	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(14, 0)
	enemy.call("set_target", player)

	var hit_count := 0
	enemy.attack_hit.connect(func(_target: Node) -> void:
		hit_count += 1
	)
	var starting_health: int = player.call("get_current_health")
	var saw_attack_window := false
	var saw_attack_geometry_hit := false
	for i in 90:
		await physics_frame
		var attack_area := enemy.get_node("AttackArea2D") as Area2D
		var attack_shape := enemy.get_node("AttackArea2D/CollisionShape2D") as CollisionShape2D
		saw_attack_window = saw_attack_window or (attack_area.monitoring and not attack_shape.disabled)
		saw_attack_geometry_hit = saw_attack_geometry_hit or enemy.call("_is_target_in_attack_area", player)
		if player.call("get_current_health") < starting_health:
			print("Enemy attack AI is valid.")
			root.queue_free()
			quit()
			return

	var attack_area := enemy.get_node("AttackArea2D") as Area2D
	var attack_shape := enemy.get_node("AttackArea2D/CollisionShape2D") as CollisionShape2D
	var sprite := enemy.get_node("Sprite") as AnimatedSprite2D
	push_error("Enemy attack AI should damage the player after entering an attack slot. State: %s, direction: %s, action: %s, elapsed: %.2f, animation: %s, attack_monitoring: %s, attack_disabled: %s, saw_attack_window: %s, saw_geometry_hit: %s, hit_count: %d, player_has_take_damage: %s, player_health: %d/%d" % [enemy.get("state"), enemy.get("current_direction"), enemy.get("current_attack_action"), enemy.get("attack_elapsed"), sprite.animation, attack_area.monitoring, attack_shape.disabled, saw_attack_window, saw_attack_geometry_hit, hit_count, player.has_method("take_damage"), player.call("get_current_health"), starting_health])
	root.queue_free()
	quit(1)
