extends SceneTree
const Game = preload("res://scripts/main.gd")
const Catalog = preload("res://scripts/mutant_catalog.gd")
var checks := 0
var failures := 0
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",label)
func center(index: int) -> Vector2:
	return Vector2(25+(index%5)*62+31,147+floori(float(index)/5)*62+31)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game := Game.new()
	game.save_path="res://.godot/prototype_test_save.json"
	game._new_game()
	check(game.cells.size()==30 and game.cells.count(Catalog.make("slime"))==4,"fresh board")
	for index in range(30):
		check(game._cell_at(center(index))==index,"cell hit %d" % index)
	for point in [Vector2(24,147),Vector2(335,147),Vector2(25,519)]:
		check(game._cell_at(point)==-1,"outside boundary")
	game._press(center(6))
	game._press(center(8))
	check(game.selected==6,"second press cannot hijack")
	game._release(center(0))
	check(game.cells[0]==Catalog.make("slime") and game.cells[6]==null and game.coins==100,"free move")
	game._press(center(0))
	game._release(Vector2.ZERO)
	check(not game.dragging and game.cells[0]==Catalog.make("slime"),"outside cancels")
	for id in Catalog.ids():
		for stage in range(1,Catalog.maximum(id)+1):
			game.cells.fill(null)
			game.cells[0]=Catalog.make(id,stage)
			game.cells[1]=Catalog.make(id,stage)
			var before := game.coins
			var count := game.merges
			game._press(center(0))
			game._release(center(1))
			if stage<Catalog.maximum(id):
				check(game.cells[0]==null and game.cells[1]==Catalog.make(id,stage+1),"species/stage merge")
				check(game.coins==before+15*(stage+1) and game.merges==count+1,"reward exactly once")
			else:
				check(game.cells[0]==Catalog.make(id,stage) and game.coins==before and game.merges==count,"maximum cannot merge")
	game.cells[0]=Catalog.make("slime",2)
	for other in [Catalog.make("wing",2),Catalog.make("slime",3)]:
		game.cells[1]=other
		game._press(center(0))
		game._release(center(1))
		check(game.cells[0]==Catalog.make("slime",2) and game.cells[1]==other,"mismatch blocked")
	game.cells.fill(null)
	game.coins=10
	game.select_species("wing")
	game._spawn()
	check(game.coins==0 and game.cells.count(Catalog.make("wing"))==1,"selected species costs ten")
	game._spawn()
	check(game.coins==0 and game.cells.count(Catalog.make("wing"))==1,"insufficient funds")
	game.cells.fill(Catalog.make("slime"))
	game.coins=100
	game._spawn()
	check(game.coins==100 and game.cells.count(null)==0,"full board no charge")
	game._save_game()
	game.cells.fill(null)
	check(game._load_game() and game.cells.count(Catalog.make("slime"))==30,"round trip")
	root.add_child(game)
	check(game.reset_dialog!=null,"reset initialized")
	game.reset_dialog.canceled.emit()
	check(game.active_species=="wing","cancel reset preserves selection")
	game.reset_dialog.confirmed.emit()
	check(game.coins==100 and game.known_discoveries()==1,"confirmed reset")
	var touch := InputEventScreenTouch.new()
	touch.index=1
	touch.pressed=true
	touch.position=Vector2(180,580)
	game._gui_input(touch)
	check(game.coins==100,"extra finger cannot buy")
	touch.index=0
	game._gui_input(touch)
	check(game.coins==90,"primary touch buys once")
	game._press(center(6))
	var extra := InputEventScreenTouch.new()
	extra.index=1
	extra.position=center(8)
	game._gui_input(extra)
	check(game.dragging and game.selected==6,"extra finger cannot release")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.dragging,"focus cancels")
	game.free()
	DirAccess.remove_absolute("res://.godot/prototype_test_save.json")
	print("Prototype checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
