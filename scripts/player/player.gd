extends CharacterBody2D

const PSM = preload("res://scripts/player/player_state_machine.gd")
const PCC = preload("res://scripts/player/player_combat_controller.gd")
const PFC = preload("res://scripts/player/firearm_controller.gd")
const PIC = preload("res://scripts/characters/controllers/player_input_controller.gd")
const ProjectileInterceptUtil = preload("res://scripts/combat/projectile_intercept.gd")

const ATTACK_INTERVAL_MANUAL := "manual"
const ATTACK_INTERVAL_REPEAT := "repeat"
const DEFAULT_MANUAL_ATTACK_LOCKOUT := 0.35
const DEFAULT_REPEAT_ATTACK_INTERVAL := 0.35

signal attack_hit(target: Node)
signal health_changed(current: int, maximum: int)
signal died(player: Node)
signal weapon_equipped(weapon_data: Resource)

@export_group("Stats")
## 玩家属性资源，提供生命值、移动速度、防御、默认攻击力和无敌时间。
@export var stats: Resource
## 没有 stats 或当前武器没有覆盖攻击力时使用的备用攻击力。
@export var damage := 10

@export_group("Combat")
## 攻击可命中的目标组名。玩家场景中通常设置为 enemy。
@export var target_group := "player"
## 是否根据当前朝向自动移动 AttackArea2D 的位置。
@export var use_directional_attack_area_offsets := true
## 空手主攻击配置。没有装备武器时，J 键会使用这个 AttackProfile。
@export var unarmed_primary_attack_profile: Resource
## 空手副攻击配置。当前阶段暂不绑定输入，但保留给后续扩展。
@export var unarmed_secondary_attack_profile: Resource
@export_group("Control")
## 是否允许键盘控制。测试场景中可关闭，用于只播放动画或由脚本驱动。
@export var keyboard_control_enabled := true
## 没有 stats 时使用的备用移动速度，单位为像素/秒。
@export var movement_speed := 90.0
## 攻击动画播放期间允许移动时使用的速度倍率。
@export_range(0.0, 1.0, 0.05) var attacking_move_speed_multiplier := 0.45
## 主攻击键，默认 J。
@export var primary_attack_key := KEY_J
## 拾取/丢弃交互键，默认 E。
@export var interact_key := KEY_E
## 暂时空置的旧副攻击键。当前阶段 K 不执行任何功能。
@export var secondary_attack_key := KEY_K

@export_group("Camera")
## 是否启用玩家子节点 FollowCamera2D 的跟随。
@export var camera_follow_enabled := true
## 玩家相机缩放比例。值越大画面越近。
@export var camera_zoom := Vector2(3, 3)
## 是否启用 Camera2D 的位置平滑。
@export var camera_smoothing_enabled := true
## 相机平滑速度。值越大越快贴近玩家。
@export var camera_smoothing_speed := 5.0

@export_group("Debug")
## 是否在控制台输出受伤日志。
@export var damage_log_enabled := true
## 是否在控制台输出攻击按键和方向日志。
@export var attack_log_enabled := true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hands_sprite: AnimatedSprite2D = get_node_or_null("HandsSprite")
@onready var attack_area: Area2D = $AttackArea2D
@onready var attack_shape: CollisionShape2D = $AttackArea2D/CollisionShape2D
@onready var follow_camera: Camera2D = get_node_or_null("FollowCamera2D")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var hurt_flash_feedback: Node = get_node_or_null("HurtFlashFeedback")

var current_direction := "side"
var health := 1
var attack_lockout_remaining := 0.0
var invincible_time_remaining := 0.0
var stun_time_remaining := 0.0
var _attack_active := false
var _equipment_visual_enabled := true
var _equipment_visual_base_position := Vector2.ZERO
var _body_visual_base_z_index := 0
var _equipment_visual_base_z_index := 0
var _unarmed_visual_sprite_frames: SpriteFrames
var _primary_attack_hold_time := 0.0
var _primary_attack_repeat_ready := false
var _primary_attack_buffer_time_remaining := 0.0
var _current_attack_hit_window_reached := false
var _current_attack_action := ""
var _current_attack_animation := ""
var _primary_attack_repeat_active := false
var _ignored_restarted_attack_animation := ""
var _player_state_machine := PSM.new()
var _combat_controller := PCC.new()
var _firearm_controller := PFC.new()
var _player_input_controller := PIC.new()
var equipped_weapon: Resource

var attack_hit_frames := {
	"attack_first": [2],
	"attack_second": [2],
}

var attack_target_limits := {
	"attack_first": 1,
	"attack_second": 3,
}

var attack_area_offsets := {
	"side": Vector2(10, 1),
	"side_left": Vector2(-10, 1),
	"down": Vector2(0, 8),
	"up": Vector2(0, -7),
}


func _ready() -> void:
	# Run visual sync after child AnimationPlayer updates so internal body/hand layers stay authoritative.
	process_priority = 100
	_combat_controller.default_hit_frames = attack_hit_frames
	_combat_controller.default_target_limits = attack_target_limits
	_player_state_machine.reset(PSM.IDLE)
	_player_input_controller.primary_attack_key = primary_attack_key
	_player_input_controller.interact_key = interact_key
	_player_input_controller.unused_key = secondary_attack_key
	health = get_max_health()
	_body_visual_base_z_index = sprite.z_index
	if hands_sprite != null:
		_equipment_visual_base_position = hands_sprite.position
		_equipment_visual_base_z_index = hands_sprite.z_index
		_unarmed_visual_sprite_frames = hands_sprite.sprite_frames
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_player_finished)
	_update_direction_from_animation()
	_set_attack_active(false)
	_configure_camera()
	play_idle(current_direction)
	health_changed.emit(health, get_max_health())


func _process(_delta: float) -> void:
	_sync_equipment_visual_to_sprite()
	_apply_equipment_visual_layer(String(sprite.animation))


func _change_player_state(next_state: String) -> bool:
	return _player_state_machine.change_to(next_state)


func _refresh_state_from_lifecycle() -> void:
	if health <= 0:
		_change_player_state(PSM.DEAD)
		return
	if stun_time_remaining > 0.0:
		_change_player_state(PSM.STUNNED)
		return
	if _player_state_machine.is_state(PSM.STUNNED):
		_change_player_state(PSM.IDLE)


func _return_to_locomotion_state() -> void:
	if health <= 0:
		_change_player_state(PSM.DEAD)
		return
	if stun_time_remaining > 0.0:
		_change_player_state(PSM.STUNNED)
		_play_idle_animation_immediate(current_direction)
		return

	var movement := _get_keyboard_movement()
	if _is_firearm_hold_session_active():
		var locked_direction := _get_firearm_hold_session_direction()
		if movement == Vector2.ZERO:
			_change_player_state(PSM.IDLE)
			play_idle(locked_direction)
		else:
			_change_player_state(PSM.MOVE)
			play_walk(locked_direction)
		return

	if movement == Vector2.ZERO:
		_change_player_state(PSM.IDLE)
		play_idle(current_direction)
		return

	var next_direction := _direction_from_vector(movement)
	_change_player_state(PSM.MOVE)
	play_walk(next_direction)


func _try_cancel_startup_attack_for_turn() -> bool:
	if not _player_state_machine.is_state(PSM.ATTACK):
		return false
	if _combat_controller.current_attack_phase != PCC.PHASE_STARTUP:
		return false
	if _get_attack_input_mode(_get_current_attack_profile()) in [PCC.INPUT_TAP_COMBO, PCC.INPUT_HOLD_REPEAT]:
		return false

	var movement := _get_keyboard_movement()
	if movement == Vector2.ZERO:
		return false

	var requested_direction := _direction_from_vector(movement)
	if requested_direction == current_direction:
		return false

	_cancel_startup_attack()
	return true


func _cancel_startup_attack() -> void:
	if animation_player != null and animation_player.is_playing():
		animation_player.stop()
	if sprite.is_playing():
		sprite.stop()
	_clear_attack_runtime_state()
	_change_player_state(PSM.IDLE)
	play_idle(current_direction)


func _physics_process(delta: float) -> void:
	attack_lockout_remaining = maxf(attack_lockout_remaining - delta, 0.0)
	invincible_time_remaining = maxf(invincible_time_remaining - delta, 0.0)
	stun_time_remaining = maxf(stun_time_remaining - delta, 0.0)
	_refresh_state_from_lifecycle()
	_update_primary_attack_buffer(delta)
	_update_primary_attack_hold_state(delta)
	if _try_cancel_startup_attack_for_turn():
		move_and_slide()
		return
	_turn_current_attack_to_movement_input()
	if _try_consume_buffered_primary_attack():
		if _can_move_during_locked_attack():
			_apply_locked_attack_movement()
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		_apply_active_attack_hits()
		return
	if _try_repeat_held_attack():
		if _can_move_during_locked_attack():
			_apply_locked_attack_movement()
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		_apply_active_attack_hits()
		return
	if not keyboard_control_enabled or _is_locked_animation() or _player_state_machine.blocks_input():
		if keyboard_control_enabled and _can_move_during_locked_attack():
			_apply_locked_attack_movement()
		else:
			velocity = Vector2.ZERO
		if _player_state_machine.is_state(PSM.STUNNED):
			_play_idle_animation_immediate(current_direction)
		move_and_slide()
		_apply_active_attack_hits()
		return

	if _is_holding_repeat_attack():
		_apply_locked_attack_movement()
		move_and_slide()
		_apply_active_attack_hits()
		return

	if _player_state_machine.is_state(PSM.ATTACK):
		_apply_locked_attack_movement()
		move_and_slide()
		_apply_active_attack_hits()
		return

	if _is_firearm_hold_session_active():
		_apply_firearm_hold_session_movement()
		move_and_slide()
		_apply_active_attack_hits()
		return

	var movement := _get_keyboard_movement()
	if movement == Vector2.ZERO:
		velocity = Vector2.ZERO
		play_idle(current_direction)
		move_and_slide()
		_apply_active_attack_hits()
		return

	current_direction = _direction_from_vector(movement)
	velocity = movement.normalized() * get_move_speed()
	play_walk(current_direction)
	move_and_slide()
	_apply_active_attack_hits()


func _unhandled_input(event: InputEvent) -> void:
	if not keyboard_control_enabled or _player_state_machine.blocks_input():
		return
	_player_input_controller.apply_event(event)
	var input_intent := _player_input_controller.build_intent()
	if input_intent.interact_pressed:
		_handle_interact_pressed()
		return
	if input_intent.primary_attack_pressed:
		_handle_primary_attack_pressed()


func _handle_interact_pressed() -> void:
	if _player_state_machine.blocks_interaction():
		return
	if equipped_weapon == null:
		_try_pickup_nearby_weapon()
	else:
		drop_current_weapon()


func play_idle(direction := current_direction) -> void:
	direction = _get_firearm_hold_session_direction(direction)
	current_direction = direction
	if not _is_locked_animation():
		if not _should_preserve_hold_repeat_input(_get_attack_profile("attack_first")):
			_clear_attack_runtime_state()
		_change_player_state(PSM.IDLE)
	_play_animation_if_changed("idle_%s" % current_direction)


func _play_idle_animation_immediate(direction := current_direction) -> void:
	current_direction = direction
	if animation_player != null and animation_player.is_playing():
		animation_player.stop()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_%s" % current_direction):
		sprite.play("idle_%s" % current_direction)
		_sync_equipment_visual_to_sprite()


func play_walk(direction := current_direction) -> void:
	direction = _get_firearm_hold_session_direction(direction)
	current_direction = direction
	if not _should_preserve_hold_repeat_input(_get_attack_profile("attack_first")):
		_clear_attack_runtime_state()
	_change_player_state(PSM.MOVE)
	_play_animation_if_changed("walk_%s" % current_direction)


func attack(action := "attack_first", direction := current_direction, interval_kind := ATTACK_INTERVAL_MANUAL) -> void:
	var attack_profile := _get_attack_profile(action)
	if equipped_weapon != null and attack_profile == null and action == "attack_second":
		return
	if _is_firearm_hold_session_active() and action == "attack_first":
		direction = _get_firearm_hold_session_direction(direction)
	current_direction = direction
	action = _get_profile_animation_action(attack_profile, action)
	var animation_name := _animation_name(action, current_direction)
	if animation_player != null and animation_player.has_animation(animation_name):
		if String(animation_player.current_animation) == animation_name:
			_ignored_restarted_attack_animation = animation_name
			animation_player.stop()
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation == StringName(animation_name):
			sprite.stop()
	_combat_controller.begin_attack(attack_profile, action, animation_name, PCC.PHASE_STARTUP)
	_sync_current_attack_debug_fields()
	_change_player_state(PSM.ATTACK)
	set_meta("current_attack_profile", attack_profile)
	attack_lockout_remaining = get_attack_interval(attack_profile, interval_kind)
	set_meta("current_attack_action", action)
	if attack_log_enabled:
		print("%s 使用%s攻击，方向 %s" % [get_display_name(), _attack_key_label_for_action(action), current_direction])
	_combat_controller.clear_hit_targets()
	_set_attack_active(false)
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		_sync_equipment_visual_to_animation(animation_name)
		call_deferred("_apply_equipment_visual_layer", animation_name)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		_sync_equipment_visual_to_sprite()
	if _get_profile_attack_type(attack_profile) == PCC.ATTACK_TYPE_PROJECTILE:
		_set_current_attack_phase(PCC.PHASE_ACTIVE)
		_execute_projectile_attack(attack_profile, animation_name)
		_set_current_attack_phase(PCC.PHASE_RECOVERY)


func _begin_primary_attack() -> void:
	_combat_controller.clear_primary_attack_input_state()
	_sync_primary_attack_input_debug_fields()
	var attack_profile := _get_attack_profile("attack_first")
	if _should_use_firearm_hold_session(attack_profile):
		_begin_firearm_hold_session(current_direction)
	attack("attack_first", _get_firearm_hold_session_direction(current_direction))


func _handle_primary_attack_pressed() -> void:
	if _can_start_primary_attack_now():
		_begin_primary_attack()
		return
	_buffer_primary_attack_input()
	_try_consume_buffered_primary_attack()


func _buffer_primary_attack_input() -> void:
	var attack_profile := _get_attack_profile("attack_first")
	if _get_attack_input_mode(attack_profile) != PCC.INPUT_TAP_COMBO:
		return
	var buffer_time := _get_attack_input_buffer_time(attack_profile)
	if buffer_time <= 0.0:
		return
	_combat_controller.set_primary_attack_buffer_time(buffer_time)
	_sync_primary_attack_input_debug_fields()


func _update_primary_attack_buffer(delta: float) -> void:
	_sync_primary_attack_input_controller_from_debug_fields()
	_combat_controller.update_primary_attack_buffer(delta)
	_sync_primary_attack_input_debug_fields()


func _try_consume_buffered_primary_attack() -> bool:
	_sync_primary_attack_input_controller_from_debug_fields()
	if not _combat_controller.has_primary_attack_buffer():
		return false
	if _can_start_primary_attack_now() or _can_cancel_current_primary_attack():
		_begin_primary_attack()
		return true
	return false


func _can_start_primary_attack_now() -> bool:
	return keyboard_control_enabled and not _player_state_machine.blocks_attack() and not _is_locked_animation() and attack_lockout_remaining <= 0.0


func _can_cancel_current_primary_attack() -> bool:
	if not keyboard_control_enabled or _player_state_machine.blocks_attack():
		return false
	if _combat_controller.current_attack_action != "attack_first":
		return false

	var attack_profile := _get_current_attack_profile()
	if _get_attack_input_mode(attack_profile) != PCC.INPUT_TAP_COMBO:
		return false
	if _get_profile_attack_type(attack_profile) != PCC.ATTACK_TYPE_MELEE:
		return false

	var cancel_last_frames := _get_attack_cancel_last_frames(attack_profile)
	if cancel_last_frames <= 0:
		return false
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return false

	var action_name := _action_from_animation(sprite.animation)
	if action_name != "attack_first":
		return false

	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count <= 0:
		return false

	var hit_frames := _get_attack_hit_frames(attack_profile, action_name)
	if not _current_attack_hit_window_reached:
		return false
	if not hit_frames.is_empty() and sprite.frame < _get_last_hit_frame(hit_frames):
		return false

	var remaining_frames := frame_count - 1 - sprite.frame
	return remaining_frames >= 0 and remaining_frames < cancel_last_frames


func play_pickup(direction := current_direction) -> void:
	if _player_state_machine.blocks_interaction():
		return
	current_direction = direction
	_change_player_state(PSM.PICKUP)
	_set_attack_active(false)
	var animation_name := _animation_name("pickup", current_direction)
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		_sync_equipment_visual_to_animation(animation_name)
		call_deferred("_apply_equipment_visual_layer", animation_name)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		_sync_equipment_visual_to_sprite()


func _on_frame_changed() -> void:
	_update_direction_from_animation()
	_sync_equipment_visual_to_sprite()
	var attack_profile := _get_current_attack_profile()
	if _get_profile_attack_type(attack_profile) == PCC.ATTACK_TYPE_PROJECTILE:
		_set_attack_active(false)
		return

	var action_name := _action_from_animation(sprite.animation)
	var hit_frames := _get_attack_hit_frames(attack_profile, action_name)
	if hit_frames.is_empty():
		_set_attack_active(false)
		return

	var should_hit := sprite.frame in hit_frames
	_update_current_attack_phase(hit_frames)
	_set_attack_active(should_hit)
	if should_hit:
		_set_current_attack_phase(PCC.PHASE_ACTIVE)
		_mark_current_attack_hit_window_reached()
		_apply_attack_hits()


func _update_current_attack_phase(hit_frames: Array) -> void:
	if _combat_controller.current_attack_action == "" or hit_frames.is_empty():
		return

	var frame_count := 0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		frame_count = sprite.sprite_frames.get_frame_count(sprite.animation)
	var phase := _combat_controller.get_attack_phase(
		_get_current_attack_profile(),
		_combat_controller.current_attack_action,
		sprite.frame,
		frame_count
	)
	if phase != PCC.PHASE_NONE:
		_set_current_attack_phase(phase)


func _on_animation_finished() -> void:
	if _ignored_restarted_attack_animation == String(sprite.animation):
		_ignored_restarted_attack_animation = ""
		return
	var action_name := _action_from_animation(sprite.animation)
	if action_name.begins_with("attack_") or action_name == "pickup":
		if action_name.begins_with("attack_"):
			var finished_attack_profile := _get_current_attack_profile()
			_set_current_attack_phase(PCC.PHASE_FINISHED)
			_clear_attack_runtime_state_after_animation(finished_attack_profile)
			_clear_attack_lockout_after_animation(finished_attack_profile)
		else:
			_set_attack_active(false)
			_change_player_state(PSM.IDLE)
		_return_to_locomotion_state()


func _on_animation_player_finished(animation_name: StringName) -> void:
	if _ignored_restarted_attack_animation == String(animation_name):
		_ignored_restarted_attack_animation = ""
		return
	var action_name := _action_from_animation(animation_name)
	if action_name.begins_with("attack_") or action_name == "pickup":
		if action_name.begins_with("attack_"):
			var finished_attack_profile := _get_current_attack_profile()
			_set_current_attack_phase(PCC.PHASE_FINISHED)
			_clear_attack_runtime_state_after_animation(finished_attack_profile)
			_clear_attack_lockout_after_animation(finished_attack_profile)
		else:
			_set_attack_active(false)
			_change_player_state(PSM.IDLE)
		_return_to_locomotion_state()


func _set_attack_active(active: bool) -> void:
	_attack_active = active
	_update_attack_area_transform()
	attack_area.monitoring = active
	attack_shape.disabled = not active


func _apply_attack_hits() -> void:
	var attack_profile := _get_current_attack_profile()
	_apply_projectile_intercepts(attack_profile)
	var max_targets := _get_current_attack_max_targets()
	var hit_targets := _combat_controller.collect_new_hit_targets(_collect_attack_hit_targets(), max_targets)
	for hit_target in hit_targets:
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(get_attack_power())
		attack_hit.emit(hit_target)


func _apply_projectile_intercepts(attack_profile: Resource) -> void:
	if attack_profile == null or not bool(attack_profile.get("can_intercept_projectile")):
		return
	for body in attack_area.get_overlapping_bodies():
		ProjectileInterceptUtil.try_intercept(body, attack_profile, self)
	for area in attack_area.get_overlapping_areas():
		ProjectileInterceptUtil.try_intercept(area, attack_profile, self)


func _apply_active_attack_hits() -> void:
	if _get_profile_attack_type(_get_current_attack_profile()) == PCC.ATTACK_TYPE_PROJECTILE:
		return
	if not _is_current_melee_hit_frame_active():
		_set_attack_active(false)
		return
	_apply_attack_hits()


func _is_current_melee_hit_frame_active() -> bool:
	return _combat_controller.is_current_melee_hit_frame_active(
		_attack_active,
		sprite.animation,
		sprite.frame,
		_action_from_animation(sprite.animation)
	)


func _clear_attack_runtime_state() -> void:
	_combat_controller.clear_runtime(PCC.PHASE_NONE)
	_sync_current_attack_debug_fields()
	_sync_primary_attack_input_debug_fields()
	if has_meta("current_attack_profile"):
		remove_meta("current_attack_profile")
	if has_meta("current_attack_action"):
		remove_meta("current_attack_action")
	_set_attack_active(false)


func _clear_attack_runtime_state_after_animation(attack_profile: Resource) -> void:
	var should_preserve_hold := _should_preserve_hold_repeat_input(attack_profile)
	var hold_time := _combat_controller.primary_attack_hold_time
	var repeat_ready := _combat_controller.primary_attack_repeat_ready
	var repeat_active := _combat_controller.primary_attack_repeat_active

	_clear_attack_runtime_state()

	if not should_preserve_hold:
		return
	_combat_controller.primary_attack_hold_time = hold_time
	_combat_controller.primary_attack_repeat_ready = repeat_ready
	_combat_controller.primary_attack_repeat_active = repeat_active
	_sync_primary_attack_input_debug_fields()


func _should_use_firearm_hold_session(attack_profile: Resource) -> bool:
	return _firearm_controller.can_use_hold_session(
		attack_profile,
		equipped_weapon,
		_is_repeat_attack_enabled(attack_profile)
	)


func _begin_firearm_hold_session(direction_name: String) -> void:
	_firearm_controller.begin_hold_session(direction_name)


func _end_firearm_hold_session() -> void:
	_firearm_controller.end_hold_session()


func _is_firearm_hold_session_active() -> bool:
	return _firearm_controller.is_hold_session_active()


func _get_firearm_hold_session_direction(fallback_direction := current_direction) -> String:
	return _firearm_controller.get_hold_session_direction(fallback_direction)


func _should_preserve_hold_repeat_input(attack_profile: Resource) -> bool:
	return _firearm_controller.should_preserve_hold_repeat_input(
		attack_profile,
		equipped_weapon,
		_is_repeat_attack_enabled(attack_profile),
		_is_key_currently_pressed(primary_attack_key)
	)


func _clear_attack_lockout_after_animation(attack_profile: Resource) -> void:
	var input_mode := _get_attack_input_mode(attack_profile)
	if input_mode == PCC.INPUT_TAP_COMBO:
		attack_lockout_remaining = 0.0
	elif _firearm_controller.should_clear_lockout_after_animation(
		attack_profile,
		equipped_weapon,
		_is_key_currently_pressed(primary_attack_key)
	):
		attack_lockout_remaining = 0.0


func _collect_attack_hit_targets() -> Array[Node]:
	var hit_targets: Array[Node] = []
	if not attack_area.monitoring:
		return hit_targets
	for body in attack_area.get_overlapping_bodies():
		_append_hit_target(hit_targets, body)
	for area in attack_area.get_overlapping_areas():
		_append_hit_target(hit_targets, area)
	hit_targets.sort_custom(_sort_attack_targets_by_distance)
	return hit_targets


func _append_hit_target(hit_targets: Array[Node], candidate: Node) -> void:
	var hit_target := _resolve_hit_target(candidate)
	if hit_target == null or hit_target in hit_targets:
		return
	hit_targets.append(hit_target)


func _sort_attack_targets_by_distance(a: Node, b: Node) -> bool:
	return _attack_target_distance_squared(a) < _attack_target_distance_squared(b)


func _attack_target_distance_squared(target: Node) -> float:
	var target_node := target as Node2D
	if target_node == null:
		return INF
	return attack_area.global_position.distance_squared_to(target_node.global_position)


func _get_current_attack_max_targets() -> int:
	var attack_profile := _get_current_attack_profile()
	var action := _get_current_attack_action_name()
	return _combat_controller.get_attack_max_targets(attack_profile, action)


func _get_current_attack_hit_count() -> int:
	return _combat_controller.get_hit_count()


func _get_current_attack_action_name() -> String:
	if _current_attack_action != "":
		return _current_attack_action
	if has_meta("current_attack_action"):
		return String(get_meta("current_attack_action"))
	return "attack_first"


func _get_attack_profile(action: String) -> Resource:
	return _combat_controller.get_attack_profile(equipped_weapon, unarmed_primary_attack_profile, unarmed_secondary_attack_profile, action)


func _get_current_attack_profile() -> Resource:
	return _combat_controller.current_attack_profile


func _get_profile_animation_action(attack_profile: Resource, fallback_action: String) -> String:
	return _combat_controller.get_profile_animation_action(attack_profile, fallback_action)


func _get_profile_attack_type(attack_profile: Resource) -> String:
	return _combat_controller.get_profile_attack_type(attack_profile)


func _get_attack_input_mode(attack_profile: Resource) -> String:
	return _combat_controller.get_attack_input_mode(attack_profile, equipped_weapon)


func _get_attack_hit_frames(attack_profile: Resource, action_name: String) -> Array:
	return _combat_controller.get_attack_hit_frames(attack_profile, action_name)


func _get_last_hit_frame(hit_frames: Array) -> int:
	return _combat_controller.get_last_hit_frame(hit_frames)


func _get_first_hit_frame(hit_frames: Array) -> int:
	return _combat_controller.get_first_hit_frame(hit_frames)


func _get_attack_input_buffer_time(attack_profile: Resource) -> float:
	return _combat_controller.get_attack_input_buffer_time(attack_profile)


func _get_attack_cancel_last_frames(attack_profile: Resource) -> int:
	return _combat_controller.get_attack_cancel_last_frames(attack_profile)


func _reset_current_attack_hits() -> void:
	_combat_controller.clear_hit_targets()


func _resolve_hit_target(target: Node) -> Node:
	var current := target
	while current != null:
		if target_group == "" or current.is_in_group(target_group):
			return current
		current = current.get_parent()
	return null


func _update_direction_from_animation() -> void:
	var animation_name := _direction_from_animation(sprite.animation)
	if animation_name == "side_left":
		current_direction = "side_left"
	elif animation_name == "side":
		current_direction = "side"
	elif animation_name == "down":
		current_direction = "down"
	elif animation_name == "up":
		current_direction = "up"


func _update_attack_area_transform() -> void:
	if use_directional_attack_area_offsets:
		attack_area.position = attack_area_offsets.get(current_direction, Vector2(10, 1))


func _execute_projectile_attack(attack_profile: Resource, animation_name: String) -> void:
	if attack_profile == null:
		return

	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return

	_firearm_controller.execute_projectile_attack(
		self,
		parent,
		get_node_or_null("/root/EffectManager"),
		attack_profile,
		animation_name,
		current_direction,
		target_group,
		_projectile_spawn_position(),
		_equipment_visual_offset_for_animation(animation_name)
	)


func _projectile_spawn_position() -> Vector2:
	var offset: Vector2 = attack_area_offsets.get(current_direction, Vector2(10, 1))
	return global_position + offset


func _try_repeat_held_attack() -> bool:
	_sync_primary_attack_input_controller_from_debug_fields()
	if not keyboard_control_enabled or is_stunned() or attack_lockout_remaining > 0.0:
		return false
	if _is_locked_animation() and not _can_repeat_during_locked_attack():
		return false
	if _combat_controller.is_primary_attack_repeat_ready() and _should_repeat_attack("attack_first"):
		_combat_controller.set_primary_attack_repeat_active(true)
		_sync_primary_attack_input_debug_fields()
		attack("attack_first", _get_firearm_hold_session_direction(current_direction), ATTACK_INTERVAL_REPEAT)
		return true
	return false


func _should_repeat_attack(action: String) -> bool:
	var attack_profile := _get_attack_profile(action)
	if _get_attack_input_mode(attack_profile) != PCC.INPUT_HOLD_REPEAT:
		return false
	return _is_repeat_attack_enabled(attack_profile)


func _can_repeat_during_locked_attack() -> bool:
	var attack_profile := _get_current_attack_profile()
	if attack_profile == null:
		attack_profile = _get_attack_profile("attack_first")
	if _get_attack_input_mode(attack_profile) != PCC.INPUT_HOLD_REPEAT:
		return false
	return _is_repeat_attack_enabled(attack_profile)


func _is_repeat_attack_enabled(attack_profile: Resource) -> bool:
	return _combat_controller.is_repeat_attack_enabled(attack_profile, equipped_weapon)


func _is_holding_repeat_attack() -> bool:
	_sync_primary_attack_input_controller_from_debug_fields()
	return _combat_controller.is_primary_attack_repeat_ready() and _should_repeat_attack("attack_first")


func _update_primary_attack_hold_state(delta: float) -> void:
	_sync_primary_attack_input_controller_from_debug_fields()
	if not _is_key_currently_pressed(primary_attack_key):
		_end_firearm_hold_session()
		if _combat_controller.primary_attack_repeat_active:
			_cancel_primary_attack_repeat()
		_combat_controller.clear_primary_attack_hold_state()
		_sync_primary_attack_input_debug_fields()
		return

	if not _should_repeat_attack("attack_first"):
		_end_firearm_hold_session()
		_combat_controller.clear_primary_attack_hold_state()
		_sync_primary_attack_input_debug_fields()
		return

	_combat_controller.update_primary_attack_hold_state(delta, true, _get_hold_to_repeat_delay(_get_attack_profile("attack_first")))
	_sync_primary_attack_input_debug_fields()


func _cancel_primary_attack_repeat() -> void:
	if _action_from_animation(sprite.animation) == "attack_first":
		if animation_player != null and animation_player.is_playing():
			animation_player.stop()
		_clear_attack_runtime_state()
		attack_lockout_remaining = 0.0
		_return_to_locomotion_state()


func _get_hold_to_repeat_delay(attack_profile: Resource) -> float:
	return _combat_controller.get_hold_to_repeat_delay(attack_profile, 0.0)


func _can_move_during_locked_attack() -> bool:
	return _player_state_machine.is_state(PSM.ATTACK)


func _apply_locked_attack_movement() -> void:
	var movement := _get_keyboard_movement()
	if movement == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	if _get_current_attack_movement_rule() == PCC.MOVEMENT_ROOTED:
		velocity = Vector2.ZERO
		return
	if _can_turn_during_current_attack():
		_turn_current_attack_to_direction(_direction_from_vector(movement))
	velocity = movement.normalized() * get_move_speed() * attacking_move_speed_multiplier


func _apply_firearm_hold_session_movement() -> void:
	var locked_direction := _get_firearm_hold_session_direction(current_direction)
	var movement := _get_keyboard_movement()
	current_direction = locked_direction
	if movement == Vector2.ZERO:
		velocity = Vector2.ZERO
		play_idle(locked_direction)
		return
	velocity = movement.normalized() * get_move_speed() * attacking_move_speed_multiplier
	play_walk(locked_direction)


func _turn_current_attack_to_movement_input() -> void:
	if not _player_state_machine.is_state(PSM.ATTACK) or not _can_turn_during_current_attack():
		return
	var movement := _get_keyboard_movement()
	if movement == Vector2.ZERO:
		return
	_turn_current_attack_to_direction(_direction_from_vector(movement))


func _can_turn_during_current_attack() -> bool:
	return _get_current_attack_movement_rule() == PCC.MOVEMENT_SLOW_TURN_TO_INPUT


func _get_current_attack_movement_rule() -> String:
	return _combat_controller.get_attack_movement_rule(_get_current_attack_profile(), equipped_weapon)


func _turn_current_attack_to_direction(next_direction: String) -> void:
	if next_direction == "" or next_direction == current_direction:
		return
	current_direction = next_direction
	_update_attack_area_transform()
	if _combat_controller.current_attack_action == "":
		return

	var next_animation := _animation_name(_combat_controller.current_attack_action, current_direction)
	if next_animation == _combat_controller.current_attack_animation:
		return

	var current_frame := sprite.frame
	var was_playing := sprite.is_playing()
	_combat_controller.update_attack_animation(next_animation)
	_sync_current_attack_debug_fields()
	if animation_player != null and animation_player.has_animation(next_animation):
		var seek_time := _animation_time_for_frame(next_animation, current_frame)
		animation_player.play(next_animation)
		if seek_time > 0.0:
			animation_player.seek(seek_time, true)
		_sync_equipment_visual_to_animation(next_animation, sprite.frame, was_playing)
		call_deferred("_apply_equipment_visual_layer", next_animation)
		return

	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(next_animation):
		return
	sprite.animation = StringName(next_animation)
	var frame_count := sprite.sprite_frames.get_frame_count(next_animation)
	sprite.frame = mini(current_frame, maxi(frame_count - 1, 0))
	if was_playing:
		sprite.play()
	else:
		sprite.stop()
	_sync_equipment_visual_to_sprite()


func _animation_time_for_frame(animation_name: String, frame: int) -> float:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return 0.0
	var animation_speed := float(sprite.sprite_frames.get_animation_speed(animation_name))
	if animation_speed <= 0.0:
		return 0.0
	return maxf(float(frame), 0.0) / animation_speed


func _direction_vector_from_name(direction_name: String) -> Vector2:
	if direction_name == "side_left":
		return Vector2.LEFT
	if direction_name == "up":
		return Vector2.UP
	if direction_name == "down":
		return Vector2.DOWN
	return Vector2.RIGHT


func _action_from_animation(animation_name: StringName) -> String:
	var name := String(animation_name)
	var parts := name.split("_", false)
	if parts.size() >= 3 and (parts[0] in ["attack", "death"]):
		return "%s_%s" % [parts[0], parts[parts.size() - 1]]
	return parts[0] if not parts.is_empty() else name


func _configure_camera() -> void:
	if follow_camera == null:
		return
	follow_camera.enabled = camera_follow_enabled
	follow_camera.zoom = camera_zoom
	follow_camera.position_smoothing_enabled = camera_smoothing_enabled
	follow_camera.position_smoothing_speed = camera_smoothing_speed


func configure_stats(new_stats: Resource) -> void:
	stats = new_stats
	health = get_max_health()
	health_changed.emit(health, get_max_health())


func equip_weapon(weapon_data: Resource) -> void:
	if weapon_data == null:
		return

	equipped_weapon = weapon_data
	var visual_sprite_frames := weapon_data.get("visual_sprite_frames") as SpriteFrames
	if visual_sprite_frames != null:
		equip_weapon_visual(visual_sprite_frames)
	play_pickup(current_direction)
	weapon_equipped.emit(weapon_data)


func drop_current_weapon() -> bool:
	if equipped_weapon == null:
		return false

	var pickup_scene_path := String(equipped_weapon.get("pickup_scene_path"))
	if pickup_scene_path == "":
		return false

	var pickup_scene := load(pickup_scene_path) as PackedScene
	if pickup_scene == null:
		return false

	var pickup := pickup_scene.instantiate() as Node2D
	if pickup == null:
		return false

	var drop_parent := get_parent()
	if drop_parent == null:
		drop_parent = get_tree().current_scene
	if drop_parent == null:
		pickup.queue_free()
		return false

	drop_parent.add_child(pickup)
	pickup.global_position = global_position + _direction_vector_from_name(current_direction) * 18.0
	pickup.set("item_data", equipped_weapon)

	equipped_weapon = null
	_end_firearm_hold_session()
	_clear_attack_runtime_state()
	attack_lockout_remaining = 0.0
	clear_weapon_visual()
	play_idle(current_direction)
	weapon_equipped.emit(null)
	return true


func _try_pickup_nearby_weapon() -> bool:
	var nearest_pickup: Node2D
	var nearest_distance := INF
	for pickup in get_tree().get_nodes_in_group("pickup_item"):
		if not pickup.has_method("can_be_picked_by") or not pickup.can_be_picked_by(self):
			continue
		var pickup_2d := pickup as Node2D
		if pickup_2d == null:
			continue
		var distance := global_position.distance_to(pickup_2d.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_pickup = pickup_2d

	if nearest_pickup == null or not nearest_pickup.has_method("pickup_by"):
		return false
	return bool(nearest_pickup.pickup_by(self))


func pickup_item(item_data: Resource) -> bool:
	if item_data == null:
		return false
	match String(item_data.get("item_type")):
		"weapon":
			equip_weapon(item_data)
			return true
		_:
			return false


func equip_weapon_visual(sprite_frames: SpriteFrames) -> void:
	if hands_sprite == null:
		return

	_equipment_visual_enabled = true
	hands_sprite.sprite_frames = sprite_frames
	_sync_equipment_visual_to_sprite()


func clear_weapon_visual() -> void:
	if hands_sprite == null:
		return

	# Clearing a weapon returns the layered hand sprite to the unarmed hand set.
	_equipment_visual_enabled = _unarmed_visual_sprite_frames != null
	hands_sprite.position = _equipment_visual_base_position
	hands_sprite.sprite_frames = _unarmed_visual_sprite_frames
	_sync_equipment_visual_to_sprite()


func take_damage(amount: int) -> void:
	if health <= 0 or invincible_time_remaining > 0.0:
		return

	var actual_damage := maxi(amount - get_defense(), 1)
	health = maxi(health - actual_damage, 0)
	invincible_time_remaining = get_invincible_time()
	if damage_log_enabled:
		print("%s 被打到了，受到 %d 点伤害，剩余血量 %d/%d" % [get_display_name(), actual_damage, health, get_max_health()])
	health_changed.emit(health, get_max_health())
	_flash_hurt()
	if health == 0:
		die()


func die() -> void:
	if health > 0:
		return

	velocity = Vector2.ZERO
	_change_player_state(PSM.DEAD)
	_end_firearm_hold_session()
	_clear_attack_runtime_state()
	var death_animation := _animation_name("death_first", current_direction)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(death_animation):
		sprite.play(death_animation)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation("death_side_first"):
		sprite.play("death_side_first")
	else:
		hide()
	died.emit(self)


func get_max_health() -> int:
	return stats.max_health if stats != null else 100


func get_current_health() -> int:
	return health


func get_player_state() -> String:
	return _player_state_machine.current_state


func get_attack_phase() -> String:
	return _combat_controller.current_attack_phase


func _set_current_attack_phase(phase: String) -> void:
	_combat_controller.set_attack_phase(phase)


func _mark_current_attack_hit_window_reached() -> void:
	_combat_controller.mark_hit_window_reached()
	_current_attack_hit_window_reached = true


func _sync_current_attack_debug_fields() -> void:
	_current_attack_action = _combat_controller.current_attack_action
	_current_attack_animation = _combat_controller.current_attack_animation
	_current_attack_hit_window_reached = _combat_controller.current_attack_hit_window_reached


func _sync_primary_attack_input_debug_fields() -> void:
	_primary_attack_hold_time = _combat_controller.primary_attack_hold_time
	_primary_attack_repeat_ready = _combat_controller.primary_attack_repeat_ready
	_primary_attack_buffer_time_remaining = _combat_controller.primary_attack_buffer_time_remaining
	_primary_attack_repeat_active = _combat_controller.primary_attack_repeat_active


func _sync_primary_attack_input_controller_from_debug_fields() -> void:
	_combat_controller.primary_attack_hold_time = _primary_attack_hold_time
	_combat_controller.primary_attack_repeat_ready = _primary_attack_repeat_ready
	_combat_controller.primary_attack_buffer_time_remaining = _primary_attack_buffer_time_remaining
	_combat_controller.primary_attack_repeat_active = _primary_attack_repeat_active


func is_alive() -> bool:
	return health > 0


func apply_status_effect(effect_name: String, duration: float, _source: Node = null) -> void:
	if health <= 0:
		return
	if effect_name == "stun":
		stun_time_remaining = maxf(stun_time_remaining, duration)
		velocity = Vector2.ZERO
		_change_player_state(PSM.STUNNED)
		_end_firearm_hold_session()
		_clear_attack_runtime_state()
		attack_lockout_remaining = 0.0
		_play_idle_animation_immediate(current_direction)


func is_stunned() -> bool:
	return stun_time_remaining > 0.0


func get_display_name() -> String:
	return stats.display_name if stats != null else name


func get_move_speed() -> float:
	return stats.move_speed if stats != null else movement_speed


func get_defense() -> int:
	return stats.defense if stats != null else 0


func get_attack_power() -> int:
	var fallback_attack_power: int = stats.attack_power if stats != null else damage
	return _combat_controller.get_attack_power(_get_current_attack_profile(), fallback_attack_power)


func _attack_key_label_for_action(action: String) -> String:
	if action == "attack_first":
		return "J"
	if action == "attack_second":
		return "K"
	return action


func get_attack_interval(attack_profile: Resource = null, interval_kind := ATTACK_INTERVAL_MANUAL) -> float:
	if attack_profile == null:
		attack_profile = _get_attack_profile("attack_first")
	var fallback_interval := DEFAULT_REPEAT_ATTACK_INTERVAL if interval_kind == ATTACK_INTERVAL_REPEAT else DEFAULT_MANUAL_ATTACK_LOCKOUT
	if interval_kind == ATTACK_INTERVAL_REPEAT:
		return _combat_controller.get_repeat_attack_cooldown(attack_profile, equipped_weapon, fallback_interval)
	return _combat_controller.get_manual_attack_lockout(attack_profile, equipped_weapon, fallback_interval)


func get_invincible_time() -> float:
	return stats.invincible_time if stats != null else 0.35


func _get_keyboard_movement() -> Vector2:
	return _player_input_controller.get_movement_vector()


func _direction_from_vector(direction_vector: Vector2) -> String:
	return _player_input_controller.direction_from_vector(direction_vector)


func _is_key_pressed(event: InputEvent, key: int) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == key or key_event.physical_keycode == key


func _is_key_currently_pressed(key: int) -> bool:
	return _player_input_controller.is_key_currently_pressed(key)


func _is_locked_animation() -> bool:
	var action_name := _action_from_animation(sprite.animation)
	return action_name.begins_with("attack_") or action_name.begins_with("death_") or action_name == "pickup"


func _play_animation_if_changed(animation_name: String) -> void:
	if sprite.animation == StringName(animation_name) and sprite.is_playing():
		return
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		_sync_equipment_visual_to_sprite()


func _animation_name(action: String, direction: String) -> String:
	var parts := action.split("_", false, 1)
	if parts.size() == 2 and (parts[0] in ["attack", "death"]):
		return "%s_%s_%s" % [parts[0], direction, parts[1]]
	return "%s_%s" % [action, direction]


func _direction_from_animation(animation_name: StringName) -> String:
	var name := String(animation_name)
	var parts := name.split("_", false)
	if parts.size() >= 3 and parts[1] == "side" and parts[2] == "left":
		return "side_left"
	if parts.size() >= 2 and parts[1] == "side":
		return "side"
	if parts.size() >= 2 and parts[1] == "down":
		return "down"
	if parts.size() >= 2 and parts[1] == "up":
		return "up"
	if name.ends_with("_side_left"):
		return "side_left"
	if name.ends_with("_side"):
		return "side"
	if name.ends_with("_down"):
		return "down"
	if name.ends_with("_up"):
		return "up"
	return current_direction


func _sync_equipment_visual_to_sprite() -> void:
	if hands_sprite == null or hands_sprite.sprite_frames == null or not _equipment_visual_enabled:
		return

	_sync_equipment_visual_to_animation(String(sprite.animation), sprite.frame, sprite.is_playing())


func _sync_equipment_visual_to_animation(animation_name: String, frame := 0, playing := true) -> void:
	if hands_sprite == null or hands_sprite.sprite_frames == null or not _equipment_visual_enabled:
		return

	_apply_equipment_visual_offset(animation_name)
	if not hands_sprite.sprite_frames.has_animation(animation_name):
		hands_sprite.hide()
		return

	hands_sprite.show()
	_apply_equipment_visual_layer(animation_name)
	if hands_sprite.animation != StringName(animation_name):
		hands_sprite.animation = StringName(animation_name)
	hands_sprite.frame = mini(frame, hands_sprite.sprite_frames.get_frame_count(animation_name) - 1)
	hands_sprite.speed_scale = sprite.speed_scale
	if playing and not hands_sprite.is_playing():
		hands_sprite.play()
	elif not playing and hands_sprite.is_playing():
		hands_sprite.stop()


func _apply_equipment_visual_offset(animation_name: String) -> void:
	if hands_sprite == null:
		return

	hands_sprite.position = _equipment_visual_base_position + _equipment_visual_offset_for_animation(animation_name)


func _equipment_visual_offset_for_animation(animation_name: String) -> Vector2:
	var visual_offset := Vector2.ZERO
	if equipped_weapon != null:
		var direction_name := _direction_from_animation(StringName(animation_name))
		if direction_name == "down":
			visual_offset = equipped_weapon.get("visual_offset_down")
		elif direction_name == "up":
			visual_offset = equipped_weapon.get("visual_offset_up")
		elif direction_name == "side_left":
			visual_offset = equipped_weapon.get("visual_offset_side_left")
		else:
			visual_offset = equipped_weapon.get("visual_offset_side")
		var animation_offsets = equipped_weapon.get("animation_visual_offsets")
		if animation_offsets is Dictionary:
			var animation_offset = animation_offsets.get(animation_name, animation_offsets.get(StringName(animation_name), Vector2.ZERO))
			if animation_offset is Vector2:
				visual_offset += animation_offset
	return visual_offset


func _apply_equipment_visual_layer(animation_name: String) -> void:
	if hands_sprite == null:
		return

	if _should_draw_hands_behind_body(animation_name):
		sprite.z_index = _body_visual_base_z_index
		hands_sprite.z_index = _equipment_visual_base_z_index - 1
	else:
		sprite.z_index = _body_visual_base_z_index
		hands_sprite.z_index = _equipment_visual_base_z_index


func _should_draw_hands_behind_body(animation_name: String) -> bool:
	return _direction_from_animation(StringName(animation_name)) == "up"


func _flash_hurt() -> void:
	if hurt_flash_feedback != null and hurt_flash_feedback.has_method("play"):
		if hurt_flash_feedback.play():
			return

	sprite.modulate = Color(1.0, 0.25, 0.25)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
