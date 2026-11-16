extends Control
## Merge Mutation: gameplay state, rules and backwards-compatible saves.
## No external assets or addons required.
const LabView = preload("res://scripts/lab_view.gd")

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
var view: LabView

func _ready() -> void:
	rng.randomize()
	if not _load_game():
		_new_game()
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.dialog_text = "Start a new game?\nCurrent progress will be replaced."
	reset_dialog.confirmed.connect(_new_game)
	add_child(reset_dialog)
	view = LabView.new()
	view.game = self
	add_child(view)
	resized.connect(view.layout)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message = "Drag matching creatures together!"
			queue_redraw()
			if is_instance_valid(view):
				view.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_cancel_drag()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if cells.size() == COLS * ROWS:
			_save_game()

func _cancel_drag() -> void:
	if is_instance_valid(view):
		view.cancel_selection()
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
	if is_instance_valid(view):
		view.rebuild()
		view.close_panel()
	queue_redraw()

func _design_position(pos: Vector2) -> Vector2:
	return view.to_local(pos) if is_instance_valid(view) else pos

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(_design_position(event.position))
		else:
			_release(_design_position(event.position))
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		pointer_pos = _design_position(event.position)
		queue_redraw()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_press(_design_position(event.position))
		else:
			_release(_design_position(event.position))
		accept_event()
	elif event is InputEventScreenDrag and dragging:
		if event.index != 0:
			return
		pointer_pos = _design_position(event.position)
		queue_redraw()
		accept_event()

func _press(pos: Vector2) -> void:
	if dragging:
		return
	if Rect2(37, 558, 286, 58).has_point(pos):
		_spawn()
		return
	var index := _cell_at(pos)
	if index >= 0 and cells[index] > 0:
		selected = index
		dragging = true
		pointer_pos = pos
		if is_instance_valid(view):
			view.pick(index)
		queue_redraw()

func _release(pos: Vector2) -> void:
	if not dragging:
		return
	var destination := _cell_at(pos)
	if destination >= 0 and destination != selected:
		if cells[destination] == 0:
			cells[destination] = cells[selected]
			cells[selected] = 0
			if is_instance_valid(view):
				view.move(selected,destination)
			_save_game()
		elif cells[destination] == cells[selected] and cells[destination] < MAX_LEVEL:
			var new_level: int = cells[destination] + 1
			cells[destination] = new_level
			cells[selected] = 0
			coins += 15 * new_level
			merges += 1
			var discovered := new_level > highest
			highest = maxi(highest, new_level)
			if is_instance_valid(view):
				view.merge(selected,destination,discovered)
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
	var index: int = empty[rng.randi_range(0, empty.size() - 1)]
	cells[index] = 1
	if is_instance_valid(view):
		view.spawn(index)
	_save_game()
	queue_redraw()

func _create_requested() -> void:
	# Native buttons also receive touch; a second finger must not buy mid-drag.
	if not dragging:
		_spawn()

func _notice(value: String) -> void:
	message = value
	message_time = 3.0
	queue_redraw()
	if is_instance_valid(view):
		view.queue_redraw()

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
	draw_rect(Rect2(Vector2.ZERO,size),Color("b9dfdf"))
