extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Unit=preload("res://tests/mutation_undo_test.gd")
var checks:=0
var failures:=0
var ui
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func tap(point: Vector2,touch: bool=true) -> void:
	for down in [true,false]:
		var event: InputEvent
		if touch: event=InputEventScreenTouch.new()
		else:
			event=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
		event.position=ui.get_global_transform_with_canvas()*point
		event.pressed=down
		root.push_input(event,true)
func wait_action() -> void: await create_timer(0.3).timeout
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/undo-"+name+".png")==OK,"screenshot "+name)
func run() -> void:
	root.size=Vector2i(360,720)
	var game=Scene.instantiate()
	game.save_path="res://.godot/undo-ui-save.json"
	root.add_child(game)
	game._save_game()
	var original:=FileAccess.get_file_as_string(game.save_path)
	var sandbox: Array=game.cells.duplicate(true)
	var coins: int=game.coins
	game.view.open_experiment()
	ui=game.view.experiment_ui
	ui.start_trial(8)
	await process_frame
	check(ui.get_node("ExperimentUndo").disabled,"empty history disables undo")
	check(ui.get_node("ExperimentSpawn").get_rect().end.x<=172 and ui.get_node("ExperimentUndo").size==Vector2(152,44),"44px controls do not overlap")
	tap(ui.center(0))
	check(ui.session.corridor_actions(0).any(func(action): return action.index==10 and action.cost==2),"real level offers two-move straight corridor")
	await shot("costs")
	var before: String=Unit.state(ui.session)
	tap(ui.center(10))
	tap(ui.center(10))
	check(ui.session.moves_used==2 and ui.history.snapshots.size()==1,"one touch command, two moves, one history entry")
	await wait_action()
	await shot("after-corridor")
	tap(Vector2(260,568))
	tap(Vector2(260,568))
	check(Unit.state(ui.session)==before and ui.history.remaining==1,"touch undo restores entire corridor once")
	await wait_action()
	await shot("restored")
	check(ui.selected==-1 and not ui.busy and ui.get_node("ExperimentUndo").disabled,"undo clears selection and empty-history control")
	# Four-cell test fixture is in memory only: no new level configuration.
	ui.start_trial(8)
	ui.session.start(Unit.fixture())
	ui.refresh()
	await process_frame
	before=Unit.state(ui.session)
	tap(ui.center(0),false)
	tap(ui.center(4),false)
	await wait_action()
	check(ui.session.moves_used==4 and ui.history.snapshots.size()==1,"mouse long command spends four moves")
	tap(Vector2(260,568),false)
	await wait_action()
	check(Unit.state(ui.session)==before and ui.history.remaining==1,"mouse undo restores all four moves")
	for iteration in range(2):
		tap(ui.center(0))
		tap(ui.center(1))
		await wait_action()
		tap(Vector2(260,568))
		await wait_action()
		if iteration==0: check(ui.history.remaining==0 and ui.session.moves_used==0,"second charge works")
		else: check(ui.history.remaining==0 and ui.session.moves_used==1,"third undo stays disabled after another action")
	ui.start_trial(8)
	ui.session.start(Unit.fixture())
	ui.refresh()
	await process_frame
	var down:=InputEventScreenTouch.new()
	down.pressed=true
	down.position=ui.get_global_transform_with_canvas()*ui.center(0)
	root.push_input(down,true)
	var drag:=InputEventScreenDrag.new()
	drag.position=ui.get_global_transform_with_canvas()*ui.center(4)
	drag.relative=Vector2(224,0)
	root.push_input(drag,true)
	var up:=InputEventScreenTouch.new()
	up.position=drag.position
	root.push_input(up,true)
	await wait_action()
	check(ui.session.moves_used==4 and ui.history.snapshots.size()==1,"touch drag is one four-step command")
	tap(Vector2(260,568))
	await wait_action()
	check(ui.session.moves_used==0 and ui.history.remaining==1,"touch drag command undoes as a whole")
	ui.start_trial(1)
	await process_frame
	check(ui.history.remaining==2 and ui.history.snapshots.is_empty(),"restart grants fresh two charges and clears history")
	tap(Vector2(98,568),false)
	await wait_action()
	check(ui.session.creations_used==1 and ui.session.moves_used==0,"free creation via mouse")
	tap(Vector2(260,568),false)
	await wait_action()
	check(ui.session.creations_used==0 and ui.session.cells[13]==null and ui.session.next_species()=="horn","undo restores creation sequence")
	ui.start_trial(8)
	var data:=Unit.fixture()
	data.move_limit=1
	ui.session.start(data)
	ui.refresh()
	await process_frame
	tap(ui.center(0))
	tap(ui.center(1))
	await wait_action()
	check(ui.session.status=="lost" and not ui.get_node("ExperimentUndo").disabled,"undo available after defeat")
	await shot("defeat")
	tap(Vector2(260,568))
	await wait_action()
	check(ui.session.status=="active" and ui.session.moves_used==0 and ui.session.reason.is_empty(),"undo revives defeated attempt")
	for previously_complete in [false,true]:
		if previously_complete: ui.completed[3]=true
		else: ui.completed.erase(3)
		ui.start_trial(3)
		await process_frame
		for pair in [[10,12],[12,13]]:
			tap(ui.center(pair[0]))
			tap(ui.center(pair[1]))
			await wait_action()
		check(ui.session.status=="won" and ui.completed.has(3),"victory before undo")
		tap(Vector2(260,568))
		await wait_action()
		check(ui.session.status=="active" and ui.completed.has(3)==previously_complete,"undo victory restores attempt completion indicator")
	check(FileAccess.get_file_as_string(game.save_path)==original and game.cells==sandbox and game.coins==coins,"undo never changes permanent save or sandbox economy")
	ui.show_list()
	check(ui.history.snapshots.is_empty(),"leaving trial releases history")
	ui.start_trial(1)
	ui.create_creature()
	ui.exit_experiment()
	check(ui.history.snapshots.is_empty(),"exit releases even animating history")
	await process_frame
	game.view.open_experiment()
	ui=game.view.experiment_ui
	ui.start_trial(1)
	check(not ui.history.can_undo() and ui.history.remaining==2,"new screen cannot undo old attempt")
	game.free()
	print("Undo UI checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
