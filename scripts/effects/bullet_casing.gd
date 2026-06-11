extends Node2D

@export_group("Defaults")
## 弹壳默认弹出速度，攻击配置未传入速度时使用。
@export var default_speed := 55.0
## 弹壳默认运动时间，单位为秒。
@export var default_lifetime := 0.45
## 弹壳开始淡出的时间比例。0 表示立即淡出，1 表示结束前不淡出。
@export_range(0.0, 1.0, 0.05) var fade_start_ratio := 0.6
## 弹壳旋转速度，单位为弧度/秒。
@export var spin_speed := 18.0
## 弹壳飞出动画的最大抬高像素。
@export var hop_height := 5.0

@onready var sprite: Sprite2D = $Sprite

var velocity := Vector2.ZERO
var lifetime := 0.45
var elapsed := 0.0
var start_position := Vector2.ZERO


func launch(direction: Vector2, speed := default_speed, active_time := default_lifetime) -> void:
	var launch_direction := direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	velocity = launch_direction * maxf(speed, 0.0)
	lifetime = maxf(active_time, 0.01)
	elapsed = 0.0
	start_position = position
	if sprite != null:
		sprite.modulate.a = 1.0


func _ready() -> void:
	start_position = position


func reset_pool_state() -> void:
	velocity = Vector2.ZERO
	elapsed = 0.0
	rotation = 0.0
	modulate = Color.WHITE
	if sprite != null:
		sprite.modulate = Color.WHITE


func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	position += velocity * delta
	position.y = start_position.y + (velocity.y * elapsed) - sin(progress * PI) * hop_height
	rotation += spin_speed * delta
	if sprite != null and progress >= fade_start_ratio:
		sprite.modulate.a = 1.0 - inverse_lerp(fade_start_ratio, 1.0, progress)
	if progress >= 1.0:
		_finish()


func _finish() -> void:
	if has_node("/root/EffectManager"):
		get_node("/root/EffectManager").recycle_effect(self)
	else:
		queue_free()
