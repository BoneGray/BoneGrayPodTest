extends Camera2D

@export var target_path: NodePath
@export var follow_smoothing := 10.0

var target: Node2D


func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D
	enabled = true
	make_current()


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var weight := clampf(follow_smoothing * delta, 0.0, 1.0)
	global_position = global_position.lerp(target.global_position, weight)
