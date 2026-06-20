extends Node2D
class_name AmbientSway2D

@export_group("Sway")
## 是否启用环境摆动。关闭时节点会回到初始位置、角度和缩放。
@export var sway_enabled := true:
	set(value):
		sway_enabled = value
		set_process(sway_enabled)
		if not sway_enabled and is_inside_tree():
			_restore_base_transform()

## 完成一次完整摆动循环所用的秒数，数值越大摆动越慢。
@export_range(0.1, 20.0, 0.01) var duration := 2.6

## 位置摆动幅度，单位为像素；挂在参与 YSort 的根节点时通常保持为 Vector2.ZERO。
@export var position_amplitude := Vector2.ZERO

## 旋转摆动幅度，单位为角度；实体主体建议很小，柔性树冠、草叶可稍大。
@export_range(0.0, 10.0, 0.01) var rotation_degrees_amplitude := 0.0

## 缩放呼吸幅度；例如 Vector2(0.01, 0.01) 表示最多放大约 1%。
@export var scale_amplitude := Vector2.ZERO

@export_group("Phase")
## 固定相位偏移，单位为 0 到 1 的循环比例，用来让不同部件错开摆动。
@export_range(0.0, 1.0, 0.001) var phase_offset := 0.0

## 是否在运行时追加随机相位，让同类物体不会完全同步摆动。
@export var randomize_phase := true

## 随机相位的最大范围，单位为 0 到 1 的循环比例。
@export_range(0.0, 1.0, 0.001) var random_phase_range := 1.0

var _base_position := Vector2.ZERO
var _base_rotation := 0.0
var _base_scale := Vector2.ONE
var _elapsed := 0.0
var _runtime_phase := 0.0


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	_base_scale = scale
	if randomize_phase:
		_runtime_phase = randf() * random_phase_range
	set_process(sway_enabled)


func _process(delta: float) -> void:
	if duration <= 0.0:
		return

	_elapsed += delta
	var phase := (_elapsed / duration + phase_offset + _runtime_phase) * TAU
	var wave := sin(phase)
	var soft_wave := sin(phase + PI * 0.5)

	position = _base_position + position_amplitude * wave
	rotation = _base_rotation + deg_to_rad(rotation_degrees_amplitude) * wave
	scale = _base_scale + scale_amplitude * soft_wave


func _restore_base_transform() -> void:
	position = _base_position
	rotation = _base_rotation
	scale = _base_scale
