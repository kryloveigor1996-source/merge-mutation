extends "res://tests/landscape_ui_test.gd"
const G=preload("res://scripts/evolution_geometry.gd")
const Levels=preload("res://scripts/evolution_levels.gd")
const Solver=preload("res://scripts/mutation_search.gd")
const Session=preload("res://scripts/evolution_session.gd")
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/pr22-"+id+".png")==OK,"capture "+id)
func run() -> void:
	game=Scene.instantiate()
	game.save_path="res://.godot/pr22-play-"+str(Time.get_ticks_usec())+".json"
	game.audio_settings_path=game.save_path+".cfg"
	root.add_child(game)
	game.music.handle_lifecycle=false
	game.music.set_volume("master",0)
	await process_frame
	await process_frame
	game.view.handle_back()
	game.view.preferences.hints=false
	game.view.preferences.save()
	var proofs={}
	for number in range(1,11):
		var state=Session.new()
		state.start(Levels.get_level(number))
		proofs[number]=Solver.solve(state)
	for tall in [false,true]:
		game.view.set_portrait(tall)
		root.size=Vector2i(G.design(tall))
		await process_frame
		await process_frame
		game.view.layout()
		var original=FileAccess.get_sha256(game.save_path)
		game.view.open_evolution()
		await process_frame
		var screen=game.view.experiment_ui
		for number in range(1,11):
			check(screen.start_trial(number),"UI trial "+str(number))
			var model=Session.new()
			model.start(Levels.get_level(number))
			var step=0
			for action in proofs[number].actions:
				if step==proofs[number].actions.size()-1 and number in [4,7,10]: await shot(("portrait" if tall else "landscape")+"-mechanics-%02d" % number)
				if action.kind=="spawn": press_button(screen.chrome.buttons.spawn,not tall)
				else:
					tap(screen,screen.center(action.source),not tall)
					tap(screen,screen.center(action.index),not tall)
				await create_timer(0.24).timeout
				check(model.apply_action(action).ok,"reference action")
				check(screen.session.signature()==model.signature(),"two taps execute exactly one reference action %d.%d %s" % [number,step,str(tall)])
				if screen.session.signature()!=model.signature(): quit(1); return
				step+=1
			check(screen.session.won() and is_instance_valid(screen.result_panel),"UI victory "+str(number))
			check(FileAccess.get_sha256(game.save_path)==original,"no permanent mutations from experiment "+str(number))
		await shot(("portrait" if tall else "landscape")+"-experimental-victory")
		screen.start_trial(4)
		var before=screen.session.signature()
		var touch=InputEventScreenTouch.new()
		touch.position=screen.get_global_transform_with_canvas()*screen.center(10); touch.pressed=true
		root.push_input(touch,true)
		touch=touch.duplicate(); touch.position=screen.get_global_transform_with_canvas()*screen.center(15); touch.pressed=false; touch.canceled=true
		root.push_input(touch,true)
		check(screen.session.signature()==before and screen.selected==-1,"canceled touch never executes a command")
		tap(screen,screen.center(10))
		tap(screen,screen.center(15))
		await create_timer(0.25).timeout
		press_button(screen.chrome.buttons.undo)
		check(screen.session.signature()==before and screen.history.remaining==1,"UI Undo")
		check(screen.completed.has(4),"Undo on replay keeps earlier successful completion")
		# Orientation switches must preserve both the attempt and a nonempty undo history.
		tap(screen,screen.center(10)); tap(screen,screen.center(15))
		await create_timer(.25).timeout
		before=screen.session.signature()
		game.view.show_panel("settings")
		var snapshots=screen.history.snapshots.size()
		game.view.set_portrait(not tall)
		check(game.view.experiment_ui==screen and screen.session.signature()==before and screen.history.remaining==1 and screen.history.snapshots.size()==snapshots,"orientation preserves attempt and history")
		game.view.handle_back()
		screen.leave()
		await process_frame
	game.free()
	print("Portrait evolution checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)