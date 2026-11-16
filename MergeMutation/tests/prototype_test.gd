extends SceneTree

const Game = preload("res://scripts/main.gd")
var failures := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func center(index: int) -> Vector2:
	return Vector2(Game.BOARD_X + (index % 5) * Game.CELL + 31,
		Game.BOARD_Y + floori(float(index) / 5) * Game.CELL + 31)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Game.new()
	# Keep test saves inside the ignored project cache, never in the player's save.
	DirAccess.make_dir_recursive_absolute("res://.godot")
	game.save_path = "res://.godot/prototype_test_save.json"
	game._new_game()
	check(game.cells.size() == 30 and game.cells.count(1) == 4, "fresh 5x6 board")
	for i in range(30):
		check(game._cell_at(center(i)) == i, "cell hit test %d" % i)
	check(game._cell_at(Vector2(24, 147)) == -1, "left boundary")
	check(game._cell_at(Vector2(335, 147)) == -1, "right boundary")
	check(game._cell_at(Vector2(25, 519)) == -1, "bottom boundary")
	game._press(center(6))
	game._press(center(8))
	check(game.selected == 6, "second press cannot hijack drag")
	game._release(center(0))
	check(game.cells[0] == 1 and game.cells[6] == 0 and game.coins == 100, "move without cost")
	game._press(center(0))
	game._release(Vector2.ZERO)
	check(game.cells[0] == 1 and not game.dragging, "outside drop cancels")
	for level in range(1, 10):
		game.cells.fill(0)
		game.cells[0] = level
		game.cells[1] = level
		var previous_coins: int = game.coins
		var previous_merges: int = game.merges
		game._press(center(0))
		game._release(center(1))
		check(game.cells[0] == 0 and game.cells[1] == level + 1, "merge level %d" % level)
		check(game.coins == previous_coins + 15 * (level + 1) and game.merges == previous_merges + 1, "merge reward %d" % level)
	game.cells[0] = 10
	game._press(center(0))
	game._release(center(1))
	check(game.cells[0] == 10 and game.cells[1] == 10, "maximum level cannot merge")
	game.cells[0] = 1
	game._press(center(0))
	game._release(center(1))
	check(game.cells[0] == 1 and game.cells[1] == 10, "different levels cannot merge")
	game._press(center(0))
	game._cancel_drag()
	check(not game.dragging and game.selected == -1, "focus loss cancels drag")
	game.cells.fill(0)
	game.coins = 10
	game._spawn()
	check(game.coins == 0 and game.cells.count(1) == 1, "spawn costs exactly ten")
	game._spawn()
	check(game.coins == 0 and game.cells.count(1) == 1, "insufficient funds")
	game.cells.fill(1)
	game.coins = 100
	game._spawn()
	check(game.coins == 100 and game.cells.count(1) == 30, "full board does not charge")
	game._save_game()
	game.cells.fill(0)
	game.coins = 0
	check(game._load_game() and game.cells.count(1) == 30 and game.coins == 100, "save/load round trip")
	for bad in ["{", "[]", '{"cells":[]}', JSON.stringify({"cells":range(30),"coins":100,"merges":0,"highest":1}), JSON.stringify({"cells":game.cells,"coins":"oops","merges":0,"highest":1})]:
		var file := FileAccess.open(game.save_path, FileAccess.WRITE)
		file.store_string(bad)
		file.close()
		check(not game._load_game() and game.coins == 100, "reject malformed save without partial changes")
	game._new_game()
	check(game.coins == 100 and game.merges == 0 and game.highest == 1 and game.cells.count(1) == 4, "new game restores playable state")
	check(game._load_game(), "new game is saved")
	var save_cells: Array = []
	save_cells.append_array(game.cells)
	var data := {"cells":save_cells,"coins":100,"merges":0,"highest":1}
	for bad_cell in ["slime", null, {}, -1, 11, 1.5, true]:
		data.cells[0] = bad_cell
		var file := FileAccess.open(game.save_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not game._load_game() and game.cells[0] == 0, "invalid cell type/range rejected")
	data.cells[0] = 7
	var file := FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(game._load_game() and game.highest == 7, "best level includes loaded creatures")
	root.add_child(game)
	check(game.reset_dialog != null, "scene initializes confirmation dialog")
	var before_reset: int = game.coins
	game.reset_dialog.canceled.emit()
	check(game.coins == before_reset and game.highest == 7, "cancel reset preserves progress")
	game.reset_dialog.confirmed.emit()
	check(game.coins == 100 and game.highest == 1, "confirm reset starts new game")
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(180, 580)
	game._gui_input(touch)
	check(game.coins == 100, "extra finger cannot buy")
	touch.index = 0
	game._gui_input(touch)
	check(game.coins == 90 and game.cells.count(1) == 5, "primary touch buys once")
	game._press(center(6))
	var extra_release := InputEventScreenTouch.new()
	extra_release.index = 1
	extra_release.position = center(8)
	game._gui_input(extra_release)
	check(game.dragging and game.selected == 6, "extra finger cannot release drag")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.dragging, "focus notification cancels drag")
	game.free()
	DirAccess.remove_absolute("res://.godot/prototype_test_save.json")
	print("Prototype checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
