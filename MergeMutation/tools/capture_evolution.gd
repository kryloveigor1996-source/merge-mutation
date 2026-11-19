extends "res://tests/landscape_ui_test.gd"
const G=preload("res://scripts/evolution_geometry.gd")
const Session=preload("res://scripts/evolution_session.gd")
const Levels=preload("res://scripts/evolution_levels.gd")
const Solver=preload("res://scripts/mutation_search.gd")
func run() -> void:
	var tall="--portrait" in OS.get_cmdline_user_args()
	root.size=Vector2i(G.design(tall)); root.content_scale_size=Vector2i(G.design(tall))
	var path="res://.godot/pr22-movie-"+str(Time.get_ticks_usec())+".json"
	var settings=ConfigFile.new()
	settings.set_value("presentation","portrait",tall)
	settings.set_value("tutorial","enabled",false)
	settings.set_value("audio","master",.5)
	settings.save(path+".cfg")
	game=Scene.instantiate(); game.save_path=path; game.audio_settings_path=path+".cfg"; root.add_child(game)
	game.music.handle_lifecycle=false; game.music.suspend(false)
	await process_frame
	await process_frame
	press_button(game.view.story_screen.get_node("StorySkip"))
	game.view.open_evolution()
	var screen=game.view.experiment_ui
	for number in [4,6,7,9,10]:
		screen.start_trial(number)
		var model=Session.new(); model.start(Levels.get_level(number))
		var proof=Solver.solve(model)
		await create_timer(.7).timeout
		for action in proof.actions:
			if action.kind=="spawn": press_button(screen.get_node("EvolutionSpawn"))
			else:
				tap(screen,G.center(action.source,tall))
				await create_timer(.12).timeout
				tap(screen,G.center(action.index,tall))
			await create_timer(.32).timeout
		check(screen.session.won(),"captured authentic UI solution")
		await create_timer(.7).timeout
	game.free()
	print("Evolution capture checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)