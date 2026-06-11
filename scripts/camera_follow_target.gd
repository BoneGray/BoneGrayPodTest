extends Camera2D

@export_group("Follow")
## 相机跟随的目标节点路径，通常指向 Player 或测试场景里的可控制角色。
@export var target_path: NodePath
## 相机跟随的平滑强度。值越大越贴近目标，值越小拖尾感越明显。
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
