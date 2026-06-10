extends CharacterBody2D

signal attack_hit(target: Node)
signal health_changed(current: int, maximum: int)
signal died(player: Node)

@export var stats: Resource
@export var damage := 10
@export var target_group := "player"
@export var use_directional_attack_area_offsets := true
@export var keyboard_control_enabled := true
@export var movement_speed := 90.0
@export var primary_attack_key := KEY_J
@export var secondary_attack_key := KEY_K
@export var camera_follow_enabled := true
@export var camera_zoom := Vector2(3, 3)
@export var camera_smoothing_enabled := true
@export var camera_smoothing_speed := 5.0
@export var damage_log_enabled := true
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
var attack_cooldown_remaining := 0.0
var invincible_time_remaining := 0.0
var stun_time_remaining := 0.0
var _hit_targets: Array[Node] = []
var _attack_active := false
var _equipment_visual_enabled := true

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
	health = get_max_health()
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


func _physics_process(delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	invincible_time_remaining = maxf(invincible_time_remaining - delta, 0.0)
	stun_time_remaining = maxf(stun_time_remaining - delta, 0.0)
	if not keyboard_control_enabled or _is_locked_animation() or is_stunned():
		velocity = Vector2.ZERO
		if is_stunned() and not _is_locked_animation():
			play_idle(current_direction)
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
	if not keyboard_control_enabled or _is_locked_animation() or is_stunned():
		return
	if attack_cooldown_remaining > 0.0:
		return
	if _is_key_pressed(event, primary_attack_key):
		attack("attack_first", current_direction)
	elif _is_key_pressed(event, secondary_attack_key):
		attack("attack_second", current_direction)


func play_idle(direction := current_direction) -> void:
	current_direction = direction
	_play_animation_if_changed("idle_%s" % current_direction)


func play_walk(direction := current_direction) -> void:
	current_direction = direction
	_play_animation_if_changed("walk_%s" % current_direction)


func attack(action := "attack_first", direction := current_direction) -> void:
	current_direction = direction
	attack_cooldown_remaining = get_attack_cooldown()
	set_meta("current_attack_action", action)
	if attack_log_enabled:
		print("%s 使用%s攻击，方向 %s" % [get_display_name(), _attack_key_label_for_action(action), current_direction])
	_hit_targets.clear()
	_set_attack_active(false)
	var animation_name := _animation_name(action, current_direction)
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		_sync_equipment_visual_to_animation(animation_name)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		_sync_equipment_visual_to_sprite()


func _on_frame_changed() -> void:
	_update_direction_from_animation()
	_sync_equipment_visual_to_sprite()
	var action_name := _action_from_animation(sprite.animation)
	if not attack_hit_frames.has(action_name):
		_set_attack_active(false)
		return

	var hit_frames: Array = attack_hit_frames[action_name]
	var should_hit := sprite.frame in hit_frames
	_set_attack_active(should_hit)
	if should_hit:
		_apply_attack_hits()


func _on_animation_finished() -> void:
	_set_attack_active(false)
	if _action_from_animation(sprite.animation).begins_with("attack_"):
		play_idle(current_direction)


func _on_animation_player_finished(animation_name: StringName) -> void:
	_set_attack_active(false)
	if _action_from_animation(animation_name).begins_with("attack_"):
		play_idle(current_direction)


func _set_attack_active(active: bool) -> void:
	_attack_active = active
	_update_attack_area_transform()
	attack_area.monitoring = active
	attack_shape.disabled = not active


func _apply_attack_hits() -> void:
	var max_targets := _get_current_attack_max_targets()
	if max_targets > 0 and _hit_targets.size() >= max_targets:
		return

	var hit_targets := _collect_attack_hit_targets()
	var applied_count := 0
	for hit_target in hit_targets:
		if hit_target in _hit_targets:
			continue

		_hit_targets.append(hit_target)
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(get_attack_power())
		attack_hit.emit(hit_target)

		applied_count += 1
		if max_targets > 0 and _hit_targets.size() >= max_targets:
			return


func _apply_active_attack_hits() -> void:
	if attack_area.monitoring and not attack_shape.disabled:
		_apply_attack_hits()


func _collect_attack_hit_targets() -> Array[Node]:
	var hit_targets: Array[Node] = []
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
	var action := String(get_meta("current_attack_action", "attack_first"))
	return attack_target_limits.get(action, 1)


func _get_current_attack_hit_count() -> int:
	return _hit_targets.size()


func _reset_current_attack_hits() -> void:
	_hit_targets.clear()


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


func equip_weapon_visual(sprite_frames: SpriteFrames) -> void:
	if hands_sprite == null:
		return

	_equipment_visual_enabled = true
	hands_sprite.sprite_frames = sprite_frames
	_sync_equipment_visual_to_sprite()


func clear_weapon_visual() -> void:
	if hands_sprite == null:
		return

	_equipment_visual_enabled = false
	hands_sprite.hide()


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
	_set_attack_active(false)
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


func is_alive() -> bool:
	return health > 0


func apply_status_effect(effect_name: String, duration: float, _source: Node = null) -> void:
	if health <= 0:
		return
	if effect_name == "stun":
		stun_time_remaining = maxf(stun_time_remaining, duration)
		velocity = Vector2.ZERO
		_set_attack_active(false)
		play_idle(current_direction)


func is_stunned() -> bool:
	return stun_time_remaining > 0.0


func get_display_name() -> String:
	return stats.display_name if stats != null else name


func get_move_speed() -> float:
	return stats.move_speed if stats != null else movement_speed


func get_defense() -> int:
	return stats.defense if stats != null else 0


func get_attack_power() -> int:
	return stats.attack_power if stats != null else damage


func _attack_key_label_for_action(action: String) -> String:
	if action == "attack_first":
		return "J"
	if action == "attack_second":
		return "K"
	return action


func get_attack_cooldown() -> float:
	return stats.attack_cooldown if stats != null else 0.35


func get_invincible_time() -> float:
	return stats.invincible_time if stats != null else 0.35


func _get_keyboard_movement() -> Vector2:
	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement.y += 1.0
	return movement


func _direction_from_vector(direction_vector: Vector2) -> String:
	if absf(direction_vector.x) >= absf(direction_vector.y):
		if direction_vector.x < 0.0:
			return "side_left"
		return "side"
	if direction_vector.y < 0.0:
		return "up"
	return "down"


func _is_key_pressed(event: InputEvent, key: int) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == key or key_event.physical_keycode == key


func _is_locked_animation() -> bool:
	var action_name := _action_from_animation(sprite.animation)
	return action_name.begins_with("attack_") or action_name.begins_with("death_")


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

	if not hands_sprite.sprite_frames.has_animation(animation_name):
		hands_sprite.hide()
		return

	hands_sprite.show()
	if hands_sprite.animation != StringName(animation_name):
		hands_sprite.animation = StringName(animation_name)
	hands_sprite.frame = mini(frame, hands_sprite.sprite_frames.get_frame_count(animation_name) - 1)
	hands_sprite.speed_scale = sprite.speed_scale
	if playing and not hands_sprite.is_playing():
		hands_sprite.play()
	elif not playing and hands_sprite.is_playing():
		hands_sprite.stop()


func _flash_hurt() -> void:
	if hurt_flash_feedback != null and hurt_flash_feedback.has_method("play"):
		if hurt_flash_feedback.play():
			return

	sprite.modulate = Color(1.0, 0.25, 0.25)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
