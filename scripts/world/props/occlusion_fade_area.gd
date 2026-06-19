extends Area2D
class_name OcclusionFadeArea

## 触发对象进入区域时要淡化的节点。留空表示不自动绑定默认目标。
@export var fade_target_path: NodePath = ^".."

## 跟随同一个遮挡区域一起淡化的额外视觉节点，适合拥有多个视觉部件的复合物体。
@export var extra_fade_target_paths: Array[NodePath] = []

## 可以触发淡化的分组名称，通常是 "player"。
@export var trigger_group := "player"

## 触发对象位于遮挡区域内时，默认目标淡化到的透明度。
@export_range(0.0, 1.0, 0.01) var faded_alpha := 0.45

## 额外淡化目标各自使用的透明度；未填写的位置会使用 faded_alpha。
@export var extra_faded_alphas: Array[float] = []

## 从正常显示淡化到遮挡透明状态所用的秒数。
@export_range(0.0, 2.0, 0.01) var fade_in_time := 0.12

## 触发对象离开后，从遮挡透明状态恢复正常显示所用的秒数。
@export_range(0.0, 2.0, 0.01) var fade_out_time := 0.18

var _overlapping_triggers: Array[Node] = []
var _targets: Array[CanvasItem] = []
var _target_faded_alphas: Array[float] = []
var _target_normal_alphas: Array[float] = []
var _target_tweens: Array[Tween] = []


func _ready() -> void:
	collision_layer = 0
	if collision_mask == 0:
		collision_mask = 2
	monitoring = true
	monitorable = false

	if not fade_target_path.is_empty():
		var default_target := get_node_or_null(fade_target_path) as CanvasItem
		if default_target == null:
			default_target = get_parent() as CanvasItem
		add_fade_target(default_target, faded_alpha)

	for index in extra_fade_target_paths.size():
		var extra_target := get_node_or_null(extra_fade_target_paths[index]) as CanvasItem
		var extra_alpha := faded_alpha
		if index < extra_faded_alphas.size():
			extra_alpha = extra_faded_alphas[index]
		add_fade_target(extra_target, extra_alpha)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func add_fade_target(target: CanvasItem, target_faded_alpha := -1.0) -> void:
	if target == null or _targets.has(target):
		return
	var clamped_alpha := faded_alpha if target_faded_alpha < 0.0 else clampf(target_faded_alpha, 0.0, 1.0)
	_targets.append(target)
	_target_faded_alphas.append(clamped_alpha)
	_target_normal_alphas.append(target.modulate.a)
	_target_tweens.append(null)

	if not _overlapping_triggers.is_empty():
		_fade_target(_targets.size() - 1, true)


func _on_body_entered(body: Node) -> void:
	if not _is_valid_trigger(body) or _overlapping_triggers.has(body):
		return
	_overlapping_triggers.append(body)
	_set_faded(true)


func _on_body_exited(body: Node) -> void:
	if not _overlapping_triggers.has(body):
		return
	_overlapping_triggers.erase(body)
	_overlapping_triggers = _overlapping_triggers.filter(func(trigger: Node) -> bool:
		return is_instance_valid(trigger)
	)
	_set_faded(not _overlapping_triggers.is_empty())


func _is_valid_trigger(body: Node) -> bool:
	if body == null:
		return false
	if trigger_group.strip_edges() == "":
		return true
	return body.is_in_group(trigger_group)


func _set_faded(should_fade: bool) -> void:
	for index in _targets.size():
		_fade_target(index, should_fade)


func _fade_target(index: int, should_fade: bool) -> void:
	if index < 0 or index >= _targets.size():
		return
	var target := _targets[index]
	if target == null or not is_instance_valid(target):
		return
	var tween := _target_tweens[index]
	if tween != null:
		tween.kill()

	var target_alpha := _target_faded_alphas[index] if should_fade else _target_normal_alphas[index]
	var duration := fade_in_time if should_fade else fade_out_time
	if duration <= 0.0:
		var color := target.modulate
		color.a = target_alpha
		target.modulate = color
		return

	tween = create_tween()
	_target_tweens[index] = tween
	tween.tween_property(target, "modulate:a", target_alpha, duration)
