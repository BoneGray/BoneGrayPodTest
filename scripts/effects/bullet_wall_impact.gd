extends Node2D

@export_group("Visual")
## 弹孔主体颜色，建议保持偏暗但不要纯黑。
@export var hole_color := Color(0.08, 0.07, 0.08, 0.95)
## 弹孔边缘颜色，用于在深色墙体上保持可见度。
@export var rim_color := Color(0.22, 0.2, 0.2, 0.65)
## 弹孔视觉半径，单位为像素。
@export var radius := 1.4

@export_group("Lifetime")
## 弹孔保持清晰的时间，单位为秒。
@export var hold_time := 4.0
## 弹孔淡出时间，单位为秒。
@export var fade_time := 1.5

var elapsed := 0.0


func reset_pool_state() -> void:
	elapsed = 0.0
	modulate = Color.WHITE
	queue_redraw()


func configure(hit_normal: Vector2, new_hold_time: float, new_fade_time: float) -> void:
	rotation = hit_normal.angle() if hit_normal != Vector2.ZERO else 0.0
	hold_time = maxf(new_hold_time, 0.0)
	fade_time = maxf(new_fade_time, 0.0)


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > hold_time and fade_time > 0.0:
		modulate.a = 1.0 - clampf((elapsed - hold_time) / fade_time, 0.0, 1.0)
	if elapsed >= hold_time + fade_time:
		_finish()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 0.8, rim_color)
	draw_circle(Vector2.ZERO, radius, hole_color)
	draw_line(Vector2(-2.0, -0.5), Vector2(2.0, 0.5), rim_color, 1.0)


func _finish() -> void:
	if has_node("/root/EffectManager"):
		get_node("/root/EffectManager").recycle_effect(self)
	else:
		queue_free()
