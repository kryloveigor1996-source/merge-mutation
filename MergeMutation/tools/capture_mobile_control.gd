extends "res://tests/landscape_ui_test.gd"
const G=preload("res://scripts/evolution_geometry.gd")
func run() -> void:
	game=Scene.instantiate(); game.save_path="res://.godot/pr22-fix-capture-"+str(Time.get_ticks_usec())+".json"; game.audio_settings_path=game.save_path+".cfg"
	root.add_child(game); game.music.handle_lifecycle=false; game.music.set_volume("master",0)
	await process_frame
	await process_frame
	press_button(game.view.story_screen.get_node("StorySkip")); game.view.preferences.hints=false
	for tall in [false,true]:
		game.view.set_portrait(tall); root.size=Vector2i(G.design(tall)); await process_frame; game.view.layout()
		game.view.open_evolution()
		var screen=game.view.experiment_ui
		for sample in [[4,10],[6,10],[7,10],[9,10]]:
			screen.start_trial(sample[0]); tap(screen,G.center(sample[1],tall))
			await create_timer(.15).timeout
			await RenderingServer.frame_post_draw
			var name="res://.godot/pr22-fix-%s-%d.png" % ["portrait" if tall else "landscape",sample[0]]
			check(root.get_texture().get_image().save_png(name)==OK,"capture "+name)
			screen.selected=-1
		screen.leave(); await process_frame
	game.free()
	print("Mobile capture checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
