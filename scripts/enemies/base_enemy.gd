extends CharacterBody2D
class_name BaseEnemy

const ESM = preload("res://scripts/enemies/enemy_state_machine.gd")
const ECC = preload("res://scripts/enemies/enemy_combat_controller.gd")
const EMC = preload("res://scripts/enemies/enemy_movement_controller.gd")
const EWC = preload("res://scripts/enemies/enemy_weapon_controller.gd")

signal died(enemy: Node)
signal health_changed(current: int, maximum: int)
signal attack_hit(target: Node)

enum State {
	IDLE,
	CHASE,
	APPROACH_ATTACK_SLOT,
	ATTACK,
	HURT,
	DEAD,
	PATROL,
}

const ATTACK_SLOT_DIRECTIONS := [
	"side",
	"side_left",
	"down",
	"up",
]

@export_group("Stats")
## 敌人属性资源，提供生命值、移动速度、攻击配置、发现范围和基础战斗数值。
@export var stats: Resource

@export_group("Targeting")
## 敌人会搜索和攻击的目标组名，通常为 player。
@export var target_group := "player"
## 初始状态。测试场景中可用来让敌人从巡逻、待机或追击等状态开始。
@export var start_state := State.IDLE
## 是否自动搜索目标。关闭后需要外部脚本主动设置 target。
@export var auto_acquire_target := true

@export_group("Navigation")
## 路径刷新间隔，单位为秒。值越小越灵敏，但更新更频繁。
@export var path_refresh_interval := 0.25
## 是否使用 NavigationAgent2D。当前原型默认关闭，使用直接移动和简单避障逻辑。
@export var use_navigation_agent := false
## 是否启用敌人之间的分离推力，避免多只敌人完全重叠。
@export var use_separation := true
## 近距离直接追击范围，单位为像素。目标很近时减少路径抖动。
@export var direct_chase_range := 48.0

@export_group("Debug")
## 是否在控制台输出受伤和生命值变化日志。
@export var damage_log_enabled := true

@export_group("Attack Slot")
## 开始寻找攻击站位时，在基础攻击范围外额外允许的距离，单位为像素。
@export var attack_slot_start_range_padding := 24.0
## 离开攻击站位逻辑时，在基础攻击范围外额外允许的距离，单位为像素。
@export var attack_slot_exit_range_padding := 36.0
## 抵达攻击站位的判定距离，单位为像素。
@export var attack_slot_arrive_distance := 6.0
## 寻找攻击站位的超时时间，单位为秒。超时后会重新评估站位。
@export var attack_slot_timeout := 1.0
## 判断敌人是否有移动进展的最小距离，单位为像素。
@export var attack_slot_progress_epsilon := 0.5
## 判断攻击站位是否可达的容忍距离，单位为像素。
@export var attack_slot_reachable_distance := 10.0

@export_group("Idle Patrol")
## 没有目标时是否在待机和巡逻之间随机切换。
@export var idle_patrol_enabled := true
## 待机最短时间，单位为秒。
@export var idle_duration_min := 0.8
## 待机最长时间，单位为秒。
@export var idle_duration_max := 1.8
## 巡逻最短时间，单位为秒。
@export var patrol_duration_min := 1.4
## 巡逻最长时间，单位为秒。
@export var patrol_duration_max := 2.4
## 巡逻速度倍率。相对于敌人正常移动速度。
@export var patrol_speed_scale := 0.6

@export_group("Weapon Retrieval")
## 捡回自身武器的距离，单位为像素。
@export var weapon_pickup_range := 8.0
## 没有武器时，如果玩家进入该范围，敌人会优先近身攻击而不是继续捡武器。
@export var no_weapon_close_attack_range := 24.0
## 追取武器的超时时间，单位为秒。超时后会重新评估目标。
@export var weapon_retrieval_timeout := 1.5
## 判断追取武器是否有移动进展的最小距离，单位为像素。
@export var weapon_retrieval_progress_epsilon := 0.5

@export_group("Line Of Sight")
## 攻击视线阻挡检测使用的碰撞层掩码。用于避免隔着墙攻击或投掷。
@export var attack_blocked_by_mask := 1

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_collision_shape: CollisionShape2D = $BodyCollisionShape2D
@onready var hitbox_area: Area2D = $HitboxArea2D
@onready var attack_area: Area2D = $AttackArea2D
@onready var attack_shape: CollisionShape2D = $AttackArea2D/CollisionShape2D
@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hurt_flash_feedback: Node = get_node_or_null("HurtFlashFeedback")

var health := 1
var state := State.IDLE
var target: Node2D
var current_direction := "down"
var last_horizontal_direction := "side"
var attack_cooldown_remaining := 0.0
var path_refresh_remaining := 0.0
var navigation_destination := Vector2.INF
var idle_patrol_remaining := 0.0
var patrol_direction := Vector2.DOWN
var attack_slot_direction := "down"
var attack_slot_position := Vector2.ZERO
var has_attack_slot := false
var attack_slot_elapsed := 0.0
var attack_slot_stuck_elapsed := 0.0
var attack_slot_last_distance := INF
var attack_slot_excluded_directions: Array[String] = []
var attack_elapsed := 0.0
var current_attack_action := ""
var current_attack_type := "melee"
var current_attack_profile := {}
var has_weapon := true
var weapon_pickup: Node2D
var projectile_attack_spawned := false
var weapon_retrieval_elapsed := 0.0
var weapon_retrieval_last_distance := INF
var leap_start_position := Vector2.ZERO
var leap_end_position := Vector2.ZERO
var leap_duration := 0.0
var _hit_targets: Array[Node] = []
var _default_collision_layer := 0
var _default_collision_mask := 0
var _default_hitbox_monitoring := true
var _default_hitbox_monitorable := true
var _default_attack_area_position := Vector2.ZERO
var _attack_slot_manager: Node
var _state_machine := ESM.new()
var _combat_controller := ECC.new()
var _movement_controller := EMC.new()
var _weapon_controller := EWC.new()

var attack_hit_frames := {
	"attack_first": [4],
	"attack_second": [7, 8],
}

var attack_hit_windows := {
	"attack_first": [Vector2(0.2, 0.65)],
	"attack_second": [Vector2(0.3, 0.9)],
}


func _ready() -> void:
	_cache_lifecycle_defaults()
	_attack_slot_manager = get_tree().root.get_node_or_null("EnemyAttackSlotManager")
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_player_finished):
		animation_player.animation_finished.connect(_on_animation_player_finished)
	if not sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		sprite.frame_changed.connect(_on_sprite_frame_changed)
	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	activate(global_position, stats)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		return

	var previous_position := global_position
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	_advance_combat_strategy_runtime(delta)
	_advance_movement_runtime(delta)
	if state == State.ATTACK:
		_advance_combat_runtime(delta)
	if target != null and not _is_valid_target(target):
		_clear_target()
	if target == null and auto_acquire_target:
		_acquire_target()

	if target == null and state != State.ATTACK:
		if _should_retrieve_weapon_without_target():
			_update_weapon_retrieval(delta)
			move_and_slide()
			return
		_update_idle_patrol(delta)
		move_and_slide()
		return

	if state == State.CHASE or state == State.APPROACH_ATTACK_SLOT:
		_update_combat_movement(delta)
	elif state == State.ATTACK:
		_update_attack_motion(delta)
		_try_spawn_projectile_attack()
		if not _uses_body_motion_hit_detection() and _is_current_attack_hit_window():
			_sync_attack_area_to_direction()
			_apply_attack_hits()
		if not _is_attack_animation_playing() and not attack_area.monitoring:
			_finish_attack()
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if state == State.ATTACK and _uses_body_motion_hit_detection():
		_apply_body_motion_attack_hits(previous_position)
	else:
		_apply_active_attack_hits()


func _process(_delta: float) -> void:
	if state == State.ATTACK:
		_apply_active_attack_hits()


func configure_stats(new_stats: Resource) -> void:
	stats = new_stats
	health = get_max_health()
	health_changed.emit(health, get_max_health())


func _change_state(next_state: int) -> bool:
	if not _state_machine.change_to(next_state):
		return false
	state = _state_machine.current_state
	return true


func _enter_idle_state(reset_idle_timer := false) -> void:
	_change_state(State.IDLE)
	velocity = Vector2.ZERO
	sprite.position = Vector2.ZERO
	if reset_idle_timer:
		idle_patrol_remaining = _random_idle_duration()
	_play_idle()


func _enter_chase_state(face_target := true, play_idle := false) -> void:
	_change_state(State.CHASE)
	velocity = Vector2.ZERO
	if face_target and target != null:
		current_direction = _direction_from_vector(target.global_position - global_position)
	if play_idle:
		sprite.position = Vector2.ZERO
		_play_idle()


func _enter_patrol_state() -> void:
	_change_state(State.PATROL)
	patrol_direction = _random_patrol_direction()
	idle_patrol_remaining = _random_patrol_duration()


func _enter_dead_state() -> void:
	_release_attack_slot()
	_change_state(State.DEAD)
	velocity = Vector2.ZERO


func _sync_combat_runtime_from_controller() -> void:
	attack_elapsed = _combat_controller.attack_elapsed
	current_attack_action = _combat_controller.current_attack_action
	current_attack_type = _combat_controller.current_attack_type
	current_attack_profile = _combat_controller.current_attack_profile
	projectile_attack_spawned = _combat_controller.projectile_attack_spawned
	_hit_targets = _combat_controller.hit_targets


func _reset_combat_runtime(clear_strategy_runtime := false) -> void:
	_combat_controller.reset(clear_strategy_runtime)
	_sync_combat_runtime_from_controller()


func _begin_combat_runtime(action_name: String, profile: Dictionary) -> void:
	_combat_controller.begin_attack(action_name, profile)
	_sync_combat_runtime_from_controller()


func _advance_combat_strategy_runtime(delta: float) -> void:
	_combat_controller.advance_runtime(delta)


func _advance_combat_runtime(delta: float) -> void:
	_combat_controller.advance(delta)
	_sync_combat_runtime_from_controller()


func _mark_projectile_attack_spawned() -> void:
	_combat_controller.mark_projectile_spawned()
	_sync_combat_runtime_from_controller()


func _has_hit_target(hit_target: Node) -> bool:
	return _combat_controller.has_hit_target(hit_target)


func _register_hit_target(hit_target: Node) -> void:
	_combat_controller.register_hit_target(hit_target)
	_sync_combat_runtime_from_controller()


func _sync_movement_runtime_from_controller() -> void:
	path_refresh_remaining = _movement_controller.path_refresh_remaining
	navigation_destination = _movement_controller.navigation_destination


func _reset_movement_path() -> void:
	_movement_controller.reset_path()
	_sync_movement_runtime_from_controller()


func _advance_movement_runtime(delta: float) -> void:
	_movement_controller.advance_path_refresh(delta)
	_sync_movement_runtime_from_controller()


func _sync_weapon_runtime_from_controller() -> void:
	has_weapon = _weapon_controller.has_weapon
	weapon_pickup = _weapon_controller.weapon_pickup
	weapon_retrieval_elapsed = _weapon_controller.weapon_retrieval_elapsed
	weapon_retrieval_last_distance = _weapon_controller.weapon_retrieval_last_distance


func _reset_weapon_runtime(armed := true) -> void:
	_weapon_controller.reset(armed)
	_sync_weapon_runtime_from_controller()


func activate(spawn_position: Vector2, new_stats: Resource = null) -> void:
	_release_attack_slot()
	if new_stats != null:
		stats = new_stats

	_state_machine.reset(start_state)
	global_position = spawn_position
	show()
	add_to_group("enemy")
	_change_state(start_state)
	health = get_max_health()
	target = null
	velocity = Vector2.ZERO
	current_direction = "down"
	last_horizontal_direction = "side"
	idle_patrol_remaining = _random_idle_duration()
	patrol_direction = _random_patrol_direction()
	attack_slot_direction = "down"
	attack_slot_position = spawn_position
	has_attack_slot = false
	attack_slot_elapsed = 0.0
	attack_slot_stuck_elapsed = 0.0
	attack_slot_last_distance = INF
	attack_slot_excluded_directions.clear()
	_reset_combat_runtime(true)
	_clear_weapon_pickup()
	_reset_weapon_runtime(true)
	leap_start_position = spawn_position
	leap_end_position = spawn_position
	leap_duration = 0.0
	attack_cooldown_remaining = 0.0
	_reset_movement_path()
	collision_layer = _default_collision_layer
	collision_mask = _default_collision_mask
	hitbox_area.monitoring = _default_hitbox_monitoring
	hitbox_area.monitorable = _default_hitbox_monitorable
	attack_area.position = _default_attack_area_position
	if animation_player != null:
		animation_player.stop()
	sprite.modulate = Color.WHITE
	sprite.position = Vector2.ZERO
	_set_attack_active(false)
	set_physics_process(true)
	_play_idle()
	health_changed.emit(health, get_max_health())
	if auto_acquire_target:
		call_deferred("_acquire_target")


func deactivate() -> void:
	_enter_dead_state()
	target = null
	attack_cooldown_remaining = 0.0
	_reset_movement_path()
	has_attack_slot = false
	attack_slot_elapsed = 0.0
	attack_slot_stuck_elapsed = 0.0
	attack_slot_last_distance = INF
	attack_slot_excluded_directions.clear()
	_reset_combat_runtime(true)
	_clear_weapon_pickup()
	leap_start_position = global_position
	leap_end_position = global_position
	leap_duration = 0.0
	remove_from_group("enemy")
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	hitbox_area.monitoring = false
	hitbox_area.monitorable = false
	if animation_player != null:
		animation_player.stop()
	sprite.stop()
	sprite.position = Vector2.ZERO
	_set_attack_active(false)
	hide()


func set_target(new_target: Node2D) -> void:
	if new_target != null and not _is_valid_target(new_target):
		new_target = null
	if new_target == target:
		return
	if new_target != target:
		_release_attack_slot()
		attack_slot_excluded_directions.clear()
	target = new_target
	if state != State.DEAD and state != State.ATTACK:
		_change_state(State.CHASE if target != null else State.IDLE)
		_reset_movement_path()
		idle_patrol_remaining = _random_idle_duration()


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	var actual_damage := maxi(amount - get_defense(), 1)
	health = maxi(health - actual_damage, 0)
	if damage_log_enabled:
		print("%s 被打到了，受到 %d 点伤害，剩余血量 %d/%d" % [get_display_name(), actual_damage, health, get_max_health()])
	health_changed.emit(health, get_max_health())
	_flash_hurt()
	if health == 0:
		die()


func die() -> void:
	if state == State.DEAD:
		return

	_enter_dead_state()
	_disable_combat_logic()
	_play_death()
	died.emit(self)


func can_attack(action_name := "") -> bool:
	if target == null or attack_cooldown_remaining > 0.0:
		return false
	if action_name == "":
		for action in get_attack_actions():
			if _can_use_attack_action(action):
				return true
		return false
	return _can_use_attack_action(action_name)


func is_alive() -> bool:
	return state != State.DEAD


func begin_attack(animation_name := "attack_first") -> void:
	if state == State.DEAD:
		return

	animation_name = _directional_animation_name(animation_name)
	var attack_action := _attack_action_from_animation(animation_name)
	if not _can_use_attack_action(attack_action):
		current_attack_action = ""
		return

	_change_state(State.ATTACK)
	attack_cooldown_remaining = get_attack_cooldown()
	_begin_combat_runtime(attack_action, get_attack_profile(attack_action))
	_prepare_attack_motion()
	_sync_attack_area_to_direction()
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
	else:
		_finish_attack()


func _on_animation_player_finished(animation_name: StringName) -> void:
	if state == State.ATTACK and _is_attack_animation(animation_name):
		_finish_attack()


func _on_sprite_frame_changed() -> void:
	if state != State.ATTACK or _uses_body_motion_hit_detection():
		return

	if _combat_controller.is_animation_hit_frame(sprite.animation, sprite.frame, attack_hit_frames):
		_sync_attack_area_to_direction()
		_apply_attack_hits()


func _on_sprite_animation_finished() -> void:
	if state == State.ATTACK and _is_attack_animation(sprite.animation):
		_finish_attack()


func _finish_attack() -> void:
	_set_attack_active(false)
	var recovery := _combat_controller.get_recovery()
	if recovery > 0.0:
		attack_cooldown_remaining = maxf(attack_cooldown_remaining, recovery)
	_reset_combat_runtime()
	leap_duration = 0.0
	if state == State.DEAD:
		return

	if target == null:
		_enter_idle_state()
		return

	_enter_chase_state(true, true)


func _clear_target() -> void:
	_release_attack_slot()
	target = null
	attack_slot_excluded_directions.clear()
	velocity = Vector2.ZERO
	_reset_movement_path()
	_reset_combat_runtime()
	leap_duration = 0.0
	_set_attack_active(false)
	if animation_player != null:
		animation_player.stop()
	if state != State.DEAD:
		_enter_idle_state(true)


func _is_attack_animation(animation_name: StringName) -> bool:
	return _combat_controller.is_attack_animation(animation_name)


func _attack_action_from_animation(animation_name: StringName) -> String:
	return _combat_controller.attack_action_from_animation(animation_name)


func _is_current_attack_hit_window() -> bool:
	return _combat_controller.is_in_hit_window(attack_hit_windows)


func _is_attack_animation_playing() -> bool:
	if animation_player != null and animation_player.is_playing():
		return _is_attack_animation(animation_player.current_animation)
	if sprite.is_playing():
		return _is_attack_animation(sprite.animation)
	return false


func _select_attack_action() -> String:
	return _combat_controller.select_attack_action(get_attack_actions(), _is_attack_action_ready, "attack_first")


func _is_attack_action_ready(action: String) -> bool:
	var animation_name := _directional_animation_name(action)
	return _has_animation(animation_name) and _can_use_attack_action(action)


func _has_animation(animation_name: String) -> bool:
	if animation_player != null and animation_player.has_animation(animation_name):
		return true
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name)


func get_max_health() -> int:
	return stats.max_health if stats != null else 30


func get_current_health() -> int:
	return health


func get_display_name() -> String:
	return stats.display_name if stats != null else name


func get_move_speed() -> float:
	return stats.move_speed if stats != null else 45.0


func get_defense() -> int:
	return stats.defense if stats != null else 0


func get_attack_power() -> int:
	return stats.attack_power if stats != null else 8


func get_attack_actions() -> Array[String]:
	if stats != null:
		var configured_actions: Variant = stats.get("attack_actions")
		if configured_actions is Array and not configured_actions.is_empty():
			var actions: Array[String] = []
			for action in configured_actions:
				actions.append(String(action))
			return actions
	return ["attack_first"]


func get_attack_profile(action_name: String) -> Dictionary:
	if stats != null:
		var profiles: Variant = stats.get("attack_profiles")
		if profiles is Dictionary and profiles.has(action_name):
			var profile: Variant = profiles[action_name]
			if profile is Dictionary:
				return profile
			if profile is Resource:
				return _attack_profile_resource_to_dictionary(profile)
	return {"type": "melee"}


func _attack_profile_resource_to_dictionary(profile: Resource) -> Dictionary:
	if profile == null:
		return {"type": "melee"}
	if profile.has_method("to_dictionary"):
		var profile_data: Variant = profile.to_dictionary()
		if profile_data is Dictionary:
			return profile_data
	var fallback := {}
	var attack_type: Variant = profile.get("attack_type")
	if attack_type != null:
		fallback["type"] = String(attack_type)
	var damage_value: Variant = profile.get("damage")
	if damage_value != null and int(damage_value) > 0:
		fallback["damage"] = int(damage_value)
	var cooldown_value: Variant = profile.get("cooldown")
	if cooldown_value != null and float(cooldown_value) > 0.0:
		fallback["special_cooldown"] = float(cooldown_value)
	if fallback.is_empty():
		fallback["type"] = "melee"
	return fallback


func get_detect_range() -> float:
	return stats.detect_range if stats != null else 96.0


func get_lose_target_range() -> float:
	return stats.lose_target_range if stats != null else 144.0


func get_attack_range() -> float:
	return stats.attack_range if stats != null else 18.0


func get_attack_cooldown() -> float:
	return stats.attack_cooldown if stats != null else 1.2


func get_separation_radius() -> float:
	return stats.separation_radius if stats != null else 16.0


func get_separation_strength() -> float:
	return stats.separation_strength if stats != null else 0.35


func get_weapon_pickup_range() -> float:
	return float(stats.get("weapon_pickup_range")) if stats != null else weapon_pickup_range


func get_no_weapon_close_attack_range() -> float:
	return float(stats.get("no_weapon_close_attack_range")) if stats != null else no_weapon_close_attack_range


func get_weapon_retrieval_timeout() -> float:
	return float(stats.get("weapon_retrieval_timeout")) if stats != null else weapon_retrieval_timeout


func get_weapon_retrieval_progress_epsilon() -> float:
	return float(stats.get("weapon_retrieval_progress_epsilon")) if stats != null else weapon_retrieval_progress_epsilon


func _update_combat_movement(_delta: float) -> void:
	if target == null:
		_enter_idle_state()
		return

	var to_target := target.global_position - global_position
	if to_target.length() > get_lose_target_range():
		set_target(null)
		_enter_idle_state()
		return

	if _should_retrieve_weapon(to_target):
		_update_weapon_retrieval(_delta)
		return

	if _should_try_special_attack_before_melee():
		var special_attack := _select_available_special_attack()
		if special_attack != "":
			_release_attack_slot()
			attack_slot_excluded_directions.clear()
			current_direction = _direction_from_vector(to_target)
			_sync_attack_area_to_direction()
			velocity = Vector2.ZERO
			begin_attack(special_attack)
			return

	if _should_use_attack_slot(to_target):
		_update_attack_slot(to_target, _delta)
		current_direction = attack_slot_direction
		_sync_attack_area_to_direction()

		var melee_attack := _select_available_melee_attack()
		if has_attack_slot and melee_attack != "":
			velocity = Vector2.ZERO
			begin_attack(melee_attack)
			return

		var to_slot := attack_slot_position - global_position
		if _should_give_up_attack_slot(to_slot):
			_exclude_current_attack_slot()
			_enter_chase_state(false, true)
			return

		if to_slot.length() <= attack_slot_arrive_distance:
			velocity = Vector2.ZERO
			_play_idle()
			return

		var slot_direction := _get_path_direction(attack_slot_position, to_slot)
		velocity = slot_direction * get_move_speed()
		_play_walk(slot_direction)
		return

	if not _should_try_special_attack_before_melee():
		var special_attack := _select_available_special_attack()
		if special_attack != "":
			_release_attack_slot()
			attack_slot_excluded_directions.clear()
			current_direction = _direction_from_vector(to_target)
			_sync_attack_area_to_direction()
			velocity = Vector2.ZERO
			begin_attack(special_attack)
			return

	_change_state(State.CHASE)
	_release_attack_slot()
	attack_slot_excluded_directions.clear()
	var direction := _get_path_direction(target.global_position, to_target)
	if use_separation:
		var separation := _get_separation_direction()
		if separation != Vector2.ZERO:
			direction = (direction + separation * get_separation_strength()).normalized()

	velocity = direction * get_move_speed()
	current_direction = _direction_from_vector(direction)
	_play_walk(direction)


func _should_try_special_attack_before_melee() -> bool:
	return get_attack_selection_order() == "special_first"


func get_attack_selection_order() -> String:
	if stats != null:
		var configured_order: Variant = stats.get("attack_selection_order")
		if configured_order is String and configured_order != "":
			return configured_order
	return "special_first"


func get_default_attack_weight() -> float:
	if stats != null:
		return maxf(float(stats.get("default_attack_weight")), 0.0)
	return 1.0


func get_special_attack_weight_multiplier() -> float:
	if stats != null:
		return maxf(float(stats.get("special_attack_weight_multiplier")), 0.0)
	return 1.0


func get_melee_attack_weight_multiplier() -> float:
	if stats != null:
		return maxf(float(stats.get("melee_attack_weight_multiplier")), 0.0)
	return 1.0


func _should_use_attack_slot(to_target: Vector2) -> bool:
	if not _has_attack_line_of_sight():
		_release_attack_slot()
		return false
	if state == State.APPROACH_ATTACK_SLOT:
		var should_keep_slot := to_target.length() <= get_attack_range() + attack_slot_exit_range_padding
		if not should_keep_slot:
			_release_attack_slot()
		return should_keep_slot
	return to_target.length() <= get_attack_range() + attack_slot_start_range_padding


func _update_attack_slot(to_target: Vector2, delta: float) -> void:
	var was_approaching := state == State.APPROACH_ATTACK_SLOT
	var preferred_direction := _direction_from_vector(to_target)
	var should_reselect_slot := has_attack_slot and _is_opposite_direction(preferred_direction, attack_slot_direction)
	_change_state(State.APPROACH_ATTACK_SLOT)
	if not was_approaching or not has_attack_slot or should_reselect_slot:
		if attack_slot_excluded_directions.size() >= ATTACK_SLOT_DIRECTIONS.size():
			attack_slot_excluded_directions.clear()
		if should_reselect_slot:
			_release_attack_slot()
		var claimed_direction := _claim_attack_slot(preferred_direction)
		has_attack_slot = claimed_direction != ""
		attack_slot_direction = claimed_direction if has_attack_slot else preferred_direction
		attack_slot_elapsed = 0.0
		attack_slot_stuck_elapsed = 0.0
		attack_slot_last_distance = INF
	attack_slot_position = _get_attack_slot_position(attack_slot_direction)
	if has_attack_slot:
		attack_slot_elapsed += delta
		_update_attack_slot_progress(global_position.distance_to(attack_slot_position), delta)
		if not _is_attack_slot_reachable(attack_slot_position):
			_exclude_current_attack_slot()


func _claim_attack_slot(preferred_direction: String) -> String:
	if _attack_slot_manager != null and _attack_slot_manager.has_method("claim_slot"):
		return _attack_slot_manager.claim_slot(self, target, preferred_direction, attack_slot_excluded_directions)
	if preferred_direction in attack_slot_excluded_directions:
		return ""
	return preferred_direction


func _release_attack_slot() -> void:
	if _attack_slot_manager != null and _attack_slot_manager.has_method("release_slot"):
		_attack_slot_manager.release_slot(self)
	has_attack_slot = false
	attack_slot_elapsed = 0.0
	attack_slot_stuck_elapsed = 0.0
	attack_slot_last_distance = INF


func _exclude_current_attack_slot() -> void:
	if has_attack_slot and not attack_slot_direction in attack_slot_excluded_directions:
		attack_slot_excluded_directions.append(attack_slot_direction)
	_release_attack_slot()
	_reset_movement_path()


func _should_give_up_attack_slot(to_slot: Vector2) -> bool:
	if not has_attack_slot:
		return false
	return attack_slot_stuck_elapsed >= attack_slot_timeout and to_slot.length() > attack_slot_arrive_distance


func _update_attack_slot_progress(distance_to_slot: float, delta: float) -> void:
	if attack_slot_last_distance == INF:
		attack_slot_last_distance = distance_to_slot
		attack_slot_stuck_elapsed = 0.0
		return

	if distance_to_slot < attack_slot_last_distance - attack_slot_progress_epsilon:
		attack_slot_stuck_elapsed = 0.0
	else:
		attack_slot_stuck_elapsed += delta
	attack_slot_last_distance = distance_to_slot


func _is_attack_slot_reachable(slot_position: Vector2) -> bool:
	if navigation_agent == null or not use_navigation_agent:
		return true

	var navigation_map := navigation_agent.get_navigation_map()
	var path := NavigationServer2D.map_get_path(navigation_map, global_position, slot_position, true)
	if path.size() < 2:
		return false

	var final_position := path[path.size() - 1]
	return final_position.distance_to(slot_position) <= attack_slot_reachable_distance


func _get_attack_slot_position(direction: String) -> Vector2:
	if not has_attack_slot:
		return _get_attack_wait_position()

	var attack_offset := _get_attack_area_position_for_direction(direction)
	if attack_offset == Vector2.ZERO:
		attack_offset = _direction_to_vector(direction) * minf(get_attack_range(), 16.0)
	return target.global_position - attack_offset


func _get_attack_wait_position() -> Vector2:
	if _attack_slot_manager != null and _attack_slot_manager.has_method("get_wait_position"):
		return _attack_slot_manager.get_wait_position(self, target)
	return target.global_position - _direction_to_vector(attack_slot_direction) * direct_chase_range


func _direction_to_vector(direction: String) -> Vector2:
	if direction == "side":
		return Vector2.RIGHT
	if direction == "side_left":
		return Vector2.LEFT
	if direction == "up":
		return Vector2.UP
	return Vector2.DOWN


func _is_opposite_direction(first_direction: String, second_direction: String) -> bool:
	if first_direction == second_direction:
		return false
	return _direction_to_vector(first_direction).dot(_direction_to_vector(second_direction)) < -0.5


func _acquire_target() -> void:
	if state == State.DEAD:
		return

	var candidates := _get_target_candidates()
	var closest: Node2D
	var detect_range_squared := get_detect_range() * get_detect_range()
	var closest_distance := detect_range_squared
	for candidate in candidates:
		var candidate_node := candidate as Node2D
		if not _is_valid_target(candidate_node):
			continue
		var distance := global_position.distance_squared_to(candidate_node.global_position)
		if distance <= closest_distance:
			closest = candidate_node
			closest_distance = distance

	set_target(closest)


func _get_target_candidates() -> Array[Node]:
	var candidates := get_tree().get_nodes_in_group(target_group)
	if not candidates.is_empty():
		return candidates

	var fallback_candidates: Array[Node] = []
	_collect_group_nodes(get_tree().root, fallback_candidates)
	return fallback_candidates


func _is_valid_target(candidate: Node) -> bool:
	var candidate_node := candidate as Node2D
	if candidate_node == null or not candidate_node.is_inside_tree():
		return false
	if target_group != "" and not candidate_node.is_in_group(target_group):
		return false
	if candidate_node.has_method("is_alive") and not candidate_node.is_alive():
		return false
	if candidate_node.has_method("get_current_health") and candidate_node.get_current_health() <= 0:
		return false
	return true


func _collect_group_nodes(node: Node, results: Array[Node]) -> void:
	if node.is_in_group(target_group):
		results.append(node)
	for child in node.get_children():
		_collect_group_nodes(child, results)


func _get_path_direction(destination: Vector2, fallback_vector: Vector2) -> Vector2:
	var direction: Vector2 = _movement_controller.get_path_direction(
		navigation_agent,
		use_navigation_agent,
		destination,
		fallback_vector,
		global_position,
		path_refresh_interval
	)
	_sync_movement_runtime_from_controller()
	return direction


func _get_separation_direction() -> Vector2:
	return _movement_controller.get_separation_direction(get_tree().get_nodes_in_group("enemy"), self, get_separation_radius())


func _update_idle_patrol(delta: float) -> void:
	if not idle_patrol_enabled:
		_enter_idle_state()
		return

	idle_patrol_remaining = maxf(idle_patrol_remaining - delta, 0.0)
	if state == State.PATROL:
		if idle_patrol_remaining == 0.0:
			_start_idle()
			return

		velocity = patrol_direction * get_move_speed() * patrol_speed_scale
		current_direction = _direction_from_vector(patrol_direction)
		_play_walk(patrol_direction)
		return

	_enter_idle_state()
	if idle_patrol_remaining == 0.0:
		_start_patrol()


func _start_idle() -> void:
	_enter_idle_state(true)


func _start_patrol() -> void:
	_enter_patrol_state()


func _random_idle_duration() -> float:
	return randf_range(idle_duration_min, maxf(idle_duration_min, idle_duration_max))


func _random_patrol_duration() -> float:
	return randf_range(patrol_duration_min, maxf(patrol_duration_min, patrol_duration_max))


func _random_patrol_direction() -> Vector2:
	var angle := randf() * TAU
	return Vector2(cos(angle), sin(angle)).normalized()


func _set_attack_active(active: bool) -> void:
	attack_area.monitoring = active
	attack_shape.disabled = not active


func _can_use_attack_action(action_name: String) -> bool:
	if target == null or attack_cooldown_remaining > 0.0:
		return false

	var profile := get_attack_profile(action_name)
	if not _is_attack_profile_available_for_weapon_state(profile):
		return false
	if not _is_independent_special_cooldown_ready(action_name, profile):
		return false

	var attack_type := String(profile.get("type", "melee"))
	var distance := global_position.distance_to(target.global_position)
	if attack_type == "leap" or attack_type == "cross" or attack_type == "projectile":
		var min_range := float(profile.get("min_range", 0.0))
		var max_range := float(profile.get("max_range", get_detect_range()))
		if distance < min_range or distance > max_range:
			return false
		if attack_type == "projectile" and not _has_projectile_line_of_sight(profile):
			return false
		return true
	if _is_ready_for_melee_attack_slot():
		return true
	return _has_attack_line_of_sight() and _is_target_in_attack_range(target) and _is_target_in_attack_area(target)


func _select_available_special_attack() -> String:
	return _combat_controller.select_available_attack_by_type(
		get_attack_actions(),
		get_attack_profile,
		_is_attack_profile_available_for_weapon_state,
		_is_attack_action_ready,
		false,
		get_default_attack_weight(),
		get_special_attack_weight_multiplier(),
		target
	)


func _select_available_melee_attack() -> String:
	return _combat_controller.select_available_attack_by_type(
		get_attack_actions(),
		get_attack_profile,
		_is_attack_profile_available_for_weapon_state,
		_is_attack_action_ready,
		true,
		get_default_attack_weight(),
		get_melee_attack_weight_multiplier(),
		target
	)


func _is_attack_profile_available_for_weapon_state(profile: Dictionary) -> bool:
	return _combat_controller.is_profile_available_for_weapon_state(profile, has_weapon)


func _is_independent_special_cooldown_ready(action_name: String, profile: Dictionary) -> bool:
	return _combat_controller.is_independent_special_cooldown_ready(action_name, profile)


func _should_retrieve_weapon(to_target: Vector2) -> bool:
	return _weapon_controller.should_retrieve_weapon(to_target.length(), get_no_weapon_close_attack_range())


func _should_retrieve_weapon_without_target() -> bool:
	return _weapon_controller.should_retrieve_without_target()


func _update_weapon_retrieval(delta: float = 0.0) -> void:
	if not _has_valid_weapon_pickup():
		return

	_release_attack_slot()
	attack_slot_excluded_directions.clear()
	var to_weapon := weapon_pickup.global_position - global_position
	_update_weapon_retrieval_progress(to_weapon.length(), delta)
	if _is_weapon_retrieval_stuck():
		_recover_lost_weapon()
		return

	if to_weapon.length() <= get_weapon_pickup_range():
		_pickup_weapon()
		return

	_change_state(State.CHASE)
	var direction := _get_path_direction(weapon_pickup.global_position, to_weapon)
	velocity = direction * get_move_speed()
	current_direction = _direction_from_vector(direction)
	_play_walk(direction)


func _update_weapon_retrieval_progress(distance: float, delta: float) -> void:
	_weapon_controller.update_retrieval_progress(distance, delta, get_weapon_retrieval_progress_epsilon())
	_sync_weapon_runtime_from_controller()


func _is_weapon_retrieval_stuck() -> bool:
	return _weapon_controller.is_retrieval_stuck(get_weapon_retrieval_timeout())


func _has_valid_weapon_pickup() -> bool:
	return _weapon_controller.has_valid_pickup()


func register_weapon_pickup(pickup: Node2D) -> void:
	_weapon_controller.register_pickup(pickup, self)
	_sync_weapon_runtime_from_controller()


func _pickup_weapon() -> void:
	if not _has_valid_weapon_pickup():
		return

	var pickup_animation := _weapon_state_animation("pickup_%s_axe" % current_direction)
	if animation_player != null and animation_player.has_animation(pickup_animation):
		animation_player.play(pickup_animation)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(pickup_animation):
		sprite.play(pickup_animation)

	var picked_weapon := _weapon_controller.collect_pickup()
	_sync_weapon_runtime_from_controller()
	if picked_weapon != null and is_instance_valid(picked_weapon):
		picked_weapon.queue_free()
	velocity = Vector2.ZERO
	_play_idle()


func _recover_lost_weapon() -> void:
	_clear_weapon_pickup()
	velocity = Vector2.ZERO
	_play_idle()


func _clear_weapon_pickup() -> void:
	_weapon_controller.clear_pickup(true, true)
	_sync_weapon_runtime_from_controller()


func _is_ready_for_melee_attack_slot() -> bool:
	if target == null or not has_attack_slot:
		return false
	if state != State.APPROACH_ATTACK_SLOT:
		return false
	if not _has_attack_line_of_sight():
		return false
	if global_position.distance_to(attack_slot_position) > attack_slot_arrive_distance:
		return false
	return global_position.distance_to(target.global_position) <= get_attack_range() + attack_slot_arrive_distance


func _prepare_attack_motion() -> void:
	leap_start_position = global_position
	leap_end_position = global_position
	leap_duration = 0.0
	if not current_attack_type in ["leap", "cross"] or target == null:
		return

	var to_target := target.global_position - global_position
	if to_target == Vector2.ZERO:
		return

	var direction := to_target.normalized()
	current_direction = _direction_from_vector(direction)
	if current_attack_type == "cross":
		var cross_distance := float(current_attack_profile.get("cross_distance", get_attack_range()))
		leap_duration = maxf(float(current_attack_profile.get("cross_duration", 0.45)), 0.05)
		leap_end_position = target.global_position + direction * cross_distance
		return

	var leap_distance := float(current_attack_profile.get("leap_distance", minf(to_target.length(), 36.0)))
	var max_distance := maxf(to_target.length() - get_attack_range() * 0.5, 0.0)
	leap_distance = minf(leap_distance, max_distance)
	leap_duration = maxf(float(current_attack_profile.get("leap_duration", 0.35)), 0.05)
	leap_end_position = global_position + direction * leap_distance


func _update_attack_motion(_delta: float) -> void:
	if not current_attack_type in ["leap", "cross"] or leap_duration <= 0.0:
		velocity = Vector2.ZERO
		return

	if attack_elapsed >= leap_duration:
		velocity = Vector2.ZERO
		return

	var remaining_time := maxf(leap_duration - attack_elapsed, 0.001)
	var to_destination := leap_end_position - global_position
	velocity = to_destination / remaining_time


func _try_spawn_projectile_attack() -> void:
	if not _combat_controller.should_spawn_projectile():
		return

	_mark_projectile_attack_spawned()
	if not _has_projectile_line_of_sight(current_attack_profile):
		return

	var scene_path := String(current_attack_profile.get("projectile_scene", ""))
	if scene_path == "":
		push_warning("%s projectile attack has no projectile_scene." % get_display_name())
		return

	var projectile_scene := load(scene_path) as PackedScene
	if projectile_scene == null:
		push_warning("%s could not load projectile scene: %s" % [get_display_name(), scene_path])
		return

	var projectile := projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	var direction := _projectile_direction()
	var spawn_offset := float(current_attack_profile.get("projectile_spawn_offset", 8.0))
	var projectile_parent := get_parent()
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	projectile_parent.add_child(projectile)
	projectile.global_position = global_position + direction * spawn_offset
	if projectile.has_method("launch"):
		projectile.launch(self, direction, current_direction, current_attack_profile)

	if bool(current_attack_profile.get("drop_weapon", false)):
		_weapon_controller.mark_unarmed()
		_sync_weapon_runtime_from_controller()


func _projectile_direction() -> Vector2:
	if target != null:
		var to_target := target.global_position - global_position
		if to_target != Vector2.ZERO:
			current_direction = _direction_from_vector(to_target)
			return to_target.normalized()
	return _vector_from_direction(current_direction)


func _has_projectile_line_of_sight(profile: Dictionary) -> bool:
	if target == null:
		return false

	var collision_mask := int(profile.get("blocked_by_mask", 1))
	if collision_mask <= 0:
		return true

	var from := global_position
	var to := target.global_position
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _has_attack_line_of_sight() -> bool:
	if target == null:
		return false
	if attack_blocked_by_mask <= 0:
		return true

	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.collision_mask = attack_blocked_by_mask
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _vector_from_direction(direction: String) -> Vector2:
	match direction:
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		"side_left":
			return Vector2.LEFT
		_:
			return Vector2.RIGHT


func _uses_body_motion_hit_detection() -> bool:
	return _combat_controller.uses_body_motion_hit_detection()


func _apply_body_motion_attack_hits(previous_position: Vector2) -> void:
	if target == null or not _is_attack_motion_active():
		return
	if _is_target_in_body_motion_area(target, previous_position):
		_try_hit_target(target)


func _is_attack_motion_active() -> bool:
	return _combat_controller.is_attack_motion_active(leap_duration)


func _is_target_in_body_motion_area(target_node: Node2D, previous_position: Vector2) -> bool:
	if target_node == null:
		return false

	var body_rect := _get_swept_body_collision_rect(previous_position)
	var target_rect := _get_target_hitbox_global_rect(target_node)
	if body_rect.size == Vector2.ZERO:
		return false
	if target_rect.size == Vector2.ZERO:
		return body_rect.has_point(target_node.global_position)
	return body_rect.intersects(target_rect, true)


func _is_target_in_attack_range(target_node: Node2D) -> bool:
	return global_position.distance_to(target_node.global_position) <= get_attack_range()


func _is_target_in_attack_area(target_node: Node2D) -> bool:
	if target_node == null:
		return false

	var attack_rect := _get_collision_shape_global_rect(attack_shape)
	var target_rect := _get_target_hitbox_global_rect(target_node)
	if attack_rect.size == Vector2.ZERO:
		return false
	if target_rect.size == Vector2.ZERO:
		return attack_rect.has_point(target_node.global_position)
	return attack_rect.intersects(target_rect, true)


func _get_attack_alignment_direction(to_target: Vector2) -> Vector2:
	if to_target == Vector2.ZERO:
		return Vector2.ZERO

	var target_half_size := _get_target_hitbox_half_size(target)
	var attack_half_size := _get_collision_shape_half_size(attack_shape)
	var horizontal_lane_half_height := attack_half_size.y + target_half_size.y
	var vertical_lane_half_width := attack_half_size.x + target_half_size.x
	var intended_direction := _direction_from_vector(to_target)

	if intended_direction == "side" or intended_direction == "side_left":
		if absf(to_target.y) > horizontal_lane_half_height:
			return Vector2(0.0, signf(to_target.y))
		return Vector2(signf(to_target.x), 0.0)

	if absf(to_target.x) > vertical_lane_half_width:
		return Vector2(signf(to_target.x), 0.0)
	return Vector2(0.0, signf(to_target.y))


func _sync_attack_area_to_direction() -> void:
	attack_area.position = _get_attack_area_position_for_direction(current_direction)


func _get_attack_area_position_for_direction(direction: String) -> Vector2:
	var animation_names := [
		"attack_%s_first" % direction,
		"idle_%s" % direction,
		"walk_%s" % direction,
	]
	for animation_name in animation_names:
		var position: Variant = _get_attack_area_position_from_animation(animation_name)
		if position != null:
			return position
	return _default_attack_area_position


func _get_attack_area_position_from_animation(animation_name: String) -> Variant:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return null

	var animation := animation_player.get_animation(animation_name)
	for track_index in animation.get_track_count():
		if animation.track_get_path(track_index) != NodePath("AttackArea2D:position"):
			continue
		if animation.track_get_key_count(track_index) == 0:
			continue
		return animation.track_get_key_value(track_index, 0)
	return null


func _direction_from_animation_name(animation_name: String) -> String:
	var parts := animation_name.split("_", false)
	if parts.size() >= 4 and parts[1] == "side" and parts[2] == "left":
		return "side_left"
	if parts.size() >= 2 and parts[1] == "side":
		return "side"
	if parts.size() >= 2 and parts[1] == "down":
		return "down"
	if parts.size() >= 2 and parts[1] == "up":
		return "up"
	if animation_name.ends_with("_side_left"):
		return "side_left"
	if animation_name.ends_with("_side"):
		return "side"
	if animation_name.ends_with("_down"):
		return "down"
	if animation_name.ends_with("_up"):
		return "up"
	return current_direction


func _get_target_hitbox_global_rect(target_node: Node2D) -> Rect2:
	var hitbox_shape := target_node.get_node_or_null("HitboxArea2D/CollisionShape2D") as CollisionShape2D
	if hitbox_shape == null:
		return Rect2()
	return _get_collision_shape_global_rect(hitbox_shape)


func _get_target_hitbox_half_size(target_node: Node2D) -> Vector2:
	if target_node == null:
		return Vector2.ZERO

	var hitbox_shape := target_node.get_node_or_null("HitboxArea2D/CollisionShape2D") as CollisionShape2D
	if hitbox_shape == null:
		return Vector2.ZERO
	return _get_collision_shape_half_size(hitbox_shape)


func _get_collision_shape_global_rect(collision_shape: CollisionShape2D) -> Rect2:
	var half_size := _get_collision_shape_half_size(collision_shape)
	if half_size == Vector2.ZERO:
		return Rect2()
	return Rect2(collision_shape.global_position - half_size, half_size * 2.0)


func _get_swept_body_collision_rect(previous_position: Vector2) -> Rect2:
	var current_rect := _get_collision_shape_global_rect(body_collision_shape)
	if current_rect.size == Vector2.ZERO:
		return Rect2()

	var previous_rect := current_rect
	previous_rect.position += previous_position - global_position
	return current_rect.merge(previous_rect)


func _get_collision_shape_half_size(collision_shape: CollisionShape2D) -> Vector2:
	if collision_shape == null:
		return Vector2.ZERO

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		return rectangle.size * 0.5

	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		return Vector2(circle.radius, circle.radius)

	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule != null:
		return Vector2(capsule.radius, capsule.height * 0.5)

	return Vector2.ZERO


func _cache_lifecycle_defaults() -> void:
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_default_hitbox_monitoring = hitbox_area.monitoring
	_default_hitbox_monitorable = hitbox_area.monitorable
	_default_attack_area_position = attack_area.position


func _disable_combat_logic() -> void:
	velocity = Vector2.ZERO
	target = null
	_reset_combat_runtime()
	leap_start_position = global_position
	leap_end_position = global_position
	leap_duration = 0.0
	remove_from_group("enemy")
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	hitbox_area.monitoring = false
	hitbox_area.monitorable = false
	if animation_player != null:
		animation_player.stop()
	sprite.position = Vector2.ZERO
	_set_attack_active(false)


func _apply_attack_hits() -> void:
	if attack_area.monitoring:
		for body in attack_area.get_overlapping_bodies():
			_try_hit_target(body)
		for area in attack_area.get_overlapping_areas():
			_try_hit_target(area)
	if target != null and _is_target_in_attack_area(target):
		_try_hit_target(target)


func _apply_active_attack_hits() -> void:
	if attack_area.monitoring and not attack_shape.disabled:
		_apply_attack_hits()


func _try_hit_target(candidate: Node) -> void:
	var hit_target := _resolve_hit_target(candidate)
	if hit_target == null or _has_hit_target(hit_target):
		return

	var attack_profile := _get_active_attack_profile()
	_register_hit_target(hit_target)
	if hit_target.has_method("take_damage"):
		hit_target.take_damage(_get_attack_damage(attack_profile))
	_apply_attack_status_effect(hit_target, attack_profile)
	attack_hit.emit(hit_target)


func _get_attack_damage(attack_profile: Dictionary) -> int:
	return _combat_controller.get_attack_damage(attack_profile, get_attack_power())


func _get_active_attack_profile() -> Dictionary:
	return _combat_controller.get_active_profile(get_attack_profile)


func _apply_attack_status_effect(hit_target: Node, attack_profile: Dictionary) -> void:
	_combat_controller.apply_attack_status_effect(hit_target, attack_profile, self)


func _resolve_hit_target(candidate: Node) -> Node:
	var current := candidate
	while current != null:
		if target_group == "" or current.is_in_group(target_group):
			return current
		current = current.get_parent()
	return null


func _play_idle() -> void:
	sprite.position = Vector2.ZERO
	var animation_name := _weapon_state_animation("idle_%s" % current_direction)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != StringName(animation_name) or not sprite.is_playing():
			sprite.play(animation_name)


func _play_walk(direction: Vector2) -> void:
	sprite.position = Vector2.ZERO
	var animation_name := "walk_side"
	if absf(direction.x) >= absf(direction.y):
		animation_name = "walk_side_left" if direction.x < 0.0 else "walk_side"
	elif direction.y < 0.0:
		animation_name = "walk_up"
	else:
		animation_name = "walk_down"

	animation_name = _weapon_state_animation(animation_name)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != StringName(animation_name) or not sprite.is_playing():
			sprite.play(animation_name)


func _weapon_state_animation(animation_name: String) -> String:
	if has_weapon or sprite.sprite_frames == null:
		return animation_name

	var no_weapon_animation := "%s_no_axe" % animation_name
	if sprite.sprite_frames.has_animation(no_weapon_animation):
		return no_weapon_animation
	return animation_name


func _direction_from_vector(direction: Vector2) -> String:
	if direction == Vector2.ZERO:
		return current_direction
	if absf(direction.x) >= absf(direction.y):
		last_horizontal_direction = "side_left" if direction.x < 0.0 else "side"
		return last_horizontal_direction
	return "up" if direction.y < 0.0 else "down"


func _directional_animation_name(animation_name: String) -> String:
	if _is_directional_animation_name(animation_name):
		return animation_name
	if animation_name.ends_with("_up") or animation_name.ends_with("_down") or animation_name.ends_with("_side") or animation_name.ends_with("_side_left"):
		return animation_name
	var parts := animation_name.split("_", false, 1)
	if parts.size() == 2 and (parts[0] in ["attack", "death"]):
		return "%s_%s_%s" % [parts[0], current_direction, parts[1]]
	return "%s_%s" % [animation_name, current_direction]


func _is_directional_animation_name(animation_name: String) -> bool:
	var parts := animation_name.split("_", false)
	if parts.size() >= 3 and (parts[0] in ["attack", "death"]):
		if parts[1] in ["up", "down"]:
			return true
		if parts[1] == "side":
			return true
	return false


func _play_death() -> void:
	var animation_names := _get_death_animation_candidates()
	if not animation_names.is_empty():
		var animation_name: StringName = animation_names.pick_random()
		sprite.animation = animation_name
		sprite.frame = 0
		if animation_player != null and animation_player.has_animation(animation_name):
			animation_player.play(animation_name)
		else:
			sprite.play(animation_name)
		return

	hide()


func _get_death_animation_candidates() -> Array[StringName]:
	var candidates: Array[StringName] = []
	if sprite.sprite_frames == null:
		return candidates

	_append_death_animations_for_direction(candidates, current_direction)
	if candidates.is_empty() and last_horizontal_direction != current_direction:
		_append_death_animations_for_direction(candidates, last_horizontal_direction)
	if candidates.is_empty():
		_append_death_animations_for_direction(candidates, "side")
	return candidates


func _append_death_animations_for_direction(candidates: Array[StringName], direction: String) -> void:
	for animation_name in sprite.sprite_frames.get_animation_names():
		var name := String(animation_name)
		if not name.begins_with("death_") or _direction_from_animation_name(name) != direction:
			continue
		var is_no_weapon_death := name.ends_with("_no_axe")
		if has_weapon and is_no_weapon_death:
			continue
		if not has_weapon and not is_no_weapon_death:
			continue
		candidates.append(animation_name)

	if candidates.is_empty() and not has_weapon:
		for animation_name in sprite.sprite_frames.get_animation_names():
			var name := String(animation_name)
			if name.begins_with("death_") and _direction_from_animation_name(name) == direction:
				candidates.append(animation_name)


func _flash_hurt() -> void:
	if hurt_flash_feedback != null and hurt_flash_feedback.has_method("play"):
		if hurt_flash_feedback.play():
			return

	sprite.modulate = Color(1.0, 0.25, 0.25)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
