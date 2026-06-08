extends CharacterBody2D

signal attack_hit(target: Node)

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

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_area: Area2D = $AttackArea2D
@onready var attack_shape: CollisionShape2D = $AttackArea2D/CollisionShape2D
@onready var follow_camera: Camera2D = get_node_or_null("FollowCamera2D")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var current_direction := "side"
var _hit_targets: Array[Node] = []
var _attack_active := false

var attack_hit_frames := {
	"first_attack": [2],
	"second_attack": [2],
}

var attack_area_offsets := {
	"side": Vector2(10, 1),
	"side_left": Vector2(-10, 1),
	"down": Vector2(0, 8),
	"up": Vector2(0, -7),
}


func _ready() -> void:
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_player_finished)
	_update_direction_from_animation()
	_set_attack_active(false)
	_configure_camera()
	play_idle(current_direction)


func _physics_process(_delta: float) -> void:
	if not keyboard_control_enabled or _is_locked_animation():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var movement := _get_keyboard_movement()
	if movement == Vector2.ZERO:
		velocity = Vector2.ZERO
		play_idle(current_direction)
		move_and_slide()
		return

	current_direction = _direction_from_vector(movement)
	velocity = movement.normalized() * movement_speed
	play_walk(current_direction)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not keyboard_control_enabled or _is_locked_animation():
		return
	if _is_key_pressed(event, primary_attack_key):
		attack("first_attack", current_direction)
	elif _is_key_pressed(event, secondary_attack_key):
		attack("second_attack", current_direction)


func play_idle(direction := current_direction) -> void:
	current_direction = direction
	_play_animation_if_changed("idle_%s" % current_direction)


func play_walk(direction := current_direction) -> void:
	current_direction = direction
	_play_animation_if_changed("walk_%s" % current_direction)


func attack(action := "first_attack", direction := current_direction) -> void:
	current_direction = direction
	_hit_targets.clear()
	_set_attack_active(false)
	var animation_name := "%s_%s" % [action, current_direction]
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)


func _on_frame_changed() -> void:
	_update_direction_from_animation()
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
	if _action_from_animation(sprite.animation).ends_with("_attack"):
		play_idle(current_direction)


func _on_animation_player_finished(animation_name: StringName) -> void:
	_set_attack_active(false)
	if _action_from_animation(animation_name).ends_with("_attack"):
		play_idle(current_direction)


func _set_attack_active(active: bool) -> void:
	_attack_active = active
	_update_attack_area_transform()
	attack_area.monitoring = active
	attack_shape.disabled = not active


func _apply_attack_hits() -> void:
	for body in attack_area.get_overlapping_bodies():
		_try_hit_target(body)
	for area in attack_area.get_overlapping_areas():
		_try_hit_target(area)


func _try_hit_target(target: Node) -> void:
	var hit_target := _resolve_hit_target(target)
	if hit_target == null or hit_target in _hit_targets:
		return

	_hit_targets.append(hit_target)
	if hit_target.has_method("take_damage"):
		hit_target.take_damage(damage)
	attack_hit.emit(hit_target)


func _resolve_hit_target(target: Node) -> Node:
	var current := target
	while current != null:
		if target_group == "" or current.is_in_group(target_group):
			return current
		current = current.get_parent()
	return null


func _update_direction_from_animation() -> void:
	var animation_name := String(sprite.animation)
	if animation_name.ends_with("_side_left"):
		current_direction = "side_left"
	elif animation_name.ends_with("_side"):
		current_direction = "side"
	elif animation_name.ends_with("_down"):
		current_direction = "down"
	elif animation_name.ends_with("_up"):
		current_direction = "up"


func _update_attack_area_transform() -> void:
	if use_directional_attack_area_offsets:
		attack_area.position = attack_area_offsets.get(current_direction, Vector2(10, 1))


func _action_from_animation(animation_name: StringName) -> String:
	var name := String(animation_name)
	if name.begins_with("first_attack_"):
		return "first_attack"
	if name.begins_with("second_attack_"):
		return "second_attack"
	if name.begins_with("first_death_"):
		return "first_death"
	if name.begins_with("second_death_"):
		return "second_death"
	if name.begins_with("third_death_"):
		return "third_death"
	if name.begins_with("idle_"):
		return "idle"
	if name.begins_with("walk_"):
		return "walk"
	return name


func _configure_camera() -> void:
	if follow_camera == null:
		return
	follow_camera.enabled = camera_follow_enabled
	follow_camera.zoom = camera_zoom
	follow_camera.position_smoothing_enabled = camera_smoothing_enabled
	follow_camera.position_smoothing_speed = camera_smoothing_speed


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
	return action_name.ends_with("_attack") or action_name.ends_with("_death")


func _play_animation_if_changed(animation_name: String) -> void:
	if sprite.animation == StringName(animation_name) and sprite.is_playing():
		return
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
