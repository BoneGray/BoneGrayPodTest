extends Area2D

const PICKUP_OUTLINE_SHADER := preload("res://shaders/pickup_outline.gdshader")

@export_group("Weapon")
## 拾取后交给玩家装备的数据资源，包含地面贴图、图标、手部动画和基础攻击参数。
@export var weapon_data: Resource
## 允许玩家按交互键拾取的最大距离，作为碰撞检测没有及时刷新时的兜底范围。
@export var pickup_radius := 18.0

@export_group("Bob")
## 是否启用地面武器的上下起伏提示动画。
@export var bob_enabled := true
## 上下起伏的像素距离。小像素物品通常保持在 1.5 到 2.5 之间比较自然。
@export var bob_offset := 2.0
## 单程起伏时间，单位为秒。完整上下循环约为该值的两倍。
@export var bob_duration := 0.75
## 玩家进入可拾取范围后，上下起伏的像素距离。
@export var active_bob_offset := 3.0
## 玩家进入可拾取范围后，单程起伏时间。值越小提示越活跃。
@export var active_bob_duration := 0.4

@export_group("Outline")
## 是否启用地面武器描边。描边只用于拾取物，不影响装备到角色手上的武器动画。
@export var outline_enabled := true
## 常态描边颜色。默认是偏冷的柔白，用来从地面上轻微跳出来。
@export var outline_color := Color(0.86, 0.92, 1.0, 1.0)
## 描边厚度，单位近似为像素。像素风小物品建议使用 1.0。
@export_range(0.0, 4.0, 0.25) var outline_size := 1.0

@export_group("Outline Breath")
## 是否启用描边呼吸动画，用于让可拾取物保持柔和提示感。
@export var outline_breath_enabled := true
## 呼吸最低透明度。值越低，描边在弱化阶段越不明显。
@export_range(0.0, 1.0, 0.05) var outline_breath_min_alpha := 0.45
## 呼吸最高透明度。值越高，描边在强化阶段越明显。
@export_range(0.0, 1.0, 0.05) var outline_breath_max_alpha := 0.95
## 呼吸单程时间，单位为秒。完整一次变强再变弱约为该值的两倍。
@export var outline_breath_duration := 1.1
## 玩家进入可拾取范围后，描边呼吸最低透明度。
@export_range(0.0, 1.0, 0.05) var active_outline_breath_min_alpha := 0.7
## 玩家进入可拾取范围后，描边呼吸最高透明度。
@export_range(0.0, 1.0, 0.05) var active_outline_breath_max_alpha := 1.0
## 玩家进入可拾取范围后，描边呼吸单程时间。值越小提示越明显。
@export var active_outline_breath_duration := 0.55

@onready var sprite: Sprite2D = get_node_or_null("Sprite")

var _sprite_start_position := Vector2.ZERO
var _outline_root: Node2D
var _outline_material: ShaderMaterial
var _nearby_players: Array[Node] = []
var _bob_tween: Tween
var _outline_breath_tween: Tween
var _pickup_hint_active := false


func _ready() -> void:
	add_to_group("weapon_pickup")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_visual()
	_apply_outline_material()
	if sprite != null:
		_sprite_start_position = sprite.position
	_refresh_pickup_hint_animation()


func _refresh_visual() -> void:
	if sprite == null or weapon_data == null:
		return

	var world_texture := weapon_data.get("world_texture") as Texture2D
	if world_texture != null:
		sprite.texture = world_texture
		_refresh_outline_textures()


func _start_bob_animation(offset: float, duration: float) -> void:
	if _bob_tween != null:
		_bob_tween.kill()
		_bob_tween = null
	if not bob_enabled or sprite == null:
		return

	sprite.position = _sprite_start_position
	if _outline_root != null:
		_outline_root.position = _sprite_start_position
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.set_trans(Tween.TRANS_SINE)
	_bob_tween.set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(sprite, "position", _sprite_start_position + Vector2(0, -offset), duration)
	if _outline_root != null:
		_bob_tween.parallel().tween_property(_outline_root, "position", _sprite_start_position + Vector2(0, -offset), duration)
	_bob_tween.tween_property(sprite, "position", _sprite_start_position + Vector2(0, offset), duration)
	if _outline_root != null:
		_bob_tween.parallel().tween_property(_outline_root, "position", _sprite_start_position + Vector2(0, offset), duration)


func _apply_outline_material() -> void:
	if sprite == null:
		return

	sprite.material = null
	if not outline_enabled:
		if _outline_root != null:
			_outline_root.queue_free()
			_outline_root = null
		return

	_outline_material = ShaderMaterial.new()
	_outline_material.shader = PICKUP_OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("outline_size", outline_size)

	_outline_root = Node2D.new()
	_outline_root.name = "OutlineSprites"
	_outline_root.position = sprite.position
	_outline_root.z_index = sprite.z_index
	add_child(_outline_root)
	move_child(_outline_root, sprite.get_index())

	for offset in _outline_offsets():
		var outline_sprite := Sprite2D.new()
		outline_sprite.name = "OutlineSprite"
		outline_sprite.texture = sprite.texture
		outline_sprite.position = offset * outline_size
		outline_sprite.centered = sprite.centered
		outline_sprite.offset = sprite.offset
		outline_sprite.flip_h = sprite.flip_h
		outline_sprite.flip_v = sprite.flip_v
		outline_sprite.region_enabled = sprite.region_enabled
		outline_sprite.region_rect = sprite.region_rect
		outline_sprite.z_index = sprite.z_index
		outline_sprite.material = _outline_material
		_outline_root.add_child(outline_sprite)


func _start_outline_breath_animation(min_alpha: float, max_alpha: float, duration: float) -> void:
	if _outline_breath_tween != null:
		_outline_breath_tween.kill()
		_outline_breath_tween = null
	if not outline_breath_enabled or _outline_material == null:
		return

	_set_outline_alpha(min_alpha)
	_outline_breath_tween = create_tween()
	_outline_breath_tween.set_loops()
	_outline_breath_tween.set_trans(Tween.TRANS_SINE)
	_outline_breath_tween.set_ease(Tween.EASE_IN_OUT)
	_outline_breath_tween.tween_method(_set_outline_alpha, min_alpha, max_alpha, duration)
	_outline_breath_tween.tween_method(_set_outline_alpha, max_alpha, min_alpha, duration)


func _set_outline_alpha(value: float) -> void:
	if _outline_material == null:
		return

	var breathed_color := outline_color
	breathed_color.a = clampf(value, 0.0, 1.0)
	_outline_material.set_shader_parameter("outline_color", breathed_color)


func _refresh_outline_textures() -> void:
	if _outline_root == null or sprite == null:
		return

	for child in _outline_root.get_children():
		var outline_sprite := child as Sprite2D
		if outline_sprite != null:
			outline_sprite.texture = sprite.texture


func _outline_offsets() -> Array[Vector2]:
	return [
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(1, 1),
	]


func _on_body_entered(body: Node) -> void:
	if weapon_data == null or not body.is_in_group("player"):
		return

	if body not in _nearby_players:
		_nearby_players.append(body)
	_refresh_pickup_hint_state()


func _on_body_exited(body: Node) -> void:
	_nearby_players.erase(body)
	_refresh_pickup_hint_state()


func _refresh_pickup_hint_state() -> void:
	var should_activate := not _nearby_players.is_empty()
	if _pickup_hint_active == should_activate:
		return

	_pickup_hint_active = should_activate
	_refresh_pickup_hint_animation()


func _refresh_pickup_hint_animation() -> void:
	if _pickup_hint_active:
		_start_outline_breath_animation(active_outline_breath_min_alpha, active_outline_breath_max_alpha, active_outline_breath_duration)
		_start_bob_animation(active_bob_offset, active_bob_duration)
	else:
		_start_outline_breath_animation(outline_breath_min_alpha, outline_breath_max_alpha, outline_breath_duration)
		_start_bob_animation(bob_offset, bob_duration)


func can_be_picked_by(body: Node) -> bool:
	if weapon_data == null or body == null or not body.is_in_group("player"):
		return false
	if not body.has_method("equip_weapon"):
		return false
	if body in _nearby_players:
		return true
	var body_2d := body as Node2D
	if body_2d == null:
		return false
	return global_position.distance_to(body_2d.global_position) <= pickup_radius


func pickup_by(body: Node) -> bool:
	if not can_be_picked_by(body):
		return false
	if not body.has_method("equip_weapon"):
		return false

	body.equip_weapon(weapon_data)
	queue_free()
	return true
