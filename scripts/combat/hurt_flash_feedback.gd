extends Node
class_name HurtFlashFeedback

@export var target_path := NodePath("../Sprite")
@export var hurt_color := Color(1.0, 0.25, 0.25)
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
