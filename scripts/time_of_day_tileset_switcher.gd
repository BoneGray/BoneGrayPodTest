extends Node2D

const TILESETS := {
	"morning": "res://resources/tiles/background_dark_green_tileset.tres",
	"noon": "res://resources/tiles/background_green_tileset.tres",
	"night": "res://resources/tiles/background_bleak_yellow_tileset.tres",
}

var tile_layers: Array[TileMapLayer] = []
var loaded_tilesets: Dictionary = {}
var buttons: Dictionary = {}


func _ready() -> void:
	_load_tilesets()
	_collect_tile_layers(self)
	_create_time_buttons()
	_set_time_of_day("night")


func _load_tilesets() -> void:
	for key in TILESETS:
		var tile_set := load(TILESETS[key]) as TileSet
		if tile_set == null:
			push_warning("Missing TileSet: " + TILESETS[key])
			continue
		loaded_tilesets[key] = tile_set


func _collect_tile_layers(node: Node) -> void:
	if node is TileMapLayer:
		tile_layers.append(node)

	for child in node.get_children():
		_collect_tile_layers(child)


func _create_time_buttons() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "TimeOfDayUI"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	canvas.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	_add_button(row, "morning", "早")
	_add_button(row, "noon", "中")
	_add_button(row, "night", "晚")


func _add_button(parent: Control, key: String, label: String) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(64, 40)
	button.toggle_mode = true
	button.pressed.connect(func() -> void: _set_time_of_day(key))
	parent.add_child(button)
	buttons[key] = button


func _set_time_of_day(key: String) -> void:
	if not loaded_tilesets.has(key):
		return

	for layer in tile_layers:
		layer.tile_set = loaded_tilesets[key]

	for button_key in buttons:
		var button := buttons[button_key] as Button
		button.set_pressed_no_signal(button_key == key)
