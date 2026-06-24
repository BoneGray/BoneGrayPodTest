extends Camera2D

@export_group("Follow")
## 相机跟随的目标节点路径，通常指向 Player 或测试场景里的可控制角色。
@export var target_path: NodePath
## 相机跟随的平滑强度。值越大越贴近目标，值越小拖尾感越明显。
@export var follow_smoothing := 10.0

@export_group("Look Ahead")
## 是否启用受阻眺望。开启后只有玩家持续按住同一方向且该方向被阻挡时，相机才会朝该方向轻微偏移。
@export var lookahead_enabled := true
## 受阻眺望的最大偏移距离，单位为像素。数值越大，撞到边界后相机越像“眺望”远处。
@export var lookahead_distance := 48.0
## 持续被阻挡多久后才触发眺望，单位为秒。数值越大，越不容易误触发。
@export var lookahead_blocked_delay := 0.35
## 判定“目标几乎没有朝输入方向移动”的每帧像素容差。数值越大，越容易认定为被阻挡。
@export var lookahead_blocked_movement_epsilon := 0.25
## 相机偏向受阻方向的平滑强度。值越大，眺望反应越快。
@export var lookahead_smoothing := 6.0
## 松开方向键或不再受阻后，相机回到玩家身上的平滑强度。值越大，回正越快。
@export var lookahead_return_smoothing := 8.0
## 左方向键列表。默认匹配当前玩家移动键位：A 和左方向键。
@export var lookahead_left_keys: Array[int] = [KEY_A, KEY_LEFT]
## 右方向键列表。默认匹配当前玩家移动键位：D 和右方向键。
@export var lookahead_right_keys: Array[int] = [KEY_D, KEY_RIGHT]
## 上方向键列表。默认匹配当前玩家移动键位：W 和上方向键。
@export var lookahead_up_keys: Array[int] = [KEY_W, KEY_UP]
## 下方向键列表。默认匹配当前玩家移动键位：S 和下方向键。
@export var lookahead_down_keys: Array[int] = [KEY_S, KEY_DOWN]

var target: Node2D
var _lookahead_offset := Vector2.ZERO
var _previous_target_position := Vector2.ZERO
var _blocked_direction := Vector2.ZERO
var _blocked_hold_time := 0.0


func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D
	if target != null:
		_previous_target_position = target.global_position
	enabled = true
	make_current()


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var target_position := target.global_position
	_update_lookahead_offset(delta, target_position)
	var weight := clampf(follow_smoothing * delta, 0.0, 1.0)
	var desired_position := target_position + _lookahead_offset
	global_position = global_position.lerp(desired_position, weight)
	_previous_target_position = target_position


func _update_lookahead_offset(delta: float, target_position: Vector2) -> void:
	var target_offset := Vector2.ZERO
	if lookahead_enabled:
		var input_direction := _get_lookahead_input_direction()
		if _is_input_direction_blocked(input_direction, target_position):
			if _is_lookahead_active():
				_blocked_direction = input_direction
				_blocked_hold_time = maxf(_blocked_hold_time, maxf(lookahead_blocked_delay, 0.0))
			elif _is_same_blocked_direction(input_direction):
				_blocked_hold_time += delta
			else:
				_blocked_direction = input_direction
				_blocked_hold_time = delta
			if _blocked_hold_time >= maxf(lookahead_blocked_delay, 0.0):
				target_offset = _blocked_direction * maxf(lookahead_distance, 0.0)
		else:
			_clear_blocked_lookahead()

	var smoothing := lookahead_smoothing
	if target_offset == Vector2.ZERO:
		smoothing = lookahead_return_smoothing
	var weight := clampf(maxf(smoothing, 0.0) * delta, 0.0, 1.0)
	_lookahead_offset = _lookahead_offset.lerp(target_offset, weight)


func _is_input_direction_blocked(input_direction: Vector2, target_position: Vector2) -> bool:
	if input_direction == Vector2.ZERO:
		return false
	var target_movement := target_position - _previous_target_position
	var movement_toward_input := target_movement.dot(input_direction)
	return movement_toward_input <= maxf(lookahead_blocked_movement_epsilon, 0.0)


func _is_same_blocked_direction(input_direction: Vector2) -> bool:
	if _blocked_direction == Vector2.ZERO:
		return false
	return _blocked_direction.dot(input_direction) > 0.98


func _is_lookahead_active() -> bool:
	if _blocked_hold_time >= maxf(lookahead_blocked_delay, 0.0):
		return true
	return _lookahead_offset.length_squared() > 1.0


func _clear_blocked_lookahead() -> void:
	_blocked_direction = Vector2.ZERO
	_blocked_hold_time = 0.0


func _get_lookahead_input_direction() -> Vector2:
	var direction := Vector2.ZERO
	if _any_key_pressed(lookahead_left_keys):
		direction.x -= 1.0
	if _any_key_pressed(lookahead_right_keys):
		direction.x += 1.0
	if _any_key_pressed(lookahead_up_keys):
		direction.y -= 1.0
	if _any_key_pressed(lookahead_down_keys):
		direction.y += 1.0
	if direction.length_squared() > 1.0:
		return direction.normalized()
	return direction


func _any_key_pressed(keys: Array[int]) -> bool:
	for key in keys:
		if Input.is_key_pressed(key) or Input.is_physical_key_pressed(key):
			return true
	return false
