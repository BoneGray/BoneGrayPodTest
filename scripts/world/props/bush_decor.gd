extends Sprite2D
class_name BushDecor

signal bush_entered(trigger: Node)
signal bush_exited(trigger: Node)

@export_group("Trigger")
## 用来检测玩家是否进入灌木范围的 Area2D 路径；留空时默认查找子节点 InteractionArea。
@export_node_path("Area2D") var interaction_area_path: NodePath = ^"InteractionArea"

## 可以触发灌木淡化和抖动的分组名称，通常是 player。
@export var trigger_group := "player"

## 是否按 YSort 规则判断真实进入灌木；开启后，只有触发对象的 Y 小于灌木排序点 Y 时才算进入。
@export var require_trigger_above_sort_y := true

## YSort 判断的容差像素，避免对象刚好在边界时频繁进出。
@export_range(0.0, 16.0, 0.1) var sort_y_margin := 0.0

@export_group("Fade")
## 灌木正常显示时的透明度，通常保持为 1.0。
@export_range(0.0, 1.0, 0.01) var normal_alpha := 1.0

## 触发对象被灌木遮挡时，灌木淡化到的透明度。
@export_range(0.0, 1.0, 0.01) var faded_alpha := 0.58

## 从正常显示淡化到半透明所用的秒数。
@export_range(0.0, 2.0, 0.01) var fade_in_time := 0.1

## 从半透明恢复正常显示所用的秒数。
@export_range(0.0, 2.0, 0.01) var fade_out_time := 0.2

@export_group("Ambient Motion")
## 是否启用常驻呼吸摆动。
@export var ambient_enabled := true

## 常驻呼吸摆动完成一次循环所用的秒数。
@export_range(0.1, 20.0, 0.01) var ambient_duration := 2.8

## 常驻左右旋转幅度，单位为角度；灌木建议保持在 0.3 到 1.5 之间。
@export_range(0.0, 10.0, 0.01) var ambient_rotation_degrees := 0.75

## 常驻缩放呼吸幅度；例如 Vector2(0.006, 0.004) 表示非常轻微的呼吸。
@export var ambient_scale_amplitude := Vector2(0.006, 0.004)

## 是否在运行时追加随机相位，让多棵灌木不会同步摆动。
@export var randomize_phase := true

## 随机相位的最大范围，单位为 0 到 1 的循环比例。
@export_range(0.0, 1.0, 0.001) var random_phase_range := 1.0

@export_group("Enter Motion")
## 真实进入灌木时是否触发进入抖动。
@export var enter_shake_enabled := true

## 进入抖动动画持续的秒数。
@export_range(0.05, 2.0, 0.01) var enter_shake_duration := 0.34

## 进入抖动旋转的最大幅度，单位为角度；通常比离开抖动更大。
@export_range(0.0, 20.0, 0.01) var enter_shake_rotation_degrees := 4.2

## 进入抖动时额外增加的缩放回弹幅度。
@export var enter_shake_scale_bump := Vector2(0.022, 0.014)

## 进入抖动动画中的来回摆动次数。
@export_range(1.0, 6.0, 0.1) var enter_shake_oscillations := 2.2

@export_group("Exit Motion")
## 真实离开灌木时是否触发离开抖动。
@export var exit_shake_enabled := true

## 离开抖动动画持续的秒数。
@export_range(0.05, 2.0, 0.01) var exit_shake_duration := 0.22

## 离开抖动旋转的最大幅度，单位为角度；通常比进入抖动更小。
@export_range(0.0, 20.0, 0.01) var exit_shake_rotation_degrees := 1.8

## 离开抖动时额外增加的缩放回弹幅度。
@export var exit_shake_scale_bump := Vector2(0.008, 0.005)

## 离开抖动动画中的来回摆动次数。
@export_range(1.0, 6.0, 0.1) var exit_shake_oscillations := 1.4

var _base_rotation := 0.0
var _base_scale := Vector2.ONE
var _base_alpha := 1.0
var _elapsed := 0.0
var _runtime_phase := 0.0
var _overlapping_triggers: Array[Node2D] = []
var _active_trigger: Node2D
var _fade_tween: Tween
var _shake_elapsed := 0.0
var _shake_duration := 0.0
var _shake_rotation_degrees := 0.0
var _shake_scale_bump := Vector2.ZERO
var _shake_oscillations := 1.0
var _shake_sign := 1.0
var _interaction_area: Area2D
var _interaction_area_local_position := Vector2.ZERO
var _base_global_scale := Vector2.ONE


func _ready() -> void:
	_base_rotation = rotation
	_base_scale = scale
	_base_global_scale = global_scale
	_base_alpha = normal_alpha
	modulate.a = normal_alpha
	if randomize_phase:
		_runtime_phase = randf() * random_phase_range
	_connect_interaction_area()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _shake_elapsed < _shake_duration:
		_shake_elapsed += delta
	_update_active_state()
	_apply_motion()
	_sync_interaction_area()


func _connect_interaction_area() -> void:
	_interaction_area = get_node_or_null(interaction_area_path) as Area2D
	if _interaction_area == null:
		return
	_interaction_area_local_position = _interaction_area.position
	_interaction_area.top_level = true
	_sync_interaction_area()
	_interaction_area.collision_layer = 0
	if _interaction_area.collision_mask == 0:
		_interaction_area.collision_mask = 2
	_interaction_area.monitoring = true
	_interaction_area.monitorable = false
	if not _interaction_area.body_entered.is_connected(_on_body_entered):
		_interaction_area.body_entered.connect(_on_body_entered)
	if not _interaction_area.body_exited.is_connected(_on_body_exited):
		_interaction_area.body_exited.connect(_on_body_exited)


func _sync_interaction_area() -> void:
	if _interaction_area == null:
		return
	_interaction_area.global_position = global_position + _interaction_area_local_position * _base_global_scale
	_interaction_area.global_rotation = 0.0
	_interaction_area.global_scale = _base_global_scale


func _on_body_entered(body: Node) -> void:
	if not _is_valid_trigger(body):
		return
	var trigger := body as Node2D
	if trigger == null or _overlapping_triggers.has(trigger):
		return
	_overlapping_triggers.append(trigger)
	_update_active_state()


func _on_body_exited(body: Node) -> void:
	var trigger := body as Node2D
	if trigger == null or not _overlapping_triggers.has(trigger):
		return
	_overlapping_triggers.erase(trigger)
	_update_active_state()


func _is_valid_trigger(body: Node) -> bool:
	if body == null:
		return false
	if trigger_group.strip_edges() == "":
		return body is Node2D
	return body.is_in_group(trigger_group) and body is Node2D


func _update_active_state() -> void:
	_overlapping_triggers = _overlapping_triggers.filter(func(trigger: Node2D) -> bool:
		return is_instance_valid(trigger)
	)

	var next_active_trigger := _find_active_trigger()
	if next_active_trigger == _active_trigger:
		return

	var previous_trigger := _active_trigger
	_active_trigger = next_active_trigger
	if _active_trigger != null:
		_on_bush_entered(_active_trigger)
	elif previous_trigger != null:
		_on_bush_exited(previous_trigger)


func _find_active_trigger() -> Node2D:
	for trigger in _overlapping_triggers:
		if _is_trigger_inside_bush(trigger):
			return trigger
	return null


func _is_trigger_inside_bush(trigger: Node2D) -> bool:
	if trigger == null:
		return false
	if not require_trigger_above_sort_y:
		return true
	return trigger.global_position.y < global_position.y - sort_y_margin


func _on_bush_entered(trigger: Node2D) -> void:
	_start_fade(true)
	_start_enter_shake(trigger)
	bush_entered.emit(trigger)


func _on_bush_exited(trigger: Node2D) -> void:
	_start_fade(false)
	_start_exit_shake(trigger)
	bush_exited.emit(trigger)


func _start_fade(should_fade: bool) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	var target_alpha := faded_alpha if should_fade else _base_alpha
	var duration := fade_in_time if should_fade else fade_out_time
	if duration <= 0.0:
		modulate.a = target_alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", target_alpha, duration)


func _start_enter_shake(trigger: Node2D) -> void:
	if not enter_shake_enabled:
		return
	_start_shake(
		trigger,
		enter_shake_duration,
		enter_shake_rotation_degrees,
		enter_shake_scale_bump,
		enter_shake_oscillations
	)


func _start_exit_shake(trigger: Node2D) -> void:
	if not exit_shake_enabled:
		return
	_start_shake(
		trigger,
		exit_shake_duration,
		exit_shake_rotation_degrees,
		exit_shake_scale_bump,
		exit_shake_oscillations
	)


func _start_shake(
	trigger: Node2D,
	duration: float,
	rotation_degrees: float,
	scale_bump: Vector2,
	oscillations: float
) -> void:
	_shake_elapsed = 0.0
	_shake_duration = duration
	_shake_rotation_degrees = rotation_degrees
	_shake_scale_bump = scale_bump
	_shake_oscillations = oscillations
	_shake_sign = -1.0 if trigger.global_position.x > global_position.x else 1.0


func _apply_motion() -> void:
	var ambient_rotation := 0.0
	var ambient_scale := Vector2.ZERO
	if ambient_enabled and ambient_duration > 0.0:
		var phase := (_elapsed / ambient_duration + _runtime_phase) * TAU
		var wave := sin(phase)
		var soft_wave := sin(phase + PI * 0.5)
		ambient_rotation = deg_to_rad(ambient_rotation_degrees) * wave
		ambient_scale = ambient_scale_amplitude * soft_wave

	var shake_rotation := 0.0
	var shake_scale := Vector2.ZERO
	if _shake_elapsed < _shake_duration:
		var progress := clampf(_shake_elapsed / maxf(_shake_duration, 0.001), 0.0, 1.0)
		var decay := 1.0 - progress
		var shake_wave := sin(progress * TAU * _shake_oscillations) * decay
		shake_rotation = deg_to_rad(_shake_rotation_degrees) * shake_wave * _shake_sign
		shake_scale = _shake_scale_bump * sin(progress * PI) * decay

	rotation = _base_rotation + ambient_rotation + shake_rotation
	scale = _base_scale + ambient_scale + shake_scale
