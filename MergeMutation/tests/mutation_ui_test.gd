extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const Session = preload("res://scripts/mutation_session.gd")
const Search = preload("res://scripts/mutation_search.gd")
const UI = preload("res://scripts/mutation_experiment.gd")
var checks := 0
var failures := 0
var game
var ui
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func tap(point: Vector2,touch: bool=true) -> void:
	var pos: Vector2=ui.get_global_transform_with_canvas()*point
	for down in [true,false]:
		var event: InputEvent
		if touch:
			event=InputEventScreenTouch.new()
			event.index=0
		else:
			event=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
		event.position=pos
		event.pressed=down
		root.push_input(event,true)
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/mutation-"+name+".png")==OK,"GPU screenshot "+name)
func run() -> void:
	root.size=Vector2i(360,720)
	game=Scene.instantiate()
	game.save_path="res://.godot/mutation-ui-save.json"
	if FileAccess.file_exists(game.save_path): DirAccess.remove_absolute(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._save_game()
	var original := FileAccess.get_file_as_string(game.save_path)
	var cells: Array=game.cells.duplicate(true)
	var coins: int=game.coins
	ui=game.view
	await process_frame
	await screenshot("laboratory-entry")
	check(game.view.experiment_button.get_rect().end.x<=268 and game.view.nav_right.get_rect().end.x<=350,"navigation stays inside portrait viewport")
	tap(Vector2(223,665))
	await process_frame
	check(is_instance_valid(game.view.experiment_ui),"native touch opens experiment from lab")
	ui=game.view.experiment_ui
	await process_frame
	await screenshot("list")
	ui.trial_scroll.scroll_vertical=10000
	await process_frame
	await screenshot("list-bottom")
	ui.trial_scroll.scroll_vertical=0
	check(ui.find_child("Trial10",true,false)!=null,"ten trial entries")
	for number in range(1,11):
		check(ui.start_trial(number),"UI start")
		await process_frame
		var proof: Dictionary={}
		if FileAccess.file_exists("res://.godot/mutation-solutions.json"):
			var witnesses: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/mutation-solutions.json"))
			for witness in witnesses:
				if int(witness.number)==number and witness.get("config_hash")==JSON.stringify(UI.config(number),"",true).sha256_text():
					proof={"won":true,"actions":witness.actions}
		if proof.is_empty(): proof=Search.solve(ui.session)
		check(proof.won,"UI solution exists")
		await screenshot("level-%02d" % number)
		for action in proof.actions:
			if action.kind=="spawn": tap(Vector2(180,568),number%2==0)
			else:
				tap(ui.center(int(action.source)),number%2==0)
				await process_frame
				check(ui.selected==int(action.source),"mouse/touch selects source")
				await screenshot("action-%s-%02d" % [action.kind,number])
				tap(ui.center(int(action.index)),number%2==0)
				var used: int=ui.session.moves_used
				tap(ui.center(int(action.index)),number%2==0)
				check(ui.session.moves_used==used,"repeat tap cannot spend twice")
			await create_timer(0.3).timeout
		check(ui.session.status=="won","UI replay victory %d" % number)
		check(game.coins==coins and game.cells==cells and not game.in_campaign(),"sandbox state preserved")
		check(FileAccess.get_file_as_string(game.save_path)==original,"no save writes or campaign rewards")
		await screenshot("victory-%02d" % number)
		ui.start_trial(number)
		check(ui.session.moves_used==0 and ui.session.status=="active","restart clears attempt")
		ui.show_list()
		check(ui.completed.has(number),"memory-only completion")
	# Dragging onto rock must never invoke explicit destruction.
	ui.start_trial(1)
	await process_frame
	var down := InputEventScreenTouch.new()
	down.pressed=true
	down.position=ui.get_global_transform_with_canvas()*ui.center(10)
	root.push_input(down,true)
	var up := InputEventScreenTouch.new()
	up.position=ui.get_global_transform_with_canvas()*ui.center(11)
	root.push_input(up,true)
	check(ui.session.ground(11)=="rock" and ui.session.moves_used==0,"drag does not break rock")
	var signature: String=ui.session.signature()
	tap(ui.center(13))
	check(ui.session.signature()==signature and not ui.message.text.is_empty(),"invalid distant action explains and preserves state")
	ui.start_trial(5)
	await process_frame
	tap(ui.center(0))
	tap(ui.center(3))
	check(ui.selected==3,"can switch between incompatible selected creatures")
	ui.exit_experiment()
	ui.exit_experiment() # Repeated navigation in the same frame must be harmless.
	await process_frame
	check(not game.in_campaign() and game.cells==cells,"exit returns to intact sandbox")
	game.view.open_experiment()
	ui=game.view.experiment_ui
	check(ui.completed.is_empty(),"completion is not persisted")
	ui.exit_experiment()
	game.free()
	print("Mutation UI checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
