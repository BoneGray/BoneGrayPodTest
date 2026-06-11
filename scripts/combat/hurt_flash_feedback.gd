extends Node
class_name HurtFlashFeedback

@export_group("Target")
## 需要播放受伤闪红效果的 CanvasItem 路径，通常指向角色的 Sprite。
@export var target_path := NodePath("../Sprite")

@export_group("Flash")
## 受伤瞬间切换到的颜色。
@export var hurt_color := Color(1.0, 0.25, 0.25)
## 从受伤颜色恢复到白色的时间，单位为秒。
@export var flash_time := 0.12

var _target: CanvasItem
var _tween: Tween


func _ready() -> void:
	_target = get_node_or_null(target_path) as CanvasItem


func play() -> bool:
	if _target == null:
		_target = get_node_or_null(target_path) as CanvasItem
	if _target == null:
		return false

	if _tween != null:
		_tween.kill()

	_target.modulate = hurt_color
	_tween = create_tween()
	_tween.tween_property(_target, "modulate", Color.WHITE, flash_time)
	return true
