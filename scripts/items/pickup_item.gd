extends Area2D
class_name PickupItem

const PICKUP_OUTLINE_SHADER := preload("res://shaders/pickup_outline.gdshader")

@export_group("Item")
## Data resource picked up by the player. The item_type routes it to weapon, tool, consumable, material, quest, or ammo handling.
@export var item_data: Resource:
	set(value):
		item_data = value
		_refresh_visual()
	get:
		return item_data
## Maximum interact distance used as a fallback when physics overlap has not refreshed yet.
@export var pickup_radius := 18.0

@export_group("Bob")
## Enables the soft up-down motion while the item is on the ground.
@export var bob_enabled := true
## Idle bob distance in pixels.
@export var bob_offset := 2.0
## Idle one-way bob duration in seconds.
@export var bob_duration := 0.75
## Bob distance in pixels while a player is in pickup range.
@export var active_bob_offset := 3.0
## One-way bob duration in seconds while a player is in pickup range.
@export var active_bob_duration := 0.4

@export_group("Outline")
## Enables the pickup outline without changing original sprite colors.
@export var outline_enabled := true
## Normal outline color. Use a soft tinted white instead of pure white.
@export var outline_color := Color(0.86, 0.92, 1.0, 1.0)
## Approximate outline size in pixels.
@export_range(0.0, 4.0, 0.25) var outline_size := 1.0

@export_group("Outline Breath")
## Enables a soft breathing alpha animation for the outline.
@export var outline_breath_enabled := true
## Minimum outline alpha while idle.
@export_range(0.0, 1.0, 0.05) var outline_breath_min_alpha := 0.45
## Maximum outline alpha while idle.
@export_range(0.0, 1.0, 0.05) var outline_breath_max_alpha := 0.95
## One-way breathing duration while idle.
@export var outline_breath_duration := 1.1
## Minimum outline alpha while a player is in pickup range.
@export_range(0.0, 1.0, 0.05) var active_outline_breath_min_alpha := 0.7
## Maximum outline alpha while a player is in pickup range.
@export_range(0.0, 1.0, 0.05) var active_outline_breath_max_alpha := 1.0
## One-way breathing duration while a player is in pickup range.
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
	add_to_group("pickup_item")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_visual()
	_apply_outline_material()
	if sprite != null:
		_sprite_start_position = sprite.position
	_refresh_pickup_hint_animation()


func can_be_picked_by(body: Node) -> bool:
	if item_data == null or body == null or not body.is_in_group("player"):
		return false
	if not _can_route_to_body(body):
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
	if not _apply_pickup_to_body(body):
		return false
	queue_free()
	return true


func _refresh_visual() -> void:
	if sprite == null or item_data == null:
		return

	var world_texture := item_data.get("world_texture") as Texture2D
	if world_texture != null:
		sprite.texture = world_texture
		_refresh_outline_textures()


func _can_route_to_body(body: Node) -> bool:
	match _get_item_type():
		"weapon":
			return body.has_method("equip_weapon")
		_:
			return body.has_method("pickup_item")


func _apply_pickup_to_body(body: Node) -> bool:
	match _get_item_type():
		"weapon":
			if body.has_method("equip_weapon"):
				body.equip_weapon(item_data)
				return true
		_:
			if body.has_method("pickup_item"):
				return bool(body.pickup_item(item_data))
	return false


func _get_item_type() -> String:
	if item_data == null:
		return ""
	var item_type := String(item_data.get("item_type"))
	return item_type if item_type != "" else "weapon"


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
	if item_data == null or not body.is_in_group("player"):
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
