extends Control
## Merge Mutation: self-contained Godot 4 playable prototype.
## No external assets or addons required.

const COLS := 5
const ROWS := 6
const CELL := 62.0
const BOARD_X := 25.0
const BOARD_Y := 147.0
const MAX_LEVEL := 10
const SPAWN_COST := 10
const SAVE_PATH := "user://merge_mutation_save.json"
const NAMES := ["", "Slime", "Eyeling", "Hornling", "Bubbler", "Shellback", "Wingling", "Tentacly", "Chimera", "Mutant Rex", "Ultra Mutant"]
const COLORS := [
	Color.TRANSPARENT, Color("83e529"), Color("28c9f2"), Color("ffab32"),
	Color("ff74b6"), Color("488df0"), Color("ac69f6"), Color("24d6cf"),
	Color("ff9a37"), Color("5cda5e"), Color("da5aff")
]

var cells: Array[int] = []
var coins: int = 100
var merges: int = 0
var highest: int = 1
var selected: int = -1
var pointer_pos := Vector2.ZERO
var dragging := false
var message := "Drag matching creatures together!"
var message_time := 0.0
var rng := RandomNumberGenerator.new()
var save_path := SAVE_PATH
var reset_dialog: ConfirmationDialog

func _ready() -> void:
	rng.randomize()
	if not _load_game():
		_new_game()
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.dialog_text = "Start a new game?\nCurrent progress will be replaced."
	reset_dialog.confirmed.connect(_new_game)
	add_child(reset_dialog)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message = "Drag matching creatures together!"
			queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_cancel_drag()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if cells.size() == COLS * ROWS:
			_save_game()

func _cancel_drag() -> void:
	selected = -1
	dragging = false
	queue_redraw()

func _new_game() -> void:
	_cancel_drag()
	cells.resize(COLS * ROWS)
	cells.fill(0)
	for index in [6, 8, 16, 18]:
		cells[index] = 1
	coins = 100
	merges = 0
	highest = 1
	message = "Drag matching creatures together!"
	message_time = 0.0
	_save_game()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		pointer_pos = event.position
		queue_redraw()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
		accept_event()
	elif event is InputEventScreenDrag and dragging:
		if event.index != 0:
			return
		pointer_pos = event.position
		queue_redraw()
		accept_event()

func _press(pos: Vector2) -> void:
	if dragging:
		return
	if Rect2(270, 620, 75, 20).has_point(pos):
		reset_dialog.popup_centered()
		return
	if Rect2(37, 558, 286, 58).has_point(pos):
		_spawn()
		return
	var index := _cell_at(pos)
	if index >= 0 and cells[index] > 0:
		selected = index
		dragging = true
		pointer_pos = pos
		queue_redraw()

func _release(pos: Vector2) -> void:
	if not dragging:
		return
	var destination := _cell_at(pos)
	if destination >= 0 and destination != selected:
		if cells[destination] == 0:
			cells[destination] = cells[selected]
			cells[selected] = 0
			_save_game()
		elif cells[destination] == cells[selected] and cells[destination] < MAX_LEVEL:
			var new_level: int = cells[destination] + 1
			cells[destination] = new_level
			cells[selected] = 0
			coins += 15 * new_level
			merges += 1
			highest = maxi(highest, new_level)
			_notice("New mutation: %s! +%d coins" % [NAMES[new_level], 15 * new_level])
			_save_game()
		else:
			_notice("Match two creatures of the same level")
	_cancel_drag()

func _cell_at(pos: Vector2) -> int:
	var x := int(floor((pos.x - BOARD_X) / CELL))
	var y := int(floor((pos.y - BOARD_Y) / CELL))
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return -1
	return y * COLS + x

func _spawn() -> void:
	if coins < SPAWN_COST:
		_notice("Not enough coins!")
		return
	var empty: Array[int] = []
	for i in range(cells.size()):
		if cells[i] == 0:
			empty.append(i)
	if empty.is_empty():
		_notice("Board full: merge some creatures first!")
		return
	coins -= SPAWN_COST
	cells[empty[rng.randi_range(0, empty.size() - 1)]] = 1
	_save_game()
	queue_redraw()

func _notice(value: String) -> void:
	message = value
	message_time = 3.0
	queue_redraw()

func _save_game() -> void:
	var data := {"coins": coins, "merges": merges, "highest": highest, "cells": cells}
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_notice("Could not save progress")
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary_path, save_path) != OK:
		_notice("Could not save progress")

func _load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return false
	var values: Variant = parsed.get("cells", [])
	if not values is Array or values.size() != COLS * ROWS:
		return false
	# Validate everything before changing live state; JSON numbers are floats.
	for value in values:
		if not _valid_integer(value, MAX_LEVEL):
			return false
	for key in ["coins", "merges", "highest"]:
		if not _valid_integer(parsed.get(key), 2147483647):
			return false
	if int(parsed.highest) < 1 or int(parsed.highest) > MAX_LEVEL:
		return false
	cells.assign(values)
	coins = int(parsed.coins)
	merges = int(parsed.merges)
	highest = maxi(int(parsed.highest), cells.max())
	return true

func _valid_integer(value: Variant, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= 0 and value <= maximum and floor(float(value)) == value

func _draw() -> void:
	var bg := Rect2(Vector2.ZERO, size)
	draw_rect(bg, Color("17112c"))
	# Background accents.
	draw_circle(Vector2(325, 80), 100, Color("271b49"))
	draw_circle(Vector2(10, 490), 90, Color("24193d"))
	_label("MERGE MUTATION", Vector2(180, 45), 26, Color("bdfb65"), HORIZONTAL_ALIGNMENT_CENTER)
	_label("CARTOON LAB PROTOTYPE", Vector2(180, 65), 11, Color("a5a0c9"), HORIZONTAL_ALIGNMENT_CENTER)
	_panel(Rect2(20, 80, 154, 48), Color("342651"))
	_panel(Rect2(185, 80, 155, 48), Color("342651"))
	_label("COINS", Vector2(34, 99), 11, Color("bcb1d8"))
	_label(str(coins), Vector2(34, 118), 21, Color("ffe16e"))
	_label("BEST MUTANT", Vector2(199, 99), 11, Color("bcb1d8"))
	_label("LEVEL %d" % highest, Vector2(199, 118), 20, Color("90f1e6"))
	_panel(Rect2(18, 139, 324, 389), Color("40325e"))
	for i in range(cells.size()):
		var col := i % COLS
		var row := floori(float(i) / COLS)
		var p := Vector2(BOARD_X + col * CELL, BOARD_Y + row * CELL)
		var r := Rect2(p + Vector2(2, 2), Vector2(58, 58))
		_panel(r, Color("554570") if (row + col) % 2 == 0 else Color("4d3f69"))
		if i == selected and dragging:
			draw_rect(r, Color("eaff83", 0.30))
		elif cells[i] > 0:
			_creature(p + Vector2(31, 30), cells[i], 1.0)
	if dragging and selected >= 0:
		_creature(pointer_pos, cells[selected], 1.15)
	_label(message, Vector2(180, 546), 12, Color("f4dffb"), HORIZONTAL_ALIGNMENT_CENTER)
	_panel(Rect2(37, 558, 286, 58), Color("79c832"))
	_label("CREATE SLIME", Vector2(180, 582), 22, Color("152b18"), HORIZONTAL_ALIGNMENT_CENTER)
	_label("10 coins  |  %d merges" % merges, Vector2(180, 603), 12, Color("244c22"), HORIZONTAL_ALIGNMENT_CENTER)
	_panel(Rect2(270, 620, 75, 20), Color("342651"))
	_label("NEW GAME", Vector2(307, 634), 11, Color("f4dffb"), HORIZONTAL_ALIGNMENT_CENTER)

func _panel(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), color.lightened(0.14))

func _label(value: String, pos: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := ThemeDB.fallback_font
	var x := pos.x
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string(font, Vector2(x, pos.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _creature(center: Vector2, level: int, scale_factor: float) -> void:
	var c: Color = COLORS[level]
	var radius := 21.0 * scale_factor
	draw_circle(center + Vector2(0, 4) * scale_factor, radius + 2, Color("221633"))
	draw_circle(center, radius, c)
	draw_circle(center + Vector2(-7, -9) * scale_factor, 6 * scale_factor, Color(1, 1, 1, 0.24))
	if level >= 3:
		for side in [-1, 1]:
			var horn_center := center + Vector2(12 * side, -18) * scale_factor
			draw_circle(horn_center, 6 * scale_factor, Color("ffe5ad"))
	if level >= 6:
		draw_circle(center + Vector2(-22, 2) * scale_factor, 9 * scale_factor, c.darkened(0.20))
		draw_circle(center + Vector2(22, 2) * scale_factor, 9 * scale_factor, c.darkened(0.20))
	var eye_count := 1 if level % 3 == 2 else 2
	if level >= 9:
		eye_count = 3
	for e in range(eye_count):
		var offset := Vector2(0, -5) if eye_count == 1 else Vector2((e - (eye_count - 1) / 2.0) * 13, -6)
		var eye := center + offset * scale_factor
		draw_circle(eye, 6.5 * scale_factor, Color.WHITE)
		draw_circle(eye + Vector2(1.5, 0.5) * scale_factor, 3.0 * scale_factor, Color("20233c"))
	draw_arc(center + Vector2(0, 5) * scale_factor, 7 * scale_factor, 0.25, PI - 0.25, 14, Color("4c2546"), 2.2 * scale_factor)
	_label(str(level), center + Vector2(0, 17) * scale_factor, int(11 * scale_factor), Color("19172c"), HORIZONTAL_ALIGNMENT_CENTER)
